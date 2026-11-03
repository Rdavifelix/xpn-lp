import assert from 'node:assert/strict';
import {connectPath,provider,safe,platforms,ProviderError} from './provider.ts';
import {validSignature} from '../zernio-webhook/signature.ts';
Deno.test('Zernio: conexões sociais e anúncios usam endpoints documentados',()=>{
 for(const [p,path] of [['metaads','/connect/facebook/ads?'],['googleads','/connect/googleads/ads?'],['linkedinads','/connect/linkedin/ads?'],['tiktokads','/connect/tiktok/ads?'],['xads','/connect/twitter/ads?'],['youtube','/connect/youtube?']])assert.ok(connectPath(p,'profile','https://crm.example/callback').startsWith(path));
 assert.equal(platforms.length,24);assert.throws(()=>connectPath('other','p','r'));
});
Deno.test('Zernio: segredos são removidos de respostas aninhadas',()=>{
 assert.deepEqual(safe({accounts:[{name:'a',accessToken:'private',api_key:'private',metadata:{secret:'s',id:1}}]}),{accounts:[{name:'a',metadata:{id:1}}]});
});
Deno.test('Zernio: assinatura depende do corpo exato e da chave do tenant',async()=>{
 const body='{"id":"1"}',secret='tenant-secret';
 const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);
 const sig=Array.from(new Uint8Array(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(body)))).map(x=>x.toString(16).padStart(2,'0')).join('');
 assert.equal(await validSignature(body,secret,sig),true);assert.equal(await validSignature(body,'another',sig),false);assert.equal(await validSignature(body+' ',secret,sig),false);assert.equal(await validSignature(body,secret,''),false);
});
Deno.test('Zernio: envia chave só ao endpoint fixo, protege retries e falhas parciais',async()=>{
 const original=globalThis.fetch;let count=0;
 globalThis.fetch=((url:any,init:any)=>{count++;assert.equal(String(url),'https://zernio.com/api/v1/posts');assert.equal(init.redirect,'error');assert.equal(init.headers.Authorization,'Bearer synthetic');assert.equal(init.headers['x-request-id'],'stable');assert.equal(init.headers['Idempotency-Key'],'stable');return Promise.resolve(new Response(JSON.stringify({post:{status:'partial'}}),{status:207}));}) as typeof fetch;
 try{assert.equal((await provider('synthetic','/posts','POST',{},'stable')).post.status,'partial');assert.equal(count,1);}finally{globalThis.fetch=original;}
});
Deno.test('Zernio: falha não é repetida automaticamente nem expõe chave',async()=>{
 const original=globalThis.fetch;let count=0;globalThis.fetch=(()=>{count++;return Promise.resolve(new Response(JSON.stringify({message:'synthetic private',code:'bad'}),{status:503}));}) as typeof fetch;
 try{await assert.rejects(()=>provider('synthetic','/accounts'),(e:any)=>e instanceof ProviderError&&e.status===503&&!e.message.includes('synthetic'));assert.equal(count,1);}finally{globalThis.fetch=original;}
});
