BEGIN;
UPDATE public.config SET value='true' WHERE key='multi_tenant_enabled';
INSERT INTO auth.users(id,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
VALUES ('ce8f8da2-0e18-4200-bb52-977aac215332','mcp-rollback-test@example.invalid',now(),'{}','{}');
SELECT set_config('request.jwt.claims','{"sub":"ce8f8da2-0e18-4200-bb52-977aac215332","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
SELECT public.tenant_onboard('MCP operações teste rollback');
RESET ROLE;
INSERT INTO auth.sessions(id,user_id) VALUES('a202a202-1111-4111-8111-222222222222','ce8f8da2-0e18-4200-bb52-977aac215332');
INSERT INTO crm_mcp.clients(client_id,resource,can_write,is_active) VALUES('test-crm-operations','https://test.example/mcp',true,true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub','ce8f8da2-0e18-4200-bb52-977aac215332','role','authenticated','client_id','test-crm-operations','aud','https://test.example/mcp','session_id','a202a202-1111-4111-8111-222222222222','app_metadata',(SELECT raw_app_meta_data FROM auth.users WHERE id='ce8f8da2-0e18-4200-bb52-977aac215332'))::text,true);
RESET ROLE;
DO $$ DECLARE tid uuid:=public.get_tenant_id();a uuid;l uuid;j uuid:=gen_random_uuid();p jsonb;r jsonb;BEGIN
 INSERT INTO agents_registry(tenant_id,slug,display_name,provider,model,system_prompt,is_active) VALUES(tid,'job-test-'||gen_random_uuid(),'Teste','openai','test','Prompt de teste',false) RETURNING id INTO a;
 INSERT INTO leads(tenant_id,name) VALUES(tid,'Contato QA') RETURNING id INTO l;
 p:=jsonb_build_object('agent_id',a,'channel','playground','playground',jsonb_build_object('lead_id',l,'deal_id',null),'message','Teste controlado');
 r:=public.mcp_playground_job(j,p);IF r->>'started'<>'true' THEN RAISE EXCEPTION 'Não iniciou';END IF;
 r:=public.mcp_playground_job(j,p);IF r->>'started'<>'false' THEN RAISE EXCEPTION 'Duplicou';END IF;
 BEGIN PERFORM public.mcp_playground_job(j,p||'{"message":"diferente"}');RAISE EXCEPTION 'Replay conflitante';EXCEPTION WHEN SQLSTATE '22023' THEN NULL;END;
 PERFORM public.playground_job_progress(j,'[{"type":"done"}]','completed');
 r:=public.mcp_playground_job(j);IF r->>'status'<>'completed' THEN RAISE EXCEPTION 'Resultado ausente';END IF;
END $$;
ROLLBACK;
