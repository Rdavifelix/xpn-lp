-- ============================================================================
-- Verificação de isolamento multi-tenant (roda e desfaz tudo: ROLLBACK).
-- Uso:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f scripts/verify-multitenant-isolation.sql
-- Precisa de privilégios de superusuário/postgres (cria dados sintéticos e
-- troca para a role authenticated). Falha (RAISE) em qualquer vazamento.
-- ============================================================================
BEGIN;

-- 0. Nenhuma policy permissiva sem guarda de tenant pode existir em tabela com tenant_id
DO $$
DECLARE v_count int; v_list text;
BEGIN
  SELECT count(*), string_agg(c.relname||'.'||p.polname, ', ') INTO v_count, v_list
  FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND p.polpermissive
    AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid=c.oid AND a.attname='tenant_id' AND NOT a.attisdropped)
    AND (p.polroles='{0}' OR EXISTS (SELECT 1 FROM pg_roles r WHERE r.oid=ANY(p.polroles) AND r.rolname='authenticated'))
    AND coalesce(pg_get_expr(p.polqual,p.polrelid),'') !~ 'tenant_id|get_tenant_id|is_admin\(\)|is_superadmin|is_tenant_admin|is_marketing_manager|crm_mcp|saas_ai'
    AND coalesce(pg_get_expr(p.polwithcheck,p.polrelid),'') !~ 'tenant_id|get_tenant_id|is_admin\(\)|is_superadmin|is_tenant_admin|is_marketing_manager|crm_mcp|saas_ai'
    AND NOT (c.relname='cs_event_rsvps' AND p.polcmd='a'); -- RSVP público: tenant vem do trigger
  IF v_count > 0 THEN RAISE EXCEPTION 'Policies permissivas sem tenant: %', v_list; END IF;
  RAISE NOTICE 'OK  nenhuma policy permissiva sem isolamento';
END $$;

-- 1. Toda tabela de negócio em public tem tenant_id (exceções: catálogos globais)
DO $$
DECLARE v_list text;
BEGIN
  SELECT string_agg(c.relname, ', ') INTO v_list
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind='r'
    AND NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid=c.oid AND a.attname='tenant_id' AND NOT a.attisdropped)
    AND c.relname NOT IN ('tenants','config','agents_skill_catalog','agents_integration_providers','prospeccao_prompts_config','prospeccao_templates_nicho');
  IF v_list IS NOT NULL THEN RAISE EXCEPTION 'Tabelas sem tenant_id: %', v_list; END IF;
  RAISE NOTICE 'OK  todas as tabelas de negócio têm tenant_id';
END $$;

-- 2. Toda tabela em public tem RLS habilitado
DO $$
DECLARE v_list text;
BEGIN
  SELECT string_agg(c.relname, ', ') INTO v_list FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind='r' AND NOT c.relrowsecurity;
  IF v_list IS NOT NULL THEN RAISE EXCEPTION 'Tabelas sem RLS: %', v_list; END IF;
  RAISE NOTICE 'OK  RLS habilitado em todas as tabelas';
END $$;

-- 3. Dados sintéticos: duas empresas, dois usuários
INSERT INTO public.tenants(id,name,slug) VALUES
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','QA Empresa A','qa-empresa-a'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','QA Empresa B','qa-empresa-b');
INSERT INTO public.team_members(tenant_id,email,name,role,auth_user_id,is_active) VALUES
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','qa-a@example.invalid','QA A','admin','11111111-1111-4111-8111-111111111111',true),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','qa-b@example.invalid','QA B','admin','22222222-2222-4222-8222-222222222222',true);
INSERT INTO public.email_templates(tenant_id,name,subject) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','QA template A','x');
INSERT INTO public.sales_playbook(tenant_id) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
INSERT INTO public.lead_interactions(tenant_id) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
INSERT INTO public.transactions(tenant_id) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
INSERT INTO public.commission_rules(tenant_id,name,commission_type,commission_value) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','QA regra A','percentage',10);
INSERT INTO public.config_audit_log(tenant_id) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
INSERT INTO public.products(id,tenant_id,name,slug) VALUES (gen_random_uuid()::text,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','QA Mentoria','qa-mentoria');

-- 4. Usuário da empresa B não vê nem altera nada da A
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","app_metadata":{"tenant_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"}}',true) \gset _
DO $$
DECLARE t text; n bigint;
BEGIN
  IF public.get_tenant_id() <> 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' THEN RAISE EXCEPTION 'get_tenant_id incorreto'; END IF;
  FOREACH t IN ARRAY ARRAY['email_templates','sales_playbook','lead_interactions','transactions','commission_rules','config_audit_log','products','team_members'] LOOP
    EXECUTE format('SELECT count(*) FROM public.%I WHERE tenant_id = %L', t, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') INTO n;
    IF n > 0 THEN RAISE EXCEPTION 'VAZAMENTO: usuário B vê % linha(s) de A em %', n, t; END IF;
  END LOOP;
  SELECT count(*) INTO n FROM public.tenants; IF n <> 1 THEN RAISE EXCEPTION 'VAZAMENTO: diretório de tenants visível (%)', n; END IF;
  UPDATE public.email_templates SET name='ALTERADO' WHERE tenant_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  SELECT count(*) INTO n FROM public.email_templates WHERE name='ALTERADO'; IF n > 0 THEN RAISE EXCEPTION 'VAZAMENTO: B alterou templates de A'; END IF;
  -- slug igual ao da outra empresa é permitido (unicidade por tenant)
  INSERT INTO public.products(id,tenant_id,name,slug) VALUES (gen_random_uuid()::text,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','QA Mentoria B','qa-mentoria');
  -- escrever em outro tenant é bloqueado pelo WITH CHECK
  BEGIN
    INSERT INTO public.sales_playbook(tenant_id) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    RAISE EXCEPTION 'VAZAMENTO: B inseriu linha no tenant A';
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN NULL; END;
  -- RPC de plataforma recusada para não-superadmin
  BEGIN
    PERFORM public.platform_list_tenants();
    RAISE EXCEPTION 'FALHA: platform_list_tenants aceitou usuário comum';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RAISE NOTICE 'OK  usuário B isolado da empresa A (leitura, escrita, unicidade, plataforma)';
END $$;
RESET ROLE;

-- 5. Superadmin administra tenants e suspensão bloqueia o acesso
UPDATE public.team_members SET is_superadmin=true WHERE auth_user_id='22222222-2222-4222-8222-222222222222';
SET LOCAL ROLE authenticated;
DO $$
DECLARE r jsonb; n int;
BEGIN
  SELECT jsonb_array_length(public.platform_list_tenants()) INTO n;
  IF n < 2 THEN RAISE EXCEPTION 'FALHA: superadmin não lista tenants (%)', n; END IF;
  r := public.platform_update_tenant('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','{"is_active":false,"suspended_reason":"qa","plan":"pro","max_users":1}'::jsonb);
  IF (r->>'is_active')::boolean OR r->>'suspended_reason' <> 'qa' OR r->>'plan' <> 'pro' THEN RAISE EXCEPTION 'FALHA: platform_update_tenant não aplicou (%)', r; END IF;
  PERFORM set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{"tenant_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}}',true);
  IF public.get_tenant_id() IS NOT NULL THEN RAISE EXCEPTION 'FALHA: tenant suspenso ainda resolve get_tenant_id'; END IF;
  SELECT count(*) INTO n FROM public.products; IF n <> 0 THEN RAISE EXCEPTION 'FALHA: usuário de tenant suspenso ainda lê dados'; END IF;
  RAISE NOTICE 'OK  superadmin lista/suspende empresas e suspensão bloqueia o acesso';
END $$;
RESET ROLE;

-- 6. Limite de usuários do plano
DO $$
BEGIN
  UPDATE public.tenants SET is_active=true, max_users=1 WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  BEGIN
    INSERT INTO public.team_members(tenant_id,email,name,role,is_active) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','qa-a2@example.invalid','QA A2','sdr',true);
    RAISE EXCEPTION 'FALHA: limite de usuários não aplicado';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RAISE NOTICE 'OK  limite de usuários por plano aplicado';
END $$;

ROLLBACK;
\echo 'Verificação de isolamento concluída: todos os dados sintéticos foram desfeitos.'
