import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  type InstanceLike,
  callRunner,
  isAgentPlatformEnabled,
  onlyDigits,
  sendAgentReply,
} from "../_shared/agent-whatsapp-send.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const bearer = (request.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    if (!serviceKey || bearer !== serviceKey) {
      return json({ error: "Forbidden" }, 403);
    }

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const body = await request.json().catch(() => ({}));
    const leadId = String(body.lead_id || "");
    const directive = String(body.directive || "").trim();
    if (!leadId) return json({ error: "lead_id obrigatório" }, 400);

    const { data: lead } = await supabase
      .from("leads")
      .select("id, name, phone, tenant_id, pipeline_stage_id")
      .eq("id", leadId)
      .maybeSingle();
    if (!lead?.tenant_id) return json({ error: "lead não encontrado" }, 404);
    const tenantId = lead.tenant_id as string;
    const phone = onlyDigits(lead.phone || "");
    if (!phone) return json({ skipped: true, reason: "lead sem telefone" });
    if (!await isAgentPlatformEnabled(supabase, tenantId)) {
      return json({ skipped: true, reason: "agente V2 inativo no tenant" });
    }

    const { data: lastMessage } = await supabase
      .from("whatsapp_messages")
      .select("instance_id")
      .eq("tenant_id", tenantId)
      .eq("lead_id", leadId)
      .not("instance_id", "is", null)
      .order("sent_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    let instanceId = lastMessage?.instance_id as string | undefined;
    if (!instanceId) {
      const { data: fallbackInstance } = await supabase
        .from("whatsapp_instances")
        .select("id")
        .eq("tenant_id", tenantId)
        .eq("status", "connected")
        .order("created_at", { ascending: true })
        .limit(1)
        .maybeSingle();
      instanceId = fallbackInstance?.id;
    }
    if (!instanceId) return json({ skipped: true, reason: "tenant sem instância WhatsApp conectada" });

    const { data: instanceRow } = await supabase
      .from("whatsapp_instances")
      .select("id, api_url, api_key, tenant_id")
      .eq("id", instanceId)
      .eq("tenant_id", tenantId)
      .maybeSingle();
    if (!instanceRow?.api_url) return json({ error: "instância inválida ou sem api_url" }, 400);
    const instance: InstanceLike = instanceRow;

    const { data: routeRows, error: routeError } = await supabase.rpc("agent_route_lookup", {
      p_channel: "whatsapp",
      p_instance_id: instanceId,
      p_ctx: {},
    });
    if (routeError) return json({ error: "falha no roteamento do agente" }, 500);
    const match = Array.isArray(routeRows) ? routeRows[0] : routeRows;
    if (!match?.agent_id || !match?.agent_slug) {
      return json({ skipped: true, reason: "sem agente V2 nesta instância" });
    }

    const { data: agent } = await supabase
      .from("agents_registry")
      .select("settings")
      .eq("id", match.agent_id)
      .eq("tenant_id", tenantId)
      .maybeSingle();
    if (!agent) return json({ error: "agente não pertence ao tenant" }, 400);

    const sessionKey = `whatsapp:${phone}`;
    const { data: existingSession } = await supabase
      .from("agents_sessions")
      .select("id")
      .eq("tenant_id", tenantId)
      .eq("agent_id", match.agent_id)
      .eq("channel", "whatsapp")
      .contains("provider_state", { external_session_key: sessionKey })
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    let sessionId = existingSession?.id as string | undefined;
    if (!sessionId) {
      const { data: newSession, error: sessionError } = await supabase
        .from("agents_sessions")
        .insert({
          tenant_id: tenantId,
          agent_id: match.agent_id,
          channel: "whatsapp",
          title: `WhatsApp ${phone}`,
          provider_state: { external_session_key: sessionKey, whatsapp_phone: phone, lead_id: leadId },
        })
        .select("id")
        .single();
      if (sessionError || !newSession) return json({ error: "falha ao criar sessão" }, 500);
      sessionId = newSession.id;
    }

    let stageName = "";
    if (lead.pipeline_stage_id) {
      const { data: stage } = await supabase
        .from("sales_pipeline_stages")
        .select("name")
        .eq("id", lead.pipeline_stage_id)
        .eq("tenant_id", tenantId)
        .maybeSingle();
      stageName = stage?.name || "";
    }

    const { data: messages } = await supabase
      .from("whatsapp_messages")
      .select("content, is_from_me, metadata, sent_at")
      .eq("tenant_id", tenantId)
      .eq("lead_id", leadId)
      .order("sent_at", { ascending: false })
      .limit(15);
    const transcript = (messages || []).slice().reverse().map((message: any) => {
      const author = !message.is_from_me
        ? "Cliente"
        : message.metadata?.sent_by === "ai_agent" ? "Você" : "Vendedor(humano)";
      return `${author}: ${(message.content || "").trim()}`;
    }).filter((line: string) => line.length > 8).join("\n");

    const nudge = `[SISTEMA] Follow-up automático de cadência. É uma mensagem SUA proativa; o lead não escreveu agora.
Lead: ${lead.name || "(sem nome)"} | Etapa atual: ${stageName || "?"}

Conversa recente (mais antiga em cima):
${transcript || "(sem histórico)"}

Abordagem deste toque: ${directive || "retomar de forma leve e checar se ficou alguma dúvida"}

Escreva um follow-up curto e contextual, no seu tom habitual, conduzindo ao próximo passo. Se não fizer sentido enviar agora — por exemplo, um humano já respondeu ou o lead pediu para não receber contato — responda apenas [PULAR].`;

    const fullText = await callRunner({
      match,
      sessionId: sessionId!,
      senderDigits: phone,
      messageId: null,
      leadId,
      instance,
      message: nudge,
      extraContext: { is_followup: true },
    });
    if (fullText === null) return json({ error: "agent-runner falhou" }, 502);
    const clean = fullText.trim();
    if (!clean || clean.toUpperCase().includes("[PULAR]")) {
      return json({ sent: false, reason: "agente optou por não enviar" });
    }

    await sendAgentReply({
      supabase,
      inst: instance,
      instance,
      match,
      tenantId,
      senderDigits: phone,
      leadId,
      fullText: clean,
      agentSettings: (agent.settings || {}) as Record<string, any>,
    });
    return json({ sent: true, agent: match.agent_slug, stage: stageName, preview: clean.slice(0, 200) });
  } catch (error) {
    console.error("[agent-followup] error:", (error as Error).message);
    return json({ error: "Internal error" }, 500);
  }
});
