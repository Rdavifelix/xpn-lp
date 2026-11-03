import {normalizeSocialEvent,metaRequest} from './social-provider.ts';
const assert=(v:unknown,m='assertion failed')=>{if(!v)throw new Error(m);};
Deno.test('comments normalize author, parent and post without pretending to be a DM',()=>{
 const r=normalizeSocialEvent({event:'comment.received',comment:{id:'c1',platformPostId:'p1',text:'oi',author:{id:'user',username:'ana'},parentCommentId:'parent',createdAt:'2026-09-10T12:00:00Z'}});
 assert(r?.remote==='comment:user');assert(r?.message.kind==='post_comment');assert(r?.message.reference_id==='p1');assert(!r?.message.outgoing);
 const own=normalizeSocialEvent({event:'comment.received',comment:{id:'r1',platformPostId:'p1',author:{id:'own',isOwnAccount:true},parentCommentId:'c1'}});assert(own?.message.kind==='comment_reply');assert(own?.message.parent_id==='c1');
});
Deno.test('DM identity uses native message ID to deduplicate echoes',()=>{
 const r=normalizeSocialEvent({event:'message.sent',conversation:{id:'opaque/1'},message:{id:'internal',platformMessageId:'native',text:'oi'}});
 assert(r?.message.id==='native');assert(r?.message.outgoing);assert(r?.remote==='opaque/1');
});
Deno.test('Meta adapter selects the documented host and never retries uncertain sends',async()=>{
 const original=globalThis.fetch;let n=0;
 try{
  globalThis.fetch=async(input,init)=>{n++;assert(String(input)==='https://graph.instagram.com/v25.0/123/messages');assert(new Headers(init?.headers).get('Authorization')==='Bearer synthetic');return new Response(JSON.stringify({error:{code:10,message:'synthetic'}}),{status:403});};
  let failed=false;try{await metaRequest({login_type:'instagram',access_token:'synthetic'},'123/messages','POST',{message:{text:'hello'}});}catch(e){failed=true;assert(!(e as Error).message.includes('synthetic'));}assert(failed);assert(n===1);
 }finally{globalThis.fetch=original;}
});
Deno.test('same send contract routes DM, public reply and private reply through each provider',async()=>{
 const {socialSend}=await import('./social-provider.ts');const original=globalThis.fetch;
 try{
  for(const selected of ['zernio','meta'])for(const action of ['send','reply_comment','private_reply']){
   let request:any,record:any;
   const rows:Record<string,any>={zernio_conversations:{remote_id:'remote',participant_id:'person',participant_name:'Ana',instagram_conversation_id:'local'},instagram_messages:{metadata:{comment_id:'comment'},reference_id:'post'},zernio_connections:{api_key:'synthetic'},social_provider_secrets:{access_token:'synthetic',login_type:'instagram',messaging_id:'123'}};
   const db={from:(table:string)=>{const chain:any={select:()=>chain,eq:()=>chain,maybeSingle:async()=>({data:rows[table]}),single:async()=>({data:rows[table]})};return chain;},rpc:async(_:string,args:any)=>{record=args;return {error:null};}};
   globalThis.fetch=async(input,init)=>{request={url:String(input),body:JSON.parse(String(init?.body))};return new Response(JSON.stringify(selected==='meta'?{message_id:'native'}:{data:{commentId:'native'}}));};
   await socialSend(db,{id:'account',tenant_id:'tenant',platform:'instagram',provider:selected},{action,conversation_id:'remote',comment_id:'local-comment',message:'Teste',request_id:'request'});
   assert(record.p_message.id==='native');assert(record.p_message.outgoing===true);
   assert(record.p_message.kind===(action==='reply_comment'?'comment_reply':'text'));
   if(selected==='zernio')assert(request.url.endsWith(action==='send'?'/inbox/conversations/remote/messages':action==='reply_comment'?'/inbox/comments/post':'/inbox/comments/post/comment/private-reply'));
   else {assert(request.url.endsWith(action==='reply_comment'?'/comment/replies':'/123/messages'));if(action==='private_reply')assert(request.body.recipient.comment_id==='comment');if(action==='send')assert(request.body.recipient.id==='person');}
  }
 }finally{globalThis.fetch=original;}
});
