/** Resolve URL and token as one pair. Never expose the token to a tenant UI. */
export async function getUazapiAdmin(db:any,tenantId:string|null){
 if(!tenantId)throw new Error('Empresa não identificada');
 const {data,error}=await db.from('tenant_config_overrides').select('key,value').eq('tenant_id',tenantId).in('key',['UAZAPI_ADMIN_URL','UAZAPI_ADMIN_TOKEN']);
 if(error)throw new Error('Não foi possível consultar a conexão WhatsApp');
 const own=Object.fromEntries((data??[]).map((r:any)=>[r.key,String(r.value??'').trim()]));
 const hasOwn=!!own.UAZAPI_ADMIN_URL||!!own.UAZAPI_ADMIN_TOKEN;
 const base=hasOwn?own.UAZAPI_ADMIN_URL:Deno.env.get('SAAS_UAZAPI_ADMIN_URL');
 const key=hasOwn?own.UAZAPI_ADMIN_TOKEN:Deno.env.get('SAAS_UAZAPI_ADMIN_TOKEN');
 if(!base||!key)return {configured:false,source:hasOwn?'own':'global',base:null,key:null};
 const u=new URL(base);if(u.protocol!=='https:'||u.username||u.password||u.search||u.hash)throw new Error('Informe uma URL HTTPS válida para a Uazapi');
 return {configured:true,source:hasOwn?'own':'global',base:u.href.replace(/\/$/,''),key};
}
