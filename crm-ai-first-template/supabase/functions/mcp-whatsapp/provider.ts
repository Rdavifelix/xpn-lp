/** Only fixed endpoints and allowlisted responses; provider payloads contain secrets. */
export function providerUrl(raw: string): string {
 const u=new URL(raw);
 if(u.protocol!=='https:'||u.username||u.password||u.search||u.hash)throw new Error('URL Uazapi inválida; configure HTTPS nas integrações.');
 return u.href.replace(/\/$/,'');
}
export async function uazapi(base:string,key:string,path:'/instance/create'|'/instance/all'|'/instance/connect'|'/instance/status'|'/webhook',body?:unknown,admin=false){
 const res=await fetch(providerUrl(base)+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',[admin?'admintoken':'token']:key},body:body===undefined?undefined:JSON.stringify(body),redirect:'error',signal:AbortSignal.timeout(10000)});
 if(!res.ok)throw new Error(`Uazapi recusou a operação (HTTP ${res.status}). Confira a configuração e consulte o estado antes de repetir.`);
 const data=await res.json();
 if(data?.error)throw new Error('Uazapi retornou um erro. Confira a configuração da instância.');
 return data;
}
export function connection(data:any){
 const i=data?.instance??{};
 const status=i.status??(typeof data?.status==='string'?data.status:null);
 const connected=status==='connected'||data?.connected===true||data?.status?.connected===true;
 const raw=i.qrcode??data?.qrcode;
 const qr=typeof raw==='string' && /^data:image\/png;base64,[A-Za-z0-9+/=\r\n]+$/.test(raw) && raw.length<600000?raw:null;
 return {connected,status:connected?'connected':(['connecting','disconnected','hibernated'].includes(status)?status:'unknown'),qr_code:connected?null:qr,phone_number:connected?String(data?.status?.jid?.user??data?.jid?.user??i.owner??'').replace(/@.*$/,''):null,checked_at:new Date().toISOString()};
}
export function webhookMatches(data:any,url:string){
 const items=Array.isArray(data)?data:[data];
 return items.some(x=>x?.enabled===true&&x.url===url&&['messages','connection'].every(e=>x.events?.includes(e))&&x.excludeMessages?.includes('wasSentByApi'));
}
