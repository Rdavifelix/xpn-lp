BEGIN;
CREATE OR REPLACE FUNCTION public.zernio_ingest(p_event_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE ev public.zernio_events;ac public.zernio_accounts;cv public.zernio_conversations;msg jsonb;sender jsonb;remote text;txt text;outgoing boolean;lid uuid;did uuid;igid uuid;stamp timestamptz;
BEGIN
 SELECT * INTO ev FROM public.zernio_events WHERE id=p_event_id FOR UPDATE;
 IF NOT FOUND OR ev.status<>'pending' THEN RETURN NULL;END IF;
 IF ev.event='webhook.test' THEN UPDATE public.zernio_connections SET webhook_status='verified' WHERE tenant_id=ev.tenant_id;UPDATE public.zernio_events SET status='completed',processed_at=now() WHERE id=ev.id;RETURN NULL;END IF;
 SELECT * INTO ac FROM public.zernio_accounts WHERE id=ev.payload#>>'{account,accountId}' AND tenant_id=ev.tenant_id AND is_active;
 IF NOT FOUND THEN UPDATE public.zernio_events SET status='ignored',error='Conta não sincronizada ou inativa',processed_at=now() WHERE id=ev.id;RETURN NULL;END IF;
 IF ev.event='account.disconnected' THEN UPDATE public.zernio_accounts SET is_active=false,automation_active=false WHERE id=ac.id;END IF;
 IF ev.event NOT IN ('message.received','message.sent') THEN UPDATE public.zernio_events SET status='completed',processed_at=now() WHERE id=ev.id;RETURN NULL;END IF;
 msg:=ev.payload->'message';sender:=msg->'sender';remote:=coalesce(ev.payload#>>'{conversation,id}',msg->>'conversationId');txt:=left(coalesce(msg->>'text',''),10000);outgoing:=ev.event='message.sent' OR msg->>'direction'='outgoing';stamp:=(msg->>'sentAt')::timestamptz;
 IF remote IS NULL OR coalesce(msg->>'platformMessageId',msg->>'id') IS NULL THEN RAISE EXCEPTION 'Evento sem conversa/mensagem';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(ac.id||remote,0));
 IF EXISTS(SELECT 1 FROM public.zernio_events ze WHERE ze.tenant_id=ac.tenant_id AND ze.id<>ev.id AND ze.status IN ('agent_running','sending') AND ze.payload#>>'{account,accountId}'=ac.id AND coalesce(ze.payload#>>'{conversation,id}',ze.payload#>>'{message,conversationId}')=remote) THEN RETURN NULL;END IF;
 SELECT * INTO cv FROM public.zernio_conversations WHERE account_id=ac.id AND remote_id=remote;
 IF NOT FOUND THEN
  INSERT INTO public.zernio_conversations(tenant_id,account_id,remote_id,participant_id,participant_name) VALUES(ac.tenant_id,ac.id,remote,sender->>'id',coalesce(sender->>'name',sender->>'username','Contato social')) RETURNING * INTO cv;
 END IF;
 lid:=cv.lead_id;did:=cv.deal_id;
 IF NOT outgoing AND lid IS NULL AND ac.pipeline_id IS NOT NULL AND ac.stage_id IS NOT NULL AND ac.member_id IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=ac.member_id AND tenant_id=ac.tenant_id AND is_active) OR NOT EXISTS(SELECT 1 FROM public.sales_pipeline_stages WHERE id=ac.stage_id AND pipeline_id=ac.pipeline_id AND tenant_id=ac.tenant_id AND NOT is_won AND NOT is_lost) THEN RAISE EXCEPTION 'Destino da entrada inválido';END IF;
  INSERT INTO public.leads(tenant_id,name,source,sales_rep_id,metadata) VALUES(ac.tenant_id,coalesce(cv.participant_name,'Contato social'),ac.platform,ac.member_id,jsonb_build_object('zernio_account_id',ac.id,'zernio_participant_id',cv.participant_id)) RETURNING id INTO lid;
  INSERT INTO public.deals(tenant_id,lead_id,title,pipeline_id,pipeline_stage_id,sales_rep_id,status) VALUES(ac.tenant_id,lid,coalesce(cv.participant_name,'Contato social'),ac.pipeline_id,ac.stage_id,ac.member_id,'negotiation') RETURNING id INTO did;
 END IF;
 igid:=cv.instagram_conversation_id;
 IF ac.platform='instagram' AND ac.instagram_account_id IS NOT NULL THEN
  IF igid IS NULL THEN
   INSERT INTO public.instagram_conversations(tenant_id,account_id,thread_id,participant_instagram_id,participant_name,participant_username,lead_id,assigned_to,metadata) VALUES(ac.tenant_id,ac.instagram_account_id,'zernio:'||ac.id||':'||remote,coalesce(cv.participant_id,remote),cv.participant_name,sender->>'username',lid,ac.member_id,jsonb_build_object('zernio_account_id',ac.id,'zernio_conversation_id',remote)) RETURNING id INTO igid;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.instagram_messages WHERE conversation_id=igid AND instagram_message_id='zernio:'||(coalesce(msg->>'platformMessageId',msg->>'id'))) THEN
   INSERT INTO public.instagram_messages(tenant_id,conversation_id,instagram_message_id,content,message_type,is_from_me,sent_at,status) VALUES(ac.tenant_id,igid,'zernio:'||(coalesce(msg->>'platformMessageId',msg->>'id')),txt,'text',outgoing,coalesce(stamp,now()),'delivered');
   UPDATE public.instagram_conversations SET last_message=txt,last_message_at=coalesce(stamp,now()),last_client_message_at=CASE WHEN outgoing THEN last_client_message_at ELSE stamp END,unread_count=unread_count+CASE WHEN outgoing THEN 0 ELSE 1 END,lead_id=lid,updated_at=now() WHERE id=igid;
  END IF;
 END IF;
 UPDATE public.zernio_conversations SET lead_id=lid,deal_id=did,instagram_conversation_id=igid,last_message=CASE WHEN last_message_at>stamp THEN last_message ELSE txt END,last_message_at=greatest(last_message_at,stamp) WHERE id=cv.id RETURNING * INTO cv;
 IF NOT outgoing AND ac.automation_active AND NOT cv.automation_paused AND NOT coalesce((ev.payload#>>'{metadata,standby}')::boolean,false) AND txt<>'' THEN
  UPDATE public.zernio_events SET status='agent_running' WHERE id=ev.id;
  RETURN jsonb_build_object('conversation',to_jsonb(cv),'account',to_jsonb(ac),'message',txt);
 END IF;
 UPDATE public.zernio_events SET status='completed',processed_at=now() WHERE id=ev.id;RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.zernio_ingest(uuid) FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.zernio_ingest(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.zernio_dispatch_pending() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,extensions AS $$
DECLARE cn public.zernio_connections;body text;base text;
BEGIN
 SELECT value INTO base FROM public.config WHERE key='SUPABASE_PROJECT_URL';
 IF base IS NULL OR base !~ '^https://[a-z0-9]+\.supabase\.co$' THEN RETURN;END IF;
 FOR cn IN SELECT zc.* FROM public.zernio_connections zc JOIN public.tenants tt ON tt.id=zc.tenant_id WHERE tt.is_active AND EXISTS(SELECT 1 FROM public.zernio_events ze WHERE ze.tenant_id=zc.tenant_id AND ze.status='pending') LOOP
 body:=jsonb_build_object('kind','drain','timestamp',now())::text;
 PERFORM net.http_post(url:=base||'/functions/v1/zernio-webhook?connection='||cn.webhook_token,headers:=jsonb_build_object('Content-Type','application/json','X-Zernio-Signature',encode(hmac(body,cn.webhook_secret,'sha256'),'hex')),body:=body::jsonb,timeout_milliseconds:=5000);
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.zernio_dispatch_pending() FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.zernio_dispatch_pending() TO service_role;
SELECT cron.schedule('zernio-pending','* * * * *','SELECT public.zernio_dispatch_pending()');
NOTIFY pgrst,'reload schema';
COMMIT;
