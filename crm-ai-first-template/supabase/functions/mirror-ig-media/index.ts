// mirror-ig-media v2 — baixa URL do IG (que expira), salva no bucket instagram-media (público),
// retorna URL pública estável. Atualiza coluna `stored_*` indicada na tabela.
//
// Multi-tenant: a linha alvo (table/row_id) PRECISA pertencer ao tenant efetivo
// (JWT do usuário; ou `tenant_id` no body para callers service_role), o par
// (table, column) é restrito a uma allowlist e a URL só pode apontar para CDNs
// do Instagram/Facebook.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { authenticateRequest, authErrorResponse } from "../_shared/auth.ts";
import { TenantMismatchError, TenantRequiredError, assertEntityTenant, tenantErrorResponse } from "../_shared/tenant.ts";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const BUCKET = "instagram-media";
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36";
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// (tabela → colunas) que podem receber a URL espelhada. Todas têm tenant_id.
const ALLOWED_TARGETS: Record<string, readonly string[]> = {
  instagram_profiles: ["stored_profile_picture_url"],
  instagram_feed_posts: ["stored_thumbnail_url"],
  instagram_stories: ["stored_media_url", "stored_thumbnail_url"],
};

function isAllowedMediaUrl(raw: string): boolean {
  try {
    const u = new URL(raw);
    if (u.protocol !== "https:") return false;
    const h = u.hostname.toLowerCase();
    if (h === "graph.facebook.com") return true;
    if (h === "cdninstagram.com" || h.endsWith(".cdninstagram.com")) return true;
    if (h === "fbcdn.net" || h.endsWith(".fbcdn.net")) return true;
    if (h.startsWith("scontent") && (h.endsWith(".instagram.com") || h.endsWith(".facebook.com"))) return true;
    return false;
  } catch { return false; }
}

function isSafePath(p: string): boolean {
  return typeof p === "string" && p.length > 0 && p.length <= 512 && /^[A-Za-z0-9_\-./]+$/.test(p) && !p.includes("..") && !p.startsWith("/");
}

async function mirrorOne(supabase: any, req: any, tenantId: string) {
  try {
    if (!req.url || !req.path) return { ok: false, error: "url e path obrigatórios" };
    if (!req.table || !req.row_id || !req.column) return { ok: false, error: "table, row_id e column obrigatórios" };
    if (req.tenant_id && req.tenant_id !== tenantId) return { ok: false, error: "tenant_mismatch" };
    const allowedCols = ALLOWED_TARGETS[String(req.table)];
    if (!allowedCols || !allowedCols.includes(String(req.column))) return { ok: false, error: "table/column não permitidos" };
    if (!isAllowedMediaUrl(String(req.url))) return { ok: false, error: "url fora dos CDNs permitidos (Instagram/Facebook)" };
    if (!isSafePath(String(req.path))) return { ok: false, error: "path inválido" };

    // A linha alvo precisa existir E pertencer ao tenant — antes de baixar/gravar.
    await assertEntityTenant(supabase, String(req.table), String(req.row_id), tenantId);

    const r = await fetch(req.url, { headers: { "User-Agent": UA, "Accept": "image/*,video/*,*/*" } });
    if (!r.ok) return { ok: false, error: `fetch ${r.status}` };
    const buf = new Uint8Array(await r.arrayBuffer());
    const contentType = r.headers.get("content-type") || "image/jpeg";
    // Storage isolado por tenant: objeto gravado em <tenant_id>/<path>.
    const storagePath = `${tenantId}/${String(req.path)}`;
    const { error: upErr } = await supabase.storage.from(BUCKET).upload(storagePath, buf, { contentType, upsert: true });
    if (upErr) return { ok: false, error: `upload: ${upErr.message}` };
    const { data } = supabase.storage.from(BUCKET).getPublicUrl(storagePath);
    if (!data?.publicUrl) return { ok: false, error: "no_public_url" };
    const { data: updated, error: updErr } = await supabase
      .from(req.table)
      .update({ [req.column]: data.publicUrl })
      .eq("id", req.row_id)
      .eq("tenant_id", tenantId)
      .select("id");
    if (updErr) return { ok: false, error: `update: ${updErr.message}` };
    if (!updated || updated.length === 0) return { ok: false, error: "row_not_found_in_tenant" };
    return { ok: true, public_url: data.publicUrl };
  } catch (e: any) {
    if (e instanceof TenantMismatchError) return { ok: false, error: "row_not_found_in_tenant" };
    return { ok: false, error: e.message || String(e) };
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    let principal;
    try {
      principal = await authenticateRequest(req);
    } catch (error: any) {
      return authErrorResponse(error);
    }
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const body = await req.json();
    const items = Array.isArray(body) ? body : (body?.items || [body]);

    // Tenant efetivo: usuário → JWT; service_role → `tenant_id` no body (verificado
    // contra a linha alvo em mirrorOne). Nunca inferido/default.
    const bodyTenant = !Array.isArray(body) && typeof body?.tenant_id === "string" ? body.tenant_id : null;
    let tenantId: string;
    if (principal.isServiceRole) {
      if (!bodyTenant || !UUID_RE.test(bodyTenant)) {
        return new Response(JSON.stringify({ error: "tenant_id (uuid) obrigatório para chamadas service_role" }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
      }
      tenantId = bodyTenant;
    } else {
      if (!principal.tenantId) throw new TenantRequiredError();
      tenantId = principal.tenantId;
      if (bodyTenant && bodyTenant !== tenantId) throw new TenantMismatchError();
    }

    const results = await Promise.all(items.map((it: any) => mirrorOne(supabase, it, tenantId)));
    return new Response(JSON.stringify({ ok: true, count: results.length, results }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e: any) {
    const t = tenantErrorResponse(e, cors);
    if (t) return t;
    return new Response(JSON.stringify({ error: e.message || String(e) }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
