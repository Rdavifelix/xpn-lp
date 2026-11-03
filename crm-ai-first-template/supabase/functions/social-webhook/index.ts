import {createClient} from 'npm:@supabase/supabase-js@2.49.8';
import {validSignature} from '../zernio-webhook/signature.ts';
import {hash} from '../zernio-api/provider.ts';
import {processEvent} from '../zernio-webhook/worker.ts';
declare const EdgeRuntime:{waitUntil(p:Promise<unknown>):void};
Deno.serve(async req=>{
 try{
  const u=new URL(req.url),token=u.searchParams.get('connection');if(!token||!/^[0-9a-f-]{36}$/i.test(token))return new Response('Not found',{status:404});
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const {data:s}=await db.from('social_provider_secrets').select('*').eq('webhook_token',token).maybeSingle();if(!s)return new Response('Not found',{status:404});
  const {data:a}=await db.from('zernio_accounts').select('*').eq('id',s.account_id).eq('tenant_id',s.tenant_id).eq('is_active',true).single();
  const {data:t}=await db.from('tenants').select('is_active').eq('id',s.tenant_id).single();if(!a||!t?.is_active)return new Response('Inactive',{status:403});
  if(req.method==='GET')return u.searchParams.get('hub.mode')==='subscribe'&&u.searchParams.get('hub.verify_token')===s.verify_token?new Response(u.searchParams.get('hub.challenge')||''):new Response('Invalid verification',{status:403});
  if(req.method!=='POST')return new Response('POST required',{status:405});
  const raw=await req.text();if(raw.length>200000)return new Response('Too large',{status:413});
  if(!await validSignature(raw,s.app_secret,(req.headers.get('x-hub-signature-256')||'').replace(/^sha256=/,'')))return new Response('Invalid signature',{status:401});
  const body=JSON.parse(raw),pending:any[]=[];
  if(body.kind==='drain'){
   if(!Number.isFinite(Date.parse(body.timestamp))||Math.abs(Date.now()-Date.parse(body.timestamp))>300000)return new Response('Expired',{status:401});
   const {data:events}=await db.from('zernio_events').select('*').eq('tenant_id',s.tenant_id).eq('status','pending').contains('payload',{account:{accountId:a.id}}).order('created_at').limit(5);
   EdgeRuntime.waitUntil((async()=>{for(const e of events||[])await processEvent(db,e);})());return new Response('Queued',{status:202});
  }
  for(const entry of body.entry||[]){
   if(String(entry.id)!==a.id.slice(5)&&String(entry.id)!==s.messaging_id)continue;
   for(const m of entry.messaging||[]){
    if(!m.message?.mid)continue;const outgoing=!!m.message.is_echo,person=outgoing?m.recipient?.id:m.sender?.id;if(!person)continue;
    pending.push({event:outgoing?'message.sent':'message.received',conversation:{id:String(person)},message:{id:m.message.mid,platformMessageId:m.message.mid,text:m.message.text||'',sentAt:new Date(m.timestamp||Date.now()).toISOString(),direction:outgoing?'outgoing':'incoming',sender:{id:String(person)},attachments:(m.message.attachments||[]).map((x:any)=>({type:x.type,url:x.payload?.url}))}});
   }
   for(const change of entry.changes||[]){
    if(!['comments','live_comments'].includes(change.field))continue;const c=change.value;if(!c?.id||!c.from?.id||!c.media?.id)continue;
    pending.push({event:'comment.received',comment:{id:c.id,platformPostId:c.media.id,text:c.text||'',author:{id:c.from.id,username:c.from.username,isOwnAccount:String(c.from.id)===a.id.slice(5)},parentCommentId:c.parent_id,createdAt:new Date((entry.time||Date.now()/1000)*1000).toISOString()}});
   }
  }
  const saved=[];
  for(const p of pending){const remote=await hash(a.id+':'+p.event+':'+(p.message?.id||p.comment?.id));const {data:e,error}=await db.from('zernio_events').insert({tenant_id:s.tenant_id,remote_id:remote,event:p.event,payload:{...p,id:remote,account:{accountId:a.id}}}).select('*').single();if(error&&error.code!=='23505')throw error;if(e)saved.push(e);}
  EdgeRuntime.waitUntil((async()=>{for(const e of saved)await processEvent(db,e);})());return new Response('Accepted',{status:202});
 }catch{return new Response('Unable to accept',{status:500});}
});
