import {createClient} from 'npm:@supabase/supabase-js@2.49.8';
import {syncSocialMetrics} from './worker.ts';
const headers={'Content-Type':'application/json','Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,x-client-info,content-type,x-supabase-client-platform,x-supabase-client-platform-version,x-supabase-client-runtime,x-supabase-client-runtime-version','Access-Control-Allow-Methods':'POST, OPTIONS'};


Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return Response.json({error:'POST obrigatório'},{status:405,headers});
 try{
 const auth=req.headers.get('Authorization')||'';
 const user=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
 const {data:ctx,error}=await user.rpc('zernio_context');if(error||!ctx?.can_write)return Response.json({error:'Administrador ativo obrigatório'},{status:403,headers});
 const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}}),tid=ctx.tenant_id;
 return Response.json(await syncSocialMetrics(db,tid),{headers});
 }catch{return Response.json({error:'Não foi possível sincronizar. Verifique sua conexão de redes sociais.'},{status:500,headers});}
});
