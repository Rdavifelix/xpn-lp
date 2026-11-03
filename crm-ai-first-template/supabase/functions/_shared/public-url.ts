/** Installation-owned origin, never a client-supplied redirect. */
export function crmPublicUrl(): string {
 const value=Deno.env.get('CRM_PUBLIC_URL');
 if(!value)throw new Error('Configure CRM_PUBLIC_URL com o endereço público deste CRM.');
 const url=new URL(value);
 if(url.protocol!=='https:' || url.username || url.password || url.search || url.hash || url.pathname!=='/')throw new Error('CRM_PUBLIC_URL deve ser uma origem HTTPS sem caminho.');
 return url.origin;
}
