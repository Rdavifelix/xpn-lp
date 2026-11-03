import {provider} from '../zernio-api/provider.ts';
export async function metaRequest(secret:any,path:string,method='GET',body?:unknown){
 const host=secret.login_type==='facebook'?'graph.facebook.com':'graph.instagram.com';
 const r=await fetch(`https://${host}/v25.0/${path}`,{method,headers:{Authorization:`Bearer ${secret.access_token}`,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),redirect:'error',signal:AbortSignal.timeout(22000)});
 const data=await r.json();if(!r.ok||data.error)throw new Error(`Meta recusou a operação (${data.error?.code||r.status}). Confira permissões, janela de atendimento e conexão.`);return data;
}
export async function socialSend(db:any,account:any,args:any){
 const {data:cv,error}=await db.from('zernio_conversations').select('*').eq('account_id',account.id).eq('tenant_id',account.tenant_id).eq('remote_id',args.conversation_id).maybeSingle();
 if(error||!cv)throw new Error('Conversa não pertence à conexão');
 let comment:any;
 if(args.action==='reply_comment'||args.action==='private_reply'){
  const r=await db.from('instagram_messages').select('*').eq('tenant_id',account.tenant_id).eq('conversation_id',cv.instagram_conversation_id).eq('id',args.comment_id).eq('message_type','post_comment').maybeSingle();comment=r.data;
  if(!comment?.metadata?.comment_id||!comment.reference_id)throw new Error('Comentário não pertence à conversa');
 }
 let result:any;
 if(account.provider==='meta'){
  const {data:secret}=await db.from('social_provider_secrets').select('*').eq('account_id',account.id).eq('tenant_id',account.tenant_id).single();if(!secret)throw new Error('Conecte sua conta Meta');
  if(args.attachment_url)throw new Error('Envio de anexo Meta ainda indisponível neste adaptador');
  result=await metaRequest(secret,args.action==='reply_comment'?encodeURIComponent(comment.metadata.comment_id)+'/replies':encodeURIComponent(secret.messaging_id)+'/messages','POST',args.action==='reply_comment'?{message:args.message}:{recipient:args.action==='private_reply'?{comment_id:comment.metadata.comment_id}:{id:cv.participant_id},message:{text:args.message}});
 }else{
  const {data:secret}=await db.from('zernio_connections').select('api_key').eq('tenant_id',account.tenant_id).single();if(!secret)throw new Error('Conecte sua conta Zernio');
  const path=comment?'/inbox/comments/'+encodeURIComponent(comment.reference_id)+(args.action==='private_reply'?'/'+encodeURIComponent(comment.metadata.comment_id)+'/private-reply':''):'/inbox/conversations/'+encodeURIComponent(cv.remote_id)+'/messages';
  if(!comment&&cv.remote_id.startsWith('comment:'))throw new Error('Este contato ainda não abriu um direct. Selecione Responder por DM no comentário.');
  result=await provider(secret.api_key,path,'POST',{accountId:account.id,message:args.message,...(args.action==='reply_comment'?{commentId:comment.metadata.comment_id}:{}),...(args.attachment_url?{attachmentUrl:args.attachment_url}:{})},args.request_id);
 }
 if(result.data?.partialFailure)throw new Error('Envio parcial. Consulte o histórico antes de repetir.');
 // Persist confirmed outbound writes in the same timeline; webhook echoes deduplicate by native ID.
 if(account.platform!=='instagram')return result;
 const native=result.messageId||result.message_id||result.commentId||result.id||result.data?.messageId||result.data?.commentId||result.data?.id;
 const {error:ingestError}=await db.rpc('social_record_interaction',{p_account:account.id,p_remote:cv.remote_id,p_message:{id:native||('request:'+args.request_id),text:args.message,sender:{id:cv.participant_id,name:cv.participant_name},sentAt:new Date().toISOString(),outgoing:true,kind:args.action==='reply_comment'?'comment_reply':'text',comment_id:comment?.metadata?.comment_id,reference_id:comment?.reference_id,reference_type:comment?'post':undefined,reference_url:comment?.reference_url,attachments:args.attachment_url?[{type:'image',url:args.attachment_url}]:[]}});
 if(ingestError)throw new Error('Envio confirmado pelo provedor, mas histórico não salvo. Não repita o envio.');
 return {...result,sent:true};
}
// Both webhook providers normalize into this same contract before touching CRM data.
export function normalizeSocialEvent(payload:any){
 if(payload.event==='comment.received'){
  const c=payload.comment;if(!c?.id||!c.author?.id||!c.platformPostId)throw new Error('Comentário incompleto');
  return {remote:'comment:'+c.author.id,message:{id:c.id,text:c.text||'',sender:c.author,sentAt:c.createdAt,outgoing:!!c.author.isOwnAccount,kind:c.author.isOwnAccount?'comment_reply':'post_comment',comment_id:c.id,parent_id:c.parentCommentId,reference_id:c.platformPostId,reference_type:'post',reference_url:c.url||null}};
 }
 const m=payload.message;if(!m)return null;
 return {remote:payload.conversation?.id||m.conversationId,message:{...m,id:m.platformMessageId||m.id,outgoing:payload.event==='message.sent'||m.direction==='outgoing',kind:'text'}};
}
