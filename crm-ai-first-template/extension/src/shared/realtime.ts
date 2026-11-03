// ============================================================
// Realtime — abre channel pra mudanças em social_selling_enrollments / interactions
// Auto-reconecta. Se falhar, popup ainda tem polling 5s como fallback.
// ============================================================
import { createClient, type SupabaseClient, type RealtimeChannel } from '@supabase/supabase-js';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './env';
import { getConfig } from './storage';
import { getValidAccessToken } from './auth';

let client: SupabaseClient | null = null;
let channel: RealtimeChannel | null = null;

async function ensureClient(): Promise<SupabaseClient> {
  if (client) return client;
  const cfg = await getConfig();
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) throw new Error('CRM não configurado');
  client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
    realtime: { params: { eventsPerSecond: 10 } },
  });
  return client;
}

/** Abre subscription. onChange dispara em qualquer INSERT/UPDATE/DELETE em enrollments ou interactions. */
export async function subscribeEnrollments(onChange: () => void): Promise<() => void> {
  const supa = await ensureClient();
  // Auth realtime com JWT do user (pra RLS funcionar)
  const accessToken = await getValidAccessToken();
  await supa.realtime.setAuth(accessToken);

  const ch = supa
    .channel('iap-ss-enrollments')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'social_selling_enrollments' }, () => onChange())
    .on('postgres_changes', { event: '*', schema: 'public', table: 'social_selling_interactions' }, () => onChange())
    .subscribe((status) => {
      console.log('[IAP-SS realtime]', status);
    });
  channel = ch;
  return () => {
    try { supa.removeChannel(ch); } catch {}
    if (channel === ch) channel = null;
  };
}

/** Subscribe em qualificação ao vivo. onEvent recebe payload (insert ou update de known_followers). */
export async function subscribeQualification(
  onEvent: (row: any, eventType: 'INSERT' | 'UPDATE') => void,
): Promise<() => void> {
  const supa = await ensureClient();
  const accessToken = await getValidAccessToken();
  await supa.realtime.setAuth(accessToken);

  const ch = supa
    .channel('iap-ss-qualification')
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'social_selling_known_followers' },
      (payload: any) => onEvent(payload.new, 'INSERT'),
    )
    .on(
      'postgres_changes',
      { event: 'UPDATE', schema: 'public', table: 'social_selling_known_followers' },
      (payload: any) => onEvent(payload.new, 'UPDATE'),
    )
    .subscribe((status) => {
      console.log('[IAP-SS qualification realtime]', status);
    });
  return () => { try { supa.removeChannel(ch); } catch {} };
}

/** Busca histórico recente de qualificações (últimos N) — usado quando o modal abre */
export async function fetchRecentQualifications(forAccount: string | undefined, limit = 20): Promise<any[]> {
  const accessToken = await getValidAccessToken();
  let url = `${SUPABASE_URL}/rest/v1/social_selling_known_followers?order=first_seen_at.desc&limit=${limit}&select=username,full_name,is_private,is_verified,qualified,qualification_score,qualification_reason,first_seen_at`;
  if (forAccount) url += `&for_account=eq.${encodeURIComponent(forAccount)}`;
  const r = await fetch(url, { headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${accessToken}` } });
  if (!r.ok) return [];
  return r.json();
}

/** Busca o perfil completo do IG (foto, bio, posts) pra mostrar no modal */
export async function fetchProfileLive(username: string): Promise<any | null> {
  const supa = await ensureClient();
  const accessToken = await getValidAccessToken();
  await supa.realtime.setAuth(accessToken);
  // Usa o anon key + Authorization Bearer pro PostgREST respeitar RLS
  const cfg = await getConfig();
  const r = await fetch(
    `${SUPABASE_URL}/rest/v1/instagram_profiles?username=eq.${encodeURIComponent(username)}&select=username,full_name,biography,follower_count,following_count,media_count,is_verified,is_private,profile_picture_url_hd,stored_profile_picture_url`,
    { headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${accessToken}` } },
  );
  if (!r.ok) return null;
  const rows = await r.json();
  return rows?.[0] || null;
}
