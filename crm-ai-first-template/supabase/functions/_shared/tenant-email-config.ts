// Helper compartilhado: lê config de email do tenant
// Estrutura adaptada pra este CRM:
//   - resend_api_key + resend_webhook_secret → tabela `config` (key-value, padrão atual)
//   - from_email/from_name/reply_to/company_*/app_url → tabela `tenant_config` (cols dedicadas)
// Mantém interface TenantEmailConfig pra compat com o módulo Marketing.

import { getIntegrationKey } from "./config.ts";

export interface TenantEmailConfig {
  tenant_id: string;
  resend_api_key: string | null;
  resend_webhook_secret: string | null;
  from_email: string | null;
  from_name: string | null;
  reply_to: string | null;
  company_address: string | null;
  company_name: string | null;
  app_url: string | null;
  is_active: boolean;
  domain_verified: boolean;
}

/**
 * Lê config de email do tenant.
 * - Tenta tabela `tenant_config` pelos campos email_*
 * - Resend API key + webhook secret vêm de `config` (key-value padrão)
 */
export async function getTenantConfig(
  supabase: any,
  tenantId: string,
): Promise<TenantEmailConfig | null> {
  if (!tenantId) return null;

  // Resend creds vêm de config (key-value) — override do tenant → global (Onda B3)
  const [resendKey, webhookSecret] = await Promise.all([
    getIntegrationKey(supabase, "RESEND_API_KEY", tenantId),
    getIntegrationKey(supabase, "RESEND_WEBHOOK_SECRET", tenantId),
  ]);

  // Demais campos vêm de tenant_config (cols dedicadas)
  const { data: tcfg } = await supabase
    .from("tenant_config")
    .select("company_name, email_from_email, email_from_name, email_reply_to, email_company_address, email_app_url, email_is_active, email_domain_verified")
    .eq("tenant_id", tenantId)
    .maybeSingle();

  return {
    tenant_id: tenantId,
    resend_api_key: resendKey,
    resend_webhook_secret: webhookSecret,
    from_email: tcfg?.email_from_email ?? null,
    from_name: tcfg?.email_from_name ?? null,
    reply_to: tcfg?.email_reply_to ?? null,
    company_address: tcfg?.email_company_address ?? null,
    company_name: tcfg?.company_name ?? null,
    app_url: tcfg?.email_app_url ?? null,
    is_active: tcfg?.email_is_active ?? false,
    domain_verified: tcfg?.email_domain_verified ?? false,
  };
}

/**
 * Garante config ativa. Lança erro se faltar algo.
 */
export function requireActiveConfig(
  config: TenantEmailConfig | null,
  tenantId: string,
): TenantEmailConfig {
  if (!config) {
    throw new Error(`Config de email não encontrada pra tenant ${tenantId}. Configure em /configuracoes.`);
  }
  if (!config.resend_api_key) {
    throw new Error(`RESEND_API_KEY não configurada. Configure em /configuracoes/integracoes.`);
  }
  if (!config.is_active) {
    throw new Error(`Email marketing inativo pro tenant ${tenantId}. Ative em /configuracoes após verificar domínio no Resend.`);
  }
  if (!config.from_email) {
    throw new Error(`from_email não configurado em tenant_config.email_from_email.`);
  }
  return config;
}
