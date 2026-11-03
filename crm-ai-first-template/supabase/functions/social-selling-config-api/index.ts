// social-selling-config-api v7 — add list_pipelines
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getIntegrationKey } from "../_shared/config.ts";
import { requireTenantFromRequest, tenantErrorResponse } from "../_shared/tenant.ts";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const ALLOWED_KEY_PREFIX = "social_selling_";
function allowedKey(key: string): boolean { return typeof key === "string" && key.startsWith(ALLOWED_KEY_PREFIX); }
const EDITABLE_AUTOMATION_FIELDS = ["name", "emoji", "description", "is_active", "trigger_type", "trigger_config", "qualification_config", "cadence_config", "on_reply_config", "rate_limit_overrides"];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    const auth = req.headers.get("Authorization") || "";
    const jwt = auth.replace(/^Bearer\s+/i, "");
    if (!jwt) return new Response(JSON.stringify({ error: "unauthenticated" }), { status: 401, headers: { ...cors, "Content-Type": "application/json" } });
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: { user }, error: authErr } = await supabase.auth.getUser(jwt);
    if (authErr || !user) return new Response(JSON.stringify({ error: "invalid_token" }), { status: 401, headers: { ...cors, "Content-Type": "application/json" } });
    // Tenant obrigatório (JWT já validado acima). Sem tenant → 401.
    const tenantId: string = requireTenantFromRequest(req);
    const { data: tm } = await supabase.from("team_members").select("id, is_active").eq("auth_user_id", user.id).maybeSingle();
    if (!tm || !tm.is_active) return new Response(JSON.stringify({ error: "forbidden" }), { status: 403, headers: { ...cors, "Content-Type": "application/json" } });

    const body = await req.json().catch(() => ({}));
    const action = body.action || "";

    if (action === "get_config") {
      const key = body.key;
      if (!allowedKey(key)) return new Response(JSON.stringify({ error: "key_not_allowed" }), { status: 403, headers: { ...cors, "Content-Type": "application/json" } });
      const raw = await getIntegrationKey(supabase, key, tenantId);
      let value: any = raw ?? null;
      if (value !== null) { try { value = JSON.parse(String(value)); } catch {} }
      return new Response(JSON.stringify({ value }), { headers: { ...cors, "Content-Type": "application/json" } });
    }
    if (action === "set_config") {
      const key = body.key;
      const value = body.value;
      if (!allowedKey(key)) return new Response(JSON.stringify({ error: "key_not_allowed" }), { status: 403, headers: { ...cors, "Content-Type": "application/json" } });
      const v = typeof value === "string" ? value : JSON.stringify(value);
      // Escrita SEMPRE no override do tenant (a `config` global nunca é alterada por aqui).
      const { error } = await supabase.from("tenant_config_overrides").upsert({ tenant_id: tenantId, key, value: v }, { onConflict: "tenant_id,key" });
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), { headers: { ...cors, "Content-Type": "application/json" } });
    }
    if (action === "list_automations") {
      let q = supabase.from("social_selling_automations").select("*").order("created_at", { ascending: false });
      if (tenantId) q = q.eq("tenant_id", tenantId);
      const { data, error } = await q;
      if (error) throw error;
      return new Response(JSON.stringify({ automations: data || [] }), { headers: { ...cors, "Content-Type": "application/json" } });
    }
    if (action === "update_automation") {
      const id = body.id;
      const patch = body.patch || {};
      if (!id) return new Response(JSON.stringify({ error: "id required" }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
      const allowed: Record<string, any> = {};
      for (const k of EDITABLE_AUTOMATION_FIELDS) if (k in patch) allowed[k] = patch[k];
      let updQ = supabase.from("social_selling_automations").update(allowed).eq("id", id);
      if (tenantId) updQ = updQ.eq("tenant_id", tenantId);
      const { error } = await updQ;
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), { headers: { ...cors, "Content-Type": "application/json" } });
    }
    if (action === "create_automation") {
      const a = body.automation || {};
      if (!a.name) return new Response(JSON.stringify({ error: "name required" }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
      const insertData: Record<string, any> = {
        ...(tenantId ? { tenant_id: tenantId } : {}),
        name: a.name, emoji: a.emoji || "🔄", is_active: false,
        cadence_config: a.cadence_config || { days: [] },
        trigger_type: a.trigger_type || "manual",
      };
      if (a.description) insertData.description = a.description;
      if (a.trigger_config) insertData.trigger_config = a.trigger_config;
      const { data, error } = await supabase.from("social_selling_automations").insert(insertData).select("id").single();
      if (error) throw error;
      return new Response(JSON.stringify({ id: data.id }), { headers: { ...cors, "Content-Type": "application/json" } });
    }
    if (action === "list_today_actions") {
      const todayStart = new Date(); todayStart.setHours(0, 0, 0, 0);
      let intQ = supabase.from("social_selling_interactions").select("id, enrollment_id, lead_id, action_type, status, content, instagram_target, error_message, executed_at, day_number").gte("executed_at", todayStart.toISOString()).order("executed_at", { ascending: false }).limit(500);
      if (tenantId) intQ = intQ.eq("tenant_id", tenantId);
      const { data, error } = await intQ;
      if (error) throw error;
      return new Response(JSON.stringify({ interactions: data || [] }), { headers: { ...cors, "Content-Type": "application/json" } });
    }

    // ✨ NOVO: lista pipelines + stages pra escolher destino dos leads qualificados
    if (action === "list_pipelines") {
      let pipQ = supabase
        .from("sales_pipelines")
        .select("id, name, position, sales_pipeline_stages(id, name, position, color)")
        .order("position");
      if (tenantId) pipQ = pipQ.eq("tenant_id", tenantId);
      const { data: pipelines, error } = await pipQ;
      if (error) throw error;
      const result = (pipelines || []).map((p: any) => ({
        id: p.id, name: p.name, position: p.position,
        stages: (p.sales_pipeline_stages || []).sort((a: any, b: any) => (a.position || 0) - (b.position || 0)),
      }));
      return new Response(JSON.stringify({ pipelines: result }), { headers: { ...cors, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "unknown action" }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e: any) {
    const t = tenantErrorResponse(e, cors);
    if (t) return t;
    console.error("social-selling-config-api error:", e);
    return new Response(JSON.stringify({ error: e.message || String(e) }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
