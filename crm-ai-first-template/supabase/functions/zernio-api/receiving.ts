import {provider} from './provider.ts';
export async function ensureReceiving(db:any,tenant:string,conn:any,url:string,force=false){
 if(!force&&conn.webhook_id&&['configured','verified'].includes(conn.webhook_status))return {receiving_ready:true};
 const retryAfter=Date.now()-new Date(conn.updated_at).getTime();
 if(!force&&conn.webhook_status==='failed'&&retryAfter<60000)return {receiving_ready:false,receiving_pending:true};
 // Atomic lease prevents duplicate provisioning from simultaneous browser/MCP requests.
 const {data:claimed,error}=await db.from('zernio_connections').update({webhook_status:'configuring',updated_at:new Date().toISOString()}).eq('tenant_id',tenant).eq('key_hash',conn.key_hash).or(`webhook_status.neq.configuring,updated_at.lt.${new Date(Date.now()-120000).toISOString()}`).select('tenant_id').maybeSingle();
 if(error)throw new Error('Não foi possível preparar o recebimento');
 if(!claimed)return {receiving_ready:false,receiving_pending:true};
 try{
  const body={name:'CRM AI-First '+tenant.slice(0,8),url:url+'/functions/v1/zernio-webhook?connection='+conn.webhook_token,secret:conn.webhook_secret,events:['account.connected','account.disconnected','message.received','message.sent','comment.received','lead.received','post.published','post.failed']};
  const listed=await provider(conn.api_key,'/webhooks/settings');
  const all=listed.webhooks||listed.data;
  if(!Array.isArray(all))throw new Error('Lista de recebimentos inválida');
  const found=all.find((x:any)=>x.url===body.url);
  const result=await provider(conn.api_key,'/webhooks/settings',found?'PUT':'POST',{...body,isActive:true,...(found?{_id:found._id}:{})});
  const wid=result.webhook?._id||found?._id;
  if(!wid)throw new Error('Recebimento não confirmado');
  const saved=await db.from('zernio_connections').update({webhook_id:wid,webhook_status:'configured',updated_at:new Date().toISOString()}).eq('tenant_id',tenant).eq('key_hash',conn.key_hash).select('tenant_id').maybeSingle();
  if(saved.error||!saved.data)throw new Error('Não foi possível confirmar recebimento');
  return {receiving_ready:true};
 }catch{
  await db.from('zernio_connections').update({webhook_status:'failed',updated_at:new Date().toISOString()}).eq('tenant_id',tenant).eq('key_hash',conn.key_hash);
  return {receiving_ready:false,receiving_error:'A conta foi salva, mas o recebimento ainda não foi confirmado. Tentaremos novamente automaticamente.'};
 }
}
