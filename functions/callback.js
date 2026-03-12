export async function onRequest(context) {
  const url = new URL(context.request.url);
  const code = url.searchParams.get("code");
  const error = url.searchParams.get("error");

  if (error || !code) {
    return Response.redirect("https://bainzuretta.pages.dev/?auth=error", 302);
  }

  const clientId = context.env.STRAVA_CLIENT_ID;
  const clientSecret = context.env.STRAVA_CLIENT_SECRET;

  // Scambia il code con i token
  const tokenRes = await fetch("https://www.strava.com/oauth/token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: clientId,
      client_secret: clientSecret,
      code: code,
      grant_type: "authorization_code"
    })
  });

  if (!tokenRes.ok) {
    return Response.redirect("https://bainzuretta.pages.dev/?auth=error", 302);
  }

  const tokenData = await tokenRes.json();

  // Salva i token nel KV
  await context.env.BAINZURETTA_DATA.put("strava_tokens", JSON.stringify({
    access_token: tokenData.access_token,
    refresh_token: tokenData.refresh_token,
    expires_at: tokenData.expires_at,
    athlete_id: tokenData.athlete.id,
    athlete_name: tokenData.athlete.firstname
  }));

  return Response.redirect("https://bainzuretta.pages.dev/?auth=success", 302);
}
