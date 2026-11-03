import {provider,safe} from '../zernio-api/provider.ts';
export const adsToolNames=['listar_contas_meta_ads','consultar_campanhas_meta_ads','consultar_metricas_meta_ads'];
export function isAdsRead(tool:{name:string;action_type:string;action_config:Record<string,unknown>}){
 return tool.action_type==='edge_function'&&tool.action_config.name==='ads-read'&&adsToolNames.includes(tool.name);
}
const fields='account_id,account_name,campaign_id,campaign_name,adset_id,adset_name,ad_id,ad_name,spend,impressions,clicks,reach,frequency,ctr,cpc,cpm,actions,action_values,website_purchase_roas';
export function readArgs(a:Record<string,unknown>){
 const level=String(a.level||'campaign');if(!['account','campaign','adset','ad'].includes(level))throw new Error('Nível inválido');
 const limit=Number(a.limit??25);if(!Number.isInteger(limit)||limit<1||limit>100)throw new Error('Limite deve ser de 1 a 100');
 const date=(v:unknown)=>typeof v==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(v)&&new Date(v).toISOString().slice(0,10)===v;
 if((a.from_date||a.to_date)&&(!date(a.from_date)||!date(a.to_date)||String(a.from_date)>String(a.to_date)))throw new Error('Informe início e fim válidos (AAAA-MM-DD)');
 if(a.from_date&&((Date.parse(String(a.to_date))-Date.parse(String(a.from_date)))/86400000>730))throw new Error('Período máximo de 730 dias');
 const cursor=String(a.cursor||'');if(cursor.length>2000)throw new Error('Cursor inválido');
 return {level,limit,cursor,from:a.from_date?String(a.from_date):null,to:a.to_date?String(a.to_date):null};
}
// Graph pagination URLs can embed tokens: expose cursors only.
export function cleanAds(v:any):any{
 if(Array.isArray(v))return v.map(cleanAds);
 if(v&&typeof v==='object')return Object.fromEntries(Object.entries(safe(v)).filter(([k])=>!['next','previous'].includes(k)).map(([k,x])=>[k,cleanAds(x)]));return v;
}
export async function graphAds(token:string,path:string,q:URLSearchParams){
 const r=await fetch('https://graph.facebook.com/v21.0/'+path+'?'+q,{headers:{Authorization:'Bearer '+token},redirect:'error',signal:AbortSignal.timeout(22000)});
 const b=await r.json().catch(()=>({}));if(!r.ok)throw new Error('Meta Ads '+r.status+': '+String(b.error?.message||'Falha ao consultar conta').replaceAll(token,'[oculto]').slice(0,400));return cleanAds(b);
}
const checked=async(q:any)=>{const {data,error}=await q;if(error)throw new Error('Falha ao consultar conexão de anúncios');return data;};
export async function adsRead(db:any,tenantId:string,memberId:string|null,action:string,a:Record<string,unknown>){
 if(!tenantId||!adsToolNames.includes(action))throw new Error('Consulta de anúncios inválida');
 // Discovery cannot depend on an account ID the caller has not discovered yet.
 if(action==='listar_contas_meta_ads')a={connection_id:a.connection_id,limit:a.limit,cursor:a.cursor};
 const tenant=await checked(db.from('tenants').select('id').eq('id',tenantId).eq('is_active',true).maybeSingle());if(!tenant)throw new Error('Empresa inativa');
 if(memberId){const member=await checked(db.from('team_members').select('id').eq('id',memberId).eq('tenant_id',tenantId).eq('is_active',true).maybeSingle());if(!member)throw new Error('Membro não autorizado');}
 const z=await checked(db.from('zernio_accounts').select('id,name,username').eq('tenant_id',tenantId).eq('provider','zernio').eq('platform','metaads').eq('is_active',true));
 const creds=await checked(db.from('agents_provider_credentials').select('id,label,owner_user_id,is_shared').eq('tenant_id',tenantId).eq('provider_type','meta_ads').eq('is_active',true));
 const connections=[...z.map((x:any)=>({id:'zernio:'+x.id,provider:'zernio',name:x.name||x.username})),...creds.filter((x:any)=>x.is_shared||(memberId&&x.owner_user_id===memberId)).map((x:any)=>({id:'meta:'+x.id,provider:'meta',name:x.label}))];
 let conn=connections.find(x=>x.id===a.connection_id);
 if(a.connection_id&&!conn)throw new Error('Conexão não disponível nesta empresa ou para este membro');
 if(!conn&&connections.length===1)conn=connections[0];
 if(!conn)return {connections,selection_required:connections.length>1,message:connections.length?'Escolha connection_id; não troque de provedor automaticamente.':'Conecte Meta Ads em Redes sociais via Zernio ou cadastre uma credencial Meta Ads direta compartilhada com a empresa.'};
 const args=readArgs(a);let key:string;
 if(conn.provider==='zernio'){const row=await checked(db.from('zernio_connections').select('api_key').eq('tenant_id',tenantId).maybeSingle());if(!row?.api_key)throw new Error('Cadastre a chave Zernio da empresa');key=row.api_key;}
 else{const row=await checked(db.from('agents_provider_credentials').select('auth_data').eq('id',conn.id.slice(5)).eq('tenant_id',tenantId).eq('is_active',true).maybeSingle());key=row?.auth_data?.token;if(!key)throw new Error('Token Meta Ads ausente na credencial direta');}
 const remoteId=conn.id.slice(conn.id.indexOf(':')+1);
 const getZ=(path:string,q:URLSearchParams)=>provider(key,path+'?'+q).then(cleanAds);
 const aq=new URLSearchParams(conn.provider==='zernio'?{accountId:remoteId}:{fields:'id,name,currency,account_status,timezone_name',limit:String(args.limit)});
 // A requested account is checked using the provider discovery, never a free Graph path.
 if(a.ad_account_id&&!/^act_\d+$/.test(String(a.ad_account_id)))throw new Error('ad_account_id deve ser act_ seguido do ID da conta');
 if(conn.provider==='zernio'&&a.ad_account_id)aq.set('adAccountId',String(a.ad_account_id));
 if(conn.provider==='meta'&&action==='listar_contas_meta_ads'&&args.cursor)aq.set('after',args.cursor);
 let listing:any;
 if(conn.provider==='meta'&&a.ad_account_id){listing={data:[await graphAds(key,String(a.ad_account_id),new URLSearchParams({fields:'id,name,currency,account_status,timezone_name'}))]};}
 else listing=conn.provider==='zernio'?await getZ('/ads/accounts',aq):await graphAds(key,'me/adaccounts',aq);
 const accounts=conn.provider==='zernio'?listing.accounts:listing.data;
 if(!Array.isArray(accounts))throw new Error('Provedor retornou lista de contas inválida');
 if(action==='listar_contas_meta_ads')return {connections,connection:conn,accounts,paging:listing.paging};
 const account=a.ad_account_id?accounts.find((x:any)=>x.id===a.ad_account_id):accounts.length===1?accounts[0]:null;
 if(!account)return {connection:conn,accounts,selection_required:true,message:'Escolha ad_account_id da lista de contas acessíveis.',paging:listing.paging};
 const q=new URLSearchParams({limit:String(args.limit)});
 if(conn.provider==='zernio')q.set('accountId',remoteId);
 if(action==='consultar_campanhas_meta_ads'){
  if(conn.provider==='zernio'){q.set('adAccountId',account.id);q.set('source','all');const page=Number(a.page??1);if(!Number.isInteger(page)||page<1||page>10000)throw new Error('Página inválida');q.set('page',String(page));if(args.from){q.set('fromDate',args.from);q.set('toDate',args.to!);}}
  else{q.set('fields','id,name,status,effective_status,objective,daily_budget,lifetime_budget,adsets.limit(25){id,name,status,ads.limit(25){id,name,status}}');if(args.cursor)q.set('after',args.cursor);}
  return {connection:conn,ad_account_id:account.id,result:conn.provider==='zernio'?await getZ('/ads/tree',q):await graphAds(key,account.id+'/campaigns',q),note:'Resultados paginados; não considere esta página como toda a conta. Orçamentos Meta diretos estão em unidades mínimas da moeda.'};
 }
 q.set('fields',fields);q.set('level',args.level);if(args.cursor)q.set('after',args.cursor);
 if(conn.provider==='zernio'){q.set('objectId',account.id);if(args.from){q.set('fromDate',args.from);q.set('toDate',args.to!);}else q.set('datePreset','last_30d');}
 else if(args.from)q.set('time_range',JSON.stringify({since:args.from,until:args.to}));else q.set('date_preset','last_30d');
 return {connection:conn,ad_account_id:account.id,period:args.from?{from:args.from,to:args.to}:{preset:'last_30d'},result:conn.provider==='zernio'?await getZ('/ads/insights',q):await graphAds(key,account.id+'/insights',q)};
}
