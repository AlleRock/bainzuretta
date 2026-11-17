// Personal OAuth broker. No activity data, tokens or client secrets are logged/stored.
// Secrets: STRAVA_CLIENT_SECRET, PAIRING_KEY, STATE_SIGNING_KEY (>=32 random bytes).
const encoder = new TextEncoder();
const callback = 'bainzuretta://strava-callback';
function b64(bytes) { return btoa(String.fromCharCode(...bytes)).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,''); }
function bytes(text) { return Uint8Array.from(atob(text.replace(/-/g,'+').replace(/_/g,'/')),c=>c.charCodeAt(0)); }
async function signingKey(env) { return crypto.subtle.importKey('raw',encoder.encode(env.STATE_SIGNING_KEY),{name:'HMAC',hash:'SHA-256'},false,['sign','verify']); }
async function sign(payload, env) {
  const body=b64(encoder.encode(JSON.stringify(payload)));
  return body+'.'+b64(new Uint8Array(await crypto.subtle.sign('HMAC',await signingKey(env),encoder.encode(body))));
}
async function verify(state,env) {
  const [body,signature,...rest]=String(state||'').split('.');
  if(!body||!signature||rest.length||!await crypto.subtle.verify('HMAC',await signingKey(env),bytes(signature),encoder.encode(body))) throw new Error('state');
  const p=JSON.parse(new TextDecoder().decode(bytes(body)));
  if(!Number.isFinite(p.exp)||p.exp<Date.now()/1000||p.exp>Date.now()/1000+1805||!/^[-_A-Za-z0-9]{32,128}$/.test(p.appState)||!/^[-_A-Za-z0-9]{43}$/.test(p.challenge)) throw new Error('state');
  return p;
}
function json(body,status=200){return new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store','Referrer-Policy':'no-referrer','X-Content-Type-Options':'nosniff'}});}
async function authorized(request, env) {
  const supplied=encoder.encode(request.headers.get('Authorization')||''), expected=encoder.encode('Bearer '+env.PAIRING_KEY);
  // HMAC verify avoids comparing a private bearer secret using a timing-sensitive string comparison.
  const key=await signingKey(env), signature=await crypto.subtle.sign('HMAC',key,expected);
  return crypto.subtle.verify('HMAC',key,signature,supplied);
}
export async function handle(request, env, upstream=fetch) {
  const url=new URL(request.url);
  if(!env.STRAVA_CLIENT_SECRET||!env.PAIRING_KEY||!env.STATE_SIGNING_KEY||env.STATE_SIGNING_KEY.length<32||!/^\d+$/.test(env.STRAVA_CLIENT_ID||'')) return json({error:'configuration'},503);
  try {
    if(request.method==='GET' && url.pathname==='/callback') {
      const state=url.searchParams.get('state'); await verify(state,env);
      const destination=new URL(callback); destination.searchParams.set('state',state);
      const error=url.searchParams.get('error'), code=url.searchParams.get('code'), scope=url.searchParams.get('scope')||'';
      if(error) destination.searchParams.set('error','access_denied');
      else if(!scope.split(/[ ,]+/).includes('activity:read_all')) destination.searchParams.set('error','scope');
      else if(code && code.length<=1024) { destination.searchParams.set('code',code); destination.searchParams.set('scope',scope); }
      else return json({error:'callback'},400);
      return new Response(null,{status:302,headers:{Location:destination.href,'Cache-Control':'no-store','Referrer-Policy':'no-referrer'}});
    }
    if(request.method!=='POST') return json({error:'method'},405);
    if(!await authorized(request,env)) return json({error:'unauthorized'},401);
    if(Number(request.headers.get('Content-Length')||0)>8192) return json({error:'size'},413);
    const text=await request.text(); if(text.length>8192) return json({error:'size'},413);
    const body=JSON.parse(text);
    if(url.pathname==='/start') {
      if(!/^[-_A-Za-z0-9]{32,128}$/.test(body.appState)||!/^[-_A-Za-z0-9]{43}$/.test(body.challenge)) return json({error:'input'},400);
      const state=await sign({appState:body.appState,challenge:body.challenge,exp:Math.floor(Date.now()/1000)+1800},env);
      const auth=new URL('https://www.strava.com/oauth/authorize');
      for(const [key,value] of Object.entries({client_id:env.STRAVA_CLIENT_ID,response_type:'code',redirect_uri:url.origin+'/callback',approval_prompt:'auto',scope:'activity:read_all',state})) auth.searchParams.set(key,value);
      return json({url:auth.href,state});
    }
    if(url.pathname==='/revoke') {
      if(typeof body.token!=='string'||!body.token||body.token.length>2048) return json({error:'input'},400);
      let response;
      try { response=await upstream('https://www.strava.com/oauth/revoke',{method:'POST',headers:{Authorization:'Basic '+btoa(env.STRAVA_CLIENT_ID+':'+env.STRAVA_CLIENT_SECRET),'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({token:body.token,token_type_hint:'refresh_token'}).toString()}); } catch { return json({error:'upstream'},502); }
      if(!response.ok) return json({error:'revoke'},response.status===429?429:response.status>=500?502:401);
      return json({revoked:true});
    }
    let tokenBody;
    if(url.pathname==='/exchange') {
      const state=await verify(body.state,env);
      if(!/^[-_A-Za-z0-9]{43,128}$/.test(body.verifier)||b64(new Uint8Array(await crypto.subtle.digest('SHA-256',encoder.encode(body.verifier))))!==state.challenge||typeof body.code!=='string'||!body.code||body.code.length>1024) return json({error:'proof'},400);
      tokenBody={client_id:env.STRAVA_CLIENT_ID,client_secret:env.STRAVA_CLIENT_SECRET,grant_type:'authorization_code',code:body.code};
    } else if(url.pathname==='/refresh') {
      if(typeof body.refresh_token!=='string'||!body.refresh_token||body.refresh_token.length>2048) return json({error:'input'},400);
      tokenBody={client_id:env.STRAVA_CLIENT_ID,client_secret:env.STRAVA_CLIENT_SECRET,grant_type:'refresh_token',refresh_token:body.refresh_token};
    } else return json({error:'route'},404);
    let response;
    try { response=await upstream('https://www.strava.com/oauth/token',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(tokenBody)}); } catch { return json({error:'upstream'},502); }
    if(!response.ok) return json({error:response.status===429?'rate_limit':'strava_auth'},response.status===429?429:response.status>=500?502:401);
    let data; try { data=await response.json(); } catch { return json({error:'upstream'},502); }
    if(typeof data.access_token!=='string'||!data.access_token||typeof data.refresh_token!=='string'||!data.refresh_token||!Number.isFinite(data.expires_at)||data.expires_at<=0) return json({error:'upstream'},502);
    return json({access_token:data.access_token,refresh_token:data.refresh_token,expires_at:data.expires_at,athlete:data.athlete,scope:data.scope});
  } catch { return json({error:'invalid_request'},400); }
}
export default {fetch:handle};
