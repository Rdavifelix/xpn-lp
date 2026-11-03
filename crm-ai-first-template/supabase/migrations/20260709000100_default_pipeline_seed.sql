-- ============================================================
-- SEED: Pipeline de vendas default + PIPELINE_ROLES
-- ------------------------------------------------------------
-- Sem isso o CRM abre sem nenhum funil (o seed antigo morava no
-- 001_post_baseline_fixes, removido por conflitar com o baseline).
-- IDs determinísticos (família 11111111-0001-...) pra o
-- PIPELINE_ROLES apontar certo já na instalação — automações de
-- pipeline funcionam out-of-the-box. O usuário pode renomear
-- etapas ou criar outros funis à vontade (tudo via config/UI).
-- Idempotente: só roda se ainda não existir nenhum pipeline.
-- ============================================================
DO $$
DECLARE
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';
  v_pipeline uuid := '11111111-0001-0001-0001-000000000000';
BEGIN
  IF EXISTS (SELECT 1 FROM sales_pipelines) THEN
    RETURN; -- já tem funil (upgrade/reinstalação) — não mexe
  END IF;

  INSERT INTO sales_pipelines (id, tenant_id, name, is_default)
  VALUES (v_pipeline, v_tenant, 'Funil de Vendas', true)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO sales_pipeline_stages (id, tenant_id, pipeline_id, name, position, color, is_won, is_lost) VALUES
    ('11111111-0001-0001-0001-000000000001', v_tenant, v_pipeline, 'Novo Lead',         1,  '#3b82f6', false, false),
    ('11111111-0001-0001-0001-000000000002', v_tenant, v_pipeline, 'Tentando Contato',  2,  '#8b5cf6', false, false),
    ('11111111-0001-0001-0001-000000000003', v_tenant, v_pipeline, 'Em Qualificação',   3,  '#06b6d4', false, false),
    ('11111111-0001-0001-0001-000000000004', v_tenant, v_pipeline, 'Reunião Agendada',  4,  '#f59e0b', false, false),
    ('11111111-0001-0001-0001-000000000005', v_tenant, v_pipeline, 'No-show',           5,  '#ef4444', false, false),
    ('11111111-0001-0001-0001-000000000006', v_tenant, v_pipeline, 'Reunião Realizada', 6,  '#10b981', false, false),
    ('11111111-0001-0001-0001-000000000007', v_tenant, v_pipeline, 'Em Fechamento',     7,  '#f97316', false, false),
    ('11111111-0001-0001-0001-000000000008', v_tenant, v_pipeline, 'Ganho',             8,  '#22c55e', true,  false),
    ('11111111-0001-0001-0001-000000000009', v_tenant, v_pipeline, 'Perdido',           9,  '#6b7280', false, true)
  ON CONFLICT (id) DO NOTHING;

  -- Papéis semânticos apontando pro seed (automações funcionam de cara).
  -- Nomes duplos (call_agendada/closer_call_agendada) porque camadas
  -- diferentes do código leem chaves diferentes.
  INSERT INTO config (key, value) VALUES ('PIPELINE_ROLES', json_build_object(
    'closer', v_pipeline,
    'stages', json_build_object(
      'call_agendada',        '11111111-0001-0001-0001-000000000004',
      'closer_call_agendada', '11111111-0001-0001-0001-000000000004',
      'no_show',              '11111111-0001-0001-0001-000000000005',
      'closer_noshow',        '11111111-0001-0001-0001-000000000005',
      'call_realizada',       '11111111-0001-0001-0001-000000000006',
      'closer_call_realizada','11111111-0001-0001-0001-000000000006',
      'em_fechamento',        '11111111-0001-0001-0001-000000000007',
      'ganho',                '11111111-0001-0001-0001-000000000008',
      'perdido',              '11111111-0001-0001-0001-000000000009',
      'sdr_leads_novos',      '11111111-0001-0001-0001-000000000001',
      'closer_leads_novos',   '11111111-0001-0001-0001-000000000001'
    )
  )::text)
  ON CONFLICT (key) DO NOTHING; -- nunca sobrescreve config existente
END $$;
