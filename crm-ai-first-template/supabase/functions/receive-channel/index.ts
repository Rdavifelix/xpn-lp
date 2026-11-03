import {createClient} from 'npm:@supabase/supabase-js@2.49.8';
const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'content-type,x-api-key,x-request-id','Access-Control-Allow-Methods':'POST,OPTIONS','Cache-Control':'no-store','Content-Type':'application/json'};
const response=(body:unknown,status=200)=>new Response(JSON.stringify(body),{headers,status});
const uuid=(x:string|null)=>!!x&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(x);
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return response({error:'Use POST com JSON'},405);
 try{
  const key=req.headers.get('x-api-key')||new URL(req.url).searchParams.get('key');const requestId=req.headers.get('x-request-id');
  if(!uuid(key)||!uuid(requestId))return response({error:'URL/chave válida e cabeçalho X-Request-Id UUID obrigatórios'},400);
  if(Number(req.headers.get('content-length')||0)>50000)return response({error:'Payload excede 50 KB'},413);
  const raw=await req.text();if(new TextEncoder().encode(raw).length>50000)return response({error:'Payload excede 50 KB'},413);
  const payload=JSON.parse(raw);
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const {data,error}=await db.rpc('inbound_receive',{p_token:key,p_request_id:requestId,p_payload:payload});
  if(error)return response({error:['22023','P0002','P0001'].includes(error.code)?error.message:'Não foi possível processar o envio'},error.code==='P0002'?404:error.code==='P0001'?429:400);
  return response(data,data.ok?200:422);
 }catch{return response({error:'JSON inválido ou envio não confirmado. Reutilize o mesmo X-Request-Id ao repetir.'},400);}
});
