import {createClient} from 'npm:@supabase/supabase-js@2.49.8';
const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'content-type, apikey, authorization','Access-Control-Allow-Methods':'GET, POST, OPTIONS','Content-Type':'application/json','Cache-Control':'no-store'};
const respond=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers});
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(!['GET','POST'].includes(req.method))return respond({error:'Método inválido'},405);
 const id=new URL(req.url).searchParams.get('id');
 if(!id||! /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id))return respond({error:'Formulário inválido'},400);
 try{
  if(req.method==='GET'){
   const {data,error}=await db.rpc('forms_public_get',{p_id:id});
   if(error||!data)return respond({error:'Formulário indisponível'},404);
   return respond(data);
  }
  const reader=req.body?.getReader();if(!reader)return respond({error:'Envio vazio'},400);
  let size=0;const chunks:Uint8Array[]=[];
  while(true){const {value,done}=await reader.read();if(done)break;size+=value.length;if(size>65000){await reader.cancel();return respond({error:'Envio muito grande'},413);}chunks.push(value);}
  const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length;}
  const body=JSON.parse(new TextDecoder().decode(bytes));
  if(body.website)return respond({ok:true});
  if(Object.keys(body).some(k=>!['request_id','values','tracking','website'].includes(k)))return respond({error:'Envio inválido'},400);
  const ip=req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()||'unknown';
  const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!),{name:'HMAC',hash:'SHA-256'},false,['sign']);
  const hash=Array.from(new Uint8Array(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(ip)))).map(b=>b.toString(16).padStart(2,'0')).join('');
  const {data,error}=await db.rpc('forms_public_submit',{p_id:id,p_request_id:body.request_id,p_values:body.values,p_tracking:body.tracking??{},p_client_hash:hash});
  if(error)return respond({error:['22023','P0002','P0001'].includes(error.code)?error.message:'Não foi possível enviar agora.'},error.code==='P0002'?404:error.code==='P0001'?429:400);
  return respond(data);
 }catch{return respond({error:'Não foi possível processar o envio.'},400);}
});
