import {tryHandleViaAgentPlatform} from './agent-platform.ts';
const assert=(v:unknown)=>{if(!v)throw new Error('assertion failed');};
function database(entry:any,error:any=null){
 const writes:any[]=[];const calls:string[]=[];
 const db={rpc(name:string){calls.push(name);assert(name==='whatsapp_entry_resolve');return Promise.resolve({data:entry,error});},from(table:string){
 let inserting=false;const q:any={select:()=>q,eq:()=>q,contains:()=>q,order:()=>q,limit:()=>q,insert:(row:any)=>{writes.push({table,row});inserting=true;return q;},single:()=>Promise.resolve({data:{id:'session'}}),maybeSingle:()=>Promise.resolve({data:table==='whatsapp_instances'?{id:'inst',tenant_id:'tenant',api_url:'https://example.invalid',api_key:'synthetic'}:table==='agents_deployments'?{config:{access_mode:'open'}}:table==='agents_registry'?{settings:{humanization:{enabled:false}}}:null}),then:(fn:any)=>fn({data:inserting?{id:'session'}:null,error:null})};return q;
 }};return {db,writes,calls};
}
const args={instance:{id:'inst'},senderPhone:'5511999999999',text:'Quero conhecer',messageId:'message',leadId:'lead',tenantId:'tenant'};
Deno.test('Entry routes bound deal to runner, replies via instance and records inbox',async()=>{
 const {db,writes,calls}=database({agent_id:'agent',agent_slug:'bella',deployment_id:'dep',deal_id:'deal'});const requests:any[]=[];const original=globalThis.fetch;
 globalThis.fetch=((url:any,init:any)=>{requests.push({url:String(url),body:JSON.parse(init.body)});return Promise.resolve(String(url).includes('agent-runner')?new Response('data: {"type":"text.delta","delta":"Olá!"}\n\n',{headers:{'Content-Type':'text/event-stream'}}):Response.json({id:'outbound'}));}) as typeof fetch;
 try{assert(await tryHandleViaAgentPlatform({...args,supabase:db}));assert(calls.length===1);assert(requests[0].body.context.deal_id==='deal');assert(requests[0].body.context.instance_id==='inst');assert(requests[1].url==='https://example.invalid/send/text');assert(writes.some(x=>x.table==='whatsapp_messages'&&x.row.content==='Olá!'));assert(writes.find(x=>x.table==='agents_sessions').row.provider_state.external_session_key.includes('inst'));}finally{globalThis.fetch=original;}
});
Deno.test('Paused entry and invalid destination consume routing without legacy or sends',async()=>{
 for(const [entry,error] of [[{paused:true},null],[null,{message:'Destino indisponível'}]]){const {db,writes,calls}=database(entry,error);assert(await tryHandleViaAgentPlatform({...args,supabase:db}));assert(writes.length===0&&calls.length===1);}
});
Deno.test('Caller cannot override instance tenant',async()=>{const {db,calls}=database({});assert(!await tryHandleViaAgentPlatform({...args,supabase:db,tenantId:'foreign'}));assert(calls.length===0);});
