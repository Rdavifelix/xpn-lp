import {adsRead,cleanAds,isAdsRead,readArgs} from './ads-read.ts';
const assert=(x:unknown,m='assertion failed')=>{if(!x)throw new Error(m);};
function fakeDb(extra:Record<string,any[]>={}){
 const rows:Record<string,any[]>={tenants:[{id:'t',is_active:true}],team_members:[{id:'m',tenant_id:'t',is_active:true}],zernio_accounts:[{id:'z1',tenant_id:'t',provider:'zernio',platform:'metaads',is_active:true,name:'Zernio'}],zernio_connections:[{tenant_id:'t',api_key:'TEST-Z-KEY'}],agents_provider_credentials:[],...extra};
 return {from(table:string){let data=rows[table]||[];const q:any={select:()=>q,eq:(k:string,v:unknown)=>{data=data.filter(x=>x[k]===v);return q;},maybeSingle:()=>Promise.resolve({data:data[0]||null}),then:(resolve:any)=>resolve({data})};return q;}};
}
Deno.test('Zernio scopes native account, period and GET insights; never exposes key',async()=>{
 const original=globalThis.fetch;const urls:string[]=[];globalThis.fetch=((url:any,init:any)=>{urls.push(String(url));assert(!init.method||init.method==='GET');assert(init.headers.Authorization==='Bearer TEST-Z-KEY');return Promise.resolve(Response.json(urls.length===1?{accounts:[{id:'act_123'}]}:{data:[{spend:'12.50'}]}));}) as typeof fetch;
 try{const r:any=await adsRead(fakeDb(),'t','m','consultar_metricas_meta_ads',{ad_account_id:'act_123',from_date:'2026-09-01',to_date:'2026-09-10'});assert(r.result.data[0].spend==='12.50');assert(urls[0].includes('accountId=z1'));assert(urls[1].includes('objectId=act_123'));assert(urls[1].includes('fromDate=2026-09-01'));assert(!JSON.stringify(r).includes('TEST-Z-KEY'));}finally{globalThis.fetch=original;}
});
Deno.test('Meta direct keeps credential and provides same insights operation',async()=>{
 const db=fakeDb({zernio_accounts:[],agents_provider_credentials:[{id:'c1',label:'Direta',tenant_id:'t',provider_type:'meta_ads',is_active:true,is_shared:true,auth_data:{token:'TEST-M-KEY'}}]});
 const original=globalThis.fetch;const urls:string[]=[];globalThis.fetch=((url:any,init:any)=>{urls.push(String(url));assert(init.headers.Authorization==='Bearer TEST-M-KEY');return Promise.resolve(Response.json(urls.length===1?{id:'act_123',name:'A'}:{data:[{clicks:'5'}],paging:{next:'https://graph.facebook.com?access_token=TEST-M-KEY',cursors:{after:'CURSOR'}}}));}) as typeof fetch;
 try{const r:any=await adsRead(db,'t','m','consultar_metricas_meta_ads',{connection_id:'meta:c1',ad_account_id:'act_123'});assert(r.connection.provider==='meta');assert(urls[1].includes('/act_123/insights?'));assert(urls[1].includes('date_preset=last_30d'));assert(!JSON.stringify(r).includes('TEST-M-KEY'));assert(r.result.paging.cursors.after==='CURSOR');}finally{globalThis.fetch=original;}
});
Deno.test('Ambiguous providers do not pick or contact either provider',async()=>{
 const db=fakeDb({agents_provider_credentials:[{id:'c1',label:'Direta',tenant_id:'t',provider_type:'meta_ads',is_active:true,is_shared:true}]});
 const r:any=await adsRead(db,'t','m','listar_contas_meta_ads',{});assert(r.selection_required&&r.connections.length===2);
});
Deno.test('Reject foreign connection, private credential, inactive tenant and invalid member before network',async()=>{
 for(const [db,t,m,args] of [[fakeDb(),'t','m',{connection_id:'zernio:foreign'}],[fakeDb({agents_provider_credentials:[{id:'private',tenant_id:'t',provider_type:'meta_ads',is_active:true,owner_user_id:'other',is_shared:false}]}),'t','m',{connection_id:'meta:private'}],[fakeDb(),'foreign','m',{}],[fakeDb(),'t','foreign',{}]] as const){let failed=false;try{await adsRead(db,t,m,'listar_contas_meta_ads',args);}catch{failed=true;}assert(failed);}
});
Deno.test('Zernio rejects ungranted ad account without querying insights',async()=>{
 const original=globalThis.fetch;let count=0;globalThis.fetch=(()=>{count++;return Promise.resolve(Response.json({accounts:[]}));}) as typeof fetch;
 try{const r:any=await adsRead(fakeDb(),'t','m','consultar_metricas_meta_ads',{ad_account_id:'act_999'});assert(r.selection_required);assert(count===1);}finally{globalThis.fetch=original;}
});
Deno.test('Provider error is not zero metrics and key is redacted',async()=>{
 const original=globalThis.fetch;globalThis.fetch=(()=>Promise.resolve(Response.json({message:'TEST-Z-KEY expired'},{status:401}))) as typeof fetch;
 try{let message='';try{await adsRead(fakeDb(),'t','m','listar_contas_meta_ads',{});}catch(e){message=(e as Error).message;}assert(message.includes('expired')&&!message.includes('TEST-Z-KEY'));}finally{globalThis.fetch=original;}
});
Deno.test('Date validation, output redaction and exact playground allowlist',()=>{
 for(const args of [{from_date:'2026-02-30',to_date:'2026-03-01'},{limit:200},{level:'delete'},{from_date:'2026-01-01'}]){let fail=false;try{readArgs(args);}catch{fail=true;}assert(fail);}
 assert(!JSON.stringify(cleanAds({nested:{access_token:'secret',paging:{next:'secret'}}})).includes('secret'));
 assert(isAdsRead({name:'listar_contas_meta_ads',action_type:'edge_function',action_config:{name:'ads-read'}}));
 assert(!isAdsRead({name:'arbitrary_write',action_type:'edge_function',action_config:{name:'ads-read'}}));
});

Deno.test('Account discovery ignores invented account and report filters',async()=>{
 const original=globalThis.fetch;let requested='';globalThis.fetch=((url:any)=>{requested=String(url);return Promise.resolve(Response.json({accounts:[{id:'act_123',name:'Real account'}]}));}) as typeof fetch;
 try{const result:any=await adsRead(fakeDb(),'t','m','listar_contas_meta_ads',{ad_account_id:'act_0',from_date:'invalid',level:'invalid'});assert(result.accounts[0].id==='act_123');assert(!requested.includes('adAccountId'));assert(requested.includes('accountId=z1'));}finally{globalThis.fetch=original;}
});
