/** Shared runtime for reactive and proactive WhatsApp agent replies. */

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

export interface InstanceLike {
  id: string;
  api_url?: string | null;
  api_key?: string | null;
}

interface HumanizationSplit {
  maxChars: number;
  delayMin: number;
  delayMax: number;
}

export function onlyDigits(value: string): string {
  return String(value).replace(/\D/g, "");
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function randomInt(min: number, max: number): number {
  return Math.floor(min + Math.random() * Math.max(1, max - min));
}

/** Reads the tenant override first and the installation default second. */
export async function isAgentPlatformEnabled(supabase: any, tenantId: string): Promise<boolean> {
  const { data: override } = await supabase
    .from("tenant_config_overrides")
    .select("value")
    .eq("tenant_id", tenantId)
    .eq("key", "agent_platform_v2_enabled")
    .maybeSingle();

  let raw: unknown = override?.value;
  if (raw === null || raw === undefined || String(raw).trim() === "") {
    const { data: global } = await supabase
      .from("config")
      .select("value")
      .eq("key", "agent_platform_v2_enabled")
      .maybeSingle();
    raw = global?.value;
  }

  if (typeof raw === "boolean") return raw;
  if (raw && typeof raw === "object") return (raw as { enabled?: boolean }).enabled === true;
  const text = String(raw || "").trim();
  if (text.toLowerCase() === "true") return true;
  try {
    const parsed = JSON.parse(text);
    return parsed === true || parsed?.enabled === true;
  } catch {
    return false;
  }
}

export async function callRunner(params: {
  match: { agent_id: string; agent_slug: string };
  sessionId: string;
  senderDigits: string;
  messageId: string | null;
  leadId: string | null;
  instance: InstanceLike;
  message: string;
  extraContext?: Record<string, unknown>;
}): Promise<string | null> {
  let fullText = "";
  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/agent-runner`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SERVICE_KEY}`,
        "apikey": SERVICE_KEY,
      },
      body: JSON.stringify({
        agent_id: params.match.agent_id,
        agent_slug: params.match.agent_slug,
        channel: "whatsapp",
        session_id: params.sessionId,
        message: params.message,
        user_id: null,
        context: {
          instance_id: params.instance.id,
          whatsapp_phone: params.senderDigits,
          recipient: params.senderDigits,
          message_id: params.messageId,
          lead_id: params.leadId,
          skip_debounce: true,
          ...(params.extraContext || {}),
        },
      }),
    });
    if (!response.ok || !response.body) {
      throw new Error(`agent-runner ${response.status}`);
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const events = buffer.split("\n\n");
      buffer = events.pop() || "";
      for (const event of events) {
        const dataLine = event.split("\n").find((line) => line.startsWith("data:"));
        if (!dataLine) continue;
        try {
          const data = JSON.parse(dataLine.slice(5).trim());
          if (data.type === "text.delta") fullText += data.delta;
        } catch {
          // Ignore malformed/unknown SSE events; the runner status still governs success.
        }
      }
    }
    return fullText;
  } catch (error) {
    console.error("[agent-send] agent-runner error:", (error as Error).message);
    return null;
  }
}

export async function sendAgentReply(params: {
  supabase: any;
  inst: InstanceLike;
  instance: InstanceLike;
  match: { agent_id: string; agent_slug: string };
  tenantId: string;
  senderDigits: string;
  leadId: string | null;
  fullText: string;
  agentSettings: Record<string, any>;
}): Promise<void> {
  const { text, images } = extractMarkdownImages(params.fullText.trim());
  const split = resolveHumanizationSplit(params.agentSettings, "whatsapp");
  const logContext = {
    tenantId: params.tenantId,
    instanceId: params.instance.id,
    leadId: params.leadId,
    senderDigits: params.senderDigits,
    agentId: params.match.agent_id,
    agentSlug: params.match.agent_slug,
  };

  const finalText = text.trim();
  if (finalText) {
    const parts = split ? splitMessage(finalText, split.maxChars) : splitText(finalText, 4000);
    for (let index = 0; index < parts.length; index++) {
      const messageId = await sendUazapi(params.inst, params.senderDigits, parts[index]);
      await logAgentReply(params.supabase, {
        ...logContext,
        content: parts[index],
        messageType: "text",
        messageId,
      });
      if (split && index < parts.length - 1) {
        await sleep(randomInt(split.delayMin, split.delayMax));
      }
    }
  } else if (images.length === 0) {
    const fallback = "Desculpa, não consegui processar agora.";
    const messageId = await sendUazapi(params.inst, params.senderDigits, fallback);
    await logAgentReply(params.supabase, {
      ...logContext,
      content: fallback,
      messageType: "text",
      messageId,
    });
  }

  let lastAlt = "";
  for (let index = 0; index < images.length; index++) {
    const image = images[index];
    const caption = image.alt && image.alt !== lastAlt ? image.alt : "";
    const messageId = await sendUazapiMedia(params.inst, params.senderDigits, image.url, caption);
    if (image.alt) lastAlt = image.alt;
    await logAgentReply(params.supabase, {
      ...logContext,
      content: image.alt || "[imagem]",
      messageType: "image",
      mediaUrl: image.url,
      messageId,
    });
    if (split && index < images.length - 1) {
      await sleep(randomInt(split.delayMin, split.delayMax));
    }
  }
}

export function extractMarkdownImages(markdown: string): {
  text: string;
  images: Array<{ url: string; alt: string }>;
} {
  const images: Array<{ url: string; alt: string }> = [];
  const text = markdown.replace(/!\[([^\]]*)\]\((https?:\/\/[^)\s]+)\)/g, (_match, alt, url) => {
    images.push({ url, alt: String(alt || "").slice(0, 900) });
    return "";
  });
  return { text, images };
}

export async function sendUazapiMedia(
  instance: InstanceLike,
  number: string,
  fileUrl: string,
  caption = "",
): Promise<string | null> {
  const base = (instance.api_url || "").replace(/\/$/, "");
  if (!base) throw new Error("WhatsApp instance has no api_url");
  try {
    const response = await fetch(`${base}/send/media`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "token": instance.api_key || "",
      },
      body: JSON.stringify({ number: onlyDigits(number), type: "image", file: fileUrl, text: caption }),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      await sendUazapi(instance, number, `🖼 ${caption || "imagem"}: ${fileUrl}`);
      return null;
    }
    return extractProviderMessageId(data);
  } catch (error) {
    console.error("[agent-send] media send error:", (error as Error).message);
    return null;
  }
}

export async function sendUazapi(
  instance: InstanceLike,
  number: string,
  text: string,
): Promise<string | null> {
  const base = (instance.api_url || "").replace(/\/$/, "");
  if (!base) throw new Error("WhatsApp instance has no api_url");
  const response = await fetch(`${base}/send/text`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "token": instance.api_key || "",
    },
    body: JSON.stringify({ number: onlyDigits(number), text }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`UAZAPI send failed (${response.status})`);
  return extractProviderMessageId(data);
}

function extractProviderMessageId(data: any): string | null {
  return data?.id || data?.key?.id || data?.messageid || data?.messageId || null;
}

async function logAgentReply(supabase: any, args: {
  tenantId: string;
  instanceId: string;
  leadId: string | null;
  senderDigits: string;
  agentId: string;
  agentSlug: string;
  content: string;
  messageType: string;
  mediaUrl?: string;
  messageId?: string | null;
}): Promise<void> {
  const { error } = await supabase.from("whatsapp_messages").insert({
    tenant_id: args.tenantId,
    message_id: args.messageId || `agentv2_${crypto.randomUUID()}`,
    instance_id: args.instanceId,
    lead_id: args.leadId,
    remote_jid: `${args.senderDigits}@s.whatsapp.net`,
    sender_phone: args.senderDigits,
    sender_name: "Agente IA",
    content: args.content,
    message_type: args.messageType,
    media_url: args.mediaUrl || null,
    is_from_me: true,
    status: "sent",
    sent_at: new Date().toISOString(),
    metadata: {
      sent_by: "ai_agent",
      platform: "v2",
      agent_id: args.agentId,
      agent_slug: args.agentSlug,
    },
  });
  // The UAZAPI echo may win the unique race. That is expected and harmless.
  if (error && error.code !== "23505") {
    console.error("[agent-send] reply log error:", error.message);
  }
}

export function splitText(text: string, max: number): string[] {
  if (text.length <= max) return [text];
  const result: string[] = [];
  let current = "";
  for (const paragraph of text.split("\n\n")) {
    if (paragraph.length > max) {
      if (current) result.push(current);
      for (let index = 0; index < paragraph.length; index += max) {
        result.push(paragraph.slice(index, index + max));
      }
      current = "";
    } else if (current && `${current}\n\n${paragraph}`.length > max) {
      result.push(current);
      current = paragraph;
    } else {
      current = current ? `${current}\n\n${paragraph}` : paragraph;
    }
  }
  if (current) result.push(current);
  return result;
}

function resolveHumanizationSplit(settings: any, channel: string): HumanizationSplit | null {
  const config = settings?.humanization;
  if (!config || config.enabled === false) return null;
  const channels = Array.isArray(config.channels) && config.channels.length
    ? config.channels
    : ["whatsapp", "telegram", "instagram"];
  if (!channels.includes(channel) || config.message_split?.enabled === false) return null;
  const split = config.message_split || {};
  return {
    maxChars: Math.max(80, Number(split.max_chars) || 280),
    delayMin: Math.max(0, Number(split.delay_between_min_ms) || 1200),
    delayMax: Math.max(0, Number(split.delay_between_max_ms) || 2500),
  };
}

export function splitMessage(text: string, maxChars: number): string[] {
  const trimmed = text.trim();
  if (!trimmed) return [];
  if (trimmed.includes("```")) return [trimmed];
  const paragraphs = trimmed.split(/\n\n+/).map((part) => part.trim()).filter(Boolean);
  if (paragraphs.length > 1) {
    return paragraphs.flatMap((paragraph) =>
      paragraph.length <= maxChars ? [paragraph] : splitBySentence(paragraph, maxChars)
    );
  }
  return trimmed.length <= maxChars ? [trimmed] : splitBySentence(trimmed, maxChars);
}

function splitBySentence(text: string, maxChars: number): string[] {
  const sentences = text.split(/(?<=[.!?])\s+/).map((part) => part.trim()).filter(Boolean);
  if (sentences.length <= 1) return splitText(text, Math.max(maxChars, 4000));
  const result: string[] = [];
  let buffer = "";
  for (const sentence of sentences) {
    if (!buffer) buffer = sentence;
    else if (`${buffer} ${sentence}`.length <= maxChars * 1.5) buffer += ` ${sentence}`;
    else {
      result.push(buffer);
      buffer = sentence;
    }
  }
  if (buffer) result.push(buffer);
  return result;
}
