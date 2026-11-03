// generate-social-selling-message v14 — POLÍTICA DE SEGURANÇA pra responder_story:
// SEM IMAGEM = SKIP. Sem exceção. Comentar story sem ver é risco real (luto, íntimo).
// COM IMAGEM = sempre Vision + detector anti-pessoal explícito (luto/família/religião).
// Tom + prompts vivem 100% no config (seed em 20260527_social_selling_seed_prompts.sql).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getIntegrationKey } from "../_shared/config.ts";
import { assertEntityTenant, requireTenantFromRequest, tenantErrorResponse } from "../_shared/tenant.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const HAIKU_MODEL = "claude-haiku-4-5-20251001";

async function readConfig(supabase: any, key: string, tenantId: string | null): Promise<string | null> {
  return await getIntegrationKey(supabase, key, tenantId);
}

async function getAnthropicKey(supabase: any, tenantId: string | null): Promise<string> {
  return (await getIntegrationKey(supabase, "ANTHROPIC_API_KEY", tenantId)) || "";
}

// Sem fallback hardcoded — se a chave `social_selling_tone` não existir no config, joga erro.
// Todo conteúdo de prompt mora no banco e é editável em /configuracoes?s=social-selling.
function parseTone(raw: string | null): string {
  if (!raw) {
    throw new Error("Chave 'social_selling_tone' não configurada. Configure em /configuracoes?s=social-selling antes de rodar a cadência.");
  }
  try {
    const t = JSON.parse(raw);
    return [
      t.description ? `INSTRUÇÕES DE TOM:\n${t.description}` : "",
      t.sample_messages ? `EXEMPLOS DE MENSAGENS DO USUÁRIO:\n${t.sample_messages}` : "",
      t.forbidden_words ? `PROIBIDO USAR:\n${t.forbidden_words}` : "",
    ].filter(Boolean).join("\n\n");
  } catch { return raw; }
}

// Helper: lê prompt obrigatório do config, joga erro claro se faltar
async function requirePrompt(supabase: any, action_type: string, tenantId: string | null): Promise<string> {
  const key = `social_selling_prompt_${action_type}`;
  const v = await readConfig(supabase, key, tenantId);
  if (!v || !v.trim()) {
    throw new Error(`Chave '${key}' não configurada. Configure em /configuracoes?s=social-selling antes de rodar a cadência.`);
  }
  return v.trim();
}
function stripEmojis(s: string): string {
  return s.replace(/[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}\u{2B00}-\u{2BFF}\u{1F300}-\u{1F9FF}\u{1F100}-\u{1F1FF}]/gu, "").replace(/  +/g, " ").trim();
}
async function callHaiku(prompt: string, anthropicKey: string, maxTokens = 250): Promise<string> {
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-api-key": anthropicKey, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({ model: HAIKU_MODEL, max_tokens: maxTokens, messages: [{ role: "user", content: prompt }] }),
  });
  if (!r.ok) throw new Error(`Anthropic ${r.status}: ${await r.text()}`);
  const data = await r.json();
  const text = (data.content?.[0]?.text || "").trim();
  return stripEmojis(text).replace(/^["'`]|["'`]$/g, "").replace(/\s+\n/g, "\n").trim();
}

// Versão multimodal pra story com imagem (Claude Vision)
async function callHaikuVision(prompt: string, imageBase64: string, anthropicKey: string, maxTokens = 250): Promise<string> {
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-api-key": anthropicKey, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({
      model: HAIKU_MODEL,
      max_tokens: maxTokens,
      messages: [{
        role: "user",
        content: [
          { type: "image", source: { type: "base64", media_type: "image/jpeg", data: imageBase64 } },
          { type: "text", text: prompt },
        ],
      }],
    }),
  });
  if (!r.ok) throw new Error(`Anthropic Vision ${r.status}: ${await r.text()}`);
  const data = await r.json();
  const text = (data.content?.[0]?.text || "").trim();
  return stripEmojis(text).replace(/^["'`]|["'`]$/g, "").replace(/\s+\n/g, "\n").trim();
}

interface PostContext { caption?: string; permalink?: string; }

async function buildPostContext(supabase: any, postUrl: string | undefined, tenantId: string | null): Promise<PostContext> {
  if (!postUrl) return {};
  const m = postUrl.match(/\/p\/([^\/]+)\/?$/) || postUrl.match(/\/reel\/([^\/]+)\/?$/);
  const code = m?.[1];
  if (!code) return { permalink: postUrl };
  let postQ = supabase.from("instagram_feed_posts").select("caption, permalink, code").eq("code", code);
  if (tenantId) postQ = postQ.eq("tenant_id", tenantId);
  const { data } = await postQ.maybeSingle();
  return { caption: data?.caption || undefined, permalink: data?.permalink || postUrl };
}

interface ConversationContext {
  lead_name?: string; sales_stage?: string; bant_summary?: string;
  recent_messages: { from: 'me' | 'lead'; text: string; date: string }[];
  past_calls: { date: string; summary: string }[];
  past_meetings: { date: string; status: string; summary?: string }[];
  upcoming_meeting?: string; days_since_last_msg?: number; msg_filter_count?: number;
}

function isInternalSystemMessage(content: string): boolean {
  if (!content) return true;
  const c = content.trim();
  if (c.length < 2) return true;
  const patterns: RegExp[] = [
    /^Mais uma tarefa criada/i, /^Tarefa criada/i, /^Tarefa concluída/i, /^Tarefa atribuída/i,
    /^Lead atribuído/i, /^Reunião Acompanhamento\s*-/i, /^Reunião agendada\s*-/i,
    /^⚠️\s*\*?ALERTA/i, /^🔴\s*\*?(ALERTA|Query)/i, /^📋\s*\*?Notif/i,
    /^✅\s*\*?(Tarefa|Lead|Deal)/i, /^🔔/, /\*ALERTA INFRA/i, /Query lenta:/i, /WITH pgrst_source/i,
    /^💰\s*\*?Pagamento/i, /^📊\s*\*?(Relatório|Resumo)/i, /^🎯\s*\*?Lead.*atribuído/i,
    /^📞\s*\*?(Chamada|Ligação) (perdida|recebida|gravada)/i, /^🤖\s*\*?Agente IA/i, /^Bot.*ativ/i,
  ];
  return patterns.some((p) => p.test(c));
}

async function buildConversationContext(supabase: any, leadId: string, tenantId: string): Promise<ConversationContext> {
  const ctx: ConversationContext = { recent_messages: [], past_calls: [], past_meetings: [] };
  // SCHEMA CRMPAIN: leads NÃO tem lead_temperature/temperature_reason
  const { data: lead } = await supabase.from("leads").select("name, sales_stage, bant_budget, bant_authority, bant_need, bant_timeline").eq("id", leadId).eq("tenant_id", tenantId).maybeSingle();
  if (lead) {
    ctx.lead_name = lead.name; ctx.sales_stage = lead.sales_stage;
    const bant = [lead.bant_budget && `Budget:${lead.bant_budget}`, lead.bant_authority && `Auth:${lead.bant_authority}`, lead.bant_need && `Need:${lead.bant_need}`, lead.bant_timeline && `TL:${lead.bant_timeline}`].filter(Boolean).join(' | ');
    if (bant) ctx.bant_summary = bant;
  }
  const { data: msgs } = await supabase.from("whatsapp_messages").select("content, is_from_me, created_at").eq("tenant_id", tenantId).eq("lead_id", leadId).order("created_at", { ascending: false }).limit(50);
  if (msgs) {
    const total = msgs.length;
    const realMsgs = msgs.filter((m: any) => !isInternalSystemMessage(m.content || ''));
    ctx.msg_filter_count = total - realMsgs.length;
    ctx.recent_messages = realMsgs.slice(0, 12).reverse().map((m: any) => ({ from: m.is_from_me ? 'me' : 'lead', text: (m.content || '').substring(0, 200), date: m.created_at }));
    const lastFromLead = realMsgs.find((m: any) => !m.is_from_me);
    if (lastFromLead) ctx.days_since_last_msg = Math.floor((Date.now() - new Date(lastFromLead.created_at).getTime()) / 86400000);
  }
  try {
    const sixMonthsAgo = new Date(Date.now() - 180 * 86400000).toISOString();
    const { data: calls } = await supabase.from("call_history").select("ai_summary, started_at").eq("tenant_id", tenantId).eq("lead_id", leadId).gte("started_at", sixMonthsAgo).not("ai_summary", "is", null).order("started_at", { ascending: false }).limit(3);
    if (calls) ctx.past_calls = calls.map((c: any) => ({ date: c.started_at, summary: String(c.ai_summary).substring(0, 350) }));
  } catch {}
  try {
    // SCHEMA CRMPAIN: meetings tem started_at (não scheduled_for) e summary (não ai_summary)
    const { data: meetings } = await supabase.from("meetings").select("summary, status, started_at, title").eq("tenant_id", tenantId).eq("lead_id", leadId).order("started_at", { ascending: false, nullsFirst: false }).limit(5);
    if (meetings) {
      const now = Date.now();
      ctx.past_meetings = meetings.filter((m: any) => m.started_at && new Date(m.started_at).getTime() < now && m.summary).slice(0, 3).map((m: any) => ({ date: m.started_at, status: m.status || '', summary: String(m.summary || '').substring(0, 350) }));
      const upcoming = meetings.find((m: any) => m.started_at && new Date(m.started_at).getTime() >= now && m.status !== 'cancelled');
      if (upcoming) {
        const dt = new Date(upcoming.started_at).toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo', day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
        ctx.upcoming_meeting = `${upcoming.title || 'Reunião'} agendada pra ${dt}`;
      }
    }
  } catch {}
  return ctx;
}

function buildPromptComentarPost(tone: string, customPrompt: string, post: PostContext): string {
  const base = customPrompt;
  return `${tone}\n\n${base}\n\nPOST:\n${post.caption || "(sem caption)"}\n\nResponda APENAS com o texto do comentário, sem aspas, sem prefixo.`;
}

/** Classifica post pra não comentar em conteúdo pessoal/íntimo (esposa/filhos/homenagem/luto). */
async function classifyPostContext(caption: string, anthropicKey: string): Promise<{ skip: boolean; reason?: string }> {
  if (!caption || caption.trim().length < 10) return { skip: false };
  const prompt = `Classifique este post do Instagram. Responda APENAS com 1 dessas palavras:

PESSOAL — se for: declaração à esposa/marido/namorada/filho/pai/mãe, foto íntima de família, homenagem (vivo ou póstuma), aniversário de pessoa querida, casamento, batizado, religião pessoal/devoção, luto, intimidade familiar, foto romântica de casal.

PROFISSIONAL — se for: negócio, conteúdo educativo, frase motivacional/empreendedora, dica/insight, evento profissional, lançamento, viagem turística (sem família íntima), opinião sobre mercado, hobby/esporte, gastronomia, paisagem, entretenimento, casual.

POST:
${caption.slice(0, 500)}

Resposta (só a palavra):`;
  try {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-api-key": anthropicKey, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({ model: HAIKU_MODEL, max_tokens: 10, messages: [{ role: "user", content: prompt }] }),
    });
    if (!r.ok) return { skip: false };
    const data = await r.json();
    const txt = (data.content?.[0]?.text || "").trim().toUpperCase();
    if (txt.startsWith("PESSOAL")) return { skip: true, reason: "personal_post" };
    return { skip: false };
  } catch { return { skip: false }; }
}

function buildPromptResponderStory(tone: string, customPrompt: string, storyContent?: string): string {
  const base = customPrompt;
  return `${tone}\n\n${base}\n\nSTORY:\n${storyContent || "(conteúdo não disponível)"}\n\nResponda APENAS com o texto da resposta, sem aspas.`;
}

function buildPromptEnviarDM(tone: string, customPrompt: string, conv: ConversationContext, post: PostContext): string {
  const base = customPrompt;
  const isCold = conv.recent_messages.length === 0 && conv.past_calls.length === 0 && conv.past_meetings.length === 0;
  const convSummary = conv.recent_messages.length > 0
    ? `HISTÓRICO REAL DE WHATSAPP (cronológico, EU=empresa, LEAD=cliente):\n${conv.recent_messages.map((m) => `  ${m.from === 'me' ? 'EU' : 'LEAD'}: ${m.text}`).join('\n')}${conv.msg_filter_count ? `\n[${conv.msg_filter_count} notificações internas filtradas — não são conversa real]` : ''}`
    : 'SEM HISTÓRICO DE WHATSAPP REAL — lead nunca conversou via WhatsApp.';
  const callsPart = conv.past_calls.length > 0 ? `\n\nCALLS PASSADAS (resumos IA):\n${conv.past_calls.map((c) => `  [${new Date(c.date).toLocaleDateString('pt-BR')}] ${c.summary}`).join('\n')}` : '';
  const pastMeetingsPart = conv.past_meetings.length > 0 ? `\n\nREUNIÕES PASSADAS (resumos IA):\n${conv.past_meetings.map((m) => `  [${new Date(m.date).toLocaleDateString('pt-BR')} · ${m.status}] ${m.summary}`).join('\n')}` : '';
  const meetPart = conv.upcoming_meeting ? `\n\nFUTURA: ${conv.upcoming_meeting}` : '\n\nNENHUMA REUNIÃO FUTURA AGENDADA.';
  const bantPart = conv.bant_summary ? `\n\nBANT: ${conv.bant_summary}` : '';
  const daysPart = conv.days_since_last_msg != null ? `\n\nDIAS DESDE ÚLTIMA MSG REAL DO LEAD: ${conv.days_since_last_msg}` : '';
  const stagePart = conv.sales_stage ? `\n\nESTÁGIO PIPELINE: ${conv.sales_stage}` : '';
  const guard = `\n\n⚠️ REGRAS ANTIALUCINAÇÃO:\n1. NUNCA invente reuniões, horários, calls ou compromissos que NÃO ESTÃO EXPLICITAMENTE no contexto acima.\n2. Se "NENHUMA REUNIÃO FUTURA AGENDADA" — não fale "amanhã às X", "semana que vem", "pra call".\n3. Se "SEM HISTÓRICO DE WHATSAPP REAL" — é primeiro contato. NÃO finja que já conversaram.\n4. Use APENAS fatos do contexto. Sem suposições.\n5. Se contexto vazio (lead frio) — DM frio: comenta perfil/post + pergunta aberta.`;
  const situacao = isCold ? `\n\nSITUAÇÃO: LEAD FRIO (primeiro contato, nunca conversou). Gere DM de prospecção INICIAL.` : `\n\nSITUAÇÃO: LEAD COM HISTÓRICO. Gere DM contextualizada — referenciar o que aconteceu.`;
  return `${tone}\n\n${base}${guard}${situacao}\n\nLEAD: ${conv.lead_name || '(sem nome)'}${bantPart}${stagePart}${daysPart}${callsPart}${pastMeetingsPart}${meetPart}\n\n${convSummary}\n\nPOST/CONTEXTO IG:\n${post.caption || "(sem post)"}\n\nResponda APENAS com o texto da DM (sem aspas, sem prefixo).`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    // Multi-tenant: chamada pela extensão com JWT do usuário → tenant do JWT.
    const tenantId = requireTenantFromRequest(req);
    const anthropicKey = await getAnthropicKey(supabase, tenantId);
    if (!anthropicKey) return new Response(JSON.stringify({ error: "ANTHROPIC_API_KEY não configurada. Configure em /configuracoes → Integrações → API Keys." }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
    const body = await req.json();
    const { lead_id, action_type, post_url, story_content, story_image } = body;
    if (!lead_id || !action_type) return new Response(JSON.stringify({ error: "lead_id and action_type required" }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
    // Lead precisa pertencer ao tenant do caller (anti-IDOR; service_role ignora RLS)
    await assertEntityTenant(supabase, "leads", lead_id, tenantId);

    // Tom + prompt da ação — OBRIGATÓRIOS no banco (sem fallback hardcoded).
    // Se faltar, retorna erro 500 claro pedindo configurar.
    const tone = parseTone(await readConfig(supabase, "social_selling_tone", tenantId));
    const customPrompt = await requirePrompt(supabase, action_type, tenantId);
    let prompt = "";
    let context_used: any = {};

    if (action_type === "comentar_post") {
      const post = await buildPostContext(supabase, post_url, tenantId);
      const classification = await classifyPostContext(post.caption || "", anthropicKey);
      if (classification.skip) {
        return new Response(JSON.stringify({ skip: true, reason: classification.reason || "personal_post", message: "" }), { headers: { ...cors, "Content-Type": "application/json" } });
      }
      prompt = buildPromptComentarPost(tone, customPrompt, post);
      context_used = { post_caption: post.caption?.substring(0, 100), classified: "professional" };
    } else if (action_type === "responder_story") {
      const sc = (story_content || "").trim();
      const hasImg = typeof story_image === "string" && story_image.length > 1000;

      // POLÍTICA: SEM IMAGEM = PULA. Sempre.
      // Comentar story sem ver é risco real (story de luto/falecimento/íntimo).
      // Na dúvida, melhor prática é não responder.
      if (!hasImg) {
        return new Response(
          JSON.stringify({ skip: true, reason: "no_story_image_safety_skip", message: "" }),
          { headers: { ...cors, "Content-Type": "application/json" } }
        );
      }

      // Tem imagem → Vision SEMPRE.
      // O prompt inclui um detector anti-pessoal que retorna "PESSOAL" pra story íntimo (esposa/filho/luto/religião).
      const visionPrompt = `${tone}\n\n${customPrompt}\n\n` +
        `CONTEXTO: você tá vendo um SCREENSHOT da tela do Instagram Stories (com a UI do IG ao redor — botões de curtir/responder/perfil). Foco no CONTEÚDO DO STORY (foto/vídeo no centro), ignore a UI.\n` +
        (sc ? `TEXTO CAPTURADO DO DOM (extra contexto):\n${sc}\n\n` : "") +
        `REGRA CRÍTICA — RESPONDA "PESSOAL" e nada mais quando o conteúdo for:\n` +
        `• Homenagem póstuma / luto / falecimento / "in memoriam"\n` +
        `• Declaração à esposa, marido, namorada(o), filho, pai, mãe, avó\n` +
        `• Foto íntima de família (casamento, batizado, aniversário de filho)\n` +
        `• Religião pessoal, oração, devoção, momento espiritual\n` +
        `• Foto romântica de casal / declaração de amor\n` +
        `• Doença grave, hospital, recuperação\n` +
        `• Tragédia, perda, desastre, acidente\n\n` +
        `Caso seja conteúdo profissional/casual/leve (negócio, viagem, food, esporte, show, paisagem, dica, motivacional), gere a resposta seguindo o tom acima. APENAS o texto da resposta, sem aspas, sem prefixo.`;
      const raw = await callHaikuVision(visionPrompt, story_image, anthropicKey, 300);
      if (/^pessoal/i.test(raw.trim())) {
        return new Response(JSON.stringify({ skip: true, reason: "personal_story", message: "" }), { headers: { ...cors, "Content-Type": "application/json" } });
      }
      return new Response(JSON.stringify({ message: raw, context_used: { mode: "vision", story_content_length: sc.length, image_kb: Math.round(story_image.length / 1024) } }), { headers: { ...cors, "Content-Type": "application/json" } });
    } else if (action_type === "enviar_dm" || action_type === "followup_story") {
      const conv = await buildConversationContext(supabase, lead_id, tenantId);
      const post = await buildPostContext(supabase, post_url, tenantId);
      prompt = buildPromptEnviarDM(tone, customPrompt, conv, post);
      context_used = {
        recent_messages_count: conv.recent_messages.length,
        msgs_filtered_internal: conv.msg_filter_count || 0,
        days_since_last_msg: conv.days_since_last_msg,
        past_calls_count: conv.past_calls.length,
        past_meetings_count: conv.past_meetings.length,
        has_upcoming_meeting: !!conv.upcoming_meeting,
        upcoming_meeting: conv.upcoming_meeting,
        sales_stage: conv.sales_stage,
      };
    } else {
      return new Response(JSON.stringify({ error: `action_type não suportado: ${action_type}` }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
    }

    const message = await callHaiku(prompt, anthropicKey, 300);
    return new Response(JSON.stringify({ message, context_used }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e: any) {
    const t = tenantErrorResponse(e, cors);
    if (t) return t;
    console.error("generate-social-selling-message error:", e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
