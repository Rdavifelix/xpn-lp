-- Segurança: remove leitura anônima das tabelas de prospecção.
-- A página pública /diagnostico/:id/print lê via edge function
-- `prospeccao-diagnostico-publico` (service role, escopada por UUID).
-- (Já aplicado na origem em 2026-07-07; versionado aqui pro template.)
DROP POLICY IF EXISTS "anon read by id" ON prospeccao_diagnosticos;
DROP POLICY IF EXISTS "anon read by id" ON prospeccao_leads_descobertos;
DROP POLICY IF EXISTS "anon read by id" ON prospeccao_buscas;
