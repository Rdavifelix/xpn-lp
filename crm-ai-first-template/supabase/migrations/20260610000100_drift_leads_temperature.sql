-- DRIFT: colunas de temperatura do lead (criadas direto em produção;
-- usadas pelas functions da plataforma de agentes). Idempotente.
ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS lead_temperature text,
  ADD COLUMN IF NOT EXISTS temperature_reason text;
