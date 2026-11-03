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
DO $$ DECLARE tid uuid:=public.get_tenant_id();a uuid;l uuid;r jsonb;BEGIN
 INSERT INTO agents_registry(tenant_id,slug,display_name,provider,model,system_prompt,is_active) VALUES(tid,'qualify-test-'||gen_random_uuid(),'Teste','openai','test','Prompt de teste',false) RETURNING id INTO a;
 INSERT INTO leads(tenant_id,name) VALUES(tid,'Contato QA') RETURNING id INTO l;
 r:=public.playground_qualify_lead(l,a,p_monthly_revenue_min=>75000,p_monthly_revenue_max=>75000,p_icp_decision=>'qualified',p_reason=>'Faturamento declarado 75 mil');
 IF r->>'ok'<>'true' OR NOT EXISTS(SELECT 1 FROM leads WHERE id=l AND qualification->>'icp_decision'='qualified' AND monthly_revenue=75000) OR NOT EXISTS(SELECT 1 FROM lead_interactions WHERE lead_id=l AND interaction_type='qualification') THEN RAISE EXCEPTION 'Qualificação não persistiu';END IF;
 BEGIN PERFORM public.playground_qualify_lead(gen_random_uuid(),a,p_reason=>'Teste inválido');RAISE EXCEPTION 'Contato externo aceito';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.playground_qualify_lead(l,a,p_monthly_revenue_min=>100,p_monthly_revenue_max=>10,p_reason=>'Inválido');RAISE EXCEPTION 'Faixa inválida aceita';EXCEPTION WHEN SQLSTATE '22023' THEN NULL;END;
 UPDATE crm_mcp.clients SET can_write=false WHERE client_id='test-crm-operations';
 BEGIN PERFORM public.playground_qualify_lead(l,a,p_reason=>'Leitor');RAISE EXCEPTION 'Leitor escreveu';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
ROLLBACK;
