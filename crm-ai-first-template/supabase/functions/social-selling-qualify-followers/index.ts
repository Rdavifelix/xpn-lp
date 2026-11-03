// social-selling-qualify-followers v20 — versão consolidada
// - Usa followers_data RICOS da extensão (web_profile_info), sem chamar sync-instagram-timeline (extinta)
// - Gate PERFIL PRIVADO (red flag automático)
// - Lead com instagram_username + Deal com pipeline_id (sem isso kanban filtra fora)
// - Registra entry de qualificação na timeline (company_activities)
// - Dispara mirror-ig-media pra profile pic em background

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getIntegrationKey } from "../_shared/config.ts";
import { getTenantFromRequest } from "../_shared/tenant.ts";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const HAIKU_MODEL = "claude-haiku-4-5-20251001";
const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
const SUPA_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;


// Dispara mirror em background (fire-and-forget)
function fireMirrorProfilePic(profile: any) {
  if (!profile?.profile_picture_url_hd || !profile?.id) return;
  const url = profile.profile_picture_url_hd;
  if (url.startsWith(`${SUPA_URL}/storage/v1/object/public/`)) return; // já mirrored
  fetch(`${SUPA_URL}/functions/v1/mirror-ig-media`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${SUPA_KEY}` },
    body: JSON.stringify({
      url, path: `profiles/${profile.id}.jpg`,
      table: "instagram_profiles", row_id: profile.id, column: "stored_profile_picture_url",
    }),
  }).catch((e) => console.warn("mirror profile pic falhou:", e?.message));
}

async function saveProfile(supabase: any, meta: any, tenantId: string | null): Promise<{ ok: boolean; error?: string; profile?: any }> {
  const profile: any = {
    ...(tenantId ? { tenant_id: tenantId } : {}),
    username: String(meta.username).toLowerCase(),
    full_name: meta.full_name || null,
    biography: meta.biography || null,
    follower_count: meta.follower_count ?? null,
    following_count: meta.following_count ?? null,
    media_count: meta.media_count ?? null,
    is_private: meta.is_private ?? null,
    is_verified: meta.is_verified ?? null,
    is_business: meta.is_business_account ?? null,
    instagram_user_id: meta.instagram_user_id ? String(meta.instagram_user_id) : null,
    profile_picture_url_hd: meta.profile_picture_url_hd || null,
    external_url: meta.external_url || null,
    category: meta.category || null,
    updated_at: new Date().toISOString(),
  };
  const { data: saved, error } = await supabase.from("instagram_profiles")
    .upsert(profile, { onConflict: "tenant_id,username" })
    .select("id, username, biography, follower_count, following_count, media_count, is_verified, is_private, is_business, full_name, instagram_user_id, profile_picture_url_hd, stored_profile_picture_url")
    .single();
  if (error) return { ok: false, error: `db: ${error.message}` };
  if (!saved?.stored_profile_picture_url) fireMirrorProfilePic(saved);
  return { ok: true, profile: saved };
}

async function qualifyWithAI(profile: any, customPrompt: string | null, anthropicKey: string): Promise<{ score: number; reason: string }> {
  if (!profile) return { score: 0, reason: "perfil não disponível" };
  const prompt = `${customPrompt || "Qualifique esse perfil pra prospecção B2B."}\n\nPERFIL:\n@${profile.username} · ${profile.full_name || ""}\nSeguidores: ${profile.follower_count || 0} · Seguindo: ${profile.following_count || 0} · Posts: ${profile.media_count || 0}\nVerificado: ${profile.is_verified ? "sim" : "não"}\nBio: ${profile.biography || "(sem bio)"}\n\nResponda em JSON: {"score": 0-100, "reason": "frase curta"}`;
  try {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-api-key": anthropicKey, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({ model: HAIKU_MODEL, max_tokens: 200, messages: [{ role: "user", content: prompt }] }),
    });
    if (!r.ok) return { score: 0, reason: `haiku ${r.status}` };
    const data = await r.json();
    const text = (data.content?.[0]?.text || "").trim();
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) return { score: 0, reason: "sem JSON" };
    const parsed = JSON.parse(match[0]);
    return { score: parseInt(parsed.score) || 0, reason: String(parsed.reason || "").slice(0, 250) };
  } catch (e: any) { return { score: 0, reason: `parse erro: ${e.message}` }; }
}

async function qualifyOne(supabase: any, meta: any, forAccount: string, automation: any, scoreMin: number, customPrompt: string | null, anthropicKey: string, tenantId: string | null) {
  const username = String(meta.username).toLowerCase();
  const tenantCol = tenantId ? { tenant_id: tenantId } : {};

  // Já processado antes → pula
  let knownQ = supabase.from("social_selling_known_followers").select("*").eq("username", username).eq("for_account", forAccount);
  if (tenantId) knownQ = knownQ.eq("tenant_id", tenantId);
  const { data: known } = await knownQ.maybeSingle();
  if (known && known.qualified !== null) {
    return { username, status: "already_known", qualified: known.qualified, score: known.qualification_score, lead_id: known.lead_id };
  }

  // Enrich falhou no client (perfil não acessível, http 404 do IG, etc)
  if (meta.fetch_error) {
    await supabase.from("social_selling_known_followers").upsert({
      ...tenantCol,
      username, for_account: forAccount,
      qualified: false, qualification_reason: `fetch_error: ${meta.fetch_error}`,
    }, { onConflict: "username,for_account" });
    return { username, status: "sync_error", error: meta.fetch_error };
  }

  // Salva perfil no banco
  const saved = await saveProfile(supabase, meta, tenantId);
  if (!saved.ok) {
    await supabase.from("social_selling_known_followers").upsert({
      ...tenantCol,
      username, for_account: forAccount,
      qualified: false, qualification_reason: `db_error: ${saved.error}`,
    }, { onConflict: "username,for_account" });
    return { username, status: "sync_error", error: saved.error };
  }
  const profile = saved.profile;

  // Gate: perfil privado → red flag automático, não chama Haiku, não cria lead
  if (profile?.is_private === true) {
    await supabase.from("social_selling_known_followers").upsert({
      ...tenantCol,
      username, for_account: forAccount,
      instagram_user_id: profile?.instagram_user_id || null,
      full_name: profile?.full_name, is_private: true, is_verified: profile?.is_verified,
      qualified: false, qualification_score: 0,
      qualification_reason: "perfil privado (red flag — não dá pra ver posts/stories)",
    }, { onConflict: "username,for_account" });
    return { username, status: "private_skip", reason: "perfil privado" };
  }

  // Qualifica via IA
  const q = await qualifyWithAI(profile, customPrompt, anthropicKey);
  const isQualified = q.score >= scoreMin;

  if (!isQualified) {
    await supabase.from("social_selling_known_followers").upsert({
      ...tenantCol,
      username, for_account: forAccount,
      instagram_user_id: profile?.instagram_user_id || null,
      full_name: profile?.full_name, is_private: profile?.is_private, is_verified: profile?.is_verified,
      qualified: false, qualification_score: q.score, qualification_reason: q.reason,
    }, { onConflict: "username,for_account" });
    return { username, status: "icp_fail", score: q.score, reason: q.reason };
  }

  // Cria lead + deal + enrollment + timeline entry
  const triggerConfig = automation.trigger_config || {};
  const targetPipelineId: string | null = triggerConfig.target_pipeline_id || null;
  const targetStageId: string | null = triggerConfig.target_stage_id || null;
  if (!targetPipelineId) return { username, status: "config_error", error: `Cadência sem target_pipeline_id` };

  let stageId = targetStageId;
  if (!stageId) {
    const { data: stages } = await supabase.from("sales_pipeline_stages").select("id").eq("pipeline_id", targetPipelineId).order("position").limit(1);
    stageId = stages?.[0]?.id || null;
  }
  if (!stageId) return { username, status: "config_error", error: `Pipeline sem stages` };

  const { data: lead, error: leadErr } = await supabase.from("leads").insert({
    ...tenantCol,
    name: profile?.full_name || username,
    phone: "",
    instagram: username,                  // campo legado
    instagram_username: username,         // campo novo (usado pelo lead view + queries)
    instagram_profile_id: profile?.id || null,
    sales_stage: "new",
    sales_score: q.score,
    pipeline_stage_id: stageId,
  }).select("id").single();

  if (leadErr) {
    console.error(`[qualify] lead insert error for @${username}:`, leadErr);
    await supabase.from("social_selling_known_followers").upsert({
      ...tenantCol,
      username, for_account: forAccount,
      qualified: false, qualification_score: q.score, qualification_reason: `lead_error: ${leadErr.message}`,
    }, { onConflict: "username,for_account" });
    return { username, status: "lead_error", error: leadErr.message };
  }

  // Deal precisa de pipeline_id (sem ele kanban filtra fora)
  await supabase.from("deals").insert({
    ...tenantCol,
    lead_id: lead.id,
    title: `Prospecção @${username}`,
    pipeline_id: targetPipelineId,
    pipeline_stage_id: stageId,
    status: "open",
  });

  // Enrollment na cadência
  const { data: enrollment } = await supabase.from("social_selling_enrollments").insert({
    ...tenantCol,
    lead_id: lead.id, automation_id: automation.id, instagram_username: username,
    current_day: 1, total_days: (automation.cadence_config?.days || []).length || 3,
    status: "active", next_action_at: new Date().toISOString(),
  }).select("id").single();

  // Timeline: registra critério de qualificação
  await supabase.from("company_activities").insert({
    ...tenantCol,
    lead_id: lead.id,
    task_type: "social_selling_qualification",
    source_type: "social_selling_qualify_followers",
    name: `🎯 Qualificação IA: aprovado com score ${q.score}/100`,
    description: q.reason,
    notes: `@${username} • ${profile?.follower_count || 0} seguidores • ${profile?.media_count || 0} posts${profile?.is_verified ? " • ✓ verificado" : ""}${profile?.is_business ? " • 💼 business" : ""}\n\nCadência aplicada: ${automation.name}`,
    status: "completed",
    completed: true,
    completed_at: new Date().toISOString(),
    ai_generated: true,
    metadata: {
      score: q.score,
      reason: q.reason,
      automation_id: automation.id,
      automation_name: automation.name,
      profile_snapshot: {
        username,
        full_name: profile?.full_name,
        follower_count: profile?.follower_count,
        following_count: profile?.following_count,
        media_count: profile?.media_count,
        is_verified: profile?.is_verified,
        is_business: profile?.is_business,
        biography: profile?.biography,
      },
    },
  });

  // Marca como qualificado no cache
  await supabase.from("social_selling_known_followers").upsert({
    ...tenantCol,
    username, for_account: forAccount,
    instagram_user_id: profile?.instagram_user_id || null,
    full_name: profile?.full_name, is_private: profile?.is_private, is_verified: profile?.is_verified,
    qualified: true, qualification_score: q.score, qualification_reason: q.reason,
    lead_id: lead.id, enrollment_id: enrollment?.id,
  }, { onConflict: "username,for_account" });

  return { username, status: "qualified", score: q.score, lead_id: lead.id };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    const auth = req.headers.get("Authorization") || "";
    const jwt = auth.replace(/^Bearer\s+/i, "");
    if (!jwt) return new Response(JSON.stringify({ error: "unauthenticated" }), { status: 401, headers: { ...cors, "Content-Type": "application/json" } });

    const supabase = createClient(SUPA_URL, SUPA_KEY);
    const tenantId = getTenantFromRequest(req);
    const { data: { user } } = await supabase.auth.getUser(jwt);
    if (!user) return new Response(JSON.stringify({ error: "invalid_token" }), { status: 401, headers: { ...cors, "Content-Type": "application/json" } });

    const { data: tm } = await supabase.from("team_members").select("is_active").eq("auth_user_id", user.id).maybeSingle();
    if (!tm?.is_active) return new Response(JSON.stringify({ error: "forbidden" }), { status: 403, headers: { ...cors, "Content-Type": "application/json" } });

    const anthropicKey = (await getIntegrationKey(supabase, "ANTHROPIC_API_KEY", tenantId)) || "";
    if (!anthropicKey) return new Response(JSON.stringify({ error: "ANTHROPIC_API_KEY não configurada" }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });

    const body = await req.json();
    const automation_id: string = body.automation_id;
    const for_account: string = body.for_account || "owner";
    const score_min: number = typeof body.score_min === "number" ? body.score_min : 60;
    const cacheOnly: boolean = body.cache_only === true;

    if (!automation_id) return new Response(JSON.stringify({ error: "automation_id obrigatório" }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });

    let automationQ = supabase.from("social_selling_automations").select("*").eq("id", automation_id);
    if (tenantId) automationQ = automationQ.eq("tenant_id", tenantId);
    const { data: automation } = await automationQ.maybeSingle();
    if (!automation) return new Response(JSON.stringify({ error: "automation_not_found" }), { status: 404, headers: { ...cors, "Content-Type": "application/json" } });

    if (!automation.trigger_config?.target_pipeline_id && !cacheOnly) {
      return new Response(JSON.stringify({ error: `Cadência "${automation.name}" sem pipeline destino.` }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
    }

    // Modo cache_only: só pré-popula known_followers (qualified=null) pra recuperação se SW morrer
    if (cacheOnly) {
      const usernames: string[] = (body.usernames || []).filter((x: any) => typeof x === "string").map((x: string) => x.toLowerCase().replace(/^@/, "").trim()).filter(Boolean);
      const followers_data: any[] = body.followers_data || [];
      if (usernames.length === 0) return new Response(JSON.stringify({ success: true, summary: { cached: 0 } }), { headers: { ...cors, "Content-Type": "application/json" } });

      const cacheRows = usernames.map((u) => {
        const meta = followers_data.find((f) => f.username?.toLowerCase() === u) || {};
        return { ...(tenantId ? { tenant_id: tenantId } : {}), username: u, for_account, full_name: meta.full_name || null, is_private: meta.is_private ?? null, is_verified: meta.is_verified ?? null };
      });
      let existingQ = supabase.from("social_selling_known_followers").select("username").in("username", usernames).eq("for_account", for_account);
      if (tenantId) existingQ = existingQ.eq("tenant_id", tenantId);
      const { data: existing } = await existingQ;
      const existingSet = new Set((existing || []).map((r: any) => r.username));
      const newCount = usernames.filter((u) => !existingSet.has(u)).length;
      await supabase.from("social_selling_known_followers").upsert(cacheRows, { onConflict: "username,for_account", ignoreDuplicates: true });
      return new Response(JSON.stringify({ success: true, summary: { cached: newCount, total_received: usernames.length } }), { headers: { ...cors, "Content-Type": "application/json" } });
    }

    // Modo qualificação: usa followers_data (enriquecido pela extensão)
    const followers_data: any[] = body.followers_data || [];
    if (followers_data.length === 0) {
      return new Response(JSON.stringify({ error: "followers_data obrigatório (passe dados ricos via extensão)" }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
    }

    const customPrompt = await getIntegrationKey(supabase, "social_selling_prompt_qualificacao", tenantId);
    const results = await Promise.all(followers_data.map((meta) => qualifyOne(supabase, meta, for_account, automation, score_min, customPrompt, anthropicKey, tenantId)));

    return new Response(JSON.stringify({
      success: true,
      score_min_used: score_min,
      summary: {
        processed: results.length,
        qualified: results.filter((r) => r.status === "qualified").length,
        icp_fail: results.filter((r) => r.status === "icp_fail").length,
        sync_errors: results.filter((r) => r.status === "sync_error").length,
        lead_errors: results.filter((r) => r.status === "lead_error").length,
        config_errors: results.filter((r) => r.status === "config_error").length,
        private_skip: results.filter((r) => r.status === "private_skip").length,
        already_known: results.filter((r) => r.status === "already_known").length,
      },
      results,
    }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e.message || String(e) }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
