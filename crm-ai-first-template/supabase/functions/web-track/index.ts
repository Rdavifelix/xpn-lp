import {createClient} from 'npm:@supabase/supabase-js@2.49.8';
const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'content-type','Access-Control-Allow-Methods':'POST,OPTIONS','Content-Type':'application/json','Cache-Control':'no-store'};
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers});
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return reply({error:'POST obrigatório'},405);
 try{
  const reader=req.body?.getReader();if(!reader)return reply({error:'Evento vazio'},400);
  const parts:Uint8Array[]=[];let n=0;
  while(true){const {value,done}=await reader.read();if(done)break;n+=value.length;if(n>4000){await reader.cancel();return reply({error:'Evento excede limite'},413);}parts.push(value);}
  const bytes=new Uint8Array(n);let offset=0;for(const p of parts){bytes.set(p,offset);offset+=p.length;}
  const b=JSON.parse(new TextDecoder().decode(bytes));
  const uuid=(x:unknown)=>typeof x==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(x);
  if(![b.key,b.session,b.visitor,b.event].every(uuid)||!['pageview','click'].includes(b.type)||typeof b.path!=='string'||b.path.length>2000)return reply({error:'Evento inválido'},400);
  const origin=req.headers.get('origin');if(!origin||origin==='null')return reply({error:'Origem obrigatória'},403);
  let referrer:string|null=null;try{if(b.referrer)referrer=new URL(b.referrer).hostname;}catch{}
  const text=(v:unknown,max:number)=>typeof v==='string'?v.slice(0,max):null;
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const {error}=await db.rpc('web_collect',{p_key:b.key,p_origin:origin,p_path:b.path,p_session:b.session,p_visitor:b.visitor,p_event:b.event,p_type:b.type,p_label:text(b.label,100),p_source:text(b.source,100),p_medium:text(b.medium,100),p_campaign:text(b.campaign,150),p_referrer:referrer});
  if(error)return reply({error:'Evento não aceito'},error.code==='42501'?403:error.code==='P0001'?429:400);
  return reply({ok:true});
 }catch{return reply({error:'Evento inválido'},400);}
});
