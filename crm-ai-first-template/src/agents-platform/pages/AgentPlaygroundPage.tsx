import {useEffect,useState} from 'react';
import {useParams,Link} from 'react-router-dom';
import {useQuery} from '@tanstack/react-query';
import {AppLayout} from '@/components/layout/AppLayout';
import {Button} from '@/components/ui/button';
import {supabase} from '@/lib/supabase';
import {useAuth} from '@/contexts/AuthContext';
import {AgentChat} from '../components/AgentChat';
import {ToolCallsPanel} from '../components/ToolCallsPanel';
import {useAgent} from '../hooks/useAgent';
import {ArrowLeft,Settings,UserRound,Wrench,ChevronDown} from 'lucide-react';

type Selection={lead_id:string;deal_id:string|null};
const field='w-full rounded-md border border-border bg-background px-3 py-2 text-sm';
export default function AgentPlaygroundPage(){
 const {slug=''}=useParams<{slug:string}>();
 const {teamMember}=useAuth();
 const [search,setSearch]=useState('');const [query,setQuery]=useState('');
 const [leadId,setLeadId]=useState('');const [dealId,setDealId]=useState('');
 const [picker,setPicker]=useState(false);const [showTools,setShowTools]=useState(true);
 useEffect(()=>{const t=setTimeout(()=>setQuery(search.trim()),250);return()=>clearTimeout(t);},[search]);
 const leads=useQuery({queryKey:['playground-leads',teamMember?.id,query],enabled:!!teamMember,queryFn:async()=>{
  let q=supabase.from('leads').select('id,name,email,phone').order('name').limit(50);
  if(query)q=q.ilike('name',`%${query.replace(/[%_]/g,'')}%`);
  const {data,error}=await q;if(error)throw error;return data??[];
 }});
 const deals=useQuery({queryKey:['playground-deals',teamMember?.id,leadId],enabled:!!leadId,queryFn:async()=>{
  const {data,error}=await supabase.from('deals').select('id,title,status').eq('lead_id',leadId).order('created_at',{ascending:false}).limit(100);
  if(error)throw error;return data??[];
 }});
 useEffect(()=>{
  if(!dealId&&deals.data){
   const open=deals.data.filter(d=>!['won','lost'].includes(d.status??''));
   if(open.length===1)setDealId(open[0].id);
  }
 },[deals.data,dealId]);
 const context=useQuery({queryKey:['playground-context',teamMember?.id,leadId,dealId],enabled:!!leadId,queryFn:async()=>{
  const {data,error}=await supabase.rpc('agent_playground_context' as never,{p_lead_id:leadId,p_deal_id:dealId||null} as never);
  if(error)throw error;return data as unknown as {lead:{name:string};deal:{title:string}|null};
 }});
 const selection=leadId?{lead_id:leadId,deal_id:dealId||null}:undefined;
 const error=leads.error||deals.error||context.error;
 const toolbar=<div className="border-b px-3 py-2 bg-muted/20">
  <div className="flex items-center gap-2 flex-wrap">
   <Button size="sm" variant="outline" onClick={()=>setPicker(!picker)} aria-expanded={picker}><UserRound className="h-4 w-4 mr-2"/>{context.data?.lead.name??'Selecionar contato'}<ChevronDown className="ml-2 h-3 w-3"/></Button>
   {context.data?.deal&&<span className="text-xs text-muted-foreground truncate max-w-60">{context.data.deal.title}</span>}
   {leadId&&<span className="text-[11px] text-amber-600 dark:text-amber-400">Ações reais no CRM</span>}
   <Button size="sm" variant={showTools?'secondary':'ghost'} className="ml-auto" onClick={()=>setShowTools(!showTools)}><Wrench className="h-3.5 w-3.5 mr-1.5"/>Ferramentas</Button>
  </div>
  {picker&&<div className="mt-3 grid gap-3 md:grid-cols-3">
   <label className="text-xs space-y-1"><span>Buscar contato</span><input className={field} value={search} onChange={e=>setSearch(e.target.value)} placeholder="Nome do contato"/></label>
   <label className="text-xs space-y-1"><span>Contato</span><select className={field} value={leadId} onChange={e=>{setLeadId(e.target.value);setDealId('');}}><option value="">Selecione um contato</option>{leads.data?.map(l=><option key={l.id} value={l.id}>{l.name}{l.email?` · ${l.email}`:''}</option>)}</select></label>
   <label className="text-xs space-y-1"><span>Oportunidade</span><select className={field} disabled={!leadId||deals.isFetching} value={dealId} onChange={e=>setDealId(e.target.value)}><option value="">Selecione a oportunidade</option>{deals.data?.map(d=><option key={d.id} value={d.id}>{d.title}</option>)}</select></label>
   <p className="text-xs text-muted-foreground md:col-span-3">A seleção vale imediatamente. Trocar contato ou oportunidade começa uma nova conversa.</p>
  </div>}
  {error&&<p role="alert" className="mt-2 text-xs text-destructive">{error.message}</p>}
 </div>;
 return <AppLayout><div className="flex flex-col gap-3 p-4 h-[calc(100dvh-110px)] min-h-[600px]">
  <header className="flex items-center justify-between"><Link to="/agentes" className="text-sm flex items-center gap-2 text-muted-foreground"><ArrowLeft size={16}/> Playground</Link><Button variant="ghost" size="sm" asChild><Link to={`/agentes/${slug}/config`}><Settings className="mr-2 h-4 w-4"/>Configurar agente</Link></Button></header>
  <PlaygroundChat key={`${slug}:${leadId}:${dealId}`} slug={slug} selection={selection} toolbar={toolbar} showTools={showTools} blocked={!leadId?undefined:deals.isFetching?'Carregando oportunidades…':!dealId&&(deals.data?.length??0)>0?'Selecione a oportunidade que será usada neste atendimento.':context.isFetching?'Carregando dados do contato…':error?'Não foi possível carregar o contexto.':undefined}/>
 </div></AppLayout>;
}
function PlaygroundChat({slug,selection,toolbar,showTools,blocked}:{slug:string;selection:Selection|undefined;toolbar:React.ReactNode;showTools:boolean;blocked?:string}){
 const agent=useAgent(slug,'playground',selection);
 return <div className={`flex-1 min-h-0 grid gap-3 ${showTools?'lg:grid-cols-[minmax(0,1fr)_300px]':''}`}>
  <div className="min-h-0 rounded-xl border overflow-hidden"><AgentChat slug={slug} channel="playground" agentOverride={agent} toolbar={toolbar} sendDisabledReason={blocked} forceToolDetails hideSessionHistory subtitle="Converse com o agente ou selecione um contato para testar o atendimento"/></div>
  {showTools&&<div className="hidden lg:block min-h-0 rounded-xl border overflow-hidden"><ToolCallsPanel tools={agent.toolHistory}/></div>}
 </div>;
}
