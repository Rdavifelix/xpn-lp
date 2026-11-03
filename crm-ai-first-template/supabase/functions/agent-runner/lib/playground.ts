export interface PlaygroundSelection {lead_id:string;deal_id:string|null}
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function parsePlayground(value:unknown):PlaygroundSelection {
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Selecione um contato para o playground.');
 const x=value as Record<string,unknown>;
 if(Object.keys(x).some(k=>!['lead_id','deal_id'].includes(k))||typeof x.lead_id!=='string'||!uuid.test(x.lead_id)||
  (x.deal_id!=null&&(typeof x.deal_id!=='string'||!uuid.test(x.deal_id))))throw new Error('Contato/oportunidade inválidos.');
 return {lead_id:x.lead_id,deal_id:(x.deal_id as string|null)??null};
}
export function matchesPlayground(saved:unknown,selected:PlaygroundSelection|null):boolean{
 if(!saved)return selected===null;
 if(!selected)return false;
 try{const p=parsePlayground(saved);return p.lead_id===selected.lead_id&&p.deal_id===selected.deal_id;}catch{return false;}
}
