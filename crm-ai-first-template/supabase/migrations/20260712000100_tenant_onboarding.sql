-- ============================================================
-- ONDA B4 — Onboarding de tenants (modo SaaS)
-- ------------------------------------------------------------
-- 1. Flag `multi_tenant_enabled` na config global (default 'false').
--    Quando 'false' o app se comporta single-tenant IDÊNTICO ao atual
--    (signup normal → tenant default 0001). Quando 'true', o signup
--    do frontend mostra "Nome da empresa" e chama a edge function
--    `tenant-signup`, que cria um tenant novo isolado.
-- 2. Policy de leitura da flag para `anon` (a tela de cadastro precisa
--    saber o modo ANTES do usuário autenticar). Aditiva — não mexe na
--    policy allowlist existente (`config_read_public_or_admin`).
-- 3. Coluna `owner_user_id` em `tenants` (dono do workspace).
-- 4. RPC `tenant_seed_defaults(p_tenant_id)` — seeda pipeline "Funil de
--    Vendas" + 9 stages + PIPELINE_ROLES (override por tenant) pro
--    tenant novo. Só executável por service_role (edge function).
--
-- Idempotente: roda limpa em banco virgem e em banco existente.
-- Nunca dropa nada existente.
-- ============================================================

-- ── 1. Flag de modo SaaS (default: desligado = single-tenant) ──────────────
INSERT INTO public.config (key, value)
VALUES ('multi_tenant_enabled', 'false')
ON CONFLICT (key) DO NOTHING;

-- ── 2. Leitura da flag por anon + authenticated (só essa key) ──────────────
-- Policies de SELECT são OR entre si — isso apenas ADICIONA a permissão de
-- ler a flag, sem alterar a allowlist da config_read_public_or_admin.
DROP POLICY IF EXISTS config_read_multi_tenant_flag ON public.config;
CREATE POLICY config_read_multi_tenant_flag ON public.config
  FOR SELECT TO anon, authenticated
  USING (key = 'multi_tenant_enabled');

GRANT SELECT ON public.config TO anon;

-- ── 3. Colunas úteis em tenants ─────────────────────────────────────────────
-- (name, slug, is_active, created_at, updated_at já existem no baseline)
ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS owner_user_id uuid;

-- ── 4. Seed de defaults pro tenant novo ─────────────────────────────────────
-- Mesma estrutura do seed 20260709000100 (tenant 0001), mas com UUIDs
-- gerados (nunca os fixos 11111111-...) e PIPELINE_ROLES gravado como
-- OVERRIDE do tenant em tenant_config_overrides (a config global fica
-- intocada — pertence ao tenant default).
CREATE OR REPLACE FUNCTION public.tenant_seed_defaults(p_tenant_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pipeline uuid;
  v_s1 uuid; v_s2 uuid; v_s3 uuid; v_s4 uuid; v_s5 uuid;
  v_s6 uuid; v_s7 uuid; v_s8 uuid; v_s9 uuid;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_seed_defaults: p_tenant_id não pode ser null';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM tenants WHERE id = p_tenant_id) THEN
    RAISE EXCEPTION 'tenant_seed_defaults: tenant % não existe', p_tenant_id;
  END IF;

  -- Idempotente: tenant já tem funil → no-op
  IF EXISTS (SELECT 1 FROM sales_pipelines WHERE tenant_id = p_tenant_id) THEN
    RETURN;
  END IF;

  v_pipeline := gen_random_uuid();
  v_s1 := gen_random_uuid(); v_s2 := gen_random_uuid(); v_s3 := gen_random_uuid();
  v_s4 := gen_random_uuid(); v_s5 := gen_random_uuid(); v_s6 := gen_random_uuid();
  v_s7 := gen_random_uuid(); v_s8 := gen_random_uuid(); v_s9 := gen_random_uuid();

  INSERT INTO sales_pipelines (id, tenant_id, name, is_default)
  VALUES (v_pipeline, p_tenant_id, 'Funil de Vendas', true);

  INSERT INTO sales_pipeline_stages (id, tenant_id, pipeline_id, name, position, color, is_won, is_lost) VALUES
    (v_s1, p_tenant_id, v_pipeline, 'Novo Lead',         1, '#3b82f6', false, false),
    (v_s2, p_tenant_id, v_pipeline, 'Tentando Contato',  2, '#8b5cf6', false, false),
    (v_s3, p_tenant_id, v_pipeline, 'Em Qualificação',   3, '#06b6d4', false, false),
    (v_s4, p_tenant_id, v_pipeline, 'Reunião Agendada',  4, '#f59e0b', false, false),
    (v_s5, p_tenant_id, v_pipeline, 'No-show',           5, '#ef4444', false, false),
    (v_s6, p_tenant_id, v_pipeline, 'Reunião Realizada', 6, '#10b981', false, false),
    (v_s7, p_tenant_id, v_pipeline, 'Em Fechamento',     7, '#f97316', false, false),
    (v_s8, p_tenant_id, v_pipeline, 'Ganho',             8, '#22c55e', true,  false),
    (v_s9, p_tenant_id, v_pipeline, 'Perdido',           9, '#6b7280', false, true);

  -- Papéis semânticos apontando pros stages NOVOS, como override do tenant.
  -- Nomes duplos (call_agendada/closer_call_agendada) porque camadas
  -- diferentes do código leem chaves diferentes (igual ao seed do 0001).
  INSERT INTO tenant_config_overrides (tenant_id, key, value)
  VALUES (p_tenant_id, 'PIPELINE_ROLES', json_build_object(
    'closer', v_pipeline,
    'stages', json_build_object(
      'call_agendada',         v_s4,
      'closer_call_agendada',  v_s4,
      'no_show',               v_s5,
      'closer_noshow',         v_s5,
      'call_realizada',        v_s6,
      'closer_call_realizada', v_s6,
      'em_fechamento',         v_s7,
      'ganho',                 v_s8,
      'perdido',               v_s9,
      'sdr_leads_novos',       v_s1,
      'closer_leads_novos',    v_s1
    )
  )::text)
  ON CONFLICT (tenant_id, key) DO NOTHING; -- nunca sobrescreve override existente
END;
$$;

-- Só a edge function (service_role) pode chamar — nunca o frontend.
REVOKE ALL ON FUNCTION public.tenant_seed_defaults(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tenant_seed_defaults(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.tenant_seed_defaults(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.tenant_seed_defaults(uuid) TO service_role;
