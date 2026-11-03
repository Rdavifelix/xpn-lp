import {crmPublicUrl} from './public-url.ts';
import {ensureReceiving} from '../zernio-api/receiving.ts';
import {adsRead,adsToolNames} from './ads-read.ts';
import {socialSend,metaRequest} from './social-provider.ts';
import {createClient} from 'npm:@supabase/supabase-js@2.49.8';
import {provider,ProviderError,safe,hash,platforms,connectPath} from '../zernio-api/provider.ts';
const headers={'Content-Type':'application/json','Cache-Control':'no-store','Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,x-client-info,content-type,x-supabase-client-platform,x-supabase-client-platform-version,x-supabase-client-runtime,x-supabase-client-runtime-version,x-supabase-client-version','Access-Control-Allow-Methods':'POST, OPTIONS'};
const reply=(b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers});
const id=(v:unknown)=>typeof v==='string'&&v.length>0&&v.length<500;
export async function socialApi(req:Request){
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});if(req.method!=='POST')return reply({error:'POST obrigatório'},405);
 let db:any,tid:string|undefined,op:string|undefined;
 try{
  const url=Deno.env.get('SUPABASE_URL')!,auth=req.headers.get('Authorization');if(!auth)return reply({error:'Entre na sua conta'},401);
  const user=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
  const {data:ctx,error}=await user.rpc('zernio_context');if(error||!ctx)return reply({error:'Membro ativo obrigatório'},403);tid=ctx.tenant_id;
  const raw=await req.text();if(raw.length>60000)return reply({error:'Dados excedem limite'},413);const b=JSON.parse(raw);let action=b.action;
  const reads=[...adsToolNames,'status','profiles','accounts','conversations','messages','posts','account_posts','ads_tree','automations','events','options'];
  if(!ctx.can_write&&!reads.includes(action))return reply({error:'Administrador obrigatório'},403);
  db=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const check=async(p:PromiseLike<any>)=>{const r=await p;if(r.error)throw new Error('Não foi possível salvar/consultar integração');return r.data;};
  if(action==='whatsapp_entry_list'||action==='whatsapp_entry_save'){
   if(!ctx.can_write)return reply({error:'Administrador obrigatório'},403);
   const result=await db.rpc('whatsapp_entry_admin',{p_tenant:tid,p_member:ctx.member_id,p_action:action==='whatsapp_entry_list'?'list':'save',p_data:b});
   if(result.error)return reply({error:result.error.message},400);return reply(result.data);
  }
  if(adsToolNames.includes(action))return reply(await adsRead(db,tid!,ctx.member_id,action,b));
  let conn=await check(db.from('zernio_connections').select('*').eq('tenant_id',tid).maybeSingle());
  if(action==='status')return reply({configured:!!conn,webhook_status:conn?.webhook_status??'not_configured',platforms,setup_path:'/configuracoes?s=zernio'});
  if(action==='save_key'){
   if(typeof b.api_key!=='string'||b.api_key.length<20||b.api_key.length>300)return reply({error:'Chave inválida'},400);
   const profiles=await provider(b.api_key,'/profiles');
   const digest=await hash(b.api_key);const rotated=conn&&conn.key_hash!==digest;await check(db.from('zernio_connections').upsert({tenant_id:tid,api_key:b.api_key,key_hash:digest,...(rotated?{webhook_token:crypto.randomUUID(),webhook_secret:await hash(crypto.randomUUID()+crypto.randomUUID()),webhook_id:null,webhook_status:'pending'}:{}),updated_at:new Date().toISOString()},{onConflict:'tenant_id'}));
   if(rotated)await check(db.from('zernio_accounts').update({is_active:false,automation_active:false}).eq('tenant_id',tid).eq('provider','zernio'));
   conn=await check(db.from('zernio_connections').select('*').eq('tenant_id',tid).single());
   return reply({configured:true,profiles:safe(profiles),next:'sync',...await ensureReceiving(db,tid!,conn,url)});
  }
  if(action==='save_meta'){
   if(!['instagram','facebook'].includes(b.login_type)||!/^\d+$/.test(b.instagram_id)||typeof b.access_token!=='string'||b.access_token.length<20||typeof b.app_secret!=='string'||b.app_secret.length<20)throw new Error('Preencha os dados da conexão Meta');
   const secret={access_token:b.access_token,app_secret:b.app_secret,login_type:b.login_type,messaging_id:b.login_type==='facebook'?b.page_id:b.instagram_id};
   if(!/^\d+$/.test(secret.messaging_id))throw new Error('ID de envio inválido');
   const profile=await metaRequest(secret,encodeURIComponent(b.instagram_id)+'?fields=id,username');
   if(String(profile.id)!==b.instagram_id)throw new Error('Conta não corresponde ao token');
   const aid='meta:'+b.instagram_id;
   const existing=await check(db.from('zernio_accounts').select('tenant_id,instagram_account_id').eq('id',aid).maybeSingle());if(existing&&existing.tenant_id!==tid)throw new Error('Conta vinculada a outra empresa');
   let ig=existing?.instagram_account_id;
   if(!ig)ig=(await check(db.from('instagram_business_accounts').insert({tenant_id:tid,instagram_business_id:b.instagram_id,instagram_username:profile.username,name:profile.username,access_token:'managed-by-social-provider',status:'connected'}).select('id').single())).id;
   await check(db.from('zernio_accounts').upsert({id:aid,tenant_id:tid,provider:'meta',platform:'instagram',profile_id:'',name:profile.username,username:profile.username,instagram_account_id:ig,is_active:true},{onConflict:'id'}));
   const saved=await check(db.from('social_provider_secrets').upsert({account_id:aid,tenant_id:tid,...secret},{onConflict:'account_id'}).select('webhook_token,verify_token').single());
   return reply({connected:true,account_id:aid,webhook_url:url+'/functions/v1/social-webhook?connection='+saved.webhook_token,verify_token:saved.verify_token});
  }
  if(action==='options'){
   const [agents,members,pipelines,stages]=await Promise.all([check(db.from('agents_registry').select('id,name:display_name,is_active').eq('tenant_id',tid)),check(db.from('team_members').select('id,name').eq('tenant_id',tid).eq('is_active',true)),check(db.from('sales_pipelines').select('id,name').eq('tenant_id',tid).eq('is_active',true)),check(db.from('sales_pipeline_stages').select('id,name,pipeline_id').eq('tenant_id',tid).eq('is_won',false).eq('is_lost',false))]);return reply({agents,members,pipelines,stages});
  }
  if(action==='events')return reply(await check(db.from('zernio_events').select('id,event,status,error,created_at').eq('tenant_id',tid).order('created_at',{ascending:false}).limit(30)));
  if(action==='accounts')return reply(await check(db.from('zernio_accounts').select('*').eq('tenant_id',tid).order('platform')));
  if(!conn&&['profiles','sync','connect','setup_webhook','test_webhook'].includes(action))return reply({error:'Cadastre sua chave em Configurações → Zernio',code:'not_configured'},409);
  if(action==='profiles')return reply(safe(await provider(conn.api_key,'/profiles')));
  if(action==='sync'){
   const remote=await provider(conn.api_key,'/accounts');const accounts=remote.accounts;if(!Array.isArray(accounts))throw new Error('Lista inválida');
   for(const a of accounts){
    const existing=await check(db.from('zernio_accounts').select('tenant_id,instagram_account_id').eq('id',a._id).maybeSingle());if(existing&&existing.tenant_id!==tid)throw new Error('Conta já pertence a outra empresa');
    const profileId=typeof a.profileId==='object'?a.profileId?._id:a.profileId;if(!profileId)throw new Error('Conta sem perfil');
    let ig=existing?.instagram_account_id;
    if(a.platform==='instagram'){
     const row={tenant_id:tid,instagram_username:a.username||a._id,name:a.displayName||a.username||'Instagram',status:a.isActive===false?'disconnected':'connected',access_token:'managed-by-zernio'};
     if(ig)await check(db.from('instagram_business_accounts').update(row).eq('id',ig).eq('tenant_id',tid));else ig=(await check(db.from('instagram_business_accounts').insert(row).select('id').single())).id;
    }
    await check(db.from('zernio_accounts').upsert({id:a._id,tenant_id:tid,profile_id:profileId,platform:a.platform,username:a.username||'',name:a.displayName||a.username||'',is_active:a.isActive!==false,instagram_account_id:ig,updated_at:new Date().toISOString()},{onConflict:'id'}));
   }
   const local=await check(db.from('zernio_accounts').select('id').eq('tenant_id',tid).eq('provider','zernio'));for(const a of local)if(!accounts.some((x:any)=>x._id===a.id))await check(db.from('zernio_accounts').update({is_active:false,automation_active:false}).eq('id',a.id).eq('tenant_id',tid));
   return reply({synced:accounts.length,...await ensureReceiving(db,tid!,conn,url)});
  }
  if(action==='accounts')return reply(await check(db.from('zernio_accounts').select('*').eq('tenant_id',tid).order('platform')));
  if(action==='connect'){
   const profiles=await provider(conn.api_key,'/profiles');if(!profiles.profiles?.some((p:any)=>p._id===b.profile_id))return reply({error:'Perfil não pertence à sua chave'},403);
   // Callback never binds a supplied accountId; sync resolves account ownership from the API.
   if(['bluesky','openaiads','shopify'].includes(b.platform))return reply({dashboard_url:'https://zernio.com/dashboard',instructions:'Conecte esta conta no painel Zernio e depois clique em Sincronizar contas no CRM.'});
   const parentPlatform=({xads:'twitter',linkedinads:'linkedin',pinterestads:'pinterest'} as Record<string,string>)[b.platform];
   const parent=parentPlatform?await check(db.from('zernio_accounts').select('id').eq('tenant_id',tid).eq('platform',parentPlatform).eq('profile_id',b.profile_id).eq('is_active',true).limit(2)):[];
   if(parentPlatform&&parent.length!==1)return reply({dashboard_url:'https://zernio.com/dashboard',instructions:'Selecione a conta social de origem no painel Zernio para conectar anúncios; depois sincronize.'});
   let path=connectPath(b.platform,b.profile_id,crmPublicUrl()+'/configuracoes?s=zernio');
   if(parent.length===1)path+='&accountId='+encodeURIComponent(parent[0].id);
   return reply(safe(await provider(conn.api_key,path)));
  }
  if(action==='setup_webhook')return reply(await ensureReceiving(db,tid!,conn,url,true));
  if(action==='test_webhook'){if(!conn.webhook_id)throw new Error('Configure webhook');return reply(safe(await provider(conn.api_key,'/webhooks/test','POST',{webhookId:conn.webhook_id})));}
  if(action==='legacy_send'){
   const cv=await check(db.from('instagram_conversations').select('id,metadata').eq('id',b.local_conversation_id||b.conversation_id).eq('tenant_id',tid).maybeSingle());
   const link=cv?await check(db.from('zernio_conversations').select('account_id,remote_id').eq('tenant_id',tid).eq('instagram_conversation_id',cv.id).maybeSingle()):null;
   if(!link)throw new Error('Conversa sem conexão configurada');
   b.account_id=link.account_id;b.conversation_id=link.remote_id;action=b.reply_kind||'send';
  }
  const account=await check(db.from('zernio_accounts').select('*').eq('id',b.account_id||'').eq('tenant_id',tid).maybeSingle());
  if(!account||!account.is_active)return reply({error:'Conta não conectada nesta empresa'},404);
  const accountId=account.id,q=new URLSearchParams({accountId});if(id(b.cursor))q.set('cursor',b.cursor);
  if(action==='bind'){
   if(b.active&&(!b.agent_id||!b.member_id||!b.pipeline_id||!b.stage_id))throw new Error('Escolha agente, responsável, funil e etapa');
   for(const [table,value] of [['agents_registry',b.agent_id],['team_members',b.member_id],['sales_pipelines',b.pipeline_id],['sales_pipeline_stages',b.stage_id]])if(value){const row=await check(db.from(table).select('*').eq('id',value).eq('tenant_id',tid).maybeSingle());if(!row)throw new Error(({agents_registry:'Agente',team_members:'Responsável',sales_pipelines:'Pipeline',sales_pipeline_stages:'Etapa'} as Record<string,string>)[table]+' não pertence a esta empresa');if(table==='agents_registry'){if(b.active&&row.is_active!==true)throw new Error('O agente selecionado está inativo. Ative-o em Meus agentes antes de ligar o atendimento automático. Você pode salvar a configuração com o atendimento desligado.');}else if(row.is_active===false)throw new Error('O responsável, pipeline ou etapa selecionado está inativo');if(table==='sales_pipeline_stages'&&(row.pipeline_id!==b.pipeline_id||row.is_won||row.is_lost))throw new Error('Escolha uma etapa aberta do pipeline selecionado');}
   if(b.active&&!platforms.find(p=>p.id===account.platform)?.inbox)throw new Error('Esta rede não oferece atendimento por inbox');
   await check(db.from('zernio_accounts').update({agent_id:b.agent_id||null,member_id:b.member_id||null,pipeline_id:b.pipeline_id||null,stage_id:b.stage_id||null,automation_active:!!b.active}).eq('id',accountId).eq('tenant_id',tid));return reply({saved:true});
  }
  if(action==='import_history'){
   if(account.platform!=='instagram')throw new Error('Importação disponível para Instagram');
   let count=0,pagination:any={};
   const secret=account.provider==='meta'?await check(db.from('social_provider_secrets').select('*').eq('tenant_id',tid).eq('account_id',account.id).single()):null;
   if(b.post_id){
    const path=encodeURIComponent(b.post_id);
    const data=account.provider==='meta'?await metaRequest(secret,path+'/comments?'+new URLSearchParams({fields:'id,text,from,timestamp,parent_id',limit:'50',...(b.cursor?{after:b.cursor}:{})})):await provider(conn.api_key,'/inbox/comments/'+path+'?'+new URLSearchParams({accountId:account.id,limit:'50',...(b.cursor?{cursor:b.cursor}:{})}));
    for(const c of data.comments||data.data||[]){if(!c.from?.id||c.from.isOwner)continue;await check(db.rpc('social_record_interaction',{p_account:account.id,p_remote:'comment:'+c.from.id,p_message:{id:c.id,kind:'post_comment',text:c.message||c.text||'',sender:c.from,comment_id:c.id,parent_id:c.parentId||c.parent_id,reference_id:b.post_id,reference_type:'post',reference_url:c.url,sentAt:c.createdTime||c.timestamp,historical:true}}));count++;}
    pagination=data.pagination||{nextCursor:data.paging?.cursors?.after,hasMore:!!data.paging?.next};
   }else{
    const data=account.provider==='meta'?await metaRequest(secret,encodeURIComponent(secret.messaging_id)+'/conversations?'+new URLSearchParams({platform:'instagram',fields:'id,participants',limit:'5',...(b.cursor?{after:b.cursor}:{})})):await provider(conn.api_key,'/inbox/conversations?'+new URLSearchParams({accountId:account.id,limit:'5',...(b.cursor?{cursor:b.cursor}:{})}));
    for(const c of data.data||[]){
     const person=account.provider==='meta'?c.participants?.data?.find((p:any)=>String(p.id)!==account.id.slice(5)&&String(p.id)!==secret.messaging_id):{id:c.participantId,name:c.participantName};if(!person?.id)continue;
     const remote=account.provider==='meta'?String(person.id):c.id;
     const existing=await check(db.from('zernio_conversations').select('id').eq('account_id',account.id).eq('tenant_id',tid).eq('participant_id',String(person.id)).limit(1));
     if(!existing.length)await check(db.from('zernio_conversations').upsert({tenant_id:tid,account_id:account.id,remote_id:remote,participant_id:String(person.id),participant_name:person.name||person.username||'Contato Instagram'},{onConflict:'account_id,remote_id',ignoreDuplicates:true}));
     const history=account.provider==='meta'?await metaRequest(secret,encodeURIComponent(c.id)+'/messages?fields=id,message,from,created_time&limit=50'):await provider(conn.api_key,'/inbox/conversations/'+encodeURIComponent(c.id)+'/messages?'+new URLSearchParams({accountId:account.id,sortOrder:'desc',limit:'50'}));
     for(const m of (history.messages||history.data||[]).slice().reverse()){
      await check(db.rpc('social_record_interaction',{p_account:account.id,p_remote:remote,p_message:{id:m.platformMessageId||m.id,text:m.message||'',sender:{id:String(person.id),name:person.name},sentAt:m.createdAt||m.created_time,outgoing:account.provider==='meta'?String(m.from?.id)!==String(person.id):m.direction==='outgoing',attachments:m.attachments||[],historical:true}}));count++;
     }
    }
    pagination=data.pagination||{nextCursor:data.paging?.cursors?.after,hasMore:!!data.paging?.next};
   }
   return reply({imported:count,pagination,note:'Histórico importado sem acionar agente ou criar oportunidades retroativas. Até 50 mensagens por conversa nesta importação.'});
  }
  if(account.platform==='instagram'&&['conversations','messages'].includes(action)){
   const offset=b.cursor?Number(b.cursor):0;if(!Number.isSafeInteger(offset)||offset<0)throw new Error('Cursor inválido');
   if(action==='conversations'){
    const rows=await check(db.from('zernio_conversations').select('remote_id,participant_id,participant_name,last_message,instagram_conversation_id').eq('tenant_id',tid).eq('account_id',account.id).order('last_message_at',{ascending:false}).range(offset,offset+49));
    return reply({data:rows.map((c:any)=>({id:c.remote_id,local_id:c.instagram_conversation_id,participantId:c.participant_id,participantName:c.participant_name,lastMessage:c.last_message})),pagination:{hasMore:rows.length===50,nextCursor:rows.length===50?String(offset+50):null}});
   }
   const cv=await check(db.from('zernio_conversations').select('instagram_conversation_id').eq('tenant_id',tid).eq('account_id',account.id).eq('remote_id',b.conversation_id).maybeSingle());if(!cv)throw new Error('Conversa não pertence à conta');
   const rows=await check(db.from('instagram_messages').select('*').eq('tenant_id',tid).eq('conversation_id',cv.instagram_conversation_id).order('sent_at',{ascending:false}).order('id').range(offset,offset+49));
   return reply({messages:rows.map((m:any)=>({...m,message:m.content,direction:m.is_from_me?'outgoing':'incoming',createdAt:m.sent_at,attachments:m.metadata?.attachments||[]})),pagination:{hasMore:rows.length===50,nextCursor:rows.length===50?String(offset+50):null}});
  }
  if(account.provider==='meta'&&!['send','reply_comment','private_reply','disconnect'].includes(action))return reply({error:'Esta capacidade ainda não está disponível no adaptador Meta direto',code:'unsupported_capability'},422);
  if(action==='conversations')return reply(safe(await provider(conn.api_key,'/inbox/conversations?'+q)));
  if(action==='messages'){q.set('sortOrder','desc');if(!id(b.conversation_id))throw new Error('Conversa obrigatória');return reply(safe(await provider(conn.api_key,'/inbox/conversations/'+encodeURIComponent(b.conversation_id)+'/messages?'+q)));}
  if(action==='posts')return reply(safe(await provider(conn.api_key,'/posts?'+new URLSearchParams({profileId:account.profile_id,accountId,limit:'50'}))));
  if(action==='account_posts')return reply(safe(await provider(conn.api_key,'/accounts/'+encodeURIComponent(accountId)+'/posts')));
  if(action==='ads_tree')return reply(safe(await provider(conn.api_key,'/ads/tree?'+q)));
  if(action==='automations'){
   const remote=await provider(conn.api_key,'/comment-automations?'+new URLSearchParams({profileId:account.profile_id}));
   const drafts=await check(db.from('zernio_campaigns').select('*').eq('tenant_id',tid).eq('account_id',accountId).is('remote_id',null));
   return reply({automations:[...drafts.map((d:any)=>({id:d.id,...d.config,isActive:false,localDraft:true})),...(remote.automations||[]).filter((a:any)=>a.accountId===accountId)]});
  }
  if(!['send','reply_comment','private_reply','create_post','disconnect','create_automation','pause_automation'].includes(action))return reply({error:'Ação inválida'},400);
  if(action==='create_post'&&b.scheduled_for){const stamp=Date.parse(/[zZ]|[+-]\d\d:\d\d$/.test(b.scheduled_for)?b.scheduled_for:b.scheduled_for+'-03:00');if(!Number.isFinite(stamp)||stamp<Date.now()+60000)throw new Error('Escolha um horário futuro para agendar');}
  if(typeof b.request_id!=='string'||! /^[0-9a-f-]{36}$/i.test(b.request_id))throw new Error('request_id UUID obrigatório');
  const input=await hash(JSON.stringify(b));const old=await check(db.from('zernio_operations').select('*').eq('tenant_id',tid).eq('request_id',b.request_id).maybeSingle());
  if(old){if(old.input_hash!==input)return reply({error:'Identificador usado para outro envio'},409);return reply(old.status==='completed'?old.result:{error:'Operação anterior não confirmada. Confira histórico antes de tentar novamente.',status:old.status},old.status==='completed'?200:409);}
  await check(db.from('zernio_operations').insert({tenant_id:tid,request_id:b.request_id,action,input_hash:input}));op=b.request_id;
  let result:any;
  if(['send','reply_comment','private_reply'].includes(action)){
   if(!id(b.conversation_id)||typeof b.message!=='string'||!b.message.trim()||b.message.length>10000)throw new Error('Conversa e mensagem obrigatórias');
   result=await socialSend(db,account,{...b,action});
  }else if(action==='disconnect'){
   result=account.provider==='meta'?{disconnected:true}:await provider(conn.api_key,'/accounts/'+encodeURIComponent(accountId),'DELETE');await check(db.from('zernio_accounts').update({is_active:false,automation_active:false}).eq('id',accountId).eq('tenant_id',tid));
  }else if(action==='create_automation'){
   if(!['instagram','facebook'].includes(account.platform)||typeof b.name!=='string'||typeof b.dm_message!=='string'||!Array.isArray(b.keywords)||b.keywords.length===0)throw new Error('Nome, palavras-chave e mensagem obrigatórios');
   const config={profileId:account.profile_id,accountId,name:b.name,keywords:b.keywords,dmMessage:b.dm_message,commentReply:b.comment_reply||undefined,platformPostId:b.platform_post_id||undefined,matchMode:'word'};
   await check(db.from('zernio_campaigns').insert({id:b.request_id,tenant_id:tid,account_id:accountId,config}));result={saved:true,id:b.request_id,isActive:false};
  }else if(action==='pause_automation'){
   const draft=/^[0-9a-f-]{36}$/i.test(b.automation_id)?await check(db.from('zernio_campaigns').select('*').eq('tenant_id',tid).eq('account_id',accountId).eq('id',b.automation_id).maybeSingle()):null;
   if(draft&&!draft.remote_id){
    if(!b.active)result={isActive:false};else{
     result=await provider(conn.api_key,'/comment-automations','POST',draft.config);
     const remoteId=result.automation?.id||result.automation?._id;if(!remoteId)throw new Error('Ativação não confirmada');
     await check(db.from('zernio_campaigns').update({remote_id:remoteId}).eq('id',draft.id).eq('tenant_id',tid));
    }
   }else{
    const remoteId=draft?.remote_id||b.automation_id;
    const all=await provider(conn.api_key,'/comment-automations?'+new URLSearchParams({profileId:account.profile_id}));
    if(!(all.automations||[]).some((x:any)=>(x.id||x._id)===remoteId&&x.accountId===accountId))throw new Error('Automação não pertence a esta conta');
    result=await provider(conn.api_key,'/comment-automations/'+encodeURIComponent(remoteId),'PATCH',{isActive:!!b.active});
   }
  }else{
   if(typeof b.content!=='string'||b.content.length>30000)throw new Error('Conteúdo inválido');
   if(b.scheduled_for&&!Number.isFinite(Date.parse(b.scheduled_for)))throw new Error('Data inválida');
   result=await provider(conn.api_key,'/posts','POST',{content:b.content,platforms:[{platform:account.platform,accountId,platformSpecificData:b.platform_options||{}}],...(b.media_items?{mediaItems:b.media_items}:{}),...(b.scheduled_for?{scheduledFor:b.scheduled_for,timezone:'America/Sao_Paulo'}:{publishNow:!!b.publish_now})},b.request_id);
  }
  result=safe(result);await check(db.from('zernio_operations').update({status:'completed',result}).eq('tenant_id',tid).eq('request_id',op));return reply(result);
 }catch(e){
  if(db&&tid&&op)await db.from('zernio_operations').update({status:'unconfirmed'}).eq('tenant_id',tid).eq('request_id',op);
  return reply({error:e instanceof ProviderError?e.message:e instanceof Error?e.message:'Operação não confirmada',code:e instanceof ProviderError?e.code:'integration_error'},e instanceof ProviderError?e.status:400);
 }
}
