BEGIN;
DO $$
DECLARE tid uuid:='460a7547-78fb-4c5a-adac-e1837abeb607';mid uuid:='0ffc1a8e-acf9-41b5-b2f4-9dda34adc2ab';pipe uuid:='bc16a1c7-378e-4df3-a84f-70f521472a19';stage uuid;ig uuid;p text;r jsonb;c jsonb;first_id text;msg jsonb;eid uuid;
BEGIN
 UPDATE public.tenants SET is_active=true WHERE id=tid;UPDATE public.team_members SET is_active=true WHERE id=mid;
 SELECT id INTO stage FROM public.sales_pipeline_stages WHERE pipeline_id=pipe AND NOT is_won AND NOT is_lost ORDER BY position LIMIT 1;
 FOREACH p IN ARRAY ARRAY['zernio','meta'] LOOP
  INSERT INTO public.instagram_business_accounts(tenant_id,name,instagram_username,access_token) VALUES(tid,'QA social '||p,'qa_'||p,'synthetic') RETURNING id INTO ig;
  INSERT INTO public.zernio_accounts(id,tenant_id,provider,profile_id,platform,name,instagram_account_id,member_id,pipeline_id,stage_id) VALUES('test-'||p,tid,p,'qa-profile','instagram','QA',ig,mid,pipe,stage);
  msg:=jsonb_build_object('id','comment-1','kind','post_comment','text','Quero conhecer','sender',jsonb_build_object('id','person-1','username','qa'),'comment_id','comment-1','reference_id','post-1','reference_type','post','sentAt',now());
  r:=public.social_record_interaction('test-'||p,'comment:person-1',msg);c:=r->'conversation';first_id:=c->>'instagram_conversation_id';
  IF c->>'lead_id' IS NULL OR c->>'deal_id' IS NULL THEN RAISE EXCEPTION 'Missing lead/deal %',p;END IF;
  IF NOT EXISTS(SELECT 1 FROM public.deals WHERE id=(c->>'deal_id')::uuid AND pipeline_stage_id=stage AND tenant_id=tid) THEN RAISE EXCEPTION 'Wrong pipeline';END IF;
  r:=public.social_record_interaction('test-'||p,'comment:person-1',msg);
  IF NOT (r->>'duplicate')::boolean THEN RAISE EXCEPTION 'Missing dedup';END IF;
  msg:=jsonb_build_object('id','dm-1','kind','text','text','Oi, sou eu','sender',jsonb_build_object('id','person-1'),'sentAt',now());
  r:=public.social_record_interaction('test-'||p,'dm:person-1',msg);
  IF r#>>'{conversation,instagram_conversation_id}'<>first_id OR r#>>'{conversation,remote_id}'<>'dm:person-1' THEN RAISE EXCEPTION 'Comment and DM split';END IF;
  IF (SELECT count(*) FROM public.zernio_conversations WHERE account_id='test-'||p)<>1 THEN RAISE EXCEPTION 'Duplicate CRM conversation';END IF;
  msg:=jsonb_build_object('id','reply-1','kind','comment_reply','text','Te respondi','sender',jsonb_build_object('id','own'),'parent_id','comment-1','outgoing',true,'sentAt',now());
  PERFORM public.social_record_interaction('test-'||p,'comment:own',msg);
  IF (SELECT count(*) FROM public.instagram_messages WHERE conversation_id=first_id::uuid)<>3 THEN RAISE EXCEPTION 'Missing public reply';END IF;
  IF (SELECT count(*) FROM public.zernio_conversations WHERE account_id='test-'||p)<>1 THEN RAISE EXCEPTION 'Created own lead';END IF;
  INSERT INTO public.zernio_events(tenant_id,remote_id,event,payload) VALUES(tid,'cross-'||p,'message.received','{"account":{"accountId":"foreign"}}') RETURNING id INTO eid;
  PERFORM public.social_ingest_event(eid,jsonb_build_object('remote','dm','message',msg));
  IF (SELECT status FROM public.zernio_events WHERE id=eid)<>'ignored' THEN RAISE EXCEPTION 'Foreign account accepted';END IF;
 END LOOP;
 IF has_table_privilege('authenticated','public.social_provider_secrets','SELECT') OR has_function_privilege('authenticated','public.social_record_interaction(text,text,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Privilege leak';END IF;
END $$;
ROLLBACK;
