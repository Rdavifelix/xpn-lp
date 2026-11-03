import {createClient} from 'npm:@supabase/supabase-js@2.49.8';
import {getIntegrationKey} from '../_shared/config.ts';
const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const db=createClient(Deno.env.get('SUPABASE_URL')!,service,{auth:{persistSession:false}});
Deno.serve(async req=>{
 if(req.method!=='POST'||(!Deno.env.get('INSTAGRAM_WORKER_SECRET')||req.headers.get('x-worker-secret')!==Deno.env.get('INSTAGRAM_WORKER_SECRET')))return new Response('Forbidden',{status:403});
 const {data:jobs,error}=await db.rpc('claim_instagram_jobs');if(error)return Response.json({error:'Fila indisponível'},{status:500});
 let completed=0;
 for(const job of jobs||[]){
  try{
   const key=await getIntegrationKey(db,'SCRAPECREATORS_API_KEY',job.tenant_id);
   if(!key){await db.from('instagram_enrichment_jobs').update({status:'needs_configuration',attempts:0,detail:'Configure ScrapeCreators em Integrações para buscar a bio.',updated_at:new Date().toISOString()}).eq('lead_id',job.lead_id).eq('username',job.username);continue;}
   const r=await fetch('https://api.scrapecreators.com/v1/instagram/profile?handle='+encodeURIComponent(job.username),{headers:{'x-api-key':key},redirect:'error',signal:AbortSignal.timeout(20000)});
   if(!r.ok)throw new Error('Não foi possível consultar o perfil. Verifique a integração e tente novamente.');
   const result=await r.json(),p=result?.data?.user;
   if(!p?.username||p.username.toLowerCase()!==job.username)throw new Error('Perfil não encontrado ou usuário diferente do solicitado.');
   const {error}=await db.rpc('complete_instagram_enrichment',{p_lead:job.lead_id,p_username:job.username,p_profile:{username:p.username,full_name:p.full_name,biography:p.biography,external_url:p.external_url,instagram_user_id:String(p.id||p.pk||''),profile_picture_url_hd:p.profile_pic_url_hd||p.profile_pic_url,is_private:!!p.is_private,is_verified:!!p.is_verified,follower_count:p.edge_followed_by?.count??p.follower_count??0,following_count:p.edge_follow?.count??p.following_count??0,media_count:p.edge_owner_to_timeline_media?.count??p.media_count??0}});
   if(error)throw new Error('Não foi possível vincular o perfil.');completed++;
  }catch(e){await db.from('instagram_enrichment_jobs').update({status:'failed',detail:(e as Error).message,updated_at:new Date().toISOString()}).eq('lead_id',job.lead_id).eq('username',job.username);}
 }
 return Response.json({processed:jobs?.length||0,completed});
});
