import {useState,useEffect} from 'react';
import {useQuery,useQueryClient} from '@tanstack/react-query';
import {Link} from 'react-router-dom';
import {supabase} from '@/lib/supabase';
import {Button} from '@/components/ui/button';
import {useCredentials} from '../hooks/useCredentials';
const field='rounded-md border bg-background px-3 py-2 text-sm w-full';
export async function aiRpc(name:string,args:Record<string,unknown>={}){const {data,error}=await supabase.rpc(name as never,args as never);if(error)throw error;return data as any;}
export function SponsoredAI(){
 const qc=useQueryClient();const {credentials}=useCredentials();
 const q=useQuery({queryKey:['saas-ai-status'],queryFn:()=>aiRpc('saas_ai_status')});
 const [id,setId]=useState(''),[model,setModel]=useState(''),[error,setError]=useState(''),[saving,setSaving]=useState(false);
 useEffect(()=>{if(q.data){setId(q.data.credential_id??'');setModel(q.data.own_model??'');}},[q.data]);
 async function save(){setSaving(true);setError('');try{await aiRpc('saas_ai_own_credential',{p_credential_id:id||null,p_model:model||null});await qc.invalidateQueries({queryKey:['saas-ai-status']});}catch(e){setError((e as Error).message);}finally{setSaving(false);}}
 if(!q.data)return q.error?<p role="alert">{q.error.message}</p>:null;
 return <section className="mb-6 rounded-xl border bg-card p-4 space-y-3"><div className="flex justify-between gap-3"><div><h2 className="font-semibold">IA da sua empresa</h2><p className="text-sm text-muted-foreground">{q.data.enabled?'IA incluída pelo SaaS está disponível.':'IA incluída indisponível. Configure uma chave própria para os agentes.'}</p></div>{q.data.is_superadmin&&<Button variant="outline" asChild><Link to="/superadmin/ia">Superadmin · IA</Link></Button>}</div>
 {q.data.daily_calls&&<p className="text-xs text-muted-foreground">{q.data.used_today}/{q.data.daily_calls} chamadas patrocinadas hoje · renovação às 00h UTC · validade: {q.data.expires_at?new Date(q.data.expires_at).toLocaleString('pt-BR'):'não definida'}</p>}
 <div className="grid md:grid-cols-3 gap-3"><label className="text-sm">Credencial padrão da empresa<select className={field} value={id} onChange={e=>setId(e.target.value)}><option value="">Usar benefício do SaaS, se liberado</option>{credentials.filter(c=>c.is_active&&['openai_api','anthropic_api','openai_codex'].includes(c.provider_type)).map(c=><option value={c.id} key={c.id}>{c.label}</option>)}</select></label><label className="text-sm">Modelo da credencial própria<input className={field} value={model} onChange={e=>setModel(e.target.value)} placeholder="ID do modelo disponível na sua API"/></label><Button className="self-end" disabled={saving||!!id&&!model.trim()} onClick={save}>{saving?'Salvando…':'Salvar preferência'}</Button></div>
 <p className="text-xs text-muted-foreground">A credencial vinculada diretamente a um agente tem prioridade sobre esta preferência. Chaves próprias não consomem o benefício do SaaS.</p>{error&&<p role="alert" className="text-destructive text-sm">{error}</p>}</section>;
}
