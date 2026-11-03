import {createClient} from 'npm:@supabase/supabase-js@2.49.8';
import {processEvent} from './worker.ts';
declare const EdgeRuntime:{waitUntil(p:Promise<unknown>):void};
import {validSignature} from './signature.ts';
Deno.serve(async req=>{
 if(req.method!=='POST')return new Response('POST required',{status:405});
 try{
  const token=new URL(req.url).searchParams.get('connection');if(!token||! /^[0-9a-f-]{36}$/i.test(token))return new Response('Not found',{status:404});
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const {data:conn}=await db.from('zernio_connections').select('tenant_id,webhook_secret').eq('webhook_token',token).maybeSingle();
  if(!conn)return new Response('Not found',{status:404});
  const {data:tenant}=await db.from('tenants').select('is_active').eq('id',conn.tenant_id).single();if(!tenant?.is_active)return new Response('Inactive',{status:403});
  if(Number(req.headers.get('Content-Length'))>200000)return new Response('Too large',{status:413});
  const raw=await req.text();if(raw.length>200000)return new Response('Too large',{status:413});
  if(!await validSignature(raw,conn.webhook_secret,req.headers.get('X-Zernio-Signature')||''))return new Response('Invalid signature',{status:401});
  const body=JSON.parse(raw);
  if(body.kind==='drain'){
   if(!Number.isFinite(Date.parse(body.timestamp))||Math.abs(Date.now()-Date.parse(body.timestamp))>300000)return new Response('Expired',{status:401});
   const {data:pending}=await db.from('zernio_events').select('*').eq('tenant_id',conn.tenant_id).eq('status','pending').order('created_at').limit(5);
   EdgeRuntime.waitUntil((async()=>{for(const ev of pending||[])await processEvent(db,ev);})());return new Response('Queued',{status:202});
  }
  if(typeof body.id!=='string'||body.id.length>100||typeof body.event!=='string')return new Response('Invalid event',{status:400});
  const {data:event,error}=await db.from('zernio_events').insert({tenant_id:conn.tenant_id,remote_id:body.id,event:body.event,payload:body}).select('*').single();
  if(error){if(error.code==='23505')return new Response('Duplicate',{status:200});throw error;}
  EdgeRuntime.waitUntil(processEvent(db,event));return new Response('Accepted',{status:202});
 }catch{return new Response('Unable to accept',{status:500});}
});
