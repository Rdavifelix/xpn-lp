import {useEffect,useMemo,useState} from 'react';
import {useSearchParams,Link} from 'react-router-dom';
import {useQueryClient} from '@tanstack/react-query';
import {AppLayout} from '@/components/layout/AppLayout';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Sheet,SheetContent,SheetHeader,SheetTitle} from '@/components/ui/sheet';
import {WhatsAppChat} from '@/components/inbox/WhatsAppChat';
import {ClientInfoPanel} from '@/components/inbox/ClientInfoPanel';
import {InstagramChat} from '@/components/sales/instagram/InstagramChat';
import {InstagramClientInfoPanel} from '@/components/sales/instagram/InstagramClientInfoPanel';
import {NetworkIcon} from '@/components/zernio/NetworkIcon';
import {useInboxConversations,type InboxConversation} from '@/hooks/useCSInbox';
import {useInstagramConversations,type InstagramConversation} from '@/hooks/useInstagram';
import {useAuth} from '@/contexts/AuthContext';
import {supabase} from '@/lib/supabase';
import {ArrowLeft,Info,MessageSquare,Search,Settings} from 'lucide-react';
import {cn} from '@/lib/utils';

type Conversation={key:string;channel:'whatsapp'|'instagram';name:string;message:string;date:string|null;unread:number;wa?:InboxConversation;ig?:InstagramConversation};
export default function UnifiedInbox(){
 const [params,setParams]=useSearchParams();
 const initial=params.get('channel');
 const [filter,setFilter]=useState(initial==='instagram'||initial==='social'?'instagram':initial==='whatsapp'?'whatsapp':'all');
 const [search,setSearch]=useState(''),[selected,setSelected]=useState<string|null>(null),[info,setInfo]=useState(false),[live,setLive]=useState(false);
 const {tenantId}=useAuth(),qc=useQueryClient();
 const wa=useInboxConversations({teamFilter:'comercial'},200);
 const ig=useInstagramConversations();
 useEffect(()=>{
  if(!tenantId)return;
  let active=true;
  const refresh=()=>{if(active)for(const key of ['inbox-conversations','conversation-messages','instagram-conversations','instagram-messages','instagram-conversation','lead-by-id'])void qc.invalidateQueries({queryKey:[key]});};
  const channel=supabase.channel('unified-inbox:'+tenantId);
  for(const table of ['whatsapp_messages','instagram_messages','instagram_conversations','zernio_conversations'])channel.on('postgres_changes',{event:'*',schema:'public',table,filter:'tenant_id=eq.'+tenantId},refresh);
  channel.subscribe(status=>{if(active){setLive(status==='SUBSCRIBED');if(status==='SUBSCRIBED')refresh();}});
  return ()=>{active=false;void supabase.removeChannel(channel);};
 },[tenantId,qc]);
 const conversations=useMemo(()=>{
  const rows:Conversation[]=[...(wa.data||[]).map(c=>({key:'wa:'+c.conversation_id,channel:'whatsapp' as const,name:c.conversation_name,message:c.last_message||'',date:c.last_message_at,unread:c.unread_count,wa:c})),...(ig.data||[]).map(c=>({key:'ig:'+c.id,channel:'instagram' as const,name:c.participant_name||c.participant_username||'Contato Instagram',message:c.last_message||'',date:c.last_message_at,unread:c.unread_count,ig:c}))];
  return rows.filter(c=>(filter==='all'||c.channel===filter)&&(!search||[c.name,c.message,c.wa?.contact_phone,c.ig?.participant_username].join(' ').toLocaleLowerCase().includes(search.toLocaleLowerCase()))).sort((a,b)=>(Date.parse(b.date||'')||0)-(Date.parse(a.date||'')||0));
 },[wa.data,ig.data,filter,search]);
 const current=conversations.find(c=>c.key===selected);
 const panel=current?.wa?<ClientInfoPanel conversation={current.wa} instanceId={current.wa.instance_id||undefined}/>:current?.ig?<InstagramClientInfoPanel conversation={current.ig}/>:<p className="p-6 text-sm text-muted-foreground">Selecione uma conversa para ver os dados do lead.</p>;
 const changeFilter=(value:string)=>{setFilter(value);setSelected(null);setParams({channel:value},{replace:true});};
 return <AppLayout><div className="flex flex-col h-[calc(100dvh-120px)] min-h-[500px] overflow-hidden rounded-xl border bg-background">
  <header className="flex items-center justify-between gap-3 border-b px-4 py-3"><div><h1 className="font-semibold text-lg">Inbox</h1><p className="text-xs text-muted-foreground">{live?'● Em tempo real':'Conectando atualização em tempo real…'}</p></div><div className="flex items-center gap-3"><Link className="text-sm text-muted-foreground hover:underline" to="/comercial/inbox/social-tools">Publicações e automações</Link><Link aria-label="Configurar canais" to="/configuracoes?s=zernio"><Settings className="h-5 w-5"/></Link></div></header>
  <div className="flex min-h-0 flex-1">
   <aside className={cn('w-full md:w-80 md:shrink-0 border-r flex flex-col',current&&'hidden md:flex')}>
    <div className="p-3 space-y-3 border-b"><div className="flex gap-1">{[['all','Todos'],['whatsapp','WhatsApp'],['instagram','Instagram']].map(([value,label])=><Button size="sm" key={value} variant={filter===value?'default':'ghost'} onClick={()=>changeFilter(value)}>{label}</Button>)}</div><div className="relative"><Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground"/><Input aria-label="Buscar conversas" placeholder="Buscar nome ou mensagem" className="pl-9" value={search} onChange={e=>setSearch(e.target.value)}/></div></div>
    <div className="overflow-y-auto flex-1">{(wa.isLoading||ig.isLoading)&&<p className="p-4 text-sm text-muted-foreground">Carregando conversas…</p>}{(wa.error||ig.error)&&<div role="alert" className="p-4 text-sm text-destructive">Não foi possível carregar {wa.error?'WhatsApp':'Instagram'}. <button className="underline" onClick={()=>{void wa.refetch();void ig.refetch();}}>Tentar novamente</button></div>}{!wa.isLoading&&!ig.isLoading&&!conversations.length&&<p className="p-6 text-sm text-muted-foreground">Nenhuma conversa encontrada.</p>}{conversations.map(c=><button key={c.key} className={cn('w-full text-left p-3 border-b flex gap-3 hover:bg-muted/50',c.key===selected&&'bg-muted')} onClick={()=>setSelected(c.key)}><NetworkIcon platform={c.channel}/><div className="min-w-0 flex-1"><div className="flex justify-between gap-2"><span className="truncate font-medium text-sm">{c.name}</span><span className="text-[10px] text-muted-foreground shrink-0">{c.date?new Date(c.date).toLocaleDateString('pt-BR',{day:'2-digit',month:'2-digit'}):''}</span></div><p className="text-xs text-muted-foreground truncate mt-1">{c.message||'Sem mensagem de texto'}</p><div className="flex justify-between mt-1"><span className="text-[10px] text-muted-foreground">{c.channel==='instagram'?'Instagram':'WhatsApp'}</span>{c.unread>0&&<span className="text-xs bg-primary text-primary-foreground rounded-full px-1.5">{c.unread}</span>}</div></div></button>)}</div>
   </aside>
   <main className={cn('flex-1 min-w-0 flex flex-col',!current&&'hidden md:flex')}>
    {current?<><div className="flex items-center justify-between border-b px-4 py-2"><div className="flex items-center gap-3 min-w-0"><Button className="md:hidden" variant="ghost" size="icon" aria-label="Voltar às conversas" onClick={()=>setSelected(null)}><ArrowLeft className="h-4 w-4"/></Button><NetworkIcon platform={current.channel}/><div className="truncate"><p className="font-medium truncate">{current.name}</p><p className="text-xs text-muted-foreground">{current.channel==='instagram'?'Instagram':'WhatsApp'}</p></div></div><Button className="xl:hidden" size="icon" variant="ghost" aria-label="Dados do lead" onClick={()=>setInfo(true)}><Info className="h-5 w-5"/></Button></div><div className="flex-1 min-h-0 flex flex-col">{current.wa?<WhatsAppChat key={current.key} contactName={current.name} contactPhone={current.wa.contact_phone} leadId={current.wa.lead_id} groupId={current.wa.group_id} instanceId={current.wa.instance_id} isGroup={current.wa.conversation_type==='grupo'} hideHeader className="flex-1" onMessageSent={()=>void wa.refetch()}/>:<InstagramChat key={current.key} conversationId={current.ig!.id} realtimeConnected={live}/>}</div></>:<div className="flex-1 flex items-center justify-center text-muted-foreground"><div className="text-center"><MessageSquare className="h-12 w-12 mx-auto mb-3 opacity-40"/><p>Selecione uma conversa</p></div></div>}
   </main>
   <aside className="hidden xl:block w-80 shrink-0 border-l overflow-y-auto">{panel}</aside>
  </div>
  <Sheet open={info} onOpenChange={setInfo}><SheetContent className="w-full sm:max-w-md p-0 overflow-y-auto"><SheetHeader className="p-4"><SheetTitle>Dados do lead</SheetTitle></SheetHeader>{panel}</SheetContent></Sheet>
 </div></AppLayout>;
}
