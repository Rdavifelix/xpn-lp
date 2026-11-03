import {provider} from '../zernio-api/provider.ts';
import {metaRequest} from '../_shared/social-provider.ts';
function resolveFormat(p: any): { format: string; confidence: "exact" | "inferred" } {
  const mt = String(p.mediaType || "").toLowerCase();
  const pt = String(p.mediaProductType || "").toUpperCase();
  const plat = String(p.platform || "").toLowerCase();

  if (pt === "STORY") return { format: "story", confidence: "exact" };
  if (pt === "REELS") return { format: "reel", confidence: "exact" };

  if (plat === "instagram") {
    if (mt === "carousel") return { format: "carousel", confidence: "exact" };
    if (mt === "image") return { format: "image", confidence: "exact" };
    if (mt === "video") {
      // Só Reels reportam estes campos — quando existem, é Reel com boa confiança.
      const a = p.analytics || {};
      const temSinalDeReel = (a.igReelsAvgWatchTime ?? 0) > 0 || (a.reelsSkipRate ?? 0) > 0 || (a.igReelsVideoViewTotalTime ?? 0) > 0;
      return { format: "reel", confidence: temSinalDeReel ? "exact" : "inferred" };
    }
  }

  if (plat === "youtube") {
    const dur = p.analytics?.videoDurationSeconds;
    // O corte oficial de Short é 3min. Sem duração, cai em 'video'.
    if (typeof dur === "number" && dur > 0) return { format: dur <= 180 ? "short" : "video", confidence: "exact" };
    return { format: "video", confidence: "inferred" };
  }

  if (plat === "tiktok") return { format: "video", confidence: mt === "video" ? "exact" : "inferred" };

  if (plat === "linkedin") {
    if (mt === "carousel") return { format: "carousel", confidence: "exact" };
    if (mt === "video") return { format: "video", confidence: "exact" };
    if (mt === "image") return { format: "image", confidence: "exact" };
    return { format: "text", confidence: "inferred" };
  }

  if (mt === "carousel" || mt === "image" || mt === "video") return { format: mt, confidence: "exact" };
  return { format: "unknown", confidence: "inferred" };
}

export async function syncSocialMetrics(db:any,tid:string){
 const check=async(q:PromiseLike<any>)=>{const r=await q;if(r.error)throw new Error('Não foi possível salvar os dados das redes.');return r.data;};
 const accounts=await check(db.from('zernio_accounts').select('*').eq('tenant_id',tid).eq('is_active',true));
 if(!accounts.length)return {posts:0,dias:0,contas:0,stories:0,warnings:[]};
 const conn=await check(db.from('zernio_connections').select('api_key').eq('tenant_id',tid).maybeSingle());
 const remoteAccounts=conn?.api_key?(await provider(conn.api_key,'/accounts')).accounts||[]:[];
 let posts=0,dias=0;const warnings:string[]=[];
 const to=new Date().toISOString().slice(0,10),from=new Date(Date.now()-90*86400000).toISOString().slice(0,10);
 for(const account of accounts){
 if(!['instagram','youtube','linkedin','tiktok'].includes(account.platform))continue;
 const remote=remoteAccounts.find((x:any)=>x._id===account.id);
 const row=await check(db.from('social_accounts').upsert({tenant_id:tid,zernio_account_id:account.id,platform:account.platform,username:account.username,display_name:account.name,profile_picture:remote?.profilePicture,profile_url:remote?.profileUrl,followers_count:remote?.followersCount,needs_reconnection:!!remote?.needsReconnection,is_active:true,updated_at:new Date().toISOString()},{onConflict:'tenant_id,zernio_account_id'}).select('id').single());
 try{
 let list:any[]=[];
 if(account.provider==='meta'){
  const secret=await check(db.from('social_provider_secrets').select('*').eq('tenant_id',tid).eq('account_id',account.id).single());
  const res=await metaRequest(secret,encodeURIComponent(account.id.slice(5))+'/media?fields=id,caption,media_type,media_product_type,permalink,thumbnail_url,media_url,timestamp,like_count,comments_count&limit=100');
  list=(res.data||[]).map((p:any)=>({_id:p.id,platform:'instagram',platformPostId:p.id,mediaType:p.media_type==='CAROUSEL_ALBUM'?'carousel':p.media_type.toLowerCase(),mediaProductType:p.media_product_type,content:p.caption,platformPostUrl:p.permalink,thumbnailUrl:p.thumbnail_url||(p.media_type==='IMAGE'?p.media_url:null),publishedAt:p.timestamp,analytics:{likes:p.like_count,comments:p.comments_count}}));
 }else{
  if(!conn?.api_key)throw new Error('Conexão sem credencial');
  for(let page=1;page<=10;page++){
   const res=await provider(conn.api_key,'/analytics?'+new URLSearchParams({accountId:account.id,fromDate:from,toDate:to,limit:'100',page:String(page),sortBy:'date',order:'desc'}));
   const batch=res.posts||[];list.push(...batch);if(!batch.length||page>=(res.pagination?.pages||1))break;
  }

 }
 const rows=list.map((p:any)=>{const a=p.analytics||{},f=resolveFormat(p);return {tenant_id:tid,account_id:row.id,zernio_post_id:account.id+':'+p._id,platform_post_id:p.platformPostId||p.platforms?.find((x:any)=>x.platform===account.platform)?.platformPostId,platform:account.platform,format:f.format,format_confidence:f.confidence,content:p.content,permalink:p.platformPostUrl,thumbnail_url:p.thumbnailUrl,published_at:p.publishedAt,impressions:a.impressions??0,reach:a.reach??0,views:a.views??0,likes:a.likes??0,comments:a.comments??0,shares:a.shares??0,saves:a.saves??0,follows:a.follows??0,engagement_rate:a.engagementRate??null,synced_at:new Date().toISOString()};});
 if(rows.length){await check(db.from('social_posts').upsert(rows,{onConflict:'tenant_id,zernio_post_id'}));posts+=rows.length;}
 if(account.provider!=='meta'){try{
  const daily=await provider(conn.api_key,'/analytics/daily-metrics?'+new URLSearchParams({accountId:account.id,fromDate:from,toDate:to}));
  const rows=(daily.dailyData||[]).flatMap((d:any)=>{const m=d.platformMetrics?.[account.platform]||d.metrics;return m?[{tenant_id:tid,account_id:row.id,platform:account.platform,metric_date:d.date,post_count:m.postCount??d.postCount??0,impressions:m.impressions??0,reach:m.reach??0,views:m.views??0,likes:m.likes??0,comments:m.comments??0,shares:m.shares??0,saves:m.saves??0}]:[];});
  if(rows.length){await check(db.from('social_metrics_daily').upsert(rows,{onConflict:'metric_date,platform,account_id'}));dias+=rows.length;}
 }catch{warnings.push((account.name||account.platform)+': histórico diário indisponível');}}
 }catch{warnings.push(account.name||account.platform);}
 }

 return {posts,dias,contas:accounts.length,stories:0,warnings};
}
