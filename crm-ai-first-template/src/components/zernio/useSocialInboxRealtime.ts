import {useEffect,useState} from 'react';
import {useQueryClient} from '@tanstack/react-query';
import {supabase} from '@/lib/supabase';
import {useAuth} from '@/contexts/AuthContext';

export function useSocialInboxRealtime(accountId:string){
 const {tenantId}=useAuth();
 const client=useQueryClient();
 const [connected,setConnected]=useState(false);
 useEffect(()=>{
  setConnected(false);
  if(!tenantId||!accountId)return;
  let alive=true;
  const refresh=()=>{
   if(!alive)return;
   for(const key of [['zernio-conversations',accountId],['zernio-messages',accountId],['instagram-messages'],['instagram-conversation'],['instagram-conversations']])void client.invalidateQueries({queryKey:key});
  };
  const channel=supabase.channel(`social-inbox:${tenantId}:${accountId}`)
   .on('postgres_changes',{event:'*',schema:'public',table:'zernio_conversations',filter:`account_id=eq.${accountId}`},refresh)
   .on('postgres_changes',{event:'*',schema:'public',table:'instagram_messages',filter:`tenant_id=eq.${tenantId}`},refresh)
   .on('postgres_changes',{event:'*',schema:'public',table:'instagram_conversations',filter:`tenant_id=eq.${tenantId}`},refresh)
   .subscribe(status=>{
    if(!alive)return;
    setConnected(status==='SUBSCRIBED');
    if(status==='SUBSCRIBED')refresh(); // Catch messages received before reconnect.
   });
  return ()=>{alive=false;void supabase.removeChannel(channel);};
 },[tenantId,accountId,client]);
 return connected;
}
