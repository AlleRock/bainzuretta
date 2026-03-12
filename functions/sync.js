export async function onRequest(context) {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Content-Type": "application/json"
  };

  if (context.request.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const clientId = context.env.STRAVA_CLIENT_ID;
    const clientSecret = context.env.STRAVA_CLIENT_SECRET;

    // Leggi i token salvati
    const tokensRaw = await context.env.BAINZURETTA_DATA.get("strava_tokens");
    if (!tokensRaw) {
      return new Response(JSON.stringify({ error: "not_authenticated" }), { status: 401, headers: corsHeaders });
    }

    let tokens = JSON.parse(tokensRaw);

    // Refresh token se scaduto
    if (Date.now() / 1000 > tokens.expires_at - 300) {
      const refreshRes = await fetch("https://www.strava.com/oauth/token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          client_id: clientId,
          client_secret: clientSecret,
          refresh_token: tokens.refresh_token,
          grant_type: "refresh_token"
        })
      });
      const refreshData = await refreshRes.json();
      tokens.access_token = refreshData.access_token;
      tokens.refresh_token = refreshData.refresh_token;
      tokens.expires_at = refreshData.expires_at;
      await context.env.BAINZURETTA_DATA.put("strava_tokens", JSON.stringify(tokens));
    }

    // Leggi i dati esistenti
    const existingRaw = await context.env.BAINZURETTA_DATA.get("activities");
    let existing = existingRaw ? JSON.parse(existingRaw) : [];

    // Trova la data dell'ultima attività per fare sync incrementale
    let afterTimestamp = 0;
    if (existing.length > 0) {
      const lastDate = existing
        .filter(a => a.strava_id) // solo quelle importate da Strava
        .sort((a, b) => new Date(b.data) - new Date(a.data))[0];
      if (lastDate) {
        afterTimestamp = Math.floor(new Date(lastDate.data).getTime() / 1000);
      }
    }

    // Scarica attività da Strava (solo bici)
    let page = 1;
    let nuove = [];
    const existingStravaIds = new Set(existing.filter(a => a.strava_id).map(a => a.strava_id));

    while (true) {
      let apiUrl = `https://www.strava.com/api/v3/athlete/activities?per_page=100&page=${page}`;
      if (afterTimestamp > 0) apiUrl += `&after=${afterTimestamp}`;

      const res = await fetch(apiUrl, {
        headers: { "Authorization": `Bearer ${tokens.access_token}` }
      });

      if (!res.ok) break;
      const activities = await res.json();
      if (!activities.length) break;

      for (const act of activities) {
        // Solo attività in bici e non già presenti
        if (!["Ride", "VirtualRide", "EBikeRide", "MountainBikeRide"].includes(act.type)) continue;
        if (existingStravaIds.has(act.id)) continue;

        const distKm = act.distance / 1000;
        const oreDec = act.moving_time / 3600;
        const media = oreDec > 0 ? distKm / oreDec : 0;

        nuove.push({
          id: act.id,
          strava_id: act.id,
          data: act.start_date_local,
          distanza: parseFloat(distKm.toFixed(2)),
          tempo: parseFloat(oreDec.toFixed(4)),
          media: parseFloat(media.toFixed(2)),
          nome: act.name || ""
        });
      }

      if (activities.length < 100) break;
      page++;
    }

    // Unisci e salva
    const merged = [...existing, ...nuove].sort((a, b) => new Date(b.data) - new Date(a.data));
    await context.env.BAINZURETTA_DATA.put("activities", JSON.stringify(merged));

    return new Response(JSON.stringify({
      success: true,
      nuove: nuove.length,
      totale: merged.length,
      activities: merged
    }), { headers: corsHeaders });

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders });
  }
}
