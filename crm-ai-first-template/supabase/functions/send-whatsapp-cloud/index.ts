import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getIntegrationKey } from "../_shared/config.ts";
import { authenticateRequest, authErrorResponse } from "../_shared/auth.ts";
import { assertEntityTenant, tenantErrorResponse } from "../_shared/tenant.ts";

/**
 * WhatsApp Cloud API (Meta oficial) — Envio de mensagens multi-tenant.
 *
 * Modelado a partir do CHEIRINCRM (arquitetura limpa). Princípios:
 *  - ZERO hardcoded: credenciais resolvidas no banco a cada request.
 *  - Multi-tenant / multi-número: resolve a instância via instance_id OU tenant_id.
 *  - Coexiste com UAZAPI: só processa instâncias provider='meta_cloud'.
 *  - Fallback global (config WHATSAPP_CLOUD_TOKEN/PHONE_NUMBER_ID) SOMENTE quando
 *    nenhuma instância é resolvida — compat com consumidores legados que ainda
 *    não passam instance_id/tenant_id (ai-sales-agent, prospecção, automation).
 *
 * Actions: send_text | send_template | send_image | send_document | send_audio | send_video
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GRAPH_API_VERSION = "v22.0";

interface CloudInstance {
  id: string;
  tenant_id: string | null;
  name: string;
  api_key: string;
  phone_number_id: string;
  business_account_id: string | null;
}

interface ResolvedCfg {
  token: string;
  phoneNumberId: string;
  tenantId: string | null;
  instanceId: string | null;
  graphUrl: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    let principal;
    try {
      principal = await authenticateRequest(req);
    } catch (error: any) {
      return authErrorResponse(error);
    }
    const body = await req.json();
    const { action, phone, lead_id, sent_by, sent_by_name, instance_id, tenant_id } = body;

    if (!phone) return jsonRes({ error: "phone required" }, 400);

    // Tenant efetivo NUNCA vem do body:
    //  - usuário (JWT): tenant do JWT; instance_id (se houver) precisa pertencer a ele.
    //  - service_role (functions/crons): tenant da LINHA referenciada — a instância
    //    (instance_id) ou, na falta dela, o lead (lead_id).
    // body.tenant_id só é conferido: divergente → 403.
    let effectiveTenant: string | null = null;
    if (principal.isServiceRole) {
      if (instance_id) {
        const { data: instRow } = await supabase
          .from("whatsapp_instances")
          .select("id, tenant_id")
          .eq("id", instance_id)
          .maybeSingle();
        if (!instRow) return jsonRes({ error: "instance_id não encontrado" }, 404);
        effectiveTenant = instRow.tenant_id || null;
      } else if (lead_id) {
        const { data: leadRow } = await supabase
          .from("leads")
          .select("id, tenant_id")
          .eq("id", lead_id)
          .maybeSingle();
        effectiveTenant = leadRow?.tenant_id || null;
      }
      if (!effectiveTenant) return jsonRes({ error: "Tenant obrigatório: informe instance_id ou lead_id de um registro existente" }, 400);
    } else {
      effectiveTenant = principal.tenantId;
      if (!effectiveTenant) return jsonRes({ error: "Tenant obrigatório" }, 403);
      if (instance_id) await assertEntityTenant(supabase, "whatsapp_instances", instance_id, effectiveTenant);
    }
    if (tenant_id && tenant_id !== effectiveTenant) {
      return jsonRes({ error: "Registro não pertence à sua empresa." }, 403);
    }
    const cfg = await resolveCfg(supabase, { instance_id, tenant_id: effectiveTenant });
    if (!cfg) {
      return jsonRes({ error: "Nenhuma instância Cloud API configurada (instance_id/tenant_id) nem credencial global." }, 404);
    }

    const cleanPhone = phone.replace(/\D/g, "");
    const formattedPhone = cleanPhone.startsWith("55") ? cleanPhone : `55${cleanPhone}`;

    let result: { ok: boolean; data: any; content: string; messageType: string; extraMeta?: any };
    switch (action) {
      case "send_template": result = await sendTemplate(body, formattedPhone, cfg, supabase); break;
      case "send_text": result = await sendText(body, formattedPhone, cfg); break;
      case "send_image": result = await sendMedia(body, formattedPhone, "image", cfg); break;
      case "send_document": result = await sendMedia(body, formattedPhone, "document", cfg); break;
      case "send_audio": result = await sendAudioViaUpload(body, formattedPhone, cfg); break;
      case "send_video": result = await sendMedia(body, formattedPhone, "video", cfg); break;
      default:
        if (body.template_name) result = await sendTemplate(body, formattedPhone, cfg, supabase);
        else if (body.text || body.message) result = await sendText(body, formattedPhone, cfg);
        else return jsonRes({ error: "action obrigatória (send_template, send_text, send_image, ...)" }, 400);
    }

    if (!result.ok) {
      const metaErr = result.data?.error;
      console.error("[cloud-api] Meta rejeitou:", JSON.stringify(result.data));
      // Erro de negócio (Meta recusou) → 200 com error legível, pra o front exibir a causa real.
      // Mensagem amigável pra token inválido/expirado (code 190).
      const friendly = metaErr?.code === 190
        ? "Token da Meta inválido ou expirado. Gere um Token Permanente (System User) e atualize a instância em Configurações → WhatsApp Oficial."
        : (metaErr?.message || "Falha ao enviar pela Meta.");
      return jsonRes({ success: false, error: friendly, meta_code: metaErr?.code || null, details: result.data }, 200);
    }

    const messageId = result.data.messages?.[0]?.id;
    console.log(`[cloud-api] Sent. message_id=${messageId}`);

    // Resolve lead por sufixo de telefone se não veio explícito (evita duplicidade pelo "9 extra").
    let resolvedLeadId = lead_id || null;
    if (!resolvedLeadId && formattedPhone) {
      const suffix = formattedPhone.slice(-8);
      let q = supabase.from("leads").select("id").like("phone", `%${suffix}`).limit(1);
      if (cfg.tenantId) q = q.eq("tenant_id", cfg.tenantId);
      const { data: existingLead } = await q.maybeSingle();
      if (existingLead?.id) resolvedLeadId = existingLead.id;
    }

    // Persistir na timeline. Atribuição via metadata (não temos colunas sent_by_* dedicadas).
    await supabase.from("whatsapp_messages").insert({
      tenant_id: cfg.tenantId,
      instance_id: cfg.instanceId,
      remote_jid: `${formattedPhone}@s.whatsapp.net`,
      message_id: messageId || `cloud_${Date.now()}`,
      message_type: result.messageType || "Conversation",
      content: result.content,
      media_url: result.extraMeta?.media_url || null,
      is_from_me: true,
      sent_at: new Date().toISOString(),
      lead_id: resolvedLeadId,
      sender_name: sent_by_name || null,
      metadata: {
        sent_by: sent_by || "system",
        sent_by_name: sent_by_name || null,
        cloud_api: true,
        provider: "meta_cloud",
        ...(result.extraMeta || {}),
      },
    });

    return jsonRes({ success: true, message_id: messageId, instance_id: cfg.instanceId });
  } catch (err: any) {
    const t = tenantErrorResponse(err, corsHeaders);
    if (t) return t;
    console.error("[cloud-api] Unexpected:", err.message);
    return jsonRes({ error: err.message }, 500);
  }
});

// ==================== RESOLVER CREDENCIAL ====================

async function resolveCfg(
  supabase: any,
  params: { instance_id?: string; tenant_id?: string }
): Promise<ResolvedCfg | null> {
  const instance = await resolveInstance(supabase, params);
  if (instance) {
    return {
      token: instance.api_key,
      phoneNumberId: instance.phone_number_id,
      tenantId: instance.tenant_id,
      instanceId: instance.id,
      graphUrl: `https://graph.facebook.com/${GRAPH_API_VERSION}/${instance.phone_number_id}/messages`,
    };
  }

  // Fallback (compat legado) — resolve override do tenant → global.
  const token = await getIntegrationKey(supabase, "WHATSAPP_CLOUD_TOKEN", params.tenant_id);
  const phoneNumberId = await getIntegrationKey(supabase, "WHATSAPP_PHONE_NUMBER_ID", params.tenant_id);
  if (!token || !phoneNumberId) return null;

  const fallbackInstanceId = params.instance_id || await getOfficialInstanceId(supabase, params.tenant_id);
  return {
    token,
    phoneNumberId,
    tenantId: params.tenant_id || null,
    instanceId: fallbackInstanceId,
    graphUrl: `https://graph.facebook.com/${GRAPH_API_VERSION}/${phoneNumberId}/messages`,
  };
}

async function resolveInstance(
  supabase: any,
  params: { instance_id?: string; tenant_id?: string }
): Promise<CloudInstance | null> {
  const baseSelect = "id, tenant_id, name, api_key, phone_number_id, business_account_id";

  if (params.instance_id) {
    let q = supabase
      .from("whatsapp_instances")
      .select(baseSelect)
      .eq("id", params.instance_id)
      .eq("provider", "meta_cloud");
    if (params.tenant_id) q = q.eq("tenant_id", params.tenant_id);
    const { data } = await q.maybeSingle();
    return hydrateInstance(data);
  }

  if (params.tenant_id) {
    const { data } = await supabase
      .from("whatsapp_instances")
      .select(baseSelect)
      .eq("tenant_id", params.tenant_id)
      .eq("provider", "meta_cloud")
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();
    return hydrateInstance(data);
  }

  return null;
}

function hydrateInstance(data: any): CloudInstance | null {
  if (!data) return null;
  if (!data.api_key || !data.phone_number_id) {
    console.warn(`[cloud-api] Instance ${data.id} sem api_key ou phone_number_id`);
    return null;
  }
  return data as CloudInstance;
}

async function getOfficialInstanceId(supabase: any, tenantId?: string | null): Promise<string | null> {
  let q = supabase
    .from("whatsapp_instances").select("id").eq("provider", "meta_cloud")
    .order("created_at", { ascending: true }).limit(1);
  if (tenantId) q = q.eq("tenant_id", tenantId);
  const { data } = await q.maybeSingle();
  return data?.id || null;
}

// ==================== SEND TEMPLATE ====================

async function sendTemplate(body: any, phone: string, cfg: ResolvedCfg, supabase: any) {
  const { template_name, template_params, template_language, header_media_url, header_media_type } = body;
  const templateName = template_name;
  const language = template_language || "pt_BR";
  if (!templateName) throw new Error("template_name obrigatório para send_template");

  const payload: any = {
    messaging_product: "whatsapp",
    to: phone,
    type: "template",
    template: { name: templateName, language: { code: language } },
  };

  const components: any[] = [];

  // HEADER de mídia (image | video | document) — link público obrigatório.
  if (header_media_url) {
    const mediaType = (header_media_type || "image").toLowerCase();
    components.push({ type: "header", parameters: [{ type: mediaType, [mediaType]: { link: header_media_url } }] });
  }

  // BODY parameters — aceita string[] OU Array<{type:'text', text}>.
  if (template_params && template_params.length > 0) {
    components.push({
      type: "body",
      parameters: template_params.map((p: any) => {
        if (p && typeof p === "object" && "text" in p) {
          const t = typeof p.text === "string" ? p.text : String(p.text ?? "");
          return { type: "text", text: t || "_" };
        }
        const s = typeof p === "string" ? p : String(p ?? "");
        return { type: "text", text: s || "_" };
      }),
    });
  }

  if (components.length > 0) payload.template.components = components;

  const response = await callCloudAPI(cfg.graphUrl, cfg.token, payload);
  const content = await buildTemplateText(supabase, cfg.tenantId, templateName, template_params);

  return {
    ok: response.ok,
    data: response.data,
    content,
    messageType: "template",
    extraMeta: {
      template_name: templateName,
      template_language: language,
      ...(header_media_url ? { media_url: header_media_url, header_media_type: header_media_type || "image" } : {}),
    },
  };
}

// ==================== SEND TEXT ====================

async function sendText(body: any, phone: string, cfg: ResolvedCfg) {
  const text = body.text || body.message;
  if (!text) throw new Error("text/message obrigatório");
  const payload = { messaging_product: "whatsapp", to: phone, type: "text", text: { body: text } };
  const response = await callCloudAPI(cfg.graphUrl, cfg.token, payload);
  return { ok: response.ok, data: response.data, content: text, messageType: "Conversation" };
}

// ==================== SEND MEDIA (image/document/video) ====================

async function sendMedia(body: any, phone: string, type: "image" | "document" | "video", cfg: ResolvedCfg) {
  const { media_url, caption, filename } = body;
  if (!media_url) throw new Error("media_url obrigatório");
  const mediaObj: any = { link: media_url };
  if (caption) mediaObj.caption = caption;
  if (filename && type === "document") mediaObj.filename = filename;
  const payload = { messaging_product: "whatsapp", to: phone, type, [type]: mediaObj };
  const response = await callCloudAPI(cfg.graphUrl, cfg.token, payload);
  const label = { image: "Imagem", document: "Documento", video: "Vídeo" }[type];
  return { ok: response.ok, data: response.data, content: caption || `[${label}]`, messageType: type, extraMeta: { media_url } };
}

// ==================== SEND AUDIO (upload via Media API) ====================

async function sendAudioViaUpload(body: any, phone: string, cfg: ResolvedCfg) {
  const { media_url: audioUrl, caption } = body;
  if (!audioUrl) throw new Error("media_url obrigatório para áudio");

  const audioRes = await fetch(audioUrl);
  if (!audioRes.ok) throw new Error("Falha ao baixar áudio");
  const audioBuffer = await audioRes.arrayBuffer();

  // Meta Cloud aceita OGG (Opus). NÃO incluir "codecs=opus" no Content-Type (Meta rejeita).
  const boundary = `----FormBoundary${Date.now()}`;
  const mimeType = "audio/ogg";
  const filename = "audio.ogg";

  const header = [
    `--${boundary}`,
    `Content-Disposition: form-data; name="messaging_product"\r\n`, `whatsapp`,
    `--${boundary}`,
    `Content-Disposition: form-data; name="type"\r\n`, mimeType,
    `--${boundary}`,
    `Content-Disposition: form-data; name="file"; filename="${filename}"`,
    `Content-Type: ${mimeType}\r\n`,
  ].join("\r\n");
  const footer = `\r\n--${boundary}--\r\n`;
  const headerBytes = new TextEncoder().encode(header);
  const footerBytes = new TextEncoder().encode(footer);
  const mediaBody = new Uint8Array(headerBytes.length + audioBuffer.byteLength + footerBytes.length);
  mediaBody.set(headerBytes, 0);
  mediaBody.set(new Uint8Array(audioBuffer), headerBytes.length);
  mediaBody.set(footerBytes, headerBytes.length + audioBuffer.byteLength);

  const uploadUrl = `https://graph.facebook.com/${GRAPH_API_VERSION}/${cfg.phoneNumberId}/media`;
  const uploadRes = await fetch(uploadUrl, {
    method: "POST",
    headers: { Authorization: `Bearer ${cfg.token}`, "Content-Type": `multipart/form-data; boundary=${boundary}` },
    body: mediaBody,
  });
  const uploadData = await uploadRes.json();

  if (!uploadRes.ok || !uploadData.id) {
    console.error("[cloud-api] Media upload failed:", JSON.stringify(uploadData));
    const payload = { messaging_product: "whatsapp", to: phone, type: "audio", audio: { link: audioUrl } };
    const response = await callCloudAPI(cfg.graphUrl, cfg.token, payload);
    return { ok: response.ok, data: response.data, content: caption || "[Áudio]", messageType: "audio", extraMeta: { media_url: audioUrl } };
  }

  const mediaId = uploadData.id;
  const payload = { messaging_product: "whatsapp", to: phone, type: "audio", audio: { id: mediaId } };
  const response = await callCloudAPI(cfg.graphUrl, cfg.token, payload);
  return { ok: response.ok, data: response.data, content: caption || "[Áudio]", messageType: "audio", extraMeta: { media_url: audioUrl, media_id: mediaId } };
}

// ==================== CALL GRAPH API ====================

async function callCloudAPI(graphUrl: string, token: string, payload: any): Promise<{ ok: boolean; data: any }> {
  const response = await fetch(graphUrl, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const data = await response.json();
  return { ok: response.ok, data };
}

// ==================== HELPERS ====================

async function buildTemplateText(
  supabase: any, tenantId: string | null, templateName: string, params?: any[]
): Promise<string> {
  // Texto exibido no histórico: extrai o BODY dos components do template Cloud.
  let q = supabase.from("whatsapp_cloud_templates").select("components").eq("name", templateName);
  if (tenantId) q = q.eq("tenant_id", tenantId);
  const { data: tpl } = await q.maybeSingle();

  let text: string | null = null;
  if (tpl?.components && Array.isArray(tpl.components)) {
    const bodyComp = tpl.components.find((c: any) => c?.type === "BODY" || c?.type === "body");
    if (bodyComp?.text) text = bodyComp.text;
  }
  if (!text) text = `[Template: ${templateName}]`;

  if (params && params.length > 0) {
    params.forEach((p: any, i: number) => {
      const val = (p && typeof p === "object" && "text" in p)
        ? (typeof p.text === "string" ? p.text : String(p.text ?? ""))
        : (typeof p === "string" ? p : String(p ?? ""));
      text = text!.replace(`{{${i + 1}}}`, val);
    });
  }
  return text;
}

function jsonRes(data: any, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
