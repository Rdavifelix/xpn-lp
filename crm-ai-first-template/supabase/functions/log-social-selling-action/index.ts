// log-social-selling-action v10 — não avança current_day (plan-day v18 cuida); só marca completed
// FIX v7: avançar dia só na VIRADA DO DIA BR (não 18h relativas).
//   D1 ontem → D2 libera hoje 00:00 BR (qualquer horário do dia novo)
//   D1 hoje → D2 amanhã 00:00 BR

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getTenantFromRequest } from "../_shared/tenant.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MESSAGE_ACTIONS = new Set(["responder_story", "enviar_dm"]);
const REFERENCE_TYPE_BY_ACTION: Record<string, string> = { responder_story: "story", enviar_dm: "dm" };
const MESSAGE_TYPE_BY_ACTION: Record<string, string> = { responder_story: "story_reply", enviar_dm: "text" };
// Parametrizável via secret SS_PIPELINE_NAME (cada cliente seta o nome do seu pipeline de prospecção)
const SOCIAL_SELLING_PIPELINE_NAME = Deno.env.get("SS_PIPELINE_NAME") || "Prospecção Social Selling";

function dateBR(iso: string | Date): string {
  const d = typeof iso === "string" ? new Date(iso) : iso;
  // Retorna 'YYYY-MM-DD' no fuso BR
  return d.toLocaleDateString("sv-SE", { timeZone: "America/Sao_Paulo" });
}

async function maybeMoveStage(supabase: any, leadId: string, actionType: string, tenantId: string | null) {
  let leadQ = supabase.from("leads").select("id, pipeline_stage_id").eq("id", leadId);
  if (tenantId) leadQ = leadQ.eq("tenant_id", tenantId);
  const { data: lead } = await leadQ.single();
  if (!lead) return null;
  let pipQ = supabase.from("sales_pipelines").select("id").eq("name", SOCIAL_SELLING_PIPELINE_NAME);
  if (tenantId) pipQ = pipQ.eq("tenant_id", tenantId);
  const { data: pipeline } = await pipQ.maybeSingle();
  if (!pipeline) return null;
  const { data: stages } = await supabase.from("sales_pipeline_stages").select("id, name, position").eq("pipeline_id", pipeline.id).order("position");
  if (!stages || stages.length === 0) return null;
  const novoQualificado = stages.find((s: any) => s.position === 1)?.id;
  const aquecendo = stages.find((s: any) => s.position === 2)?.id;
  const dmEnviada = stages.find((s: any) => s.position === 3)?.id;
  let targetStage: string | null = null;
  if (lead.pipeline_stage_id === novoQualificado && ["curtir_posts", "reagir_story", "comentar_post", "responder_story"].includes(actionType)) targetStage = aquecendo;
  else if (lead.pipeline_stage_id === aquecendo && actionType === "enviar_dm") targetStage = dmEnviada;
  if (targetStage && targetStage !== lead.pipeline_stage_id) {
    await supabase.from("leads").update({ pipeline_stage_id: targetStage }).eq("id", leadId);
    await supabase.from("deals").update({ pipeline_stage_id: targetStage }).eq("lead_id", leadId);
    return { moved_to: stages.find((s: any) => s.id === targetStage)?.name };
  }
  return null;
}

async function ensureMessage(supabase: any, params: any) {
  const { lead_id, action_type, content, instagram_target, metadata, tenantId } = params;
  const tenantCol = tenantId ? { tenant_id: tenantId } : {};
  if (!content || !MESSAGE_ACTIONS.has(action_type)) return null;
  let leadQ = supabase.from("leads").select("instagram, name").eq("id", lead_id);
  if (tenantId) leadQ = leadQ.eq("tenant_id", tenantId);
  const { data: lead } = await leadQ.single();
  const targetUsername = (lead?.instagram || "").toLowerCase().replace(/^@/, "");
  if (!targetUsername) return null;
  let acctQ = supabase.from("instagram_business_accounts").select("id, instagram_username").limit(1);
  if (tenantId) acctQ = acctQ.eq("tenant_id", tenantId);
  let { data: account } = await acctQ.maybeSingle();
  if (!account) {
    const { data: created } = await supabase.from("instagram_business_accounts").insert({
      ...tenantCol,
      instagram_business_id: "social-selling-outbound", instagram_username: Deno.env.get("SS_OWNER_USERNAME") || "owner", name: "Social Selling Outbound",
      status: "connected", access_token: "PLAYWRIGHT_NO_TOKEN", biography: "Conta operada via Playwright (sem Meta API)",
    }).select("id, instagram_username").single();
    account = created;
  }
  if (!account) return null;
  const threadId = `social_selling::${targetUsername}`;
  let { data: conv } = await supabase.from("instagram_conversations").select("id, total_messages").eq("account_id", account.id).eq("participant_username", targetUsername).maybeSingle();
  if (!conv) {
    const { data: created } = await supabase.from("instagram_conversations").insert({
      ...tenantCol,
      account_id: account.id, lead_id, thread_id: threadId,
      participant_instagram_id: targetUsername, participant_username: targetUsername, participant_name: lead?.name || targetUsername,
      last_message: content, last_message_at: new Date().toISOString(), last_agent_message_at: new Date().toISOString(),
      total_messages: 1, status: "open", metadata: { source: "social_selling_outbound" },
    }).select("id, total_messages").single();
    conv = created;
  } else {
    await supabase.from("instagram_conversations").update({
      last_message: content, last_message_at: new Date().toISOString(), last_agent_message_at: new Date().toISOString(),
      total_messages: (conv.total_messages || 0) + 1,
    }).eq("id", conv.id);
  }
  if (!conv) return null;
  const refType = REFERENCE_TYPE_BY_ACTION[action_type] || null;
  const msgType = MESSAGE_TYPE_BY_ACTION[action_type] || "text";
  const refUrl = instagram_target && instagram_target.startsWith("http") ? instagram_target : null;
  const refId = metadata?.story_id || null;
  const { data: msg, error: insErr } = await supabase.from("instagram_messages").insert({
    ...tenantCol,
    conversation_id: conv.id, content, message_type: msgType, is_from_me: true, sender_username: account.instagram_username,
    reference_type: refType, reference_id: refId, reference_url: refUrl, status: "sent", sent_at: new Date().toISOString(),
  }).select("id").single();
  if (insErr) {
    console.error("[log-action] instagram_messages insert FAILED:", insErr);
    throw new Error(`instagram_messages insert: ${insErr.message || insErr.code}`);
  }
  return msg?.id || null;
}

// v10 — NOVO MODELO: "Dia N" = D+(N-1) dias após inscrição.
// Esta função NÃO avança current_day mais (quem cuida é o plan-day v18).
// Só verifica se completou a última etapa pra marcar enrollment como `completed`.
async function maybeAdvanceDay(supabase: any, enrollment_id: string) {
  const { data: enr } = await supabase.from("social_selling_enrollments")
    .select("id, current_day, total_days, automation_id, flow_config, status, started_at").eq("id", enrollment_id).single();
  if (!enr) return null;
  const automationId = enr.automation_id || enr.flow_config?.automation_id;
  if (!automationId) return null;
  const { data: automation } = await supabase.from("social_selling_automations").select("cadence_config").eq("id", automationId).single();
  if (!automation) return null;
  const days: any[] = automation.cadence_config?.days || [];
  if (days.length === 0) return null;

  const maxDay = Math.max(...days.map((d: any) => d.day));
  if (enr.current_day !== maxDay) {
    // Ainda não chegou na última etapa — plan-day cuida do avanço
    return { advanced: false, reason: "not_last_day", current_day: enr.current_day };
  }

  // Verifica se completou todas as ações da última etapa
  const lastDayCfg = days.find((d: any) => d.day === maxDay);
  const expected = lastDayCfg?.actions || [];
  const { data: tried } = await supabase.from("social_selling_interactions")
    .select("action_type, status")
    .eq("enrollment_id", enrollment_id).eq("day_number", maxDay)
    .in("status", ["success", "skipped", "failed"]);
  const triedByType: Record<string, number> = {};
  for (const a of (tried || [])) triedByType[a.action_type] = (triedByType[a.action_type] || 0) + 1;
  for (const exp of expected) {
    if ((triedByType[exp.type] || 0) < (exp.count || 1)) {
      return { advanced: false, reason: "actions_pending_last_day", current_day: enr.current_day };
    }
  }

  // Tudo da última etapa feito → marca completed
  await supabase.from("social_selling_enrollments").update({
    status: "completed",
    completed_at: new Date().toISOString(),
    next_action_at: null,
    last_action_at: new Date().toISOString(),
  }).eq("id", enrollment_id);

  return { advanced: true, completed: true, current_day: maxDay };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    const body = await req.json();
    const { enrollment_id, lead_id, action_type, content, instagram_target,
      status = "success", error_message, day_number, metadata = {} } = body;
    if (!lead_id || !action_type) {
      return new Response(JSON.stringify({ error: "lead_id and action_type required" }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
    }
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const tenantId = getTenantFromRequest(req);
    const { data: interaction, error: interactionError } = await supabase.from("social_selling_interactions")
      .insert({ ...(tenantId ? { tenant_id: tenantId } : {}), lead_id, enrollment_id, action_type, content, instagram_target, status, error_message, day_number, metadata }).select().single();
    if (interactionError) {
      const isDup = String(interactionError.message || "").includes("uq_ssi_lead_action_target") || (interactionError as any).code === "23505";
      if (isDup) return new Response(JSON.stringify({ success: true, skipped: true, reason: "duplicate_action" }), { headers: { ...cors, "Content-Type": "application/json" } });
      throw interactionError;
    }
    let advanced = null;
    let stage_move = null;
    if (["success", "skipped", "failed"].includes(status)) {
      if (enrollment_id) {
        await supabase.from("social_selling_enrollments").update({
          last_action_at: new Date().toISOString(), last_visited_at: new Date().toISOString(),
        }).eq("id", enrollment_id);
        advanced = await maybeAdvanceDay(supabase, enrollment_id);
      }
      if (status === "success") stage_move = await maybeMoveStage(supabase, lead_id, action_type, tenantId);
    }
    let message_id: string | null = null;
    let message_error: string | null = null;
    if (status === "success" && content && MESSAGE_ACTIONS.has(action_type)) {
      try { message_id = await ensureMessage(supabase, { lead_id, action_type, content, instagram_target: instagram_target || "", metadata, tenantId }); }
      catch (e: any) { console.error("ensureMessage failed:", e); message_error = e.message || String(e); }
    }
    return new Response(JSON.stringify({
      success: true, interaction_id: interaction.id, message_id, message_error, enrollment_advance: advanced, stage_move,
    }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (error: any) {
    return new Response(JSON.stringify({ success: false, error: error.message }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
