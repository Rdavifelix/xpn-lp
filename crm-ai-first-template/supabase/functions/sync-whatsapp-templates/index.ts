import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getTenantFromRequest } from "../_shared/tenant.ts";

/**
 * sync-whatsapp-templates — puxa templates da Meta Cloud API e faz upsert local.
 * Multi-tenant: identifica instância por tenant_id, lê WABA + token do banco.
 *
 * POST { tenant_id }
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GRAPH_API_VERSION = "v22.0";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const body = await req.json();
    const { instance_id } = body;
    // O tenant sempre vem do JWT validado pelo gateway; nunca do body.
    const tenant_id = getTenantFromRequest(req);

    if (!tenant_id) return jsonRes({ error: "tenant_id obrigatório" }, 400);

    // Prontidão = status (gravado na origem ao salvar/testar). instance_id é opcional (multi-número).
    let query = supabase
      .from("whatsapp_instances")
      .select("id, business_account_id, api_key")
      .eq("tenant_id", tenant_id)
      .eq("provider", "meta_cloud")
      .in("status", ["connected", "active"]);
    if (instance_id) query = query.eq("id", instance_id);
    const { data: instance } = await query
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();

    if (!instance?.business_account_id || !instance?.api_key) {
      return jsonRes({ error: "Nenhuma instância Cloud API conectada. Cadastre/teste a conexão em Configurações → WhatsApp Oficial (Cloud)." }, 404);
    }

    const url = `https://graph.facebook.com/${GRAPH_API_VERSION}/${instance.business_account_id}/message_templates?fields=id,name,language,category,status,components,quality_score,rejected_reason&limit=100`;
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${instance.api_key}` },
    });
    const data = await res.json();

    if (data.error) {
      return jsonRes({ error: "Meta API error", details: data.error }, 502);
    }

    const templates = data.data || [];
    let upserted = 0;

    for (const t of templates) {
      const body = (t.components || []).find((c: any) => c.type === "BODY");
      const variables = countVariables(body?.text || "");

      const { error } = await supabase
        .from("whatsapp_cloud_templates")
        .upsert(
          {
            tenant_id,
            instance_id: instance.id,
            meta_template_id: t.id,
            name: t.name,
            language: t.language,
            category: t.category,
            status: t.status,
            rejection_reason: t.rejected_reason || null,
            components: t.components || [],
            variables_count: variables,
            last_synced_at: new Date().toISOString(),
          },
          { onConflict: "tenant_id,name,language" }
        );

      if (error) console.error("[sync-whatsapp-templates] upsert error:", error.message);
      else upserted++;
    }

    return jsonRes({ success: true, total: templates.length, upserted });
  } catch (err: any) {
    console.error("[sync-whatsapp-templates]", err);
    return jsonRes({ error: err.message }, 500);
  }
});

function countVariables(text: string): number {
  const matches = text.match(/\{\{\s*(\d+)\s*\}\}/g) || [];
  return new Set(matches).size;
}

function jsonRes(body: any, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
