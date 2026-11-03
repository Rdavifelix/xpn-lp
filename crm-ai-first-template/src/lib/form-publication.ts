export function formPublication(origin:string,id:string){
 const url=new URL(`/form/${encodeURIComponent(id)}`,origin).href;
 const embedUrl=url+'?embed=1';
 return {url,embedUrl,code:`<iframe src="${embedUrl}" title="Formulário de contato" width="100%" height="720" loading="lazy" referrerpolicy="strict-origin-when-cross-origin" style="width:100%;border:0;border-radius:16px;"></iframe>`};
}
