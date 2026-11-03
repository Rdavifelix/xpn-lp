import {useState} from 'react';
import {useQuery,useQueryClient} from '@tanstack/react-query';
import {Card,CardContent,CardHeader,CardTitle} from '@/components/ui/card';
import {Button} from '@/components/ui/button';
import {zernio} from '@/components/zernio/api';
import {toast} from 'sonner';
export function WhatsAppEntryRules(){
 const qc=useQueryClient();
 const rules=useQuery({queryKey:['whatsapp-entry-rules'],queryFn:()=>zernio('whatsapp_entry_list'),retry:false});
 const options=useQuery({queryKey:['zernio-options'],queryFn:()=>zernio('options'),retry:false});
 return <div className="space-y-4"><div><h2 className="text-lg font-semibold">Quando chegar uma mensagem neste número</h2><p className="text-sm text-muted-foreground">Escolha quem atende e onde a oportunidade entra. A regra vale para mensagens individuais recebidas. Contatos e oportunidades existentes são reaproveitados.</p></div>
 {(rules.isLoading||options.isLoading)&&<p>Carregando configurações…</p>}
 {(rules.isError||options.isError)&&<p role="alert">{rules.error?.message||options.error?.message}</p>}
 {rules.data?.instances?.length===0&&<p>Conecte um número em Configurações → WhatsApp para configurar sua entrada.</p>}
 {rules.data?.instances?.map((instance:any)=>{const rule=rules.data.rules.find((r:any)=>r.config.instance_id===instance.id);return <Entry key={instance.id+JSON.stringify(rule)} instance={instance} rule={rule} options={options.data} onSaved={()=>qc.invalidateQueries({queryKey:['whatsapp-entry-rules']})}/>;})}</div>;
}
function Entry({instance,rule,options,onSaved}:{instance:any;rule:any;options:any;onSaved:()=>unknown}){
 const [agent,setAgent]=useState(rule?.agent_id||''),[pipeline,setPipeline]=useState(rule?.config.pipeline_id||''),[stage,setStage]=useState(rule?.config.stage_id||''),[member,setMember]=useState(rule?.config.member_id||''),[active,setActive]=useState(rule?.active||false),[busy,setBusy]=useState(false);
 const select=(label:string,value:string,set:(v:string)=>void,items:any[],empty:string)=><label className="text-sm space-y-1">{label}<select aria-label={label+' '+instance.name} className="w-full rounded-md border bg-background p-2" value={value} onChange={e=>set(e.target.value)}><option value="">{empty}</option>{items?.map(x=><option key={x.id} value={x.id}>{x.name}{x.is_active===false?' (inativo)':''}</option>)}</select></label>;
 const save=async()=>{setBusy(true);try{await zernio('whatsapp_entry_save',{instance_id:instance.id,agent_id:agent,pipeline_id:pipeline,stage_id:stage,member_id:member||null,active});toast.success('Regra de entrada salva');await onSaved();}catch(e){toast.error((e as Error).message);}finally{setBusy(false);}};
 return <Card><CardHeader><CardTitle className="text-base">{instance.name} {instance.phone_number&&`· ${instance.phone_number}`}</CardTitle><p className="text-sm text-muted-foreground">{instance.status==='connected'?'WhatsApp conectado':'WhatsApp desconectado'} · {rule?(rule.active?'Regra ativa':'Regra pausada'):'Sem regra de entrada'}</p></CardHeader><CardContent className="space-y-4"><div className="grid sm:grid-cols-2 gap-4">
 {select('Agente que atende',agent,setAgent,options?.agents,'Selecionar agente')}
 {select('Pipeline de entrada',pipeline,v=>{setPipeline(v);setStage('');},options?.pipelines,'Selecionar pipeline')}
 {select('Etapa inicial',stage,setStage,options?.stages?.filter((x:any)=>x.pipeline_id===pipeline),'Selecionar etapa')}
 {select('Responsável humano (opcional)',member,setMember,options?.members,'Sem responsável inicial')}
 </div><label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={active} onChange={e=>setActive(e.target.checked)}/>Atender automaticamente as próximas mensagens</label><p className="text-xs text-muted-foreground">Ativar permite respostas reais pelo agente. Pausar mantém as mensagens no inbox e interrompe o atendimento automático deste número. A etapa inicial é aplicada apenas a oportunidades novas; as existentes mantêm sua etapa.</p><Button disabled={busy||!agent||!pipeline||!stage} onClick={save}>{busy?'Salvando…':'Salvar regra do número'}</Button></CardContent></Card>;
}
