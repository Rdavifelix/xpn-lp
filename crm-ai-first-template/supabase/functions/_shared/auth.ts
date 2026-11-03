import { createClient, type User } from "jsr:@supabase/supabase-js@2";

export interface RequestPrincipal {
  user: User | null;
  tenantId: string | null;
  isServiceRole: boolean;
}

function bearerToken(req: Request): string {
  const header = req.headers.get("authorization") || "";
  return header.replace(/^Bearer\s+/i, "").trim();
}

/**
 * Validates the caller with Supabase Auth. Never trusts decoded JWT claims
 * before auth.getUser() has verified the signature and token state.
 */
export async function authenticateRequest(req: Request): Promise<RequestPrincipal> {
  const token = bearerToken(req);
  if (!token) throw new Error("unauthorized");

  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  if (serviceRole && token === serviceRole) {
    return { user: null, tenantId: null, isServiceRole: true };
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
  if (!supabaseUrl || !anonKey) throw new Error("auth_not_configured");

  const client = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) throw new Error("unauthorized");

  return {
    user: data.user,
    tenantId: (data.user.app_metadata?.tenant_id as string | undefined) || null,
    isServiceRole: false,
  };
}

/**
 * Exige a chave service_role (chamadas de cron/pg_net ou function→function).
 * Use em processadores agendados que não devem ser disparados por usuários.
 */
export function requireServiceRole(req: Request): void {
  const token = bearerToken(req);
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  if (!token || !serviceRole || token !== serviceRole) throw new Error("unauthorized");
}

/** Caller autenticado COM tenant; service_role passa sem tenant (crons). */
export async function authenticateTenantRequest(req: Request): Promise<RequestPrincipal & { tenantId: string | null }> {
  const principal = await authenticateRequest(req);
  if (!principal.isServiceRole && !principal.tenantId) throw new Error("tenant_required");
  return principal;
}

export function authErrorResponse(error: unknown): Response {
  const message = error instanceof Error ? error.message : "unauthorized";
  const status = message === "auth_not_configured" ? 500 : message === "forbidden" ? 403 : 401;
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
