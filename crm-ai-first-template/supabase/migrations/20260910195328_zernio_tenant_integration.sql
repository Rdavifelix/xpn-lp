BEGIN;
CREATE TABLE public.zernio_connections (
 tenant_id uuid PRIMARY KEY REFERENCES public.tenants(id),
 api_key text NOT NULL, key_hash text NOT NULL UNIQUE,
 webhook_token uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 webhook_secret text NOT NULL DEFAULT encode(gen_random_bytes(32),'hex'),
 webhook_id text, webhook_status text NOT NULL DEFAULT 'pending',
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.zernio_connections ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.zernio_connections FROM anon,authenticated;
GRANT ALL ON public.zernio_connections TO service_role;
CREATE TABLE public.zernio_accounts (
 id text PRIMARY KEY, tenant_id uuid NOT NULL REFERENCES public.tenants(id),
 profile_id text NOT NULL, platform text NOT NULL, username text NOT NULL DEFAULT '',
 name text NOT NULL DEFAULT '', is_active boolean NOT NULL DEFAULT true,
 instagram_account_id uuid REFERENCES public.instagram_business_accounts(id),
 agent_id uuid REFERENCES public.agents_registry(id), member_id uuid REFERENCES public.team_members(id),
 pipeline_id uuid REFERENCES public.sales_pipelines(id), stage_id uuid REFERENCES public.sales_pipeline_stages(id),
 automation_active boolean NOT NULL DEFAULT false, updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,id)
);
CREATE TABLE public.zernio_conversations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id uuid NOT NULL REFERENCES public.tenants(id),
 account_id text NOT NULL, remote_id text NOT NULL, participant_id text, participant_name text,
 last_message text,last_message_at timestamptz, lead_id uuid REFERENCES public.leads(id),deal_id uuid REFERENCES public.deals(id),
 instagram_conversation_id uuid REFERENCES public.instagram_conversations(id), session_id uuid REFERENCES public.agents_sessions(id),
 automation_paused boolean NOT NULL DEFAULT false,created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(account_id,remote_id),FOREIGN KEY(tenant_id,account_id) REFERENCES public.zernio_accounts(tenant_id,id)
);
CREATE TABLE public.zernio_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id uuid NOT NULL REFERENCES public.tenants(id),remote_id text NOT NULL,
 event text NOT NULL,payload jsonb NOT NULL,status text NOT NULL DEFAULT 'pending',error text,
 created_at timestamptz NOT NULL DEFAULT now(),processed_at timestamptz,UNIQUE(tenant_id,remote_id)
);
CREATE TABLE public.zernio_operations (
 tenant_id uuid NOT NULL REFERENCES public.tenants(id),request_id uuid NOT NULL,action text NOT NULL,input_hash text NOT NULL,
 status text NOT NULL DEFAULT 'running',result jsonb,created_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(tenant_id,request_id)
);
DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['zernio_accounts','zernio_conversations','zernio_events','zernio_operations'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON public.%I FROM anon,authenticated',t);
 EXECUTE format('GRANT SELECT ON public.%I TO authenticated',t);
 EXECUTE format('GRANT ALL ON public.%I TO service_role',t);
 EXECUTE format('CREATE POLICY tenant_read ON public.%I FOR SELECT TO authenticated USING (tenant_id=public.get_tenant_id() AND EXISTS(SELECT 1 FROM public.team_members m JOIN public.tenants t ON t.id=m.tenant_id WHERE m.auth_user_id=auth.uid() AND m.tenant_id=public.get_tenant_id() AND m.is_active AND t.is_active))',t);
 END LOOP; END $$;
CREATE INDEX ON public.zernio_events(status,created_at);
CREATE INDEX ON public.zernio_conversations(tenant_id,last_message_at DESC);
CREATE OR REPLACE FUNCTION public.zernio_context() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c jsonb;m public.team_members;
BEGIN
 IF (auth.jwt()->>'client_id') IS NOT NULL THEN RETURN public.mcp_context(); END IF;
 SELECT tm.* INTO m FROM public.team_members tm JOIN public.tenants t ON t.id=tm.tenant_id WHERE tm.auth_user_id=auth.uid() AND tm.tenant_id=public.get_tenant_id() AND tm.is_active AND t.is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Membro ativo obrigatório' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('tenant_id',m.tenant_id,'member_id',m.id,'user_id',auth.uid(),'can_write',m.role='admin');
END $$;
REVOKE ALL ON FUNCTION public.zernio_context() FROM PUBLIC,anon;GRANT EXECUTE ON FUNCTION public.zernio_context() TO authenticated;
-- Extend the OAuth RPC allowlist without weakening its existing checks.
DO $$ DECLARE src text;BEGIN
 SELECT pg_get_functiondef('public.mcp_request_guard()'::regprocedure) INTO src;
 IF position('rpc/zernio_context' in src)=0 THEN src:=replace(src,'''rpc/inbound_admin''','''rpc/inbound_admin'',''rpc/zernio_context''');EXECUTE src;END IF;
END $$;
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
 IF remote IS NULL OR msg->>'id' IS NULL THEN RAISE EXCEPTION 'Evento sem conversa/mensagem';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(ac.id||remote,0));
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
  IF NOT EXISTS(SELECT 1 FROM public.instagram_messages WHERE conversation_id=igid AND instagram_message_id='zernio:'||(msg->>'id')) THEN
   INSERT INTO public.instagram_messages(tenant_id,conversation_id,instagram_message_id,content,message_type,is_from_me,sent_at,status) VALUES(ac.tenant_id,igid,'zernio:'||(msg->>'id'),txt,'text',outgoing,coalesce(stamp,now()),'delivered');
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

NOTIFY pgrst,'reload schema';
COMMIT;
