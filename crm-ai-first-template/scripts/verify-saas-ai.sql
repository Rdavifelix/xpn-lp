-- Executar após as migrations, com supabase db query --linked --project-ref <projeto> --file.
-- Todos os dados sintéticos são desfeitos com ROLLBACK.
BEGIN;
SELECT set_config('test.foreign_pipeline',(SELECT id::text FROM public.sales_pipelines WHERE tenant_id='00000000-0000-0000-0000-000000000001' LIMIT 1),true);
UPDATE public.config SET value='true' WHERE key='multi_tenant_enabled';
INSERT INTO auth.users(id,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
VALUES ('ce8f8da2-0e18-4200-bb52-977aac215332','mcp-rollback-test@example.invalid',now(),'{}','{}');
SELECT set_config('request.jwt.claims','{"sub":"ce8f8da2-0e18-4200-bb52-977aac215332","role":"authenticated","email":"mcp-rollback-test@example.invalid"}',true);
SET LOCAL ROLE authenticated;
SELECT public.tenant_onboard('Empresa teste rollback');
RESET ROLE;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub','ce8f8da2-0e18-4200-bb52-977aac215332','role','authenticated','app_metadata',(SELECT raw_app_meta_data FROM auth.users WHERE id='ce8f8da2-0e18-4200-bb52-977aac215332'))::text,true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF (public.saas_ai_status()->>'is_superadmin')::boolean THEN RAISE EXCEPTION 'Admin comum virou superadmin'; END IF;
 BEGIN PERFORM public.saas_ai_admin(); RAISE EXCEPTION 'Admin comum acessou global'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.saas_ai_resolve(gen_random_uuid()); RAISE EXCEPTION 'Cliente leu segredo'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
UPDATE public.team_members SET is_superadmin=true WHERE auth_user_id=auth.uid();
SET LOCAL ROLE authenticated;
SELECT public.saas_ai_admin('settings',p_data=>'{"enabled":true,"auto_enroll":true,"trial_days":7,"daily_calls":1,"provider":"openai_api","model":"test-model","api_key":"sk-fake-for-rollback-tests-only"}');
SELECT public.saas_ai_admin('tenant',public.get_tenant_id(),jsonb_build_object('enabled',true,'expires_at',now()+interval '1 day','daily_calls',1));
RESET ROLE;
DO $$ DECLARE a uuid; c uuid; r jsonb; tid uuid:=public.get_tenant_id(); member uuid; child uuid; BEGIN
 SELECT id INTO member FROM public.team_members WHERE auth_user_id=auth.uid();
 INSERT INTO public.agents_registry(slug,display_name,provider,model,system_prompt,is_active,tenant_id,created_by,responsible_user_id) VALUES('qa-saas-'||gen_random_uuid(),'QA SaaS','openai','test','No external call',false,tid,member,member) RETURNING id INTO a;
 r:=public.saas_ai_resolve(a);
 IF r->>'source'<>'sponsored' OR r->'credential'->'auth_data'->>'api_key'<>'sk-fake-for-rollback-tests-only' THEN RAISE EXCEPTION 'Resolução patrocinada falhou'; END IF;
 PERFORM public.saas_ai_finish((r->>'call_id')::uuid,true,11,7);
 PERFORM public.saas_ai_finish((r->>'call_id')::uuid,true,100,100);
 IF (SELECT input_tokens FROM saas_ai.calls WHERE id=(r->>'call_id')::uuid)<>11 THEN RAISE EXCEPTION 'Contagem repetida'; END IF;
 BEGIN PERFORM public.saas_ai_resolve(a);RAISE EXCEPTION 'Quota ignorada';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 INSERT INTO public.agents_provider_credentials(owner_user_id,tenant_id,provider_type,label,auth_data,is_active) VALUES(member,tid,'openai_api','QA own','{"api_key":"sk-fake-own"}',true) RETURNING id INTO c;
 UPDATE saas_ai.tenants SET credential_id=c,model='own-model',enabled=false WHERE tenant_id=tid;
 r:=public.saas_ai_resolve(a);IF r->>'source'<>'own' OR r->>'model'<>'own-model' THEN RAISE EXCEPTION 'Prioridade própria falhou'; END IF;
 UPDATE public.agents_provider_credentials SET is_active=false WHERE id=c;
 BEGIN PERFORM public.saas_ai_resolve(a);RAISE EXCEPTION 'Credencial inválida caiu na global';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 UPDATE saas_ai.tenants SET credential_id=NULL,enabled=true,daily_calls=20,expires_at=now()-interval '1 second' WHERE tenant_id=tid;
 BEGIN PERFORM public.saas_ai_resolve(a);RAISE EXCEPTION 'Expiração ignorada';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 UPDATE saas_ai.tenants SET expires_at=now()+interval '1 day' WHERE tenant_id=tid;
 UPDATE saas_ai.settings SET enabled=false;
 BEGIN PERFORM public.saas_ai_resolve(a);RAISE EXCEPTION 'Chave global desligada ignorada';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 INSERT INTO public.tenants(name,slug) VALUES('Auto enrollment QA','auto-qa-'||gen_random_uuid()) RETURNING id INTO child;
 IF NOT EXISTS(SELECT 1 FROM saas_ai.tenants WHERE tenant_id=child AND enabled AND daily_calls=1 AND expires_at>now()) THEN RAISE EXCEPTION 'Cadastro automático falhou';END IF;
END $$;
SET LOCAL ROLE authenticated;
DO $$ BEGIN IF public.saas_ai_admin()::text LIKE '%sk-fake%' OR public.saas_ai_status()::text LIKE '%sk-fake%' THEN RAISE EXCEPTION 'Segredo vazou';END IF; END $$;
RESET ROLE;
ROLLBACK;
