// Helpers de resolução de TENANT nas edge functions.
//
// Regra: NUNCA assumir tenant único. O tenant vem de uma destas fontes,
// nesta ordem de preferência:
//   1. JWT do usuário (functions chamadas pelo frontend)  → requireTenantFromRequest
//   2. Entidade do evento (webhooks: instância/conta tem tenant_id)
//   3. A própria linha processada (crons: toda linha de negócio tem tenant_id)
//
// Desde a auditoria multi-tenant (2026-11-03) NÃO existe mais fallback para o
// tenant default: uma requisição sem tenant identificável é recusada (401) e
// uma linha sem tenant_id é ignorada e registrada como órfã. O UUID do tenant
// default permanece exportado apenas para rotinas de migração de dados legados.

export const DEFAULT_TENANT = "00000000-0000-0000-0000-000000000001";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export class TenantRequiredError extends Error {
  readonly status = 401;
  constructor(message = "tenant_required") {
    super(message);
    this.name = "TenantRequiredError";
  }
}

/** Extrai app_metadata.tenant_id do JWT do request (sem validar assinatura —
 *  a validação é do gateway quando verify_jwt=true). Retorna null se ausente
 *  ou se não for um UUID. Nunca retorna o tenant default por conveniência. */
export function getTenantFromRequest(req: Request): string | null {
  try {
    const auth = req.headers.get("Authorization") || "";
    const token = auth.replace(/^Bearer\s+/i, "");
    if (!token || token.split(".").length !== 3) return null;
    const payload = JSON.parse(
      new TextDecoder().decode(
        Uint8Array.from(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0))
      )
    );
    const tenant = payload?.app_metadata?.tenant_id;
    return typeof tenant === "string" && UUID_RE.test(tenant) ? tenant : null;
  } catch {
    return null;
  }
}

/** Tenant obrigatório: lança TenantRequiredError (401) quando o JWT não traz
 *  app_metadata.tenant_id. Use em toda function chamada pelo frontend. */
export function requireTenantFromRequest(req: Request): string {
  const tenant = getTenantFromRequest(req);
  if (!tenant) throw new TenantRequiredError();
  return tenant;
}

/**
 * @deprecated Fallback para o tenant default foi removido. Mantido só para
 * compatibilidade de import; comporta-se como requireTenantFromRequest.
 */
export function getTenantFromRequestOrDefault(req: Request): string {
  return requireTenantFromRequest(req);
}

/** Resposta padrão para erros de tenant; outros erros são repassados. */
export function tenantErrorResponse(error: unknown, headers: Record<string, string> = {}): Response | null {
  if (error instanceof TenantRequiredError) {
    return new Response(JSON.stringify({ error: "Conta sem empresa vinculada. Conclua o cadastro da empresa." }), {
      status: 401,
      headers: { ...headers, "Content-Type": "application/json" },
    });
  }
  if (error instanceof TenantMismatchError) {
    return new Response(JSON.stringify({ error: "Registro não pertence à sua empresa." }), {
      status: 403,
      headers: { ...headers, "Content-Type": "application/json" },
    });
  }
  return null;
}

export class TenantMismatchError extends Error {
  readonly status = 403;
  constructor(message = "tenant_mismatch") {
    super(message);
    this.name = "TenantMismatchError";
  }
}

interface SupabaseQueryClient {
  from(table: string): any;
}

/**
 * Garante que a linha `table.id = id` pertence ao tenant informado. Para uso
 * em functions que recebem IDs no body e operam com service_role (RLS off).
 * Lança TenantMismatchError se a linha não existir ou for de outro tenant.
 * Retorna a linha (colunas em `select`) para evitar segunda consulta.
 */
export async function assertEntityTenant<T = Record<string, unknown>>(
  supabase: SupabaseQueryClient,
  table: string,
  id: string | null | undefined,
  tenantId: string,
  select = "id, tenant_id",
  idColumn = "id",
): Promise<T> {
  if (!id || !UUID_RE.test(String(id))) throw new TenantMismatchError(`${table}: id inválido`);
  const { data, error } = await supabase.from(table).select(select).eq(idColumn, id).eq("tenant_id", tenantId).maybeSingle();
  if (error) throw new Error(`${table}: ${error.message}`);
  if (!data) throw new TenantMismatchError(`${table}:${id}`);
  return data as T;
}

/** Linhas de cron sem tenant_id são órfãs: registra e sinaliza para pular. */
export function rowTenantOrSkip(row: { tenant_id?: string | null } | null | undefined, context: string): string | null {
  const tenant = row?.tenant_id;
  if (typeof tenant === "string" && UUID_RE.test(tenant)) return tenant;
  console.warn(`[tenant] ${context}: linha sem tenant_id ignorada`);
  return null;
}
