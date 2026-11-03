import {socialSend,normalizeSocialEvent} from '../_shared/social-provider.ts';
export async function processEvent(db:any,event:any){
 try{
  const {data:source}=await db.from('zernio_accounts').select('platform').eq('id',event.payload?.account?.accountId).eq('tenant_id',event.tenant_id).maybeSingle();
  const normalized=source?.platform==='instagram'&&['message.received','message.sent','comment.received'].includes(event.event)?normalizeSocialEvent(event.payload):null;
  const {data:work,error}=normalized?await db.rpc('social_ingest_event',{p_event:event.id,p_normalized:normalized}):await db.rpc('zernio_ingest',{p_event_id:event.id});if(error)throw new Error(error.message);if(!work)return;
  const {account:a,conversation:c,message}=work;
  const {data:agent}=await db.from('agents_registry').select('id,is_active,tenant_id').eq('id',a.agent_id).eq('tenant_id',event.tenant_id).maybeSingle();
  const {data:member}=await db.from('team_members').select('id').eq('id',a.member_id).eq('tenant_id',event.tenant_id).eq('is_active',true).maybeSingle();
  if(!agent?.is_active||!member)throw new Error('Agente ou responsável inativo');
  const sk=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,url=Deno.env.get('SUPABASE_URL')!;
  const r=await fetch(url+'/functions/v1/agent-runner',{method:'POST',headers:{Authorization:'Bearer '+sk,'Content-Type':'application/json'},body:JSON.stringify({agent_id:a.agent_id,user_id:member.id,channel:a.platform,session_id:c.session_id||undefined,message,context:{lead_id:c.lead_id,deal_id:c.deal_id,social_account_id:a.id,social_conversation_id:c.remote_id,skip_debounce:true}}),signal:AbortSignal.timeout(150000)});
  if(!r.ok)throw new Error('Agente recusou atendimento');
  const stream=await r.text();const events=stream.split('\n').filter(l=>l.startsWith('data: ')).map(l=>{try{return JSON.parse(l.slice(6));}catch{return {};}});
  const session=events.find(e=>e.type==='session.info')?.session_id;
  if(session)await db.from('zernio_conversations').update({session_id:session}).eq('id',c.id).eq('tenant_id',event.tenant_id);
  if(events.some(e=>e.type==='error')||!events.some(e=>e.type==='done'))throw new Error('Agente não concluiu; consulte sua execução antes de repetir');
  const text=events.filter(e=>e.type==='text.delta').map(e=>e.delta||'').join('');if(!text.trim())throw new Error('Agente não produziu resposta');
  const {data:current}=await db.from('zernio_accounts').select('automation_active').eq('id',a.id).eq('tenant_id',event.tenant_id).single();
  const {data:conn}=await db.from('zernio_connections').select('api_key').eq('tenant_id',event.tenant_id).single();
  if(!current?.automation_active)throw new Error('Atendimento pausado antes do envio');
  await db.from('zernio_events').update({status:'sending'}).eq('id',event.id);
  const result=await socialSend(db,a,{action:'send',conversation_id:c.remote_id,message:text,request_id:event.id});
  if(result.data?.partialFailure)throw new Error('Envio parcial; consulte histórico');
  await db.from('zernio_events').update({status:'completed',processed_at:new Date().toISOString()}).eq('id',event.id);
 }catch(e){await db.from('zernio_events').update({status:'needs_attention',error:(e instanceof Error?e.message:'Falha no atendimento').slice(0,300)}).eq('id',event.id);}
}
