/** Select only an unambiguous open opportunity of this lead in this tenant. */
export async function resolveWhatsAppDeal(db:any,tenantId:string,leadId:string|null):Promise<string|null>{
 if(!leadId)return null;
 const {data,error}=await db.from('deals').select('id').eq('tenant_id',tenantId).eq('lead_id',leadId).not('status','in','(won,lost)').limit(2);
 if(error)throw new Error('Não foi possível resolver a oportunidade do WhatsApp');
 return data?.length===1?data[0].id:null;
}
