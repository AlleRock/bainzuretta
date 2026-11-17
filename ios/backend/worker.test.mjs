import {test} from 'node:test';
import assert from 'node:assert/strict';
import {handle} from './worker.mjs';
const env={STRAVA_CLIENT_ID:'210700',STRAVA_CLIENT_SECRET:'unit-test-only',PAIRING_KEY:'test-pairing',STATE_SIGNING_KEY:'test-signing-key-at-least-32-characters'};
const base='https://broker.example';
const verifier='a'.repeat(43), appState='b'.repeat(43);
const challenge=Buffer.from(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(verifier))).toString('base64url');
const post=(path,body,key=env.PAIRING_KEY)=>new Request(base+path,{method:'POST',headers:{Authorization:'Bearer '+key},body:JSON.stringify(body)});
test('OAuth start, signed state, native callback, proof-bound exchange',async()=>{
 const start=await handle(post('/start',{appState,challenge}),env), data=await start.json(); assert.equal(start.status,200);
 const auth=new URL(data.url); assert.equal(auth.hostname,'www.strava.com'); assert.equal(auth.searchParams.get('redirect_uri'),base+'/callback');
 const cb=await handle(new Request(base+'/callback?'+new URLSearchParams({code:'test-code',scope:'activity:read_all',state:data.state})),env);
 assert.equal(cb.status,302); assert.equal(new URL(cb.headers.get('Location')).protocol,'bainzuretta:');
 const upstream=async(url,req)=>{const b=JSON.parse(req.body);assert.equal(b.client_secret,env.STRAVA_CLIENT_SECRET);assert.equal(b.code,'test-code');return Response.json({access_token:'a',refresh_token:'r',expires_at:2000000000});};
 const token=await handle(post('/exchange',{code:'test-code',state:data.state,verifier}),env,upstream); assert.equal(token.status,200); assert.equal((await token.json()).access_token,'a');
 assert.equal((await handle(post('/exchange',{code:'test-code',state:data.state,verifier:'c'.repeat(43)}),env,upstream)).status,400);
 assert.equal((await handle(new Request(base+'/callback?state=tampered'),env)).status,400);
});
test('pairing, no open redirect, scope, refresh errors and malformed upstream',async()=>{
 assert.equal((await handle(post('/start',{appState,challenge},'wrong'),env)).status,401);
 const {state}=await(await handle(post('/start',{appState,challenge}),env)).json();
 const cb=await handle(new Request(base+'/callback?'+new URLSearchParams({state,code:'c',scope:'read',redirect_uri:'https://attacker.example'})),env);
 assert.equal(new URL(cb.headers.get('Location')).searchParams.get('error'),'scope');
 for(const status of [401,429,500]) assert.equal((await handle(post('/refresh',{refresh_token:'r'}),env,async()=>new Response('',{status}))).status,status===500?502:status);
 assert.equal((await handle(post('/refresh',{refresh_token:'r'}),env,async()=>Response.json({}))).status,502);
 assert.equal((await handle(post('/refresh',{refresh_token:'r'}),env,async()=>{throw Error('offline');})).status,502);
 assert.equal((await handle(post('/start',{appState,challenge}),{})).status,503);
});
