// social-selling-plan-day v17 — fix: forceMode NÃO pula trava de dia BR (cadência sempre respeitada)
// + v14: trava entre dias = VIRADA DO DIA BR
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getIntegrationKey } from "../_shared/config.ts";
import { getTenantFromRequest } from "../_shared/tenant.ts";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };

function dateBR(iso: string | Date): string {
  const d = typeof iso === "string" ? new Date(iso) : iso;
  return d.toLocaleDateString("sv-SE", { timeZone: "America/Sao_Paulo" });
}

async function readConfig(supabase: any, key: string, tenantId: string | null): Promise<any> {
  const raw = await getIntegrationKey(supabase, key, tenantId);
  if (!raw) return null;
  try { return JSON.parse(raw); } catch { return raw; }
}
function shuffle<T>(arr: T[]): T[] { const a = [...arr]; for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }
function randomBetween(min: number, max: number) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function isWithinWorkingHoursBR(start: string, end: string): boolean {
  const now = new Date(new Date().toLocaleString("en-US", { timeZone: "America/Sao_Paulo" }));
  const cur = now.getHours() * 60 + now.getMinutes();
  const [sh, sm] = (start || "09:00").split(":").map(Number);
  const [eh, em] = (end || "20:00").split(":").map(Number);
  return cur >= sh * 60 + sm && cur <= eh * 60 + em;
}
function isWeekendBR(): boolean {
  const now = new Date(new Date().toLocaleString("en-US", { timeZone: "America/Sao_Paulo" }));
  const d = now.getDay();
  return d === 0 || d === 6;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const tenantId = getTenantFromRequest(req);
    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
    const skipBudget = body.skip_budget === true;
    const selectedIds = Array.isArray(body.enrollment_ids) ? body.enrollment_ids.filter((x: any) => typeof x === "string") : [];

    const limits = (await readConfig(supabase, "social_selling_limits", tenantId)) || {};
    const workStart = limits.working_hours_start || "09:00";
    const workEnd = limits.working_hours_end || "20:00";
    const pauseWeekends = limits.pause_weekends ?? true;
    const totalActionsLimit = limits.total_actions_per_day || 80;
    const dmsLimit = limits.dms_per_day || 15;
    const commentsLimit = limits.comments_per_day || 20;
    const likesLimit = limits.likes_per_day || 60;
    const minDelay = limits.delay_min_seconds || 45;
    const maxDelay = limits.delay_max_seconds || 180;
    const minMinBetween = limits.min_minutes_between_actions_same_lead || 30;
    const skipPct = (limits.random_skip_pct ?? 10) / 100;

    const forceMode = skipBudget || selectedIds.length > 0;
    const reasons: string[] = [];
    if (!forceMode && pauseWeekends && isWeekendBR()) reasons.push("weekend_pause");
    if (!forceMode && !isWithinWorkingHoursBR(workStart, workEnd)) reasons.push(`outside_working_hours (${workStart}-${workEnd} BR)`);
    if (reasons.length > 0) return new Response(JSON.stringify({ ok: false, reason: reasons.join(", "), plan: [] }), { headers: { ...cors, "Content-Type": "application/json" } });

    let autoQ = supabase.from("social_selling_automations").select("*").eq("is_active", true);
    if (tenantId) autoQ = autoQ.eq("tenant_id", tenantId);
    const { data: automations } = await autoQ;
    if (!automations || automations.length === 0) return new Response(JSON.stringify({ ok: false, reason: "no_active_automations", plan: [] }), { headers: { ...cors, "Content-Type": "application/json" } });

    let enrQuery = supabase.from("social_selling_enrollments").select("id, lead_id, instagram_username, current_day, total_days, status, last_action_at, automation_id, flow_config, started_at").eq("status", "active");
    if (tenantId) enrQuery = enrQuery.eq("tenant_id", tenantId);
    if (selectedIds.length > 0) enrQuery = enrQuery.in("id", selectedIds);
    else if (!skipBudget) enrQuery = enrQuery.lte("next_action_at", new Date().toISOString());
    let { data: enrollments } = await enrQuery;
    if (!enrollments || enrollments.length === 0) return new Response(JSON.stringify({ ok: false, reason: "no_active_enrollments", plan: [] }), { headers: { ...cors, "Content-Type": "application/json" } });

    const todayBR = dateBR(new Date());

    // v18 — NOVO MODELO DE CADÊNCIA: "Dia N" = D+(N-1) dias após inscrição
    // Lead inscrito hoje (D+0) → Dia 1 hoje, Dia 3 em 2 dias, Dia 7 em 6 dias.
    // Calcula desiredDay = dias decorridos desde started_at_BR + 1.
    // Se não houver etapa correspondente, pula (não é dia dele).
    function daysBetweenBR(start: string, end: string): number {
      const a = new Date(`${start}T00:00:00-03:00`).getTime();
      const b = new Date(`${end}T00:00:00-03:00`).getTime();
      return Math.round((b - a) / 86400000);
    }

    const advanced: any[] = [];
    for (const enr of enrollments) {
      const automation = automations.find((a: any) => a.id === enr.automation_id) || automations.find((a: any) => a.id === enr.flow_config?.automation_id) || automations[0];
      const days = automation?.cadence_config?.days || [];
      if (days.length === 0) continue;

      const startedDateBR = dateBR(enr.started_at);
      const daysSince = daysBetweenBR(startedDateBR, todayBR);
      const desiredDay = daysSince + 1; // Dia 1 = mesmo dia da inscrição

      // Se passou da última etapa, marca completed
      const maxDay = Math.max(...days.map((d: any) => d.day));
      if (desiredDay > maxDay) {
        // checa se já completou todas ações da última etapa
        const { data: lastTried } = await supabase.from("social_selling_interactions")
          .select("action_type, status")
          .eq("enrollment_id", enr.id).eq("day_number", maxDay)
          .in("status", ["success", "skipped", "failed"]);
        const triedByType: Record<string, number> = {};
        for (const a of (lastTried || [])) triedByType[a.action_type] = (triedByType[a.action_type] || 0) + 1;
        const lastDayCfg = days.find((d: any) => d.day === maxDay);
        const expected = lastDayCfg?.actions || [];
        let allDone = true;
        for (const exp of expected) { if ((triedByType[exp.type] || 0) < (exp.count || 1)) { allDone = false; break; } }
        if (allDone) {
          await supabase.from("social_selling_enrollments").update({
            current_day: maxDay, status: "completed", completed_at: new Date().toISOString(), next_action_at: null,
          }).eq("id", enr.id);
          advanced.push({ enrollment_id: enr.id, completed: true });
          enr.status = "completed";
        }
        continue;
      }

      // Encontra etapa pra hoje (se existir)
      const dayCfg = days.find((d: any) => d.day === desiredDay);
      if (!dayCfg) {
        // Hoje não é dia de etapa (ex: cadência [1,3,7] e desiredDay=2). Espera o próximo D.
        continue;
      }

      // Atualiza current_day pra refletir o dia atual (informativo)
      if (enr.current_day !== desiredDay) {
        await supabase.from("social_selling_enrollments").update({
          current_day: desiredDay, next_action_at: new Date().toISOString(),
        }).eq("id", enr.id);
        advanced.push({ enrollment_id: enr.id, from: enr.current_day, to: desiredDay });
        enr.current_day = desiredDay;
      }
    }
    enrollments = enrollments.filter((e: any) => e.status === "active");

    const cacheCutoff = new Date(Date.now() - 3 * 86400000).toISOString();
    const usernames = enrollments.map((e: any) => e.instagram_username);
    if (usernames.length > 0) {
      let profQ = supabase.from("instagram_profiles").select("username, updated_at").in("username", usernames);
      if (tenantId) profQ = profQ.eq("tenant_id", tenantId);
      const { data: existingProfiles } = await profQ;
      const profileMap = new Map<string, string>((existingProfiles || []).map((p: any) => [p.username, p.updated_at]));
      const needRefresh = enrollments.filter((e: any) => { const lastUpdate = profileMap.get(e.instagram_username); return !lastUpdate || lastUpdate < cacheCutoff; });
      if (needRefresh.length > 0) {
        const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
        const SUPA_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const refreshOne = async (username: string) => {
          try {
            const r = await fetch(`${SUPA_URL}/functions/v1/sync-instagram-timeline`, { method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${SUPA_KEY}` }, body: JSON.stringify({ instagram: username }) });
            if (!r.ok) console.warn(`refresh ${username}: ${r.status}`);
          } catch (e) { console.warn(`refresh ${username}:`, e); }
        };
        for (let i = 0; i < needRefresh.length; i += 5) {
          const batch = needRefresh.slice(i, i + 5);
          await Promise.all(batch.map((e: any) => refreshOne(e.instagram_username)));
        }
      }
    }

    if (enrollments.length === 0) return new Response(JSON.stringify({ ok: false, reason: "all_completed_after_advance", plan: [], advanced }), { headers: { ...cors, "Content-Type": "application/json" } });

    const { data: doneTodayData } = await supabase.rpc("ss_actions_today", { p_action: null });
    const totalDoneToday: number = doneTodayData || 0;
    if (!forceMode && totalDoneToday >= totalActionsLimit) return new Response(JSON.stringify({ ok: false, reason: `daily_limit_reached`, plan: [] }), { headers: { ...cors, "Content-Type": "application/json" } });

    type PlanItem = { enrollment_id: string; lead_id: string; instagram_username: string; day: number; action_type: string; target_url?: string; target_id?: string; delay_after_seconds: number; };
    const plan: PlanItem[] = [];
    const skipped: any[] = [];
    const shuffled = shuffle(enrollments);

    for (const enr of shuffled) {
      const automation = automations.find((a: any) => a.id === enr.automation_id) || automations.find((a: any) => a.id === enr.flow_config?.automation_id) || automations[0];
      const days = automation.cadence_config?.days || [];
      const dayCfg = days.find((d: any) => d.day === enr.current_day) || days.find((d: any) => d.day > (enr.current_day ?? 0));
      if (!dayCfg) { skipped.push({ enrollment_id: enr.id, instagram_username: enr.instagram_username, reason: "no_more_days_in_cadence" }); continue; }
      if (enr.last_action_at && !forceMode) {
        const minutesAgo = (Date.now() - new Date(enr.last_action_at).getTime()) / 60000;
        if (minutesAgo < minMinBetween) { skipped.push({ enrollment_id: enr.id, instagram_username: enr.instagram_username, reason: `too_recent` }); continue; }
      }

      const { data: actedRows } = await supabase.from("social_selling_interactions").select("action_type, instagram_target, status").eq("lead_id", enr.lead_id).in("status", ["success", "skipped", "failed"]);
      const actedSet = new Set((actedRows || []).map((r: any) => `${r.action_type}|${r.instagram_target}`));
      const actedActions = new Set((actedRows || []).filter((r: any) => ["success", "skipped", "failed"].includes(r.status)).map((r: any) => r.action_type));

      for (const action of (dayCfg.actions || [])) {
        const actionType = action.type;
        if (Math.random() < skipPct && !forceMode) { skipped.push({ enrollment_id: enr.id, instagram_username: enr.instagram_username, action: actionType, reason: "random_skip_humanization" }); continue; }
        const todayCount = (actedRows || []).filter((r: any) => r.action_type === actionType).length;
        const need = action.count || 1;
        if (todayCount >= need) { skipped.push({ enrollment_id: enr.id, instagram_username: enr.instagram_username, action: actionType, reason: "already_tried_today" }); continue; }

        if (actionType === "curtir_posts" || actionType === "comentar_post") {
          let profileQ = supabase.from("instagram_profiles").select("id").eq("username", enr.instagram_username);
          if (tenantId) profileQ = profileQ.eq("tenant_id", tenantId);
          const { data: profile } = await profileQ.maybeSingle();
          if (!profile) { skipped.push({ enrollment_id: enr.id, instagram_username: enr.instagram_username, action: actionType, reason: "no_profile_in_db" }); continue; }
          const cutoff60d = new Date(Date.now() - 60 * 24 * 60 * 60 * 1000).toISOString();
          const { data: posts } = await supabase.from("instagram_feed_posts").select("code, permalink, caption, like_count, taken_at").eq("instagram_profile_id", profile.id).gte("taken_at", cutoff60d).order("taken_at", { ascending: false }).limit(20);
          const candidates = (posts || []).filter((p: any) => {
            const url = p.permalink || `https://instagram.com/p/${p.code}/`;
            if (actedSet.has(`${actionType}|${url}`)) return false;
            if (actionType === "comentar_post" && (!p.caption || p.caption.trim().length < 10)) return false;
            return true;
          });
          const maxLikes = Math.max(1, ...candidates.map((p: any) => p.like_count || 0));
          const now = Date.now();
          candidates.sort((a: any, b: any) => {
            const ageA = (now - new Date(a.taken_at).getTime()) / (60 * 24 * 60 * 60 * 1000);
            const ageB = (now - new Date(b.taken_at).getTime()) / (60 * 24 * 60 * 60 * 1000);
            const scoreA = (1 - ageA) * 0.7 + ((a.like_count || 0) / maxLikes) * 0.3;
            const scoreB = (1 - ageB) * 0.7 + ((b.like_count || 0) / maxLikes) * 0.3;
            return scoreB - scoreA;
          });
          const remaining = need - todayCount;
          const chosen = candidates.slice(0, remaining);
          if (chosen.length === 0) { skipped.push({ enrollment_id: enr.id, instagram_username: enr.instagram_username, action: actionType, reason: "all_posts_already_acted" }); continue; }
          for (const p of chosen) {
            const url = p.permalink || `https://instagram.com/p/${p.code}/`;
            plan.push({ enrollment_id: enr.id, lead_id: enr.lead_id, instagram_username: enr.instagram_username, day: dayCfg.day, action_type: actionType, target_url: url, target_id: p.code, delay_after_seconds: randomBetween(minDelay, maxDelay) });
          }
        } else if (actionType === "reagir_story" || actionType === "responder_story" || actionType === "followup_story") {
          const today = new Date().toISOString().slice(0, 10);
          const { data: todayRow } = await supabase.from("social_selling_interactions").select("id").eq("lead_id", enr.lead_id).eq("action_type", actionType).gte("executed_at", today).limit(1);
          if (todayRow && todayRow.length > 0) { skipped.push({ enrollment_id: enr.id, instagram_username: enr.instagram_username, action: actionType, reason: "already_done_today" }); continue; }
          plan.push({ enrollment_id: enr.id, lead_id: enr.lead_id, instagram_username: enr.instagram_username, day: dayCfg.day, action_type: actionType, target_url: `https://www.instagram.com/stories/${enr.instagram_username}/`, delay_after_seconds: randomBetween(minDelay, maxDelay) });
        } else if (actionType === "enviar_dm") {
          if (actedActions.has("enviar_dm")) { skipped.push({ enrollment_id: enr.id, instagram_username: enr.instagram_username, action: actionType, reason: "dm_already_sent" }); continue; }
          plan.push({ enrollment_id: enr.id, lead_id: enr.lead_id, instagram_username: enr.instagram_username, day: dayCfg.day, action_type: actionType, target_url: `https://instagram.com/${enr.instagram_username}/`, delay_after_seconds: randomBetween(minDelay * 2, maxDelay * 2) });
        } else if (actionType === "verificar_resposta") {
          plan.push({ enrollment_id: enr.id, lead_id: enr.lead_id, instagram_username: enr.instagram_username, day: dayCfg.day, action_type: actionType, target_url: "https://instagram.com/direct/inbox/", delay_after_seconds: randomBetween(minDelay, maxDelay) });
        }
      }
    }

    let likesUsed = 0, commentsUsed = 0, dmsUsed = 0;
    const finalPlan: PlanItem[] = [];
    for (const item of plan) {
      if (item.action_type === "curtir_posts") { if (likesUsed >= likesLimit && !forceMode) { skipped.push({ ...item, reason: "likes_daily_limit" }); continue; } likesUsed++; }
      else if (item.action_type === "comentar_post") { if (commentsUsed >= commentsLimit && !forceMode) { skipped.push({ ...item, reason: "comments_daily_limit" }); continue; } commentsUsed++; }
      else if (item.action_type === "enviar_dm") { if (dmsUsed >= dmsLimit && !forceMode) { skipped.push({ ...item, reason: "dms_daily_limit" }); continue; } dmsUsed++; }
      if (totalDoneToday + finalPlan.length >= totalActionsLimit && !forceMode) { skipped.push({ ...item, reason: "total_daily_limit" }); continue; }
      finalPlan.push(item);
    }

    return new Response(JSON.stringify({
      ok: true, generated_at: new Date().toISOString(),
      counts: { total_planned: finalPlan.length, total_skipped: skipped.length, likes: likesUsed, comments: commentsUsed, dms: dmsUsed, already_done_today: totalDoneToday },
      working_hours: { start: workStart, end: workEnd, pause_weekends: pauseWeekends, weekend: isWeekendBR() },
      plan: finalPlan, skipped, advanced,
    }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e: any) {
    console.error("plan-day error:", e);
    return new Response(JSON.stringify({ error: String(e), stack: e?.stack }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
