// ============================================================
// Background service worker — cron, orchestration, dispatch de ações
// ============================================================
import { ActionType, ExtMessage, ExtensionConfig, PlanItem, QueueItem } from '../shared/types';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from '../shared/env';
import { getConfig, getQueue, setQueue, updateQueueItem, pushHistory, uid, pushLog } from '../shared/storage';
import { fetchPlanDay, generateMessage, logAction, qualifyFollowers, readConfigKey } from '../shared/api';
import { getValidAccessToken } from '../shared/auth';

// Lê limits do CRM (config table) — score_min, chunk_size, etc são configuráveis sem rebuild
async function getQualifyLimits(): Promise<{ score_min: number; chunk_size: number }> {
  try {
    const cfg = await getConfig();
    const limits = await readConfigKey(cfg, 'social_selling_limits');
    return {
      score_min: typeof limits?.score_min === 'number' ? limits.score_min : 60,
      chunk_size: typeof limits?.chunk_size === 'number' ? limits.chunk_size : 10,
    };
  } catch { return { score_min: 60, chunk_size: 10 }; }
}

const ALARM_DAILY = 'iap-social-selling-daily';
const ALARM_TICK = 'iap-ss-worker-tick';
const ALARM_QUALIFY = 'iap-ss-qualify-chunk';
const QUALIFY_STATE_KEY = 'iap_ss_qualify_state';

// ------------------------------------------------------------
// Lifecycle
// ------------------------------------------------------------

chrome.runtime.onInstalled.addListener(async () => {
  console.log('[IAP-SS] Installed');
  await recoverZombieExecuting().catch(() => {});
  await scheduleAlarm();
  await updateBadge();
  // Configura side panel pra abrir ao clicar no ícone
  try {
    await chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true });
  } catch (e) {
    console.warn('sidePanel API not available:', e);
  }
});

chrome.runtime.onStartup.addListener(async () => {
  await recoverZombieExecuting().catch(() => {});
  await scheduleAlarm();
  await updateBadge();
  try {
    await chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true });
  } catch {}
  // Auto-recover qualify alarm se houver state (SW morreu mas state persiste)
  await ensureQualifyAlarm().catch(() => {});
});

// Garante alarm periódico do qualify se state existe (resiliente a morte do SW)
async function ensureQualifyAlarm() {
  const stored = await chrome.storage.local.get(QUALIFY_STATE_KEY);
  if (!stored[QUALIFY_STATE_KEY]) return;
  const existing = await chrome.alarms.get(ALARM_QUALIFY);
  if (existing) return;
  await chrome.alarms.create(ALARM_QUALIFY, { delayInMinutes: 0.5, periodInMinutes: 1 });
  await pushLog({ level: 'info', message: '🔄 alarm qualify restaurado (SW reviveu)' }).catch(() => {});
}

// ------------------------------------------------------------
// Cron via chrome.alarms
// ------------------------------------------------------------

async function scheduleAlarm() {
  // v20: cron lê working_hours_start e pause_weekends do CRM (config.social_selling_limits)
  const cfg = await getConfig();
  let cronHour = 9;
  let pauseWeekends = true;
  try {
    const limits = await readConfigKey(cfg, 'social_selling_limits');
    if (limits?.working_hours_start) {
      const [h] = String(limits.working_hours_start).split(':');
      cronHour = parseInt(h) || 9;
    }
    if (typeof limits?.pause_weekends === 'boolean') pauseWeekends = limits.pause_weekends;
  } catch {}
  const next = nextRunAtMs(cronHour, pauseWeekends);
  await chrome.alarms.clear(ALARM_DAILY);
  await chrome.alarms.create(ALARM_DAILY, { when: next, periodInMinutes: 60 * 24 });
  console.log('[IAP-SS] Próximo cron:', new Date(next).toLocaleString('pt-BR'));
}

function nextRunAtMs(hourBR: number, pauseWeekends: boolean): number {
  // Calcula próximo horário X:00 BR (UTC-3) em ms
  const now = new Date();
  const nowBR = new Date(now.toLocaleString('en-US', { timeZone: 'America/Sao_Paulo' }));
  const next = new Date(nowBR);
  next.setHours(hourBR, 0, 0, 0);
  if (next.getTime() <= nowBR.getTime()) {
    next.setDate(next.getDate() + 1);
  }
  if (pauseWeekends) {
    while (next.getDay() === 0 || next.getDay() === 6) {
      next.setDate(next.getDate() + 1);
    }
  }
  // Converte BR pra UTC e retorna ms
  const offset = nowBR.getTime() - now.getTime();
  return next.getTime() - offset;
}

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === ALARM_DAILY) {
    await runDailyJob();
    await scheduleAlarm(); // re-schedule pra próximo dia
  } else if (alarm.name === ALARM_TICK) {
    await chrome.storage.local.set({ iap_ss_idle_until: 0, iap_ss_idle_next: null });
    runWorker().catch((e) => console.error('[IAP-SS] worker tick error:', e));
  } else if (alarm.name === ALARM_QUALIFY) {
    pushLog({ level: 'info', message: '⏰ Alarm qualify-chunk disparou' }).catch(() => {});
    processQualifyChunk().catch((e) => pushLog({ level: 'error', message: `qualify chunk error: ${e.message}` }));
  }
});

// ============================================================
// Qualificação em chunks via chrome.alarms (SW pode dormir entre chunks)
// ============================================================
const QUALIFY_LOCK_KEY = 'iap_ss_qualify_lock';
const QUALIFY_LOCK_TIMEOUT = 3 * 60 * 1000; // 3min
const PAUSED_KEY = 'iap_ss_paused';

async function isPaused(): Promise<boolean> {
  const r = await chrome.storage.local.get(PAUSED_KEY);
  return r[PAUSED_KEY] === true;
}

// Busca pendentes via REST direto (com JWT do user) — RLS permite
async function fetchPendingFollowers(forAccount: string, limit: number): Promise<{ username: string }[]> {
  const accessToken = await getValidAccessToken();
  const url = `${SUPABASE_URL}/rest/v1/social_selling_known_followers?for_account=eq.${encodeURIComponent(forAccount)}&qualified=is.null&order=first_seen_at.asc&limit=${limit}&select=username`;
  const r = await fetch(url, { headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${accessToken}` } });
  if (!r.ok) throw new Error(`fetchPending ${r.status}`);
  return r.json();
}

// Enriquece perfis via chrome.scripting.executeScript — não depende do content script atual
// (injeta a função na tab IG e executa com os cookies do user logado)
async function enrichViaContentScript(usernames: string[]): Promise<any[]> {
  if (usernames.length === 0) return [];
  const tabs = await chrome.tabs.query({ url: ['*://*.instagram.com/*'] });
  let tab = tabs.find((t) => t.id != null && t.url?.includes('instagram.com'));

  // Se não tem aba IG aberta, abre uma em background (sem roubar foco) e espera carregar.
  // Isso é necessário pros cookies de auth ficarem disponíveis ao chrome.scripting.executeScript.
  if (!tab?.id) {
    await pushLog({ level: 'info', message: '🪟 enrich: abrindo aba do IG em background pra ter cookies de auth' });
    const newTab = await chrome.tabs.create({ url: 'https://www.instagram.com/', active: false });
    if (!newTab.id) {
      await pushLog({ level: 'error', message: '❌ enrich: não consegui abrir aba do IG' });
      return usernames.map((u) => ({ username: u, fetch_error: 'cant_open_ig_tab' }));
    }
    // Espera até o IG carregar (até 15s)
    try {
      await waitForTabComplete(newTab.id, 15000);
      // Pequeno buffer pro IG hidratar
      await new Promise((r) => setTimeout(r, 2000));
      tab = newTab;
      await pushLog({ level: 'success', message: '✅ enrich: aba IG aberta, prosseguindo' });
    } catch (e: any) {
      await pushLog({ level: 'error', message: `❌ enrich: aba IG não carregou: ${e?.message || e}` });
      return usernames.map((u) => ({ username: u, fetch_error: 'ig_tab_load_timeout' }));
    }
  }
  try {
    const [{ result }] = await chrome.scripting.executeScript({
      target: { tabId: tab.id! },
      world: 'ISOLATED', // tem cookies do origin instagram.com
      func: async (usernames: string[]) => {
        const out: any[] = [];
        for (let i = 0; i < usernames.length; i += 5) {
          const batch = usernames.slice(i, i + 5);
          const batchRes = await Promise.all(
            batch.map(async (u) => {
              try {
                const r = await fetch(
                  `https://www.instagram.com/api/v1/users/web_profile_info/?username=${encodeURIComponent(u)}`,
                  { headers: { 'X-IG-App-ID': '936619743392459' }, credentials: 'include' },
                );
                if (!r.ok) return { username: u, fetch_error: `http_${r.status}` };
                const j = await r.json();
                const usr = j?.data?.user;
                if (!usr) return { username: u, fetch_error: 'no_user' };
                return {
                  username: u,
                  instagram_user_id: usr.id || usr.pk || null,
                  full_name: usr.full_name || null,
                  biography: usr.biography || null,
                  follower_count: usr.edge_followed_by?.count ?? null,
                  following_count: usr.edge_follow?.count ?? null,
                  media_count: usr.edge_owner_to_timeline_media?.count ?? null,
                  is_verified: !!usr.is_verified,
                  is_private: !!usr.is_private,
                  is_business_account: !!usr.is_business_account,
                  profile_picture_url_hd: usr.profile_pic_url_hd || usr.profile_pic_url || null,
                  external_url: usr.external_url || null,
                  category: usr.category_name || null,
                };
              } catch (e: any) {
                return { username: u, fetch_error: e?.message || String(e) };
              }
            }),
          );
          out.push(...batchRes);
          if (i + 5 < usernames.length) await new Promise((r) => setTimeout(r, 800 + Math.random() * 1000));
        }
        return out;
      },
      args: [usernames],
    });
    return (result as any[]) || usernames.map((u) => ({ username: u, fetch_error: 'no_result' }));
  } catch (e: any) {
    return usernames.map((u) => ({ username: u, fetch_error: e?.message || String(e) }));
  }
}

async function processQualifyChunk() {
  if (await isPaused()) {
    return; // sistema pausado pelo usuário
  }
  // Lock distribuído via storage — evita 2 chunks concorrentes
  const lock = (await chrome.storage.local.get(QUALIFY_LOCK_KEY))[QUALIFY_LOCK_KEY] || 0;
  if (lock && Date.now() - lock < QUALIFY_LOCK_TIMEOUT) {
    return; // outro chunk tá rolando
  }
  await chrome.storage.local.set({ [QUALIFY_LOCK_KEY]: Date.now() });

  try {
    await pushLog({ level: 'info', message: '🔍 [chunk] entrou em processQualifyChunk' });
    const stored = await chrome.storage.local.get(QUALIFY_STATE_KEY);
    const state = stored[QUALIFY_STATE_KEY];
    if (!state) {
      await pushLog({ level: 'info', message: '⏸ qualify-chunk sem state — pulando' });
      return;
    }
    await pushLog({ level: 'info', message: `🔍 [chunk] state ok, automation=${state.automationId?.slice(0, 8)}` });
    const config = await getConfig();
    const { score_min, chunk_size } = await getQualifyLimits();

    // 1) Busca N pendentes do banco (N=chunk_size do CRM config)
    const pending = await fetchPendingFollowers(state.forAccount, chunk_size);
    if (pending.length === 0) {
      await pushLog({ level: 'success', message: `🎉 Qualificação concluída. Total: ${state.totals?.qualified || 0} qualificados, ${state.totals?.icp_fail || 0} fora ICP, ${state.totals?.lead_errors || 0} lead_err, ${state.totals?.sync_errors || 0} sync_err` });
      await chrome.storage.local.remove(QUALIFY_STATE_KEY);
      await chrome.alarms.clear(ALARM_QUALIFY);
      return;
    }
    const usernames = pending.map((p) => p.username);
    await pushLog({ level: 'info', message: `📥 ${pending.length} pendentes — enriquecendo via API interna do IG...` });

    // 2) Enriquece via content script (API interna do IG, com cookies do user)
    const enriched = await enrichViaContentScript(usernames);
    const ok = enriched.filter((e) => !e.fetch_error).length;
    const fail = enriched.length - ok;
    await pushLog({ level: ok > 0 ? 'success' : 'error', message: `🔎 enrich: ${ok} OK, ${fail} fail` });

    // 3) Chama edge function com followers_data RICO (process_pending=false)
    await pushLog({ level: 'info', message: '🔍 [chunk] chamando edge function com dados ricos...' });
    const r = await qualifyFollowers(config, {
      usernames,
      followers_data: enriched,
      automation_id: state.automationId,
      for_account: state.forAccount,
      score_min,
      process_pending: false,
    } as any);
    const summary = r.summary || {};
    const processed = summary.processed || 0;
    if (processed === 0) {
      await pushLog({ level: 'success', message: `🎉 Qualificação concluída. Total: ${state.totals?.qualified || 0} qualificados, ${state.totals?.icp_fail || 0} fora ICP, ${state.totals?.lead_errors || 0} lead_err, ${state.totals?.sync_errors || 0} sync_err` });
      await chrome.storage.local.remove(QUALIFY_STATE_KEY);
      await chrome.alarms.clear(ALARM_QUALIFY);
      return;
    }
    const totals = state.totals || { qualified: 0, icp_fail: 0, sync_errors: 0, lead_errors: 0 };
    totals.qualified += summary.qualified || 0;
    totals.icp_fail += summary.icp_fail || 0;
    totals.sync_errors += summary.sync_errors || 0;
    totals.lead_errors = (totals.lead_errors || 0) + (summary.lead_errors || 0);
    await chrome.storage.local.set({ [QUALIFY_STATE_KEY]: { ...state, totals } });
    await pushLog({ level: 'info', message: `🤖 chunk: +${summary.qualified || 0} qual / +${summary.icp_fail || 0} fail / +${summary.lead_errors || 0} lead_err / +${summary.sync_errors || 0} sync_err (total: ${totals.qualified}/${totals.icp_fail}/${totals.sync_errors})` });
    // Lock liberado no finally. Alarm é PERIÓDICO — não precisa reagendar.
    await chrome.storage.local.remove(QUALIFY_LOCK_KEY);
  } catch (e: any) {
    await pushLog({ level: 'error', message: `qualify chunk erro: ${e.message}` });
    await chrome.storage.local.remove(QUALIFY_LOCK_KEY);
  } finally {
    // Garantia adicional: libera lock mesmo em error não-capturado
    await chrome.storage.local.remove(QUALIFY_LOCK_KEY).catch(() => {});
  }
}

async function startBackgroundQualification(automationId: string, forAccount: string) {
  try {
    await pushLog({ level: 'info', message: `▶ start: automation=${automationId.slice(0, 8)} account=${forAccount}` });
    await chrome.storage.local.set({
      [QUALIFY_STATE_KEY]: { automationId, forAccount, startedAt: Date.now(), totals: { qualified: 0, icp_fail: 0, sync_errors: 0, lead_errors: 0 } },
    });
    await pushLog({ level: 'info', message: '✓ state salvo em chrome.storage' });
    // Alarm PERIÓDICO — sobrevive a morte do SW (Chrome reagenda automaticamente)
    await chrome.alarms.create(ALARM_QUALIFY, { delayInMinutes: 0.5, periodInMinutes: 1 });
    await pushLog({ level: 'info', message: '✓ alarm periódico agendado (a cada 1min)' });
    // Dispara primeiro chunk IMEDIATAMENTE também
    await pushLog({ level: 'info', message: '⚡ Disparando primeiro chunk imediato...' });
    await processQualifyChunk();
  } catch (e: any) {
    await pushLog({ level: 'error', message: `❌ start erro: ${e.message || e}` });
    console.error('[IAP-SS] startBackgroundQualification error:', e);
  }
}

// ------------------------------------------------------------
// Job principal — busca plano, monta fila, executa auto, alerta o resto
// ------------------------------------------------------------

async function runDailyJob(opts: { force?: boolean; enrollmentIds?: string[] } = {}) {
  if (await isPaused()) { await pushLog({ level: 'info', message: '⏸ Sistema pausado — runDailyJob abortado' }); return; }
  const force = opts.force === true;
  const enrollmentIds = opts.enrollmentIds && opts.enrollmentIds.length > 0 ? opts.enrollmentIds : undefined;
  console.log('[IAP-SS] Run daily job', new Date().toISOString(), 'force=', force, 'selected=', enrollmentIds?.length || 'all');
  await pushLog({
    level: 'step',
    message: enrollmentIds
      ? `🎯 Rodando ${enrollmentIds.length} selecionado${enrollmentIds.length > 1 ? 's' : ''}`
      : force ? '🚀 Execução manual (ignora horário)' : '🚀 Iniciando rodada do dia',
  });
  const config = await getConfig();

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    notify('Configuração pendente', 'Configure URL e token do CRM nas opções da extensão.');
    await pushLog({ level: 'error', message: 'Configuração pendente — URL/token do CRM' });
    return;
  }

  let plan: PlanItem[] = [];
  try {
    await pushLog({ level: 'info', message: '📡 Buscando plano do dia…' });
    const res = await fetchPlanDay(config, force, enrollmentIds);
    if (!res.ok) {
      console.log('[IAP-SS] Plano vazio:', res.reason);
      await pushLog({ level: 'info', message: `Plano vazio: ${res.reason || 'no items'}` });
      return;
    }
    plan = res.plan || [];
    await pushLog({ level: 'info', message: `📋 ${plan.length} ações no plano` });
  } catch (e: any) {
    console.error('[IAP-SS] fetchPlanDay error:', e);
    await pushLog({ level: 'error', message: `Erro ao buscar plano: ${e.message}` });
    notify('Erro ao buscar plano', e.message || 'Falha de rede');
    return;
  }

  if (plan.length === 0) return;

  // Merge com fila existente (não duplica)
  const existing = await getQueue();
  const existingKeys = new Set(existing.map((q) => `${q.enrollment_id}|${q.action_type}|${q.target_url}`));
  const newItems: QueueItem[] = [];

  for (const item of plan) {
    const key = `${item.enrollment_id}|${item.action_type}|${item.target_url}`;
    if (existingKeys.has(key)) continue;
    // v20: action_mode vem do CRM (cadência configurada). Fallback approve pra textos.
    const mode = item.action_mode || (['comentar_post', 'enviar_dm', 'responder_story', 'followup_story'].includes(item.action_type) ? 'approve' : 'auto');
    // responder_story NÃO gera msg aqui — gera só no execute, depois de abrir story e capturar conteúdo real.
    // Sem isso, story_content vai vazio e a IA aluciana ("Story não disponível pra eu ver").
    const needsMessage = ['comentar_post', 'enviar_dm', 'followup_story'].includes(item.action_type);

    let generated_message: string | undefined;
    let skipReason: string | undefined;
    if (needsMessage) {
      try {
        await pushLog({ level: 'info', message: `🤖 Gerando msg IA pra @${item.instagram_username}` });
        const r = await generateMessage(config, {
          lead_id: item.lead_id,
          action_type: item.action_type,
          post_url: item.target_url,
        });
        if ((r as any).skip) {
          skipReason = (r as any).reason || 'skip';
          await pushLog({ level: 'info', message: `⏭ Pulado @${item.instagram_username} ${item.action_type}: ${skipReason}` });
        } else {
          generated_message = r.message;
          await pushLog({ level: 'info', message: `   "${(r.message || '').slice(0, 60)}…"` });
        }
      } catch (e: any) {
        console.warn('[IAP-SS] generateMessage falhou:', e);
        await pushLog({ level: 'error', message: `Erro IA: ${e.message || e}` });
      }
    }

    // Se IA classificou como pessoal → pula direto, registra log no banco
    if (skipReason) {
      try {
        await logAction(config, {
          enrollment_id: item.enrollment_id,
          lead_id: item.lead_id,
          action_type: item.action_type,
          status: 'skipped',
          day_number: item.day,
          instagram_target: item.target_url,
          error_message: skipReason,
          metadata: { skipped_by: 'ai_classifier', reason: skipReason },
        });
      } catch {}
      continue; // não entra na fila local
    }

    newItems.push({
      ...item,
      local_id: uid(),
      state: mode === 'auto' ? 'auto_ready' : 'pending_approval',
      generated_message,
      created_at: Date.now(),
    });
  }

  const updated = [...existing, ...newItems];
  await setQueue(updated);

  // Dispara worker (serializado — não roda em paralelo)
  runWorker().catch((e) => console.error('[IAP-SS] worker error:', e));

  await updateBadge();

  const pending = (await getQueue()).filter((q) => q.state === 'pending_approval').length;
  if (pending > 0 && config.notifyOnApprovalNeeded) {
    notify(
      `${pending} ação${pending > 1 ? 'ões' : ''} pra revisar`,
      'Abra a extensão pra aprovar comentários e DMs.',
    );
  }
}

// ------------------------------------------------------------
// Executar 1 item — orquestra Playwright-like via content script
// ------------------------------------------------------------

// ════════ Serialização: lock em storage (sobrevive service worker dormir) ════════
// Service worker do Manifest V3 dorme após ~30s. setTimeout longos morrem junto.
// Por isso usamos chrome.alarms pra acordar pra próxima ação + storage como lock.
const WORKER_LOCK_KEY = 'iap_ss_worker_lock';
const WORKER_LOCK_TIMEOUT_MS = 5 * 60 * 1000; // 5min — se travou, libera

async function recoverZombieExecuting() {
  // Recovery: items em 'executing' há > 2min são zumbi (service worker morreu).
  // Marca como failed e move pra history.
  const queue = await getQueue();
  const now = Date.now();
  const ZOMBIE_MS = 2 * 60 * 1000;
  const zombies = queue.filter((q) => q.state === 'executing' && (!q.executing_started_at || now - q.executing_started_at > ZOMBIE_MS));
  if (zombies.length === 0) return;
  console.log(`[IAP-SS] Recovery: ${zombies.length} items zumbi`);
  for (const z of zombies) {
    await pushLog({ level: 'error', message: `🧟 Recuperado item travado: ${z.action_type} @${z.instagram_username}` });
    await pushHistory({ ...z, state: 'failed', executed_at: now, error_message: 'zombie_recovery (service worker morreu)' });
    // Loga no banco também
    try {
      const config = await getConfig();
      await logAction(config, {
        enrollment_id: z.enrollment_id,
        lead_id: z.lead_id,
        action_type: z.action_type,
        status: 'failed',
        day_number: z.day,
        instagram_target: z.target_url,
        error_message: 'zombie_recovery',
        metadata: { recovered: true },
      });
    } catch {}
  }
  const cleaned = queue.filter((q) => !zombies.some((z) => z.local_id === q.local_id));
  await setQueue(cleaned);
  await updateBadge();
}

async function runWorker() {
  if (await isPaused()) return;
  // Recovery de items zumbi ANTES de pegar o lock
  await recoverZombieExecuting();

  // Lock via storage (não em memória — service worker dorme e perde memória)
  const r = await chrome.storage.local.get(WORKER_LOCK_KEY);
  const lockedAt = r[WORKER_LOCK_KEY] || 0;
  if (lockedAt && Date.now() - lockedAt < WORKER_LOCK_TIMEOUT_MS) {
    console.log('[IAP-SS] worker lock ativo, pulando');
    return;
  }
  await chrome.storage.local.set({ [WORKER_LOCK_KEY]: Date.now() });

  try {
    const queue = await getQueue();
    const next = queue.find((q) => q.state === 'auto_ready');
    if (!next) {
      const stillPending = queue.find((q) => q.state === 'pending_approval');
      if (stillPending) {
        await pushLog({ level: 'info', message: `⏸ Aguardando aprovação: ${stillPending.action_type} @${stillPending.instagram_username}` });
      }
      await chrome.storage.local.set({ iap_ss_idle_until: 0, iap_ss_idle_next: null });
      return;
    }

    // Executa UMA ação por chamada (evita setTimeout longos)
    await executeQueueItem(next);

    // Tem mais auto_ready pra rodar?
    const after = await getQueue();
    const upcoming = after.find((q) => q.state === 'auto_ready');
    if (!upcoming) {
      await chrome.storage.local.set({ iap_ss_idle_until: 0, iap_ss_idle_next: null });
      return;
    }

    // Agenda alarm pra acordar e rodar a próxima após o delay humanizado.
    // ⚠ Chrome MV3 tem mínimo de 30s pra chrome.alarms (delays menores não disparam).
    // Clampa entre 30s e 300s pra garantir que o SW acorde.
    const rawDelay = next.delay_after_seconds || 60;
    const delaySec = Math.max(30, Math.min(rawDelay, 300));
    const idleUntil = Date.now() + delaySec * 1000;
    await chrome.storage.local.set({ iap_ss_idle_until: idleUntil, iap_ss_idle_next: upcoming.local_id });
    if (rawDelay < 30) {
      await pushLog({ level: 'info', message: `⚠ delay ${rawDelay}s ajustado pra 30s (mínimo MV3)` });
    }
    await pushLog({
      level: 'info',
      message: `⏳ Aguardando ${delaySec}s antes da próxima (${upcoming.action_type} @${upcoming.instagram_username})`,
    });
    // Usa delayInMinutes (mais confiável que `when:` em MV3)
    await chrome.alarms.create(ALARM_TICK, { delayInMinutes: delaySec / 60 });
  } finally {
    await chrome.storage.local.remove(WORKER_LOCK_KEY);
  }
}

async function executeQueueItem(item: QueueItem) {
  const config = await getConfig();
  await updateQueueItem(item.local_id, { state: 'executing', executing_started_at: Date.now() });
  await updateBadge();

  const message = item.edited_message || item.generated_message;
  const lbl = `${item.action_type} @${item.instagram_username}`;
  await pushLog({ level: 'step', message: `▶ Iniciando ${lbl}` });

  // Determina URL a abrir
  let targetUrl = item.target_url;
  if (!targetUrl) {
    targetUrl = `https://www.instagram.com/${item.instagram_username}/`;
  }

  let result: { success: boolean; error?: string } = { success: false };
  // Declarado FORA do try porque o logAction lá embaixo referencia (precisa estar no escopo).
  let finalMessage = message;

  try {
    await pushLog({ level: 'info', message: `🌐 Abrindo ${targetUrl}` });
    const tab = await chrome.tabs.create({ url: targetUrl, active: false });
    if (!tab.id) throw new Error('Não conseguiu criar aba');

    await waitForTabComplete(tab.id, 15000);
    await pushLog({ level: 'info', message: `📖 Página carregada — executando` });

    // Pequeno delay extra pro IG terminar de hidratar
    await new Promise((r) => setTimeout(r, 1500));

    // responder_story: late-binding da mensagem.
    // Abre o story, captura o conteúdo visível (legenda/sticker/mention) e
    // SÓ AÍ chama a IA pra gerar a resposta contextualizada.
    if (item.action_type === 'responder_story') {
      await pushLog({ level: 'step', message: `🎬 Abrindo story de @${item.instagram_username} pra capturar contexto` });
      const capRes: any = await chrome.tabs.sendMessage(tab.id, {
        kind: 'CAPTURE_STORY_CONTENT',
        username: item.instagram_username,
      } as ExtMessage).catch((e) => ({ ok: false, error: String(e) }));

      if (!capRes?.ok) {
        // Sem story ativo (ou erro) → skip a ação (não manda msg cega)
        result = { success: false, error: capRes?.error || 'capture_story_failed' };
        await chrome.tabs.remove(tab.id).catch(() => {});
        if (result.success) {
          await pushLog({ level: 'success', message: `✅ ${lbl} executado` });
        } else {
          await pushLog({ level: 'error', message: `❌ ${lbl}: ${result.error}` });
        }
        try {
          await logAction(config, {
            enrollment_id: item.enrollment_id, lead_id: item.lead_id, action_type: item.action_type,
            status: 'skipped', day_number: item.day, instagram_target: item.target_url,
            error_message: result.error,
            metadata: { skipped_by: 'story_capture', reason: result.error },
          });
        } catch {}
        const finalItem: QueueItem = { ...item, state: 'failed', executed_at: Date.now(), error_message: result.error };
        await pushHistory(finalItem);
        const queue = await getQueue();
        await setQueue(queue.filter((q) => q.local_id !== item.local_id));
        await updateBadge();
        return;
      }

      const storyContent = capRes.story_content || '';
      await pushLog({ level: 'info', message: `📝 Story texto (${storyContent.length} chars): "${storyContent.slice(0, 60)}..."` });

      // Vision: tira screenshot do story pra IA ver a imagem real
      // (story em geral é foto/vídeo sem texto sobreposto — sem isso a IA não tem o que dizer)
      // captureVisibleTab PRECISA da aba ativa → ativa temporariamente e restaura.
      let storyImage: string | undefined;
      try {
        // Descobre qual aba estava ativa pra restaurar depois
        const [prevActive] = await chrome.tabs.query({ active: true, windowId: tab.windowId });
        // Ativa a aba do IG (story tá pausado, sem auto-advance — ok roubar foco por 500ms)
        await chrome.tabs.update(tab.id, { active: true });
        await new Promise((r) => setTimeout(r, 350));
        const dataUrl = await chrome.tabs.captureVisibleTab(tab.windowId!, { format: 'jpeg', quality: 70 });
        // Restaura aba anterior se existia
        if (prevActive?.id && prevActive.id !== tab.id) {
          await chrome.tabs.update(prevActive.id, { active: true }).catch(() => {});
        }
        storyImage = dataUrl?.split(',')[1] || undefined;
        if (storyImage) {
          await pushLog({ level: 'info', message: `📸 Screenshot capturado (${Math.round(storyImage.length / 1024)} KB)` });
        }
      } catch (e: any) {
        await pushLog({ level: 'error', message: `⚠ Screenshot falhou (segue sem vision): ${e?.message || e}` });
      }

      // Agora SIM gera a mensagem com contexto real (texto + imagem)
      try {
        const gen = await generateMessage(config, {
          lead_id: item.lead_id,
          action_type: 'responder_story',
          story_content: storyContent,
          story_image: storyImage,
        });
        if ((gen as any).skip) {
          // IA ainda achou que devia pular (provavelmente story_content < 3 chars)
          result = { success: false, error: (gen as any).reason || 'ai_skipped' };
          await chrome.tabs.remove(tab.id).catch(() => {});
          await pushLog({ level: 'info', message: `⏭ IA pulou: ${result.error}` });
          try {
            await logAction(config, {
              enrollment_id: item.enrollment_id, lead_id: item.lead_id, action_type: item.action_type,
              status: 'skipped', day_number: item.day, instagram_target: item.target_url,
              error_message: result.error,
              metadata: { skipped_by: 'ai_after_capture', story_content_length: storyContent.length },
            });
          } catch {}
          const finalItem: QueueItem = { ...item, state: 'failed', executed_at: Date.now(), error_message: result.error };
          await pushHistory(finalItem);
          const queue = await getQueue();
          await setQueue(queue.filter((q) => q.local_id !== item.local_id));
          await updateBadge();
          return;
        }
        finalMessage = gen.message;
        await pushLog({ level: 'info', message: `🤖 Msg gerada: "${(finalMessage || '').slice(0, 80)}..."` });
      } catch (e: any) {
        result = { success: false, error: `generate_failed: ${e.message || e}` };
        await chrome.tabs.remove(tab.id).catch(() => {});
        await pushLog({ level: 'error', message: `❌ Erro IA: ${result.error}` });
        const finalItem: QueueItem = { ...item, state: 'failed', executed_at: Date.now(), error_message: result.error };
        await pushHistory(finalItem);
        const queue = await getQueue();
        await setQueue(queue.filter((q) => q.local_id !== item.local_id));
        await updateBadge();
        return;
      }
    }

    const response = await chrome.tabs.sendMessage(tab.id, {
      kind: 'EXECUTE_ACTION',
      item: { ...item, edited_message: finalMessage },
    } as ExtMessage).catch((e) => ({ kind: 'ACTION_RESULT', success: false, error: String(e) }));

    if (response && response.kind === 'ACTION_RESULT') {
      result = { success: response.success, error: response.error };
    } else {
      result = { success: false, error: 'No response from content script' };
    }

    await chrome.tabs.remove(tab.id).catch(() => {});
  } catch (e: any) {
    result = { success: false, error: e.message || String(e) };
  }

  if (result.success) {
    await pushLog({ level: 'success', message: `✅ ${lbl} executado` });
  } else {
    await pushLog({ level: 'error', message: `❌ ${lbl}: ${result.error}` });
  }

  // Loga no banco
  try {
    await logAction(config, {
      enrollment_id: item.enrollment_id,
      lead_id: item.lead_id,
      action_type: item.action_type,
      status: result.success ? 'success' : 'failed',
      day_number: item.day,
      content: finalMessage,
      instagram_target: item.target_url,
      error_message: result.error,
      metadata: { executed_via: 'extension', extension_version: chrome.runtime.getManifest().version },
    });
  } catch (e: any) {
    console.warn('[IAP-SS] logAction falhou:', e);
    // Antes era silencioso — agora aparece no painel de logs do popup
    await pushLog({ level: 'error', message: `⚠ logAction falhou (não registrou no CRM): ${e?.message || e}` });
  }

  // Atualiza fila + histórico
  const finalItem: QueueItem = {
    ...item,
    state: result.success ? 'success' : 'failed',
    executed_at: Date.now(),
    error_message: result.error,
  };
  await pushHistory(finalItem);
  // Remove da fila
  const queue = await getQueue();
  await setQueue(queue.filter((q) => q.local_id !== item.local_id));

  // Delay humanizado é controlado pelo runWorker (não aqui)
  await updateBadge();
}

// ============================================================
// Captura de novos seguidores: abre IG, scroll, qualify em batch
// ============================================================
async function runCaptureNewFollowers(opts: {
  targetUsername: string;
  limit: number;
  automationId: string;
  forAccount: string;
}) {
  const config = await getConfig();
  await pushLog({ level: 'step', message: `📥 Capturando seguidores de @${opts.targetUsername} (até ${opts.limit})` });

  // Busca @s já processados (qualified true/false ou null = pendente) pra captura PARAR cedo
  // quando achar um conhecido. IG lista os mais recentes primeiro, então hit_known = "chegou onde
  // já parei na última vez" → não desperdiça scroll/enrich em quem já foi.
  let knownUsernames: string[] = [];
  try {
    const accessToken = await getValidAccessToken();
    const r = await fetch(
      `${SUPABASE_URL}/rest/v1/social_selling_known_followers?for_account=eq.${encodeURIComponent(opts.forAccount)}&select=username&limit=5000`,
      { headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${accessToken}` } },
    );
    if (r.ok) {
      const rows = await r.json();
      knownUsernames = rows.map((x: any) => String(x.username).toLowerCase());
      await pushLog({ level: 'info', message: `🧠 ${knownUsernames.length} @s já processados antes — captura vai parar quando bater num` });
    }
  } catch (e: any) {
    await pushLog({ level: 'info', message: `⚠ falhou buscar known_followers (segue sem stop_on_known): ${e?.message || e}` });
  }

  // Abre aba do IG no perfil do target
  const tab = await chrome.tabs.create({ url: `https://www.instagram.com/${opts.targetUsername}/`, active: true });
  if (!tab.id) {
    await pushLog({ level: 'error', message: '❌ Não conseguiu abrir aba IG' });
    return;
  }
  await waitForTabComplete(tab.id, 20000).catch(() => {});
  await new Promise((r) => setTimeout(r, 2000));

  // Dispara captura no content script — tenta API privada primeiro (ordem garantida, sem virtualização)
  let captureRes: any = { success: false };
  try {
    await pushLog({ level: 'step', message: `🚀 Capturando via API privada do IG...` });
    captureRes = await chrome.tabs.sendMessage(tab.id, {
      kind: 'CAPTURE_FOLLOWERS_API',
      target_username: opts.targetUsername,
      limit: opts.limit,
      stop_on_known: knownUsernames,
    });
  } catch (e: any) {
    await pushLog({ level: 'error', message: `❌ erro content script (API): ${e.message}` });
  }

  // Fallback: se API falhou (rate-limit, bloqueio), tenta scroll do modal (menos preciso mas resiliente)
  if (!captureRes?.success) {
    await pushLog({ level: 'info', message: `⚠ API falhou (${captureRes?.reason || 'unknown'}) — tentando fallback scroll do modal` });
    try {
      captureRes = await chrome.tabs.sendMessage(tab.id, {
        kind: 'CAPTURE_FOLLOWERS',
        target_username: opts.targetUsername,
        limit: opts.limit,
        stop_on_known: knownUsernames,
      });
    } catch (e: any) {
      await pushLog({ level: 'error', message: `❌ erro content script (scroll fallback): ${e.message}` });
    }
  }

  await chrome.tabs.remove(tab.id).catch(() => {});

  if (!captureRes?.success) {
    await pushLog({ level: 'error', message: `❌ Captura falhou: ${captureRes?.reason || 'unknown'}` });
    return;
  }

  await pushLog({ level: 'success', message: `✅ Coletados ${captureRes.usernames.length} usernames (${captureRes.iterations} scrolls, motivo: ${captureRes.reason})` });

  if (captureRes.usernames.length === 0) {
    await pushLog({ level: 'info', message: '📭 Nenhum novo pra qualificar.' });
    return;
  }

  // SEGURANÇA: salva TODOS no cache antes de iniciar qualify
  // Se SW morrer no meio, lista persiste no banco e botão "Continuar pendentes" processa
  await pushLog({ level: 'info', message: `💾 Salvando ${captureRes.usernames.length} no cache antes de qualificar...` });
  try {
    const r = await qualifyFollowers(config, {
      usernames: captureRes.usernames,
      automation_id: opts.automationId,
      for_account: opts.forAccount,
      score_min: 60,
      followers_data: captureRes.followers_data,
      cache_only: true, // só upsert, sem qualify
    } as any);
    await pushLog({ level: 'info', message: `   ${r.summary?.cached || 0} novos no cache` });
  } catch (e: any) {
    await pushLog({ level: 'error', message: `cache erro: ${e.message}` });
  }

  // Inicia qualificação em chunks via chrome.alarms (SW pode dormir entre chunks)
  await pushLog({ level: 'step', message: `🚀 Iniciando qualificação em background — pode demorar uns 10min, pode fechar painel` });
  await startBackgroundQualification(opts.automationId, opts.forAccount);
}

// Continua qualificação de pendentes (qualified=null no banco) sem capturar de novo
async function runContinuePending(opts: { automationId: string; forAccount: string }) {
  await pushLog({ level: 'step', message: `🔄 Continuando qualificação de pendentes em background` });
  await startBackgroundQualification(opts.automationId, opts.forAccount);
}

function waitForTabComplete(tabId: number, timeoutMs: number): Promise<void> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      chrome.tabs.onUpdated.removeListener(listener);
      reject(new Error('Tab load timeout'));
    }, timeoutMs);
    const listener = (id: number, info: chrome.tabs.TabChangeInfo) => {
      if (id === tabId && info.status === 'complete') {
        clearTimeout(timer);
        chrome.tabs.onUpdated.removeListener(listener);
        // small extra grace
        setTimeout(resolve, 1500);
      }
    };
    chrome.tabs.onUpdated.addListener(listener);
  });
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

// ------------------------------------------------------------
// Notifications & Badge
// ------------------------------------------------------------

function notify(title: string, message: string) {
  chrome.notifications.create({
    type: 'basic',
    iconUrl: chrome.runtime.getURL('public/icons/icon-128.png'),
    title: `📷 ${title}`,
    message,
    priority: 1,
  });
}

async function updateBadge() {
  const queue = await getQueue();
  const pending = queue.filter((q) => q.state === 'pending_approval').length;
  const executing = queue.filter((q) => q.state === 'executing').length;
  const text = pending > 0 ? String(pending) : executing > 0 ? '⋯' : '';
  await chrome.action.setBadgeText({ text });
  if (pending > 0) {
    await chrome.action.setBadgeBackgroundColor({ color: '#c8952e' }); // amber
  } else if (executing > 0) {
    await chrome.action.setBadgeBackgroundColor({ color: '#3a8a5c' }); // moss/green
  }
}

// ------------------------------------------------------------
// Mensagens do popup/options
// ------------------------------------------------------------

chrome.runtime.onMessage.addListener((msg: ExtMessage, _sender, sendResponse) => {
  (async () => {
    try {
      if (msg.kind === 'GET_QUEUE') {
        // Recovery automático ao abrir painel (qualquer GET_QUEUE)
        await recoverZombieExecuting();
        const queue = await getQueue();
        sendResponse({ kind: 'QUEUE_RESPONSE', queue });
      } else if (msg.kind === 'GET_CONFIG') {
        const config = await getConfig();
        sendResponse({ kind: 'CONFIG_RESPONSE', config });
      } else if (msg.kind === 'SAVE_CONFIG') {
        const { setConfig } = await import('../shared/storage');
        await setConfig(msg.config);
        await scheduleAlarm();
        sendResponse({ ok: true });
      } else if (msg.kind === 'APPROVE_ITEM') {
        const queue = await getQueue();
        const item = queue.find((q) => q.local_id === msg.local_id);
        if (!item) return sendResponse({ ok: false, error: 'not_found' });
        const updated: QueueItem = { ...item, edited_message: msg.edited_message ?? item.generated_message, state: 'auto_ready' };
        await updateQueueItem(item.local_id, updated);
        // Marca como auto_ready e deixa o worker processar (serializado)
        runWorker().catch((e) => console.error('[IAP-SS] worker error:', e));
        sendResponse({ ok: true });
      } else if ((msg as any).kind === 'REJECT_TARGET_AND_RETRY') {
        // Marca o target como skipped no banco (pra plan-day filtrar) + remove da fila + dispara nova rodada SÓ pro enrollment
        const localId = (msg as any).local_id;
        const queue = await getQueue();
        const item = queue.find((q) => q.local_id === localId);
        if (!item) return sendResponse({ ok: false, error: 'not_found' });
        const config = await getConfig();
        try {
          await logAction(config, {
            enrollment_id: item.enrollment_id,
            lead_id: item.lead_id,
            action_type: item.action_type,
            status: 'skipped',
            day_number: item.day,
            instagram_target: item.target_url,
            error_message: 'user_rejected_post',
            metadata: { rejected_by: 'user' },
          });
        } catch (e) { console.warn('logAction skipped falhou', e); }
        await setQueue(queue.filter((q) => q.local_id !== localId));
        await pushLog({ level: 'info', message: `🔄 Buscando outro post pra @${item.instagram_username}…` });
        runDailyJob({ force: true, enrollmentIds: [item.enrollment_id] }).catch((e) => console.error(e));
        sendResponse({ ok: true });
      } else if (msg.kind === 'SKIP_ITEM') {
        const queue = await getQueue();
        const item = queue.find((q) => q.local_id === msg.local_id);
        if (item) {
          await pushHistory({ ...item, state: 'skipped', executed_at: Date.now() });
          await setQueue(queue.filter((q) => q.local_id !== msg.local_id));
        }
        await updateBadge();
        sendResponse({ ok: true });
      } else if (msg.kind === 'REGENERATE_MESSAGE') {
        const config = await getConfig();
        const queue = await getQueue();
        const item = queue.find((q) => q.local_id === msg.local_id);
        if (!item) return sendResponse({ ok: false, error: 'not_found' });
        const r = await generateMessage(config, {
          lead_id: item.lead_id,
          action_type: item.action_type,
          post_url: item.target_url,
        });
        await updateQueueItem(item.local_id, { generated_message: r.message, edited_message: undefined });
        sendResponse({ ok: true, message: r.message });
      } else if ((msg as any).kind === 'CLEAR_LOCAL_HISTORY') {
        await chrome.storage.local.remove(['iap_ss_history', 'iap_ss_queue', 'iap_ss_live_log', 'iap_ss_idle_until', 'iap_ss_idle_next']);
        await updateBadge();
        sendResponse({ ok: true });
      } else if (msg.kind === 'RUN_NOW') {
        const cfg = await getConfig();
        const enrollmentIds = (msg as any).enrollment_ids as string[] | undefined;
        // "Executar agora" sempre força ignorar horário comercial (intenção do user manual)
        runDailyJob({ force: true, enrollmentIds });
        sendResponse({ ok: true });
      } else if ((msg as any).kind === 'CAPTURE_NEW_FOLLOWERS') {
        const m = msg as any;
        runCaptureNewFollowers({
          targetUsername: m.target_username || '',
          limit: m.limit || 200,
          automationId: m.automation_id,
          forAccount: m.for_account || m.target_username || '',
        }).catch((e) => pushLog({ level: 'error', message: `❌ captura erro: ${e.message}` }));
        sendResponse({ ok: true });
      } else if ((msg as any).kind === 'CONTINUE_PENDING_QUALIFICATION') {
        const m = msg as any;
        runContinuePending({
          automationId: m.automation_id,
          forAccount: m.for_account || '',
        }).catch((e) => pushLog({ level: 'error', message: `❌ continue erro: ${e.message}` }));
        sendResponse({ ok: true });
      } else if ((msg as any).kind === 'CONTENT_LOG') {
        const m: any = msg;
        await pushLog({ level: m.level || 'info', message: String(m.message || ''), context: m.context });
        sendResponse({ ok: true });
      } else if ((msg as any).kind === 'PAUSE_ALL') {
        await chrome.storage.local.set({ [PAUSED_KEY]: true });
        await pushLog({ level: 'step', message: '🛑 SISTEMA PAUSADO — fechando tabs IG ativas' });
        // Fecha tabs do Instagram abertas pela extensão (em background)
        try {
          const tabs = await chrome.tabs.query({ url: ['*://*.instagram.com/*', '*://instagram.com/*'] });
          for (const t of tabs) {
            if (t.id != null && t.active === false) {
              await chrome.tabs.remove(t.id).catch(() => {});
            }
          }
        } catch {}
        // Marca items 'executing' como 'pending_approval' pra retomada manual
        const q = await getQueue();
        const paused = q.map((it) => (it.state === 'executing' || it.state === 'auto_ready') ? { ...it, state: 'pending_approval' as const } : it);
        await setQueue(paused);
        await updateBadge();
        sendResponse({ ok: true });
      } else if ((msg as any).kind === 'RESUME_ALL') {
        await chrome.storage.local.remove(PAUSED_KEY);
        await pushLog({ level: 'success', message: '▶ Sistema retomado' });
        sendResponse({ ok: true });
      } else if ((msg as any).kind === 'GET_PAUSED') {
        const paused = await isPaused();
        sendResponse({ ok: true, paused });
      }
    } catch (e: any) {
      sendResponse({ ok: false, error: e.message || String(e) });
    }
  })();
  return true; // async
});
