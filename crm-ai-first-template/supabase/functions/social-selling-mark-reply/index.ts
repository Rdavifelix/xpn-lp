// social-selling-mark-reply
// Marca enrollment como replied + move card pra "✅ Respondeu" no pipeline.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getTenantFromRequest } from "../_shared/tenant.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const RESPONDED_STAGE_NAME = Deno.env.get("SS_RESPONDED_STAGE_NAME") || "✅ Respondeu";
const SOCIAL_SELLING_PIPELINE_NAME = Deno.env.get("SS_PIPELINE_NAME") || "Prospecção Social Selling";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    const body = await req.json();
    const { lead_id, instagram_username, message_content, message_type = "dm" } = body;

    if (!lead_id && !instagram_username) {
      return new Response(JSON.stringify({ error: "lead_id or instagram_username required" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const tenantId = getTenantFromRequest(req);

    let lead: any;
    if (lead_id) {
      let leadQ = supabase.from("leads").select("*").eq("id", lead_id);
      if (tenantId) leadQ = leadQ.eq("tenant_id", tenantId);
      const { data } = await leadQ.single();
      lead = data;
    } else {
      const handle = String(instagram_username).toLowerCase().replace(/^@/, "");
      let leadQ = supabase.from("leads").select("*").eq("instagram", handle);
      if (tenantId) leadQ = leadQ.eq("tenant_id", tenantId);
      const { data } = await leadQ.limit(1).single();
      lead = data;
    }

    if (!lead) {
      return new Response(JSON.stringify({ error: "Lead not found" }), {
        status: 404,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    await supabase
      .from("social_selling_enrollments")
      .update({
        status: "replied",
        completed_at: new Date().toISOString(),
        metadata: {
          reply_received_at: new Date().toISOString(),
          reply_content: message_content,
          reply_type: message_type,
        },
      })
      .eq("lead_id", lead.id)
      .eq("status", "active");

    let pipQ = supabase
      .from("sales_pipelines")
      .select("id")
      .eq("name", SOCIAL_SELLING_PIPELINE_NAME);
    if (tenantId) pipQ = pipQ.eq("tenant_id", tenantId);
    const { data: pipeline } = await pipQ.maybeSingle();

    let movedToStage: string | null = null;
    if (pipeline) {
      const { data: stage } = await supabase
        .from("sales_pipeline_stages")
        .select("id, name")
        .eq("pipeline_id", pipeline.id)
        .eq("name", RESPONDED_STAGE_NAME)
        .maybeSingle();
      if (stage) {
        await supabase
          .from("leads")
          .update({ pipeline_stage_id: stage.id, updated_at: new Date().toISOString() })
          .eq("id", lead.id);
        await supabase
          .from("deals")
          .update({ pipeline_stage_id: stage.id, updated_at: new Date().toISOString() })
          .eq("lead_id", lead.id);
        movedToStage = stage.name;
      }
    }

    return new Response(
      JSON.stringify({ success: true, lead_id: lead.id, moved_to_stage: movedToStage }),
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }
});
