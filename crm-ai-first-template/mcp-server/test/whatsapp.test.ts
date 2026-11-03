import {test} from 'node:test';
import assert from 'node:assert/strict';
import {connection,providerUrl,uazapi,webhookMatches} from '../../supabase/functions/mcp-whatsapp/provider.ts';
import {registerWhatsApp} from '../src/whatsapp.js';
test('WhatsApp: QR sanitizado, estado atual e webhook verificado sem segredos',()=>{
 const result=connection({instance:{qrcode:'data:image/png;base64,aGVsbG8=',status:'connecting',token:'private',openai_apikey:'secret'}});
 assert.equal(result.qr_code,'data:image/png;base64,aGVsbG8=');assert.doesNotMatch(JSON.stringify(result),/private|secret/);
 assert.equal(connection({instance:{status:'connected',qrcode:result.qr_code}}).qr_code,null);
 assert.equal(connection({instance:{qrcode:'https://untrusted.example/pixel'}}).qr_code,null);
 assert.equal(connection({status:{connected:true,jid:{user:'5511999999999'}}}).phone_number,'5511999999999');
 assert.equal(webhookMatches([{enabled:true,url:'https://crm.example/hook',events:['messages','connection'],excludeMessages:['wasSentByApi']}],'https://crm.example/hook'),true);
 assert.equal(webhookMatches([{enabled:false,url:'https://crm.example/hook'}],'https://crm.example/hook'),false);
 assert.throws(()=>providerUrl('http://example.com'));assert.throws(()=>providerUrl('https://user:secret@example.com'));
});
test('WhatsApp: contrato Uazapi e falhas não vazam payload/credenciais',async()=>{
 const original=globalThis.fetch;
 try{
  globalThis.fetch=async(url,init)=>{assert.equal(url,'https://provider.example/instance/create');assert.equal((init!.headers as any).admintoken,'private');assert.equal(init!.redirect,'error');return new Response(JSON.stringify({token:'created'}));};
  assert.equal((await uazapi('https://provider.example','private','/instance/create',{name:'Demo'},true)).token,'created');
  globalThis.fetch=async()=>new Response('private error payload',{status:401});
  await assert.rejects(uazapi('https://provider.example','private','/instance/status'),e=>e instanceof Error&&!e.message.includes('private')&&e.message.includes('401'));
 }finally{globalThis.fetch=original;}
});
test('WhatsApp MCP: imagem nativa, isolamento do catálogo e erro visível',async()=>{
 type ToolHandler=(...args:unknown[])=>unknown;
 const callbacks=new Map<string,ToolHandler>();
 const server={registerTool:(name:string,_:unknown,fn:ToolHandler)=>callbacks.set(name,fn)} as any;
 registerWhatsApp(server,{can_write:false} as any,async()=>({}));assert.equal(callbacks.size,0);
 registerWhatsApp(server,{can_write:true} as any,async()=>({connected:false,qr_code:'data:image/png;base64,aGVsbG8='}));
 assert.equal(callbacks.size,5);
 const r=await callbacks.get('gerar_qrcode_whatsapp')!({instance_id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'});
 assert.equal(r.content[1].type,'image');assert.equal(r.content[1].data,'aGVsbG8=');assert.ok(!r.content[0].text.includes('base64'));
 registerWhatsApp(server,{can_write:true} as any,async()=>{throw new Error('Uazapi não configurada');});
 assert.equal((await callbacks.get('listar_instancias_whatsapp')!()).isError,true);
});

test('WhatsApp: oportunidade somente do contato/tenant e sem escolher entre duas',async()=>{
 const {resolveWhatsAppDeal}=await import('../../supabase/functions/whatsapp-webhook/deal-context.ts');
 for(const rows of [[],[{id:'deal-a'}],[{id:'deal-a'},{id:'deal-b'}]]){
  const filters:unknown[]=[];
  const q:any={select:()=>q,eq:(...args:unknown[])=>{filters.push(args);return q;},not:()=>q,limit:async()=>({data:rows,error:null})};
  assert.equal(await resolveWhatsAppDeal({from:()=>q},'tenant-a','lead-a'),rows.length===1?'deal-a':null);
  assert.deepEqual(filters,[['tenant_id','tenant-a'],['lead_id','lead-a']]);
 }
});
