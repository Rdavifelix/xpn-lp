export const platforms=[
 ['instagram','Instagram','social'],['facebook','Facebook','social'],['linkedin','LinkedIn','social'],['twitter','X','social'],['tiktok','TikTok','social'],['youtube','YouTube','social'],['pinterest','Pinterest','social'],['reddit','Reddit','social'],['bluesky','Bluesky','social'],['threads','Threads','social'],['googlebusiness','Google Business Profile','social'],['snapchat','Snapchat (beta fechado)','social'],['telegram','Telegram','messages'],['whatsapp','WhatsApp','messages'],['discord','Discord','messages'],['slack','Slack','messages'],['metaads','Meta Ads','ads'],['googleads','Google Ads','ads'],['linkedinads','LinkedIn Ads','ads'],['tiktokads','TikTok Ads','ads'],['pinterestads','Pinterest Ads','ads'],['xads','X Ads','ads'],['openaiads','OpenAI Ads','ads'],['shopify','Shopify (artigos)','commerce'],
].map(([id,name,group])=>({id,name,group,inbox:['instagram','facebook','twitter','bluesky','reddit','telegram','whatsapp','slack'].includes(id),credential:['bluesky','telegram','openaiads','shopify'].includes(id)}));
export class ProviderError extends Error{constructor(public status:number,public code:string,message:string){super(message)}}
export async function provider(key:string,path:string,method='GET',body?:unknown,requestId?:string){
 if(!path.startsWith('/')||path.includes('://'))throw new Error('Caminho inválido');
 const response=await fetch('https://zernio.com/api/v1'+path,{method,headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json',...(requestId?{'Idempotency-Key':requestId,'x-request-id':requestId}:{})},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(22000),redirect:'error'});
 const data=await response.json().catch(()=>({}));
 if(!response.ok)throw new ProviderError(response.status,String(data.code||'provider_error'),String(data.message||data.error||'Zernio recusou a operação').replaceAll(key,'[oculto]').slice(0,400));
 return data;
}
export function safe(value:any):any{
 if(Array.isArray(value))return value.map(safe);
 if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).filter(([k])=>!/token|secret|api.?key|password|authorization/i.test(k)).map(([k,v])=>[k,safe(v)]));return value;
}
export const hash=async(s:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)))).map(b=>b.toString(16).padStart(2,'0')).join('');
export function connectPath(platform:string,profileId:string,redirect:string){
 if(!platforms.some(p=>p.id===platform))throw new Error('Plataforma inválida');
 const q=new URLSearchParams({profileId,redirect_url:redirect});
 if(platform==='metaads'){q.set('loginMode','business');return '/connect/facebook/ads?'+q;}
 if(platform.endsWith('ads'))return '/connect/'+({'linkedinads':'linkedin','pinterestads':'pinterest','tiktokads':'tiktok','xads':'twitter'}[platform]||platform)+'/ads?'+q;
 return '/connect/'+platform+'?'+q;
}
