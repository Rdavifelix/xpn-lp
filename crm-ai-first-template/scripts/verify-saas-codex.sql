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
 BEGIN PERFORM public.saas_codex_refresh(gen_random_uuid(),gen_random_uuid(),'acquire');RAISE EXCEPTION 'Cliente acessou refresh';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
RESET ROLE;
UPDATE public.team_members SET is_superadmin=true WHERE auth_user_id=auth.uid();
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.saas_ai_admin('settings',p_data=>'{"provider":"openai_codex","codex_auth":{"tokens":{"access_token":"bad"}}}');RAISE EXCEPTION 'Sessão incompleta aceita';EXCEPTION WHEN SQLSTATE '22023' THEN NULL;END;
 PERFORM public.saas_ai_admin('settings',p_data=>'{"enabled":true,"provider":"openai_codex","model":"test-model","codex_auth":{"tokens":{"access_token":"fake-access-token-only-for-tests","refresh_token":"fake-refresh-token-only-for-tests","account_id":"fake-test-account"}}}');
 PERFORM public.saas_ai_admin('tenant',public.get_tenant_id(),jsonb_build_object('enabled',true,'expires_at',now()+interval '1 day','daily_calls',10));
 IF public.saas_ai_admin()::text LIKE '%fake-access%' THEN RAISE EXCEPTION 'Token exposto no painel';END IF;
END $$;
RESET ROLE;
DO $$ DECLARE a uuid; member uuid; r jsonb; sid uuid; owner1 uuid:=gen_random_uuid(); owner2 uuid:=gen_random_uuid(); auth_data jsonb;BEGIN
 SELECT id INTO member FROM public.team_members WHERE auth_user_id=auth.uid();
 INSERT INTO public.agents_registry(slug,display_name,provider,model,system_prompt,is_active,tenant_id,created_by,responsible_user_id) VALUES('qa-codex-'||gen_random_uuid(),'QA Codex','openai','test','No external calls',false,public.get_tenant_id(),member,member) RETURNING id INTO a;
 r:=public.saas_ai_resolve(a);sid:=(r->'credential'->>'id')::uuid;
 IF r->'credential'->>'provider_type'<>'openai_codex' OR r->'credential'->'auth_data'->>'account_id'<>'fake-test-account' OR r->'credential'->'metadata'->>'saas_global'<>'true' THEN RAISE EXCEPTION 'Resolução Codex falhou'; END IF;
 r:=public.saas_codex_refresh(sid,owner1,'acquire');auth_data:=r->'auth';
 IF r->>'acquired'<>'true' THEN RAISE EXCEPTION 'Lease falhou';END IF;
 r:=public.saas_codex_refresh(sid,owner2,'acquire');IF r->>'acquired'<>'false' THEN RAISE EXCEPTION 'Renovação concorrente permitida';END IF;
 BEGIN PERFORM public.saas_codex_refresh(sid,owner2,'save',auth_data);RAISE EXCEPTION 'Outro dono sobrescreveu token';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 PERFORM public.saas_codex_refresh(sid,owner1,'save',auth_data||'{"access_token":"renewed-fake-token-only-for-tests"}'::jsonb);
 r:=public.saas_ai_resolve(a);IF r->'credential'->'auth_data'->>'access_token'<>'renewed-fake-token-only-for-tests' THEN RAISE EXCEPTION 'Renovação não persistiu';END IF;
END $$;
ROLLBACK;
