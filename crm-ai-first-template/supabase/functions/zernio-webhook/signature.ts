export async function validSignature(raw:string,secret:string,signature:string){
 if(!/^[0-9a-f]{64}$/i.test(signature))return false;
 const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);
 return crypto.subtle.verify('HMAC',key,Uint8Array.from(signature.match(/../g)!.map(x=>parseInt(x,16))),new TextEncoder().encode(raw));
}
