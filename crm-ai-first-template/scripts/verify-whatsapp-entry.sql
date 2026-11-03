BEGIN;
DO $$
DECLARE tid uuid:='460a7547-78fb-4c5a-adac-e1837abeb607';mid uuid:='0ffc1a8e-acf9-41b5-b2f4-9dda34adc2ab';pid uuid:='bc16a1c7-378e-4df3-a84f-70f521472a19';sid uuid;iid uuid;aid uuid;lid uuid;did uuid;r jsonb;b jsonb;failed boolean;
BEGIN
 UPDATE tenants SET is_active=true WHERE id=tid;UPDATE team_members SET is_active=true WHERE id=mid;
 SELECT id INTO sid FROM sales_pipeline_stages WHERE pipeline_id=pid AND NOT is_won AND NOT is_lost ORDER BY position LIMIT 1;
 INSERT INTO whatsapp_instances(tenant_id,name,api_url,api_key,status,purpose,teams) VALUES(tid,'QA entry','https://example.invalid','synthetic','connected','inbox',ARRAY['comercial']) RETURNING id INTO iid;
 INSERT INTO agents_registry(tenant_id,slug,display_name,provider,model,system_prompt,is_active) VALUES(tid,'qa-entry-'||iid,'QA entry','anthropic_api','test','test',true) RETURNING id INTO aid;
 INSERT INTO leads(tenant_id,name,phone) VALUES(tid,'QA entry','5511000000000') RETURNING id INTO lid;
 b=jsonb_build_object('instance_id',iid,'agent_id',aid,'pipeline_id',pid,'stage_id',sid,'member_id',mid,'active',true);
 r=whatsapp_entry_admin(tid,mid,'save',b);
 PERFORM whatsapp_entry_admin(tid,mid,'save',b);
 IF (SELECT count(*) FROM agents_deployments WHERE tenant_id=tid AND config->>'instance_id'=iid::text AND config->>'entry_rule'='true')<>1 THEN RAISE EXCEPTION 'Duplicate route';END IF;
 r=whatsapp_entry_resolve(iid,lid);did=(r->>'deal_id')::uuid;
 IF did IS NULL OR r->>'agent_id'<>aid::text THEN RAISE EXCEPTION 'Agent/deal missing';END IF;
 IF NOT EXISTS(SELECT 1 FROM deals WHERE id=did AND pipeline_id=pid AND pipeline_stage_id=sid AND sales_rep_id=mid) THEN RAISE EXCEPTION 'Wrong destination';END IF;
 PERFORM whatsapp_entry_resolve(iid,lid);
 IF (SELECT count(*) FROM deals WHERE tenant_id=tid AND lead_id=lid)<>1 THEN RAISE EXCEPTION 'Repeated message duplicated opportunity';END IF;
 UPDATE deals SET status='lost' WHERE id=did;PERFORM whatsapp_entry_resolve(iid,lid);
 IF (SELECT count(*) FROM deals WHERE tenant_id=tid AND lead_id=lid)<>1 OR (SELECT status FROM deals WHERE id=did)<>'lost' THEN RAISE EXCEPTION 'Reopened lost deal';END IF;
 PERFORM whatsapp_entry_admin(tid,mid,'save',b||'{"active":false}');r=whatsapp_entry_resolve(iid,lid);IF NOT (r->>'paused')::boolean THEN RAISE EXCEPTION 'Pause failed';END IF;
 failed=false;BEGIN PERFORM whatsapp_entry_admin(tid,mid,'save',b||jsonb_build_object('pipeline_id',gen_random_uuid()));EXCEPTION WHEN OTHERS THEN failed=true;END;IF NOT failed THEN RAISE EXCEPTION 'Foreign destination accepted';END IF;
 failed=false;BEGIN PERFORM whatsapp_entry_admin(tid,gen_random_uuid(),'save',b);EXCEPTION WHEN OTHERS THEN failed=true;END;IF NOT failed THEN RAISE EXCEPTION 'Foreign member accepted';END IF;
 IF has_function_privilege('authenticated','public.whatsapp_entry_resolve(uuid,uuid)','EXECUTE') OR has_function_privilege('anon','public.whatsapp_entry_admin(uuid,uuid,text,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Privilege leak';END IF;
 IF position('entry_rule' IN pg_get_functiondef('public.trigger_enqueue_for_ai_agent()'::regprocedure))=0 THEN RAISE EXCEPTION 'Legacy double enqueue guard missing';END IF;
END $$;
ROLLBACK;
