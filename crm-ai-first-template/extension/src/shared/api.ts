// ============================================================
// API client — fala com Supabase (edge functions)
// ============================================================
import { ExtensionConfig, PlanItem, ActionType } from './types';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './env';
import { getValidAccessToken } from './auth';

async function fnPost(config: ExtensionConfig, fnName: string, body: any): Promise<any> {
  const url = `${SUPABASE_URL}/functions/v1/${fnName}`;
  const accessToken = await getValidAccessToken();
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${fnName} ${res.status}: ${text}`);
  }
  return res.json();
}

export async function fetchPlanDay(config: ExtensionConfig, skipBudget = false, enrollmentIds?: string[]): Promise<{ ok: boolean; plan: PlanItem[]; reason?: string; counts?: any }> {
  const body: any = { skip_budget: skipBudget };
  if (enrollmentIds && enrollmentIds.length > 0) body.enrollment_ids = enrollmentIds;
  return fnPost(config, 'social-selling-plan-day', body);
}

export async function logAction(config: ExtensionConfig, params: {
  enrollment_id?: string;
  lead_id: string;
  action_type: ActionType;
  status: 'success' | 'failed' | 'skipped';
  day_number?: number;
  content?: string;
  instagram_target?: string;
  error_message?: string;
  metadata?: any;
}): Promise<any> {
  return fnPost(config, 'log-social-selling-action', params);
}

export async function generateMessage(config: ExtensionConfig, params: {
  lead_id: string;
  action_type: ActionType;
  post_caption?: string;
  post_url?: string;
  story_content?: string;
  story_image?: string;  // base64 (sem prefixo data:image/...) — pra Claude Vision
}): Promise<{ message: string; context_used?: any; skip?: boolean; reason?: string }> {
  return fnPost(config, 'generate-social-selling-message', params);
}

export async function markReply(config: ExtensionConfig, params: {
  lead_id?: string;
  instagram_username?: string;
  message_content?: string;
  message_type?: string;
}): Promise<any> {
  return fnPost(config, 'social-selling-mark-reply', params);
}

/** Lista enrollments ATIVOS (incl. com next_action_at futuro) — pra preview no popup */
export async function listActiveEnrollments(config: ExtensionConfig): Promise<any[]> {
  try {
    const r = await fnPost(config, 'get-social-selling-enrollments', {});
    return r.enrollments || [];
  } catch (e) {
    console.warn('[IAP-SS] listActiveEnrollments error:', e);
    return [];
  }
}

// ============================================================
// Config API — exige login Supabase Auth (verify_jwt=true na edge fn)
// ============================================================

async function callConfigApi(config: ExtensionConfig, body: any): Promise<any> {
  const accessToken = await getValidAccessToken();
  const r = await fetch(`${SUPABASE_URL}/functions/v1/social-selling-config-api`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(body),
  });
  const data = await r.json();
  if (!r.ok) throw new Error(data?.error || `config-api ${r.status}`);
  return data;
}

export async function readConfigKey(config: ExtensionConfig, key: string): Promise<any> {
  const r = await callConfigApi(config, { action: 'get_config', key });
  return r.value;
}

export async function writeConfigKey(config: ExtensionConfig, key: string, value: any): Promise<void> {
  await callConfigApi(config, { action: 'set_config', key, value });
}

export async function listAutomations(config: ExtensionConfig): Promise<any[]> {
  const r = await callConfigApi(config, { action: 'list_automations' });
  return r.automations || [];
}

export async function updateAutomation(config: ExtensionConfig, id: string, patch: Record<string, any>): Promise<void> {
  await callConfigApi(config, { action: 'update_automation', id, patch });
}

export async function createAutomation(config: ExtensionConfig, automation: { name: string; emoji?: string; cadence_config: any }): Promise<{ id: string }> {
  const r = await callConfigApi(config, { action: 'create_automation', automation });
  return r;
}

export async function listPipelines(config: ExtensionConfig): Promise<any[]> {
  const r = await callConfigApi(config, { action: 'list_pipelines' });
  return r.pipelines || [];
}

/** Manda lista de @s pro qualify-followers (chunked) com timeout de 90s */
export async function qualifyFollowers(
  config: ExtensionConfig,
  body: { usernames: string[]; automation_id: string; for_account?: string; score_min?: number; followers_data?: any[]; cache_only?: boolean; process_pending?: boolean; chunk_limit?: number },
): Promise<{ success: boolean; summary: any; results?: any[] }> {
  const accessToken = await getValidAccessToken();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort('timeout 90s'), 90_000);
  try {
    const r = await fetch(`${SUPABASE_URL}/functions/v1/social-selling-qualify-followers`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    clearTimeout(timer);
    const data = await r.json();
    if (!r.ok) throw new Error(data?.error || `qualify-followers ${r.status}`);
    return data;
  } catch (e: any) {
    clearTimeout(timer);
    if (e.name === 'AbortError') throw new Error('fetch timeout 90s');
    throw e;
  }
}

/** Busca interactions de hoje via config-api autenticada — substitui o cache local de history */
export async function listTodayInteractions(config: ExtensionConfig): Promise<any[]> {
  const r = await callConfigApi(config, { action: 'list_today_actions' });
  return r.interactions || [];
}

/** Testa conexão (ping) — útil pra options page */
export async function testConnection(config: ExtensionConfig): Promise<{ ok: boolean; error?: string }> {
  try {
    const accessToken = await getValidAccessToken();
    const res = await fetch(`${SUPABASE_URL}/functions/v1/social-selling-plan-day`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ skip_budget: false }),
    });
    if (res.status === 401 || res.status === 403) {
      return { ok: false, error: 'Token inválido ou sem permissão' };
    }
    if (!res.ok) {
      return { ok: false, error: `HTTP ${res.status}` };
    }
    return { ok: true };
  } catch (e: any) {
    return { ok: false, error: e.message || 'Falha de rede' };
  }
}
