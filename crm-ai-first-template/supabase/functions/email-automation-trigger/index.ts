import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { authenticateRequest, authErrorResponse } from "../_shared/auth.ts";
import { TenantMismatchError, TenantRequiredError, tenantErrorResponse } from "../_shared/tenant.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface TriggerBody {
  event: string;
  lead_id?: string;
  deal_id?: string;
  organization_id?: string;
  tenant_id?: string; // IGNORADO como fonte: só conferido contra o tenant resolvido (403 se divergir)
  context?: Record<string, any>;
}

/**
 * Multi-tenant: busca automações apenas do tenant correto baseado em lead/deal/org.
 */
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  // Caller: DB trigger / functions (service_role) ou usuário (JWT com tenant).
  let principal;
  try {
    principal = await authenticateRequest(req);
  } catch (error: any) {
    return authErrorResponse(error);
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const body: TriggerBody = await req.json();
    const { event, lead_id, deal_id, organization_id, context = {} } = body;
    const claimedTenant = body.tenant_id || null;

    if (!event) throw new Error("event obrigatório");
    if (!lead_id && !deal_id && !organization_id) {
      throw new Error("precisa de lead_id, deal_id ou organization_id");
    }

    // Resolve lead_id e o tenant da ENTIDADE referenciada (lead/deal/org).
    // body.tenant_id nunca é fonte de verdade.
    let resolvedLeadId = lead_id || null;
    let entityTenant: string | null = null;

    if (resolvedLeadId) {
      const { data: lead } = await supabase
        .from("leads")
        .select("tenant_id")
        .eq("id", resolvedLeadId)
        .single();
      entityTenant = lead?.tenant_id || null;
    }

    if (!resolvedLeadId && deal_id) {
      const { data: deal } = await supabase
        .from("deals")
        .select("lead_id, tenant_id")
        .eq("id", deal_id)
        .single();
      resolvedLeadId = deal?.lead_id || null;
      entityTenant = deal?.tenant_id || null;
    }

    if (!resolvedLeadId && organization_id) {
      const { data: org } = await supabase
        .from("organizations")
        .select("primary_contact_id, tenant_id")
        .eq("id", organization_id)
        .single();
      resolvedLeadId = org?.primary_contact_id || null;
      entityTenant = org?.tenant_id || null;
    }

    // Tenant efetivo: service_role → entidade; usuário → JWT (entidade deve bater).
    let tenant_id: string | null;
    if (principal.isServiceRole) {
      tenant_id = entityTenant;
    } else {
      if (!principal.tenantId) throw new TenantRequiredError();
      tenant_id = principal.tenantId;
      if (entityTenant && entityTenant !== tenant_id) throw new TenantMismatchError();
    }
    if (!tenant_id) {
      return new Response(JSON.stringify({ error: "Tenant não identificável para lead/deal/organization informado" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (claimedTenant && claimedTenant !== tenant_id) throw new TenantMismatchError("tenant_id do body diverge");

    if (!resolvedLeadId) {
      return new Response(JSON.stringify({ ok: true, ignored: true, reason: "no lead resolved" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Busca automações ativas DESSE tenant
    const { data: automations } = await supabase
      .from("email_automations")
      .select("id, trigger_event, trigger_filter, flow_json")
      .eq("is_active", true)
      .eq("trigger_event", event)
      .eq("tenant_id", tenant_id);

    if (!automations || automations.length === 0) {
      return new Response(JSON.stringify({ ok: true, triggered: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let triggered = 0;
    for (const auto of automations) {
      const flow = auto.flow_json || {};
      const nodes = flow.nodes || [];
      const triggerNode = nodes.find((n: any) => n.type === "trigger");
      if (!triggerNode) continue;

      const filter = auto.trigger_filter || {};
      let matches = true;
      if (filter.pipeline_id && context.pipeline_id !== filter.pipeline_id) matches = false;
      if (filter.stage_id && context.stage_id !== filter.stage_id) matches = false;
      if (filter.source && context.source !== filter.source) matches = false;
      if (!matches) continue;

      const { error } = await supabase
        .from("email_automation_runs")
        .insert({
          tenant_id,
          automation_id: auto.id,
          lead_id: resolvedLeadId,
          current_node_id: triggerNode.id,
          scheduled_next_at: new Date().toISOString(),
          status: "active",
          context: { trigger_event: event, ...context },
        });

      if (!error) triggered++;
    }

    return new Response(JSON.stringify({ ok: true, triggered, total_automations: automations.length }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    const t = tenantErrorResponse(err, corsHeaders);
    if (t) return t;
    console.error("Erro:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
