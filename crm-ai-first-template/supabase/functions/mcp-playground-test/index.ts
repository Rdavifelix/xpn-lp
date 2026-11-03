declare const EdgeRuntime:{waitUntil(promise:Promise<unknown>):void};
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {createClient} from 'npm:@supabase/supabase-js@2.49.8';
Deno.serve(async req=>{
 const headers={'Content-Type':'application/json','Cache-Control':'no-store'};const reply=(x:unknown,s=200)=>new Response(JSON.stringify(x),{status:s,headers});
 if(req.method!=='POST')return reply({error:'POST obrigatório'},405);
 try{
  const url=Deno.env.get('SUPABASE_URL')!,key=Deno.env.get('SUPABASE_ANON_KEY')!,auth=req.headers.get('Authorization');if(!auth)return reply({error:'Autenticação obrigatória'},401);
  const client=createClient(url,key,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
  const raw=await req.text();if(raw.length>15000)return reply({error:'Teste muito grande'},413);
  const {request_id,...payload}=JSON.parse(raw);
  const {data:job,error}=await client.rpc('mcp_playground_job',{p_id:request_id,p_payload:payload});if(error)return reply({error:error.message},403);
  if(job.started){
   const admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
   EdgeRuntime.waitUntil((async()=>{
    const events:Record<string,unknown>[]=[];let pending='';let last=0;
    const save=async(status:string)=>{const {error}=await admin.rpc('playground_job_progress',{p_id:request_id,p_events:events,p_status:status});if(error)throw new Error('Falha ao salvar resultado');};
    try{
     const r=await fetch(url+'/functions/v1/agent-runner',{method:'POST',headers:{Authorization:auth,apikey:key,'Content-Type':'application/json'},body:JSON.stringify(payload),signal:AbortSignal.timeout(150000)});
     if(!r.ok||!r.body){const detail=await r.json().catch(()=>null);const message=typeof detail?.error==='string'?detail.error.slice(0,500):'Runner recusou o teste';events.push({type:'error',message,http_status:r.status});await save('failed');return;}
     const reader=r.body.getReader(),decoder=new TextDecoder();let size=0;
     while(true){const {value,done}=await reader.read();if(done)break;size+=value.length;if(size>700000){await reader.cancel();throw new Error('Resultado excedeu limite');}pending+=decoder.decode(value,{stream:true});const lines=pending.split('\n');pending=lines.pop()??'';for(const line of lines){if(line.startsWith('data: ')){try{events.push(JSON.parse(line.slice(6)));}catch{}}}if(Date.now()-last>3000){await save('running');last=Date.now();}}
     await save(events.some(e=>e.type==='error')?'failed':events.some(e=>e.type==='done')?'completed':'interrupted');
    }catch{events.push({type:'error',message:'Execução interrompida; consulte o histórico antes de repetir ações.'});await save('interrupted').catch(()=>{});}
   })());
  }
  return reply({...job,instructions:'Consulte consultar_teste_agente com test_id. Não repita a mensagem com outro request_id enquanto este teste estiver em execução.'},202);
 }catch{return reply({error:'Não foi possível iniciar o teste'},400);}
});
