// get-social-selling-enrollments v7 — histórico filtrado por day_number=current_day (não por data UTC)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getTenantFromRequest } from "../_shared/tenant.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const tenantId = getTenantFromRequest(req);

    let enrQ = supabase
      .from("social_selling_enrollments")
      .select(`
        id, lead_id, instagram_username, current_day, total_days, status,
        last_action_at, next_action_at, started_at, automation_id,
        automation:social_selling_automations(id, name, emoji, cadence_config, trigger_config),
        lead:leads!social_selling_enrollments_lead_id_fkey(
          name, instagram, lead_temperature, pipeline_stage_id,
          stage:sales_pipeline_stages!leads_pipeline_stage_id_fkey(
            id, name,
            pipeline:sales_pipelines(id, name)
          )
        )
      `)
      .eq("status", "active")
      .order("next_action_at", { ascending: true, nullsFirst: false });
    if (tenantId) enrQ = enrQ.eq("tenant_id", tenantId);
    const { data: enrollments } = await enrQ;

    // Busca interactions DO DIA ATUAL DA CADÊNCIA (current_day) — não filtra por data UTC
    const enrollmentsWithHistory = await Promise.all(
      (enrollments || []).map(async (e: any) => {
        const { data: interactions } = await supabase
          .from("social_selling_interactions")
          .select("action_type, status, day_number, executed_at, instagram_target, content, error_message")
          .eq("enrollment_id", e.id)
          .eq("day_number", e.current_day)
          .order("executed_at", { ascending: true });
        return { ...e, interactions_today: interactions || [] };
      }),
    );

    return new Response(
      JSON.stringify({ ok: true, count: enrollmentsWithHistory.length, enrollments: enrollmentsWithHistory }),
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e: any) {
    return new Response(JSON.stringify({ ok: false, error: e.message || String(e) }), {
      status: 500, headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
