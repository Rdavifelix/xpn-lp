import {createClient} from 'npm:@supabase/supabase-js@2.49.8';
import {getUazapiAdmin} from '../_shared/uazapi-config.ts';
import {connection,uazapi,webhookMatches} from './provider.ts';
const headers={'Content-Type':'application/json','Cache-Control':'no-store'};
const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers});
const uuid=(v:unknown)=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
Deno.serve(async req=>{
 if(req.method!=='POST')return reply({error:'Método inválido'},405);
 try{
  const bearer=req.headers.get('Authorization');if(!bearer?.startsWith('Bearer '))return reply({error:'Autenticação obrigatória'},401);
  const url=Deno.env.get('SUPABASE_URL')!;
  const user=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:bearer}},auth:{persistSession:false,autoRefreshToken:false}});
  const {data:ctx,error}=await user.rpc('mcp_context');
  if(error||!ctx?.can_write)return reply({error:'Conexão MCP de administrador ativo obrigatória'},403);
  const raw=await req.text();if(raw.length>4000)return reply({error:'Payload muito grande'},413);
  const b=JSON.parse(raw);
  const fields:Record<string,string[]>={list:['action'],create:['action','name','request_id'],connect:['action','instance_id'],status:['action','instance_id'],bind:['action','instance_id','agent_id','active']};
  if(!fields[b.action]||Object.keys(b).some(k=>!fields[b.action].includes(k)))return reply({error:'Ação/campos inválidos'},400);
  const db=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
  const admin=async(action:string,data:unknown)=>{
   const r=await db.rpc('mcp_whatsapp_admin',{p_tenant_id:ctx.tenant_id,p_user_id:ctx.user_id,p_action:action,p_data:data});
   if(r.error)throw new Error('Configuração recusada: '+r.error.message.slice(0,250));return r.data;
  };
  if(b.action==='list'){
   const [rows,connection]=await Promise.all([db.from('whatsapp_instances').select('id,name,status,phone_number,purpose').eq('tenant_id',ctx.tenant_id).order('created_at'),getUazapiAdmin(db,ctx.tenant_id)]);
   if(rows.error)throw new Error('Não foi possível listar as instâncias');
   const routes=await db.from('agents_deployments').select('id,agent_id,is_active,config').eq('tenant_id',ctx.tenant_id).eq('channel','whatsapp');
   if(routes.error)throw new Error('Não foi possível consultar os canais');
   return reply({instances:rows.data,configured:connection.configured,connection_source:connection.source,deployments:routes.data.map(d=>({id:d.id,agent_id:d.agent_id,active:d.is_active,instance_id:d.config?.instance_id??null})),setup_path:'/configuracoes',instructions:'A conexão incluída do SaaS é usada por padrão. Conexão própria opcional em Configurações > WhatsApp; não envie segredos no chat. Estados desta lista são locais; consultar_conexao_whatsapp atualiza pelo provedor.'});
  }
  if(b.action==='create'){
   if(!uuid(b.request_id)||typeof b.name!=='string'||!b.name.trim()||b.name.length>100)return reply({error:'Nome/request_id inválido'},400);
   const {base,key}=await getUazapiAdmin(db,ctx.tenant_id);
   if(!base||!key)return reply({error:'Configure a URL e o Admin Token da Uazapi em Configurações > Integrações > API Keys.',code:'uazapi_not_configured'},400);
   const state=await admin('reserve',{request_id:b.request_id,name:b.name.trim()});
   if(state.instance_id)return reply({instance_id:state.instance_id,reused:true,next:'gerar_qrcode_whatsapp'});
   let provider:any;
   if(state.should_create){
    provider=await uazapi(base,key,'/instance/create',{name:b.name.trim(),adminField01:ctx.tenant_id,adminField02:b.request_id},true);
   }else{
    // Uncertain requests never blindly create again. Recover only our exact tagged record.
    const all=await uazapi(base,key,'/instance/all',undefined,true);
    const matches=(Array.isArray(all)?all:[]).filter(i=>i.adminField01===ctx.tenant_id&&i.adminField02===b.request_id);
    if(matches.length!==1)return reply({error:'Criação anterior ainda não confirmada. Nenhuma nova instância foi criada; mantenha o request_id e confira a Uazapi.',code:'creation_unconfirmed'},409);
    provider={instance:matches[0],token:matches[0].token};
   }
   const token=provider.token??provider.instance?.token;
   if(typeof token!=='string'||!token)return reply({error:'Uazapi não retornou o token. Mantenha o request_id para recuperar a criação.'},502);
   const saved=await admin('finish',{request_id:b.request_id,api_url:base,token,provider_id:provider.instance?.id});
   return reply({...saved,next:'gerar_qrcode_whatsapp',connected:false});
  }
  if(!uuid(b.instance_id))return reply({error:'instance_id inválido'},400);
  const {data:inst,error:ie}=await db.from('whatsapp_instances').select('id,api_url,api_key').eq('id',b.instance_id).eq('tenant_id',ctx.tenant_id).maybeSingle();
  if(ie||!inst)return reply({error:'Instância não encontrada nesta empresa'},404);
  if(!inst.api_url||!inst.api_key)return reply({error:'Instância sem credenciais; configure na tela de integrações.'},400);
  const webhookUrl=`${url}/functions/v1/whatsapp-webhook?token=${encodeURIComponent(inst.api_key)}`;
  if(b.action==='bind'&&(!uuid(b.agent_id)||typeof b.active!=='boolean'))return reply({error:'agent_id/active inválidos'},400);
  if(b.action==='bind'&&!b.active)return reply(await admin('bind',b));
  if(b.action==='connect'){
   await uazapi(inst.api_url,inst.api_key,'/webhook',{enabled:true,url:webhookUrl,events:['messages','messages_update','connection','groups','contacts','call','chats'],excludeMessages:['wasSentByApi'],addUrlEvents:false});
  }
  const current=connection(await uazapi(inst.api_url,inst.api_key,'/instance/status'));
  const state=b.action==='connect'&&!current.connected?connection(await uazapi(inst.api_url,inst.api_key,'/instance/connect',{})):current;
  const updated=await db.from('whatsapp_instances').update({status:state.status,phone_number:state.phone_number,updated_at:new Date().toISOString()}).eq('id',inst.id).eq('tenant_id',ctx.tenant_id);
  if(updated.error)throw new Error('Estado do provedor recebido, mas não foi possível salvá-lo. Consulte novamente.');
  const webhook=webhookMatches(await uazapi(inst.api_url,inst.api_key,'/webhook'),webhookUrl);
  if(b.action==='bind'){
   if(!state.connected||!webhook)return reply({error:'Conecte a instância e configure o webhook com gerar_qrcode_whatsapp antes de ativar o atendimento.',connected:state.connected,webhook_ready:webhook},409);
   return reply(await admin('bind',b));
  }
  return reply({instance_id:inst.id,...state,webhook_ready:webhook,delivery_tested:false,instructions:state.connected?'Conectado. Vincule o agente validado com vincular_whatsapp_agente.':'Abra WhatsApp > Aparelhos conectados > Conectar um aparelho e escaneie o QR. Consulte o estado; se o QR expirar, gere outro. Não guarde o QR em prompts/planos.'});
 }catch(e){
  const msg=e instanceof Error?e.message:'';
  return reply({error:msg.startsWith('Uazapi ')||msg.startsWith('Configuração recusada:')?msg:'Operação não confirmada. Consulte o estado; na criação, repita com o mesmo request_id.'},502);
 }
});
