import {getUazapiAdmin} from './uazapi-config.ts';
function db(values:Record<string,string>){const q={select:()=>q,eq:()=>q,in:()=>Promise.resolve({data:Object.entries(values).map(([key,value])=>({key,value})),error:null})};return {from:()=>q};}
Deno.test('global fallback, own pair and incomplete own settings never mix credentials',async()=>{
 Deno.env.set('SAAS_UAZAPI_ADMIN_URL','https://global.example');Deno.env.set('SAAS_UAZAPI_ADMIN_TOKEN','global-test');
 const global=await getUazapiAdmin(db({}),'tenant');if(global.source!=='global'||global.key!=='global-test')throw Error('global missing');
 const own=await getUazapiAdmin(db({UAZAPI_ADMIN_URL:'https://own.example',UAZAPI_ADMIN_TOKEN:'own-test'}),'tenant');if(own.source!=='own'||own.key!=='own-test'||own.base!=='https://own.example')throw Error('own mismatch');
 const partial=await getUazapiAdmin(db({UAZAPI_ADMIN_URL:'https://own.example'}),'tenant');if(partial.configured||partial.key!==null)throw Error('global key leaked into own URL');
 let rejected=false;try{await getUazapiAdmin(db({}),null);}catch{rejected=true;}if(!rejected)throw Error('missing tenant accepted');
 Deno.env.delete('SAAS_UAZAPI_ADMIN_URL');Deno.env.delete('SAAS_UAZAPI_ADMIN_TOKEN');
});
