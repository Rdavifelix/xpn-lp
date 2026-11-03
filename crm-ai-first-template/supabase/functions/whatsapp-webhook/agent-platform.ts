/** Tenant-safe WhatsApp gate for the Agent Platform V2. */
import {resolveWhatsAppDeal} from './deal-context.ts';

import {
  type InstanceLike,
  callRunner,
  isAgentPlatformEnabled,
  onlyDigits,
  sendAgentReply,
  sendUazapi,
  sleep,
} from "../_shared/agent-whatsapp-send.ts";

export async function tryHandleViaAgentPlatform(args: {
  supabase: any;
  instance: InstanceLike;
  senderPhone: string;
  text: string;
  messageId: string | null;
  leadId?: string | null;
  tenantId?: string | null;
}): Promise<boolean> {
  const { supabase, instance, messageId } = args;
  const text = args.text.trim();


  // Never trust a caller-provided tenant without checking the instance owner.
  const { data: instanceRow } = await supabase
    .from("whatsapp_instances")
    .select("id, tenant_id, api_url, api_key")
    .eq("id", instance.id)
    .maybeSingle();
  const tenantId = instanceRow?.tenant_id as string | undefined;
  if (!tenantId || (args.tenantId && args.tenantId !== tenantId)) return false;
  const {data:entry,error:entryError}=await supabase.rpc('whatsapp_entry_resolve',{p_instance:instance.id,p_lead:args.leadId||null});
  if(entryError){console.error('[wpp-entry] configuração recusada:',entryError.message);return true;}
  if(entry?.paused)return true;
  if(!text||text==="[Mídia]")return !!entry;
  if (!entry && !await isAgentPlatformEnabled(supabase, tenantId)) return false;

  const { data: routeRows, error: routeError } = entry ? {data:entry,error:null} : await supabase.rpc("agent_route_lookup", {
    p_channel: "whatsapp",
    p_instance_id: instance.id,
    p_ctx: { text },
  });
  if (routeError) {
    console.error("[wpp-v2] route error:", routeError.message);
    return false;
  }
  const match = Array.isArray(routeRows) ? routeRows[0] : routeRows;
  if (!match?.agent_id || !match?.agent_slug) return false;

  const { data: deployment } = await supabase
    .from("agents_deployments")
    .select("config")
    .eq("id", match.deployment_id)
    .eq("tenant_id", tenantId)
    .maybeSingle();
  if (!deployment) return false;

  const config = (deployment.config || {}) as Record<string, any>;
  const senderDigits = onlyDigits(args.senderPhone);
  if (!senderDigits) return false;
  const resolvedInstance: InstanceLike = {
    id: instance.id,
    api_url: instance.api_url || instanceRow.api_url,
    api_key: instance.api_key || instanceRow.api_key,
  };

  if ((config.access_mode || "open") === "private") {
    const allowlist = (config.authorized_numbers || [])
      .map((number: unknown) => onlyDigits(String(number)))
      .filter(Boolean);
    const authorized = allowlist.some((allowed: string) =>
      senderDigits.endsWith(allowed) || allowed.endsWith(senderDigits)
    );
    if (!authorized) {
      if (config.unauthorized_message) {
        await sendUazapi(resolvedInstance, senderDigits, String(config.unauthorized_message));
      }
      console.log(`[wpp-v2] unauthorized number for agent ${match.agent_slug}`);
      return true;
    }
  }

  const sessionKey = entry ? `whatsapp:${instance.id}:${senderDigits}` : `whatsapp:${senderDigits}`;
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
        title: `WhatsApp ${senderDigits}`,
        provider_state: {
          external_session_key: sessionKey,
          whatsapp_phone: senderDigits,
          lead_id: args.leadId || null,
        },
      })
      .select("id")
      .single();
    if (sessionError || !newSession) {
      console.error("[wpp-v2] session error:", sessionError?.message);
      return false;
    }
    sessionId = newSession.id;
  }

  const { data: agentRow } = await supabase
    .from("agents_registry")
    .select("settings")
    .eq("id", match.agent_id)
    .eq("tenant_id", tenantId)
    .maybeSingle();
  if (!agentRow) return false;

  const pending = scheduleBackground(() => runAgentReply({
    supabase,
    instance: resolvedInstance,
    match,
    tenantId,
    sessionId: sessionId!,
    senderDigits,
    text,
    messageId,
    leadId: args.leadId || null,
    agentSettings: (agentRow.settings || {}) as Record<string, any>,
    entryDealId: entry?.deal_id || null,
  }));
  if (pending) await pending;
  return true;
}

async function runAgentReply(context: {
  supabase: any;
  instance: InstanceLike;
  match: { agent_id: string; agent_slug: string };
  tenantId: string;
  sessionId: string;
  senderDigits: string;
  text: string;
  messageId: string | null;
  leadId: string | null;
  agentSettings: Record<string, any>;
  entryDealId: string|null;
}): Promise<void> {
  let message = context.text;
  try {
    const debounceSeconds = resolveDebounceSeconds(context.agentSettings, "whatsapp");
    if (debounceSeconds > 0 && context.leadId && context.messageId) {
      await sleep(debounceSeconds * 1000);

      const baseInbound = context.supabase
        .from("whatsapp_messages")
        .select("message_id")
        .eq("tenant_id", context.tenantId)
        .eq("instance_id", context.instance.id)
        .eq("lead_id", context.leadId)
        .eq("is_from_me", false)
        .is("group_id", null);
      const { data: latestInbound } = await baseInbound
        .order("sent_at", { ascending: false })
        .order("message_id", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (latestInbound && latestInbound.message_id !== context.messageId) return;

      // Any outbound message (agent or human) is a safe boundary: never answer
      // older lead fragments after a salesperson has already intervened.
      const { data: lastOutbound } = await context.supabase
        .from("whatsapp_messages")
        .select("sent_at")
        .eq("tenant_id", context.tenantId)
        .eq("instance_id", context.instance.id)
        .eq("lead_id", context.leadId)
        .eq("is_from_me", true)
        .is("group_id", null)
        .order("sent_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      let pendingQuery = context.supabase
        .from("whatsapp_messages")
        .select("content, sent_at")
        .eq("tenant_id", context.tenantId)
        .eq("instance_id", context.instance.id)
        .eq("lead_id", context.leadId)
        .eq("is_from_me", false)
        .is("group_id", null)
        .order("sent_at", { ascending: true });
      if (lastOutbound?.sent_at) pendingQuery = pendingQuery.gt("sent_at", lastOutbound.sent_at);
      const { data: pendingMessages } = await pendingQuery;
      if (!pendingMessages?.length) return;
      const combined = pendingMessages
        .map((item: any) => item.content)
        .filter((content: unknown) => content && content !== "[Mídia]")
        .join("\n")
        .trim();
      if (combined) message = combined;
    }

    const dealId = context.entryDealId || await resolveWhatsAppDeal(context.supabase,context.tenantId,context.leadId);
    const fullText = await callRunner({
      match: context.match,
      sessionId: context.sessionId,
      senderDigits: context.senderDigits,
      messageId: context.messageId,
      leadId: context.leadId,
      instance: context.instance,
      message,
      extraContext: { deal_id: dealId, opportunity_resolution: dealId ? 'unique_open' : 'none_or_ambiguous; não invente oportunidade' },
    });
    if (fullText === null) {
      await sendUazapi(
        context.instance,
        context.senderDigits,
        "⚠️ Tive um problema técnico. Tenta de novo daqui a pouco?",
      );
      return;
    }
    await sendAgentReply({
      supabase: context.supabase,
      inst: context.instance,
      instance: context.instance,
      match: context.match,
      tenantId: context.tenantId,
      senderDigits: context.senderDigits,
      leadId: context.leadId,
      fullText,
      agentSettings: context.agentSettings,
    });
  } catch (error) {
    console.error("[wpp-v2] background reply error:", (error as Error).message);
  }
}

function scheduleBackground(task: () => Promise<void>): Promise<void> | null {
  const promise = task().catch((error) => {
    console.error("[wpp-v2] background task error:", (error as Error).message);
  });
  const runtime = (globalThis as any).EdgeRuntime;
  if (runtime && typeof runtime.waitUntil === "function") {
    runtime.waitUntil(promise);
    return null;
  }
  return promise;
}

function resolveDebounceSeconds(settings: any, channel: string): number {
  const config = settings?.humanization;
  if (!config || config.enabled === false) return 0;
  const channels = Array.isArray(config.channels) && config.channels.length
    ? config.channels
    : ["whatsapp", "telegram", "instagram"];
  if (!channels.includes(channel)) return 0;
  return Math.max(0, Number(config.debounce_seconds) || 0);
}
