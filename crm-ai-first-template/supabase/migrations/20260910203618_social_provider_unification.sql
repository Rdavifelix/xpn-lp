BEGIN;
ALTER TABLE public.instagram_messages ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;
-- Keep existing table names/IDs for compatibility; provider is connection metadata.
ALTER TABLE public.zernio_accounts ADD COLUMN provider text NOT NULL DEFAULT 'zernio' CHECK(provider IN ('zernio','meta'));
CREATE TABLE public.social_provider_secrets(
 account_id text PRIMARY KEY REFERENCES public.zernio_accounts(id),tenant_id uuid NOT NULL REFERENCES public.tenants(id),
 access_token text NOT NULL,app_secret text NOT NULL,messaging_id text NOT NULL,login_type text NOT NULL CHECK(login_type IN ('instagram','facebook')),
 webhook_token uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,verify_token text NOT NULL DEFAULT encode(gen_random_bytes(24),'hex'),
 FOREIGN KEY(tenant_id,account_id) REFERENCES public.zernio_accounts(tenant_id,id)
);
ALTER TABLE public.social_provider_secrets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.social_provider_secrets FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.social_provider_secrets TO service_role;

CREATE OR REPLACE FUNCTION public.social_record_interaction(p_account text,p_remote text,p_message jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE a public.zernio_accounts;c public.zernio_conversations;ig public.instagram_conversations;mid text:=p_message->>'id';
 outgoing boolean:=coalesce((p_message->>'outgoing')::boolean,false);kind text:=coalesce(p_message->>'kind','text');sender jsonb:=p_message->'sender';
 stamp timestamptz:=coalesce((p_message->>'sentAt')::timestamptz,now());txt text:=left(coalesce(p_message->>'text',''),10000);att jsonb:=p_message->'attachments'->0;
 lid uuid;did uuid;ignored boolean:=false;
BEGIN
 SELECT * INTO a FROM public.zernio_accounts WHERE id=p_account AND is_active;
 IF NOT FOUND OR a.platform<>'instagram' OR a.instagram_account_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=a.tenant_id AND is_active) THEN RAISE EXCEPTION 'Conexão Instagram inativa';END IF;
 IF mid IS NULL OR p_remote IS NULL THEN RAISE EXCEPTION 'Interação sem identificador';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('social:'||a.id,0));
 SELECT * INTO c FROM public.zernio_conversations WHERE tenant_id=a.tenant_id AND account_id=a.id AND remote_id=p_remote;
 IF c.id IS NULL AND outgoing AND p_message->>'parent_id' IS NOT NULL THEN
  SELECT zc.* INTO c FROM public.zernio_conversations zc JOIN public.instagram_messages im ON im.conversation_id=zc.instagram_conversation_id WHERE zc.account_id=a.id AND zc.tenant_id=a.tenant_id AND im.metadata->>'comment_id'=p_message->>'parent_id' LIMIT 1;
 END IF;
 IF c.id IS NULL AND NOT outgoing AND sender->>'id' IS NOT NULL THEN
  SELECT * INTO c FROM public.zernio_conversations WHERE tenant_id=a.tenant_id AND account_id=a.id AND participant_id=sender->>'id' ORDER BY created_at LIMIT 1;
 END IF;
 IF c.id IS NULL AND outgoing THEN RETURN jsonb_build_object('ignored',true);END IF;
 IF c.id IS NULL THEN
  INSERT INTO public.zernio_conversations(tenant_id,account_id,remote_id,participant_id,participant_name) VALUES(a.tenant_id,a.id,p_remote,sender->>'id',coalesce(sender->>'name',sender->>'username','Contato Instagram')) RETURNING * INTO c;
 ELSIF NOT outgoing AND p_remote NOT LIKE 'comment:%' AND c.remote_id LIKE 'comment:%' THEN
  UPDATE public.zernio_conversations SET remote_id=p_remote WHERE id=c.id RETURNING * INTO c;
 END IF;
 SELECT * INTO ig FROM public.instagram_conversations WHERE id=c.instagram_conversation_id AND tenant_id=a.tenant_id;
 IF ig.id IS NULL THEN
  SELECT * INTO ig FROM public.instagram_conversations WHERE account_id=a.instagram_account_id AND tenant_id=a.tenant_id AND participant_instagram_id=c.participant_id ORDER BY created_at LIMIT 1;
 END IF;
 IF ig.id IS NOT NULL AND EXISTS(SELECT 1 FROM public.instagram_messages WHERE conversation_id=ig.id AND instagram_message_id IN ('social:'||a.instagram_account_id||':'||mid,mid,'zernio:'||mid)) THEN
  RETURN jsonb_build_object('conversation',to_jsonb(c),'duplicate',true);
 END IF;
 lid:=coalesce(c.lead_id,ig.lead_id);did:=c.deal_id;
 IF NOT outgoing AND NOT coalesce((p_message->>'historical')::boolean,false) AND lid IS NULL AND a.pipeline_id IS NOT NULL AND a.stage_id IS NOT NULL AND a.member_id IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=a.member_id AND tenant_id=a.tenant_id AND is_active) OR NOT EXISTS(SELECT 1 FROM public.sales_pipeline_stages WHERE id=a.stage_id AND pipeline_id=a.pipeline_id AND tenant_id=a.tenant_id AND NOT is_won AND NOT is_lost) THEN RAISE EXCEPTION 'Destino da entrada inválido';END IF;
  INSERT INTO public.leads(tenant_id,name,source,sales_rep_id,metadata) VALUES(a.tenant_id,c.participant_name,'instagram',a.member_id,jsonb_build_object('social_account_id',a.id,'social_participant_id',c.participant_id)) RETURNING id INTO lid;
  INSERT INTO public.deals(tenant_id,lead_id,title,pipeline_id,pipeline_stage_id,sales_rep_id,status) VALUES(a.tenant_id,lid,c.participant_name,a.pipeline_id,a.stage_id,a.member_id,'negotiation') RETURNING id INTO did;
 END IF;
 IF ig.id IS NULL THEN
  INSERT INTO public.instagram_conversations(tenant_id,account_id,thread_id,participant_instagram_id,participant_name,participant_username,lead_id,assigned_to) VALUES(a.tenant_id,a.instagram_account_id,'social:'||c.id,coalesce(c.participant_id,p_remote),c.participant_name,sender->>'username',lid,a.member_id) RETURNING * INTO ig;
 END IF;
 IF att IS NOT NULL AND kind='text' THEN
  kind:=CASE WHEN att->>'type' IN ('image','video','audio','sticker') THEN att->>'type' ELSE 'link' END;
 END IF;
 INSERT INTO public.instagram_messages(tenant_id,conversation_id,instagram_message_id,content,message_type,is_from_me,sent_at,status,sender_instagram_id,sender_username,media_url,reference_type,reference_id,reference_url,metadata)
 VALUES(a.tenant_id,ig.id,'social:'||a.instagram_account_id||':'||mid,txt,kind,outgoing,stamp,'delivered',sender->>'id',sender->>'username',att->>'url',p_message->>'reference_type',p_message->>'reference_id',p_message->>'reference_url',jsonb_build_object('provider',a.provider,'comment_id',p_message->>'comment_id','parent_id',p_message->>'parent_id','attachments',coalesce(p_message->'attachments','[]'::jsonb)));
 UPDATE public.instagram_conversations SET lead_id=lid,last_message=CASE WHEN last_message_at>stamp THEN last_message ELSE txt END,last_message_at=greatest(last_message_at,stamp),last_client_message_at=CASE WHEN outgoing OR kind IN ('post_comment','comment_reply') THEN last_client_message_at ELSE greatest(last_client_message_at,stamp) END,unread_count=coalesce(unread_count,0)+CASE WHEN outgoing THEN 0 ELSE 1 END,metadata=coalesce(metadata,'{}')||jsonb_build_object('social_account_id',a.id,'social_conversation_id',c.remote_id),updated_at=now() WHERE id=ig.id;
 UPDATE public.zernio_conversations SET lead_id=lid,deal_id=did,instagram_conversation_id=ig.id,last_message=CASE WHEN last_message_at>stamp THEN last_message ELSE txt END,last_message_at=greatest(last_message_at,stamp) WHERE id=c.id RETURNING * INTO c;
 RETURN jsonb_build_object('conversation',to_jsonb(c),'duplicate',false);
END $$;
REVOKE ALL ON FUNCTION public.social_record_interaction(text,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.social_record_interaction(text,text,jsonb) TO service_role;
CREATE OR REPLACE FUNCTION public.social_ingest_event(p_event uuid,p_normalized jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE ev public.zernio_events;a public.zernio_accounts;r jsonb;c jsonb;
BEGIN
 SELECT * INTO ev FROM public.zernio_events WHERE id=p_event FOR UPDATE;
 IF NOT FOUND OR ev.status<>'pending' THEN RETURN NULL;END IF;
 SELECT * INTO a FROM public.zernio_accounts WHERE id=ev.payload#>>'{account,accountId}' AND tenant_id=ev.tenant_id AND is_active;
 IF NOT FOUND THEN UPDATE public.zernio_events SET status='ignored' WHERE id=ev.id;RETURN NULL;END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('social:'||a.id,0));
 IF EXISTS(SELECT 1 FROM public.zernio_events WHERE tenant_id=a.tenant_id AND id<>ev.id AND status IN ('agent_running','sending') AND payload#>>'{account,accountId}'=a.id) THEN RETURN NULL;END IF;
 r:=public.social_record_interaction(a.id,p_normalized->>'remote',p_normalized->'message');c:=r->'conversation';
 IF NOT coalesce((r->>'duplicate')::boolean,false) AND NOT coalesce((r->>'ignored')::boolean,false) AND a.automation_active AND NOT coalesce((c->>'automation_paused')::boolean,false) AND ev.event='message.received' AND NOT coalesce((ev.payload#>>'{metadata,standby}')::boolean,false) AND coalesce(p_normalized#>>'{message,text}','')<>'' THEN
  UPDATE public.zernio_events SET status='agent_running' WHERE id=ev.id;
  RETURN jsonb_build_object('account',to_jsonb(a),'conversation',c,'message',p_normalized#>>'{message,text}');
 END IF;
 UPDATE public.zernio_events SET status='completed',processed_at=now() WHERE id=ev.id;RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.social_ingest_event(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.social_ingest_event(uuid,jsonb) TO service_role;
CREATE OR REPLACE FUNCTION public.social_dispatch_meta_pending() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,extensions AS $$
DECLARE cn public.social_provider_secrets;body text;base text;
BEGIN
 SELECT value INTO base FROM public.config WHERE key='SUPABASE_PROJECT_URL';
 IF base IS NULL OR base !~ '^https://[a-z0-9]+\.supabase\.co$' THEN RETURN;END IF;
 FOR cn IN SELECT s.* FROM public.social_provider_secrets s JOIN public.tenants t ON t.id=s.tenant_id WHERE t.is_active AND EXISTS(SELECT 1 FROM public.zernio_events e WHERE e.tenant_id=s.tenant_id AND e.status='pending' AND e.payload#>>'{account,accountId}'=s.account_id) LOOP
 body:=jsonb_build_object('kind','drain','timestamp',now())::text;
 PERFORM net.http_post(url:=base||'/functions/v1/social-webhook?connection='||cn.webhook_token,headers:=jsonb_build_object('Content-Type','application/json','x-hub-signature-256','sha256='||encode(hmac(body,cn.app_secret,'sha256'),'hex')),body:=body::jsonb,timeout_milliseconds:=5000);
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.social_dispatch_meta_pending() FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.social_dispatch_meta_pending() TO service_role;
SELECT cron.schedule('social-meta-pending','* * * * *','SELECT public.social_dispatch_meta_pending()');
NOTIFY pgrst,'reload schema';
COMMIT;
