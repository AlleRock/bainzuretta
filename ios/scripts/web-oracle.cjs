/* Runs the original JS, including its real render functions, in a tiny DOM adapter.
   No copied statistical implementation: only capture hooks inside original functions. */
const fs = require('node:fs'), vm = require('node:vm'), crypto = require('node:crypto'), path = require('node:path');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const sha = crypto.createHash('sha256').update(source).digest('hex');
let js = source.match(/<script>([\s\S]*?)<\/script>/)[1];
js = js.replace('let maxVal = s.length', `window._ranking = s.map(y => ({year:+y,total:p[y].tot,value:m==='distanza'?p[y].d:m==='ponderata'?p[y].dW/(p[y].tSum||1):m==='dislivello'?p[y].dis:p[y].mSum/(p[y].c||1)})); let maxVal = s.length`);
js = js.replace("const paceBar = document.getElementById('pace-bar');", `window._home = {total:totK,km:kY,bestYear:bestY==='-'?null:+bestY,bestSpeed:maxAvg,remaining:mancanti,projection:Math.round((kY/Math.max(1,doyOggi))*giorniAnno),weekly:Math.ceil(mancanti/(giorniRimanenti/7))}; const paceBar = document.getElementById('pace-bar');`);
js = js.replace("const dateLabel = `${fmtGiornoNum(da)} – ${fmtGiornoNum(a)}`;", "const dateLabel = `${fmtGiornoNum(da)} – ${fmtGiornoNum(a)}`;"); // retained literal source
js = js.replace('const isCurrent = (lun === lunOggi);', 'const isCurrent = (lun === lunOggi); window._challenge.push({number:numRiga,from:da,to:a,quota,km:kmFatti,current:isCurrent});');
js = js.replace("const container = document.getElementById('lista-sfida');", "window._challenge=[]; const container = document.getElementById('lista-sfida');");
const categories = ['dist','vel','tempo','disliv','cad','cost','cur'];
const unescape = x => (x || '').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&');
function oracle(input) {
  const elements = {}, storage = new Map();
  function el(id) { return elements[id] ||= {value:'',innerHTML:'',innerText:'',style:{},className:'',options:categories.map(value=>({value})),parentElement:{scrollTop:0},classList:{add(){},remove(){}}}; }
  class FixedDate extends Date { constructor(...args){ super(...(args.length ? args : [input.now])); } static now(){return new Date(input.now).getTime();} }
  const context = {Date:FixedDate, console, TextDecoder, URLSearchParams, setTimeout(){}, navigator:{}, window:{}, document:{getElementById:el,addEventListener(){},querySelector:()=>el('small'),querySelectorAll:()=>[]}, localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,String(v)),removeItem:k=>storage.delete(k)},alert(){},confirm:()=>false};
  vm.createContext(context); vm.runInContext(js,context);
  context.input = input; vm.runInContext('rawData = validaArchivio(input.activities); myTarget=input.target;',context);
  vm.runInContext('aggiornaStats(); disegnaSfida();',context);
  const records = {};
  if(input.activities.length) for(const category of categories) {
    storage.set('bainzuretta_record_cat', category); vm.runInContext('disegnaRecords()',context);
    records[category] = context.window._recList.map(r=>({title:r.titolo,value:r.val ?? r.entries[0]?.val ?? '—',subtitle:r.sub||'',all:!!r.tutte,entries:r.entries.map(e=>({title:e.t,subtitle:unescape(e.sub),value:e.val,id:e.act?String(e.act.id):null}))}));
  } else for(const c of categories) records[c]=[];
  const ranking={};
  for(const m of ['distanza','ponderata','media','dislivello']) { el('metrica').value=m; vm.runInContext('disegnaClassifica()',context); ranking[m]=context.window._ranking; }
  const groups = vm.runInContext(`[gruppaMesi(rawData),gruppaSett(rawData)].map(list=>list.map(g=>({key:g.key,km:g.km,hours:g.ore,elevation:g.dislivello,count:g.count,ids:g.items.map(a=>String(a.id))})))`,context);
  context.stravaRaw = [1125,2675,2625,42501].map((distance,i)=>({id:90000+i,type:'Ride',distance,moving_time:900,start_date_local:'2026-01-01T00:01:00Z',start_date:'2025-12-31T23:01:00Z',name:'Arrotondamento '+i,average_cadence:null,total_elevation_gain:null}));
  const mapped = vm.runInContext('stravaRaw.map(attivitaDaStrava)',context);
  const stravaMappings = context.stravaRaw.map((raw,i)=>({raw,expected:mapped[i]}));
  return {stravaMappings,name:input.name,now:input.now,target:input.target,activities:vm.runInContext('rawData',context),sourceSHA256:sha,home:context.window._home,challenge:context.window._challenge,records,ranking,groups};
}
function act(id,date,km,hours,speed,extra={}) { return {id,data:date,distanza:km,tempo:hours,media:speed,...extra}; }
const boundary = [
 act(1,'2018-12-31T23:59:00Z',150,6,25,{dislivello:3000,cadenza:90}),
 act(2,'2019-01-01T00:01:00Z',100,4,25,{strava_id:123,nome:'Alba & <salita>',data_utc:'2018-12-31T23:01:00Z',dislivello:1000,cadenza:80}),
 act(3,'2020-02-29',60,2,30,{cadenza:100,dislivello:1200}),act(4,'2021-03-01',50,1.5,33.33,{cadenza:95,dislivello:600}),
 act(5,'2024-12-30T23:59:59-08:00',110,4,27.5,{cadenza:88,dislivello:2000}),
 act(6,'2025-01-05T00:01:00+14:00',49.99,2,24.995,{cadenza:85}),
 act('manuale_7','2026-01-01',0,0,0,{future:{flag:true,notes:['conservare']}}),
 act('0008','2026-01-04',30,1,30,{cadenza:99}),act(9,'2026-01-05',100,3.3333,30,{cadenza:90,dislivello:900}),
 act(10,'2026-02-28',59.99,3,0,{cadenza:70}),act(11,'2026-03-01',150,5,30,{cadenza:91}),
 act(12,'2026-03-02',50,1,50,{cadenza:105}),act(13,'2026-03-03',100,2,50,{cadenza:105}),act(14,'2026-03-04',25,1,25),
 act(15,'2026-03-05',20,0.8,25,{dislivello:1500}),act(16,'2026-03-06',19.99,1,19.99,{dislivello:9999}),
 {id:17,data:'2026-11-16T23:58:00Z',distanza:'42,5',media:'25.5',nome:null,dislivello:null,cadenza:null},
 {id:18,data:'2026-11-17',distanza:55,tempo:2},act(19,'2026-12-31',200,6,33.33,{cadenza:90})
];
let seed=82731; const random=()=>{seed=(seed*1664525+1013904223)>>>0; return seed/4294967296;};
const history=[];
for(let i=0;i<600;i++) { const d=new Date(Date.UTC(2017+Math.floor(random()*10),Math.floor(random()*12),1+Math.floor(random()*28),23,59)); const km=Math.round(random()*18000)/100, h=Math.round(random()*60000)/10000; history.push(act(1000+i,d.toISOString(),km,h,i%23===0?0:Math.round(km/(h||1)*100)/100,{nome:'Uscita '+i,dislivello:i%4===0?0:Math.round(random()*2200),cadenza:i%3===0?0:Math.round(random()*1100)/10})); }
const cases=[{name:'empty',activities:[],now:'2026-11-17T12:30:00Z',target:5000},
 {name:'boundaries',activities:boundary,now:'2026-11-17T12:30:00Z',target:5000},
 {name:'leap-year',activities:boundary,now:'2024-02-29T12:30:00Z',target:3000},
 {name:'january',activities:boundary,now:'2026-01-01T12:30:00Z',target:5000},
 {name:'december-achieved',activities:boundary,now:'2026-12-31T12:30:00Z',target:100},
 {name:'ten-years',activities:history,now:'2026-07-01T12:30:00Z',target:7500}];
const out=path.join(root,'ios/Tests/BainzurettaCoreTests/Fixtures/oracle.json');
fs.writeFileSync(out,JSON.stringify(cases.map(oracle),null,2)+'\n');
console.log(`Original JavaScript evaluated: ${cases.length} datasets, 7 categories, source SHA256 ${sha}`);
