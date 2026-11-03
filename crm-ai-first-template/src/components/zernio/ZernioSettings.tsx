import {supabase} from '@/lib/supabase';
import {useAuth} from '@/contexts/AuthContext';
import {Dialog,DialogContent,DialogHeader,DialogTitle,DialogDescription} from '@/components/ui/dialog';
import {NetworkIcon} from './NetworkIcon';
import {MetaConnection} from './MetaConnection';
import {useState,useEffect,useRef} from 'react';
import {useQuery,useQueryClient} from '@tanstack/react-query';
import {Link} from 'react-router-dom';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Card,CardContent,CardHeader,CardTitle} from '@/components/ui/card';
import {Badge} from '@/components/ui/badge';
import {toast} from 'sonner';
import {zernio} from './api';
export function ZernioSettings(){
 const {tenantId}=useAuth();
 const qc=useQueryClient(),[key,setKey]=useState(''),[profile,setProfile]=useState(''),[busy,setBusy]=useState(false),[connection,setConnection]=useState<any>(null),[connecting,setConnecting]=useState(false),[connectionName,setConnectionName]=useState(''),[connectionError,setConnectionError]=useState('');
 const status=useQuery({queryKey:['zernio-status'],queryFn:()=>zernio('status')});
 const profiles=useQuery({queryKey:['zernio-profiles'],queryFn:()=>zernio('profiles'),enabled:!!status.data?.configured,retry:false});
 const accounts=useQuery({queryKey:['zernio-accounts'],queryFn:()=>zernio('accounts'),retry:false});
 const options=useQuery({queryKey:['zernio-options'],queryFn:()=>zernio('options')});
 const events=useQuery({queryKey:['zernio-events'],queryFn:()=>zernio('events'),enabled:!!status.data?.configured});
 useEffect(()=>{
  const available=profiles.data?.profiles;
  if(!available?.length||available.some((p:any)=>p._id===profile))return;
  const preferred=available.find((p:any)=>p.name?.trim().toLowerCase()==='default')||available[0];
  setProfile(preferred._id);
 },[profiles.data?.profiles,profile]);
 const [syncMessage,setSyncMessage]=useState('');
 const initialSync=useRef<{tenant:string;promise:Promise<any>}|null>(null);
 useEffect(()=>{
  if(!status.data?.configured||!tenantId)return;
  let current=true,inFlight=false;
  const refresh=async(initial=false)=>{
   if(inFlight||(!initial&&document.visibilityState==='hidden'))return;
   inFlight=true;
   try{
    let request:Promise<any>;
    if(initial){
     if(initialSync.current?.tenant!==tenantId)initialSync.current={tenant:tenantId,promise:zernio('sync')};
     request=initialSync.current.promise;
    }else request=zernio('sync');
    const result=await request;
    if(!current)return;
    await qc.invalidateQueries({queryKey:['zernio-accounts']});
    setSyncMessage(result.receiving_ready===false?(result.receiving_error||'Preparando o recebimento automático…'):result.synced>0?'Contas atualizadas · recebimento automático pronto.':'Nenhuma conta autorizada ainda. Escolha uma rede e conclua a autorização.');
    void qc.invalidateQueries({queryKey:['zernio-status']});
   }catch(error){if(current)setSyncMessage('Não foi possível atualizar as contas: '+(error as Error).message);}
   finally{inFlight=false;}
  };
  setSyncMessage('Conferindo suas contas…');
  void refresh(true);
  const onVisible=()=>{if(document.visibilityState==='visible')void refresh();};
  window.addEventListener('focus',onVisible);
  document.addEventListener('visibilitychange',onVisible);
  const interval=window.setInterval(()=>void refresh(),10000);
  const channel=supabase.channel('zernio-accounts:'+tenantId).on('postgres_changes',{event:'*',schema:'public',table:'zernio_accounts',filter:'tenant_id=eq.'+tenantId},()=>{void qc.invalidateQueries({queryKey:['zernio-accounts']});}).subscribe();
  return ()=>{current=false;window.clearInterval(interval);window.removeEventListener('focus',onVisible);document.removeEventListener('visibilitychange',onVisible);void supabase.removeChannel(channel);};
 },[status.data?.configured,tenantId,qc]);
 const run=async(action:string,args:Record<string,unknown>={})=>{setBusy(true);try{const result=await zernio(action,args);await qc.invalidateQueries({queryKey:['zernio-status']});await qc.invalidateQueries({queryKey:['zernio-accounts']});await qc.invalidateQueries({queryKey:['zernio-profiles']});await qc.invalidateQueries({queryKey:['zernio-events']});if(action==='sync'&&result.receiving_ready===false){setSyncMessage(result.receiving_error||'Preparando recebimento automático…');toast.warning(result.receiving_error||'Preparando recebimento automático');}else if(action==='sync'){setSyncMessage(result.synced>0?'Contas atualizadas.':'Nenhuma conta autorizada ainda.');toast.success(result.synced>0?'Contas sincronizadas':'Consulta concluída: nenhuma conta autorizada');}else if(action!=='connect'){if(result.receiving_ready===false)toast.warning(result.receiving_error||'Preparando recebimento automático');else toast.success('Operação concluída');}return result;}catch(e){toast.error((e as Error).message);return null;}finally{setBusy(false);}};
 return <div className="space-y-6 max-w-5xl"><Card><CardHeader><CardTitle>Conexão das redes sociais</CardTitle><p className="text-sm text-muted-foreground">Conecte suas redes para receber mensagens e configurar o atendimento.</p></CardHeader><CardContent className="space-y-4">
 <div className="flex gap-2"><Input aria-label="Chave da integração" type="password" autoComplete="new-password" value={key} onChange={e=>setKey(e.target.value)} placeholder={status.data?.configured?'Chave cadastrada. Cole outra para substituir.':'Cole sua chave da integração'}/><Button disabled={busy||!key.trim()} onClick={async()=>{if(await run('save_key',{api_key:key.trim()})){setKey('');await run('sync');}}}>Validar e salvar</Button></div>
 <a href="https://zernio.com/dashboard" target="_blank" rel="noreferrer" className="text-sm underline">Gerenciar integração</a>
 {status.isError&&<p role="alert">{status.error.message}</p>}
 {status.data?.configured&&<div className="flex flex-wrap gap-2 items-center"><Badge>Chave cadastrada</Badge><Badge variant="outline">{['configured','verified'].includes(status.data.webhook_status)?'Recebimento automático pronto':status.data.webhook_status==='failed'?'Recebimento pendente · nova tentativa automática':'Preparando recebimento automático'}</Badge><Button variant="outline" disabled={busy} onClick={()=>run('sync')}>Sincronizar contas</Button><Button variant="outline" disabled={busy||status.data.webhook_status==='pending'} onClick={()=>run('test_webhook')}>Testar recebimento</Button><Link className="text-sm underline" to="/comercial/inbox?channel=social">Abrir inbox das redes</Link></div>}
 {syncMessage&&<p role="status" className="text-sm text-muted-foreground">{syncMessage}</p>}
 </CardContent></Card>

 <section className="space-y-3"><h3 className="font-semibold">Contas da empresa</h3>{accounts.isError&&<p role="alert">{accounts.error.message}</p>}{accounts.data?.length===0&&<p className="text-muted-foreground">Nenhuma conta sincronizada.</p>}{accounts.data?.map((a:any)=><Account key={a.id+JSON.stringify([a.agent_id,a.automation_active])} a={a} options={options.data} run={run} busy={busy}/>)}</section>
 {status.data&&<>
 <label className="block space-y-2 text-sm">Perfil das contas<select aria-label="Perfil das contas" className="w-full rounded-md border bg-background p-2" value={profile} onChange={e=>setProfile(e.target.value)}><option value="">Escolha o perfil para conectar novas contas</option>{profiles.data?.profiles?.map((p:any)=><option key={p._id} value={p._id}>{p.name}</option>)}</select></label>
 {profiles.isError&&<p role="alert">{profiles.error.message}</p>}
 {profiles.data?.profiles?.length===0&&<p>Crie um perfil no painel da integração e atualize esta página.</p>}
 {['social','messages','ads','commerce'].map(group=><section key={group} className="space-y-3"><h3 className="font-semibold">{{social:'Redes sociais',messages:'Mensagens',ads:'Contas de anúncios',commerce:'Conteúdo da loja'}[group]}</h3><div className="grid sm:grid-cols-2 xl:grid-cols-3 gap-3">{status.data.platforms.filter((p:any)=>p.group===group).map((p:any)=>{const connected=accounts.data?.filter((a:any)=>a.platform===p.id&&a.is_active)||[];return <Card key={p.id}><CardContent className="p-4 space-y-3"><div className="flex items-center gap-3 font-medium"><NetworkIcon platform={p.id}/><span>{p.name}</span></div>{connected.length>0&&<div className="space-y-2"><Badge className="bg-emerald-100 text-emerald-800 hover:bg-emerald-100 dark:bg-emerald-950 dark:text-emerald-300">Conectado</Badge>{connected.map((a:any)=><Link key={a.id} to={'/comercial/inbox?channel=social&account='+a.id} className="block text-sm font-medium underline underline-offset-4">{a.username?'@'+a.username.replace(/^@/,''):a.name||p.name}</Link>)}</div>}<p className="text-xs text-muted-foreground">{p.group==='ads'?'Conexão e permissões próprias de anúncios':p.inbox?'Publicações e atendimento pelo inbox':'Recursos conforme disponibilidade da rede'}</p><Button variant="outline" disabled={!profile||busy} onClick={async()=>{setConnectionName(p.name);setConnection(null);setConnectionError('');setConnecting(true);setBusy(true);try{const r=await zernio('connect',{profile_id:profile,platform:p.id});if(!r?.authUrl&&!r?.dashboard_url&&!r?.instructions&&!r?.code&&!r?.alreadyConnected)throw new Error('Não recebemos o link de autorização. Tente novamente ou abra o painel da integração.');setConnection(r);}catch(e){setConnectionError((e as Error).message);}finally{setBusy(false);setConnecting(false);}}}>{connected.length?'Adicionar outra conta':'Conectar '+p.name}</Button></CardContent></Card>})}</div></section>)}
 <Dialog open={!!connectionName} onOpenChange={open=>{if(!open){setConnectionName('');setConnection(null);}}}><DialogContent className="sm:max-w-md"><DialogHeader><DialogTitle>Conectar {connectionName}</DialogTitle><DialogDescription>{connecting?'Preparando a autorização…':'Autorize sua conta para continuar a conexão com o CRM.'}</DialogDescription></DialogHeader>
 {connecting&&<p role="status" className="text-sm text-muted-foreground py-4">Preparando acesso seguro…</p>}
 {connectionError&&<p role="alert" className="text-sm text-destructive">{connectionError}</p>}
 {connection&&<div className="space-y-4">
 {connection.authUrl&&<Button asChild className="w-full"><a href={connection.authUrl} rel="noreferrer">Autorizar {connectionName}</a></Button>}
 {connection.dashboard_url&&<Button asChild className="w-full"><a href={connection.dashboard_url} rel="noreferrer">Continuar autorização</a></Button>}
 {connection.instructions&&<p className="text-sm text-muted-foreground">{Array.isArray(connection.instructions)?connection.instructions.join(' • '):connection.instructions}</p>}
 {connection.code&&<p>Código: <strong>{connection.code}</strong></p>}
 {connection.alreadyConnected&&<p className="text-sm">Esta conta já está conectada. Sincronize para atualizar a lista.</p>}
 <p className="text-sm text-muted-foreground">Ao voltar da autorização, suas contas serão sincronizadas automaticamente.</p>
 </div>}
 </DialogContent></Dialog>
 <section><h3 className="font-semibold mb-3">Recebimentos recentes</h3>{events.data?.map((e:any)=><div className="border-b py-2 text-sm" key={e.id}>{e.event} · {e.status}{e.error&&<p className="text-destructive">{e.error}</p>}</div>)}</section>
 </>}
 <Card><CardHeader><CardTitle>Meta Ads no agente de tráfego</CardTitle></CardHeader><CardContent className="space-y-3 text-sm"><p>Use sua conexão acima ou a integração direta com a Meta. O agente Vinicius encontra as conexões disponíveis e pergunta qual usar quando houver mais de uma.</p><p>No playground, peça: “Liste minhas contas Meta Ads e analise os últimos 30 dias”. As consultas usam a chave da conexão escolhida, sem cadastrar outra no agente.</p><Link className="underline" to="/agentes/credenciais">Configurar credencial Meta Ads direta</Link></CardContent></Card>
 <MetaConnection run={run} busy={busy}/>

 </div>;
}
function Account({a,options,run,busy}:{a:any;options:any;run:any;busy:boolean}){
 const [agent,setAgent]=useState(a.agent_id||''),[member,setMember]=useState(a.member_id||''),[pipeline,setPipeline]=useState(a.pipeline_id||''),[stage,setStage]=useState(a.stage_id||''),[active,setActive]=useState(a.automation_active),[disconnect,setDisconnect]=useState(false);
 const inactiveAgent=!!agent&&options?.agents?.some((item:any)=>item.id===agent&&item.is_active===false);
 return <Card><CardContent className="p-4 space-y-4"><div className="flex justify-between gap-2"><div className="flex items-center gap-3"><NetworkIcon platform={a.platform}/><div><strong>{a.name||a.username}</strong><p className="text-sm text-muted-foreground">{a.platform} · {a.is_active?'Conectada':'Desconectada'}</p></div></div><Link to={'/comercial/inbox?channel=social&account='+a.id} className="text-sm underline">Abrir conta</Link></div>
 {['instagram','facebook','twitter','bluesky','reddit','telegram','whatsapp','slack'].includes(a.platform)&&<><div className="grid sm:grid-cols-2 gap-3">{[['Agente',agent,setAgent,options?.agents],['Responsável',member,setMember,options?.members],['Pipeline',pipeline,(v:string)=>{setPipeline(v);setStage('');},options?.pipelines],['Etapa',stage,setStage,options?.stages?.filter((s:any)=>s.pipeline_id===pipeline)]].map(([label,value,set,items]:any)=><label className="text-sm space-y-1" key={label}>{label}<select aria-label={label+' '+a.name} className="w-full rounded-md border bg-background p-2" value={value} onChange={e=>set(e.target.value)}><option value="">Selecionar</option>{items?.map((x:any)=><option key={x.id} value={x.id}>{x.name}{label==='Agente'&&x.is_active===false?' (inativo)':''}</option>)}</select></label>)}</div><label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={!!active} onChange={e=>setActive(e.target.checked)}/>Atender novas mensagens automaticamente</label><p className="text-xs text-muted-foreground">O destino cria contato e oportunidade quando uma nova conversa recebe mensagem. Ativar o agente habilita respostas reais nesta conta.</p>{inactiveAgent&&<p className="text-sm rounded-lg border bg-muted/40 p-3">Este agente está inativo. Você pode salvar a configuração com o atendimento desligado. <Link className="underline font-medium" to="/agentes">Ativar em Meus agentes</Link></p>}<Button disabled={busy||(!!active&&inactiveAgent)} onClick={()=>run('bind' ,{account_id:a.id,agent_id:agent||null,member_id:member||null,pipeline_id:pipeline||null,stage_id:stage||null,active})}>Salvar atendimento</Button></>}
 {disconnect?<div className="flex gap-2 items-center"><span className="text-sm">Desconectar esta conta?</span><Button variant="destructive" disabled={busy} onClick={()=>run('disconnect',{account_id:a.id,request_id:crypto.randomUUID()})}>Confirmar desconexão</Button><Button variant="ghost" onClick={()=>setDisconnect(false)}>Cancelar</Button></div>:<Button variant="ghost" onClick={()=>setDisconnect(true)}>Desconectar conta</Button>}
 </CardContent></Card>;
}
