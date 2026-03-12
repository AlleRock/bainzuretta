export async function onRequest(context) {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Content-Type": "application/json"
  };

  if (context.request.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  // GET: leggi tutti i dati
  if (context.request.method === "GET") {
    const activitiesRaw = await context.env.BAINZURETTA_DATA.get("activities");
    const tokensRaw = await context.env.BAINZURETTA_DATA.get("strava_tokens");
    const activities = activitiesRaw ? JSON.parse(activitiesRaw) : [];
    const authenticated = !!tokensRaw;
    const athleteName = tokensRaw ? JSON.parse(tokensRaw).athlete_name : null;

    return new Response(JSON.stringify({ activities, authenticated, athlete_name: athleteName }), { headers: corsHeaders });
  }

  // POST: salva dati aggiornati (inserimento manuale, modifica, cancellazione)
  if (context.request.method === "POST") {
    const body = await context.request.json();
    await context.env.BAINZURETTA_DATA.put("activities", JSON.stringify(body.activities));
    return new Response(JSON.stringify({ success: true }), { headers: corsHeaders });
  }

  return new Response("Method not allowed", { status: 405, headers: corsHeaders });
}
