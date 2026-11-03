import {useQuery} from '@tanstack/react-query';
import {supabase} from '@/lib/supabase';
import {useAuth} from '@/contexts/AuthContext';
import type {FormSettings} from '@/types/marketing-form.types';
const field='mt-1 w-full rounded-lg border bg-background px-3 py-2 text-sm';
export function FormDestination({settings,onChange}:{settings:FormSettings;onChange:(s:FormSettings)=>void}){
 const {tenantId}=useAuth();
 const q=useQuery({queryKey:['form-destinations',tenantId],enabled:!!tenantId,queryFn:async()=>{
  const [p,s,m]=await Promise.all([supabase.from('sales_pipelines').select('id,name').eq('is_active',true),supabase.from('sales_pipeline_stages').select('id,name,pipeline_id,position,is_won,is_lost').order('position'),supabase.from('team_members').select('id,name').eq('is_active',true)]);
  if(p.error||s.error||m.error)throw p.error||s.error||m.error;return {pipelines:p.data??[],stages:s.data??[],members:m.data??[]};
 }});
 return <section className="space-y-4 rounded-xl border bg-muted/20 p-4"><div><h3 className="font-semibold">Destino das respostas</h3><p className="text-xs text-muted-foreground mt-1">Cada envio cria ou reutiliza o contato e uma oportunidade aberta neste funil. Respostas adicionais aparecem na timeline.</p></div>{q.error&&<p role="alert">Não foi possível carregar os destinos.</p>}<label className="block text-sm">Funil<select className={field} value={settings.pipeline_id??''} onChange={e=>onChange({...settings,pipeline_id:e.target.value,stage_id:''})}><option value="">Selecione o funil</option>{q.data?.pipelines.map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label><label className="block text-sm">Etapa inicial<select className={field} value={settings.stage_id??''} onChange={e=>onChange({...settings,stage_id:e.target.value})}><option value="">Selecione a etapa</option>{q.data?.stages.filter(s=>s.pipeline_id===settings.pipeline_id&&!s.is_won&&!s.is_lost).map(s=><option key={s.id} value={s.id}>{s.name}</option>)}</select></label><label className="block text-sm">Responsável<select className={field} value={settings.responsible_id??''} onChange={e=>onChange({...settings,responsible_id:e.target.value||undefined})}><option value="">Sem responsável</option>{q.data?.members.map(m=><option key={m.id} value={m.id}>{m.name}</option>)}</select></label></section>;
}
