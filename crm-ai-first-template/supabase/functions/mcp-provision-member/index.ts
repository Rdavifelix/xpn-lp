import {crmPublicUrl} from '../_shared/public-url.ts';
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {createClient} from 'npm:@supabase/supabase-js@2.49.8';
const headers={'Content-Type':'application/json','Cache-Control':'no-store'};
const response=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers});
Deno.serve(async req=>{
 if(req.method!=='POST')return response({error:'Método inválido'},405);
 try{
  const bearer=req.headers.get('Authorization');if(!bearer?.startsWith('Bearer '))return response({error:'Autenticação obrigatória'},401);
  const url=Deno.env.get('SUPABASE_URL')!;
  const client=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:bearer}},auth:{persistSession:false,autoRefreshToken:false}});
  const {data:ctx,error:ce}=await client.rpc('mcp_context');
  if(ce||!ctx?.can_write)return response({error:'Conexão MCP administrativa obrigatória'},403);
  if(Number(req.headers.get('content-length')||0)>12000)return response({error:'Payload muito grande'},413);
  const raw=await req.text();if(raw.length>12000)return response({error:'Payload muito grande'},413);
  const args=JSON.parse(raw);
  if(Object.keys(args).some(k=>!['request_id','data'].includes(k)))return response({error:'Campos inválidos'},400);
  const {error:reserveError}=await client.rpc('mcp_team',{p_action:'provision',p_request_id:args.request_id,p_data:args.data});
  if(reserveError)return response({error:reserveError.message},400);
  const admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
  const finish=()=>admin.rpc('team_provision_finish',{p_tenant_id:ctx.tenant_id,p_request_id:args.request_id});
  let state=await finish();if(state.error)throw state.error;
  if(state.data.needs_create){
   const {error}=await admin.auth.admin.createUser({email:args.data.email.toLowerCase(),password:crypto.randomUUID()+crypto.randomUUID(),email_confirm:true,user_metadata:{name:args.data.name},app_metadata:{tenant_id:ctx.tenant_id,team_request_id:args.request_id}});
   // A retry may find the user created by this same request; finish validates ownership.
   state=await finish();if(state.error||state.data.needs_create){if(error)return response({error:'Não foi possível criar o acesso. Confira o email e repita com o mesmo request_id.'},400);throw state.error||new Error('Provisionamento incompleto');}
  }
  if(state.data.access_already_used)return response({member:state.data.member,access_already_used:true,message:'Acesso já utilizado ou membro desativado; não foi gerado outro link.'});
  const redirectTo=crmPublicUrl()+'/reset-password';
  const {data:link,error:le}=await admin.auth.admin.generateLink({type:'recovery',email:state.data.email,options:{redirectTo}});
  if(le) return response({member:state.data.member,error:'Usuário criado; link ainda não gerado. Repita com o mesmo request_id.'},502);
  return response({member:state.data.member,access_url:link.properties.action_link,email_sent:false,instructions:'Link pessoal de primeiro acesso para definir a senha. Entregue apenas ao membro; não salve em planos nem envie sem autorização. Uma nova tentativa pode substituir o link anterior.'});
 }catch{return response({error:'Não foi possível concluir. Repita a mesma solicitação com o mesmo request_id.'},500);}
});
