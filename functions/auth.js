export async function onRequest(context) {
  const clientId = context.env.STRAVA_CLIENT_ID;
  const redirectUri = `https://bainzuretta.pages.dev/functions/callback`;
  const scope = "activity:read_all";
  const url = `https://www.strava.com/oauth/authorize?client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}&response_type=code&scope=${scope}`;
  return Response.redirect(url, 302);
}
