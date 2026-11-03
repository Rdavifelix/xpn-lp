import {db} from '../../_shared/supabase.ts';
import {adsRead} from '../../../_shared/ads-read.ts';
export async function execAdsRead(agentId:string,sessionId:string,userId:string|null,name:string,args:Record<string,unknown>){
 const {data:s,error}=await db.from('agents_sessions').select('tenant_id,agent_id,user_id').eq('id',sessionId).eq('agent_id',agentId).maybeSingle();
 if(error||!s?.tenant_id||s.user_id!==userId)throw new Error('Sessão de anúncios não autorizada');
 const {data:agent}=await db.from('agents_registry').select('tenant_id,is_template').eq('id',agentId).maybeSingle();
 if(!agent||(agent.tenant_id!==s.tenant_id&&!(agent.is_template&&!agent.tenant_id)))throw new Error('Agente não pertence à empresa');
 return adsRead(db,s.tenant_id,userId,name,args);
}
