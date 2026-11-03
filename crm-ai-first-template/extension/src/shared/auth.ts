// ============================================================
// Supabase Auth client — login email/senha + refresh automático
// Salva access_token + refresh_token + user em chrome.storage.
// URL e anon key vêm do build (injetadas via .env do projeto raiz).
// ============================================================

import { SUPABASE_URL, SUPABASE_ANON_KEY, envIsConfigured } from './env';

const SESSION_KEY = 'iap_ss_session';

export interface AuthSession {
  access_token: string;
  refresh_token: string;
  expires_at: number; // ms epoch
  user: { id: string; email?: string };
}

export async function getSession(): Promise<AuthSession | null> {
  const r = await chrome.storage.local.get(SESSION_KEY);
  return (r[SESSION_KEY] as AuthSession) || null;
}

async function setSession(s: AuthSession | null) {
  if (s) await chrome.storage.local.set({ [SESSION_KEY]: s });
  else await chrome.storage.local.remove(SESSION_KEY);
}

export async function signIn(email: string, password: string): Promise<AuthSession> {
  if (!envIsConfigured()) throw new Error('Extensão buildada sem credenciais. Verifique o .env do CRM antes de rodar npm run build.');
  const r = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_ANON_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ email, password }),
  });
  const data = await r.json();
  if (!r.ok) throw new Error(data?.error_description || data?.msg || `Login falhou (${r.status})`);
  const session: AuthSession = {
    access_token: data.access_token,
    refresh_token: data.refresh_token,
    expires_at: Date.now() + (data.expires_in || 3600) * 1000,
    user: { id: data.user?.id, email: data.user?.email },
  };
  await setSession(session);
  return session;
}

export async function signOut() {
  await setSession(null);
}

async function refresh(refreshToken: string): Promise<AuthSession> {
  const r = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_ANON_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ refresh_token: refreshToken }),
  });
  const data = await r.json();
  if (!r.ok) throw new Error(data?.error_description || `Refresh falhou`);
  const session: AuthSession = {
    access_token: data.access_token,
    refresh_token: data.refresh_token,
    expires_at: Date.now() + (data.expires_in || 3600) * 1000,
    user: { id: data.user?.id, email: data.user?.email },
  };
  await setSession(session);
  return session;
}

/**
 * Retorna access_token válido. Se expirou em <60s, faz refresh.
 * Lança erro se não tem sessão ou refresh falhou.
 */
export async function getValidAccessToken(): Promise<string> {
  let s = await getSession();
  if (!s) throw new Error('Não autenticado');
  if (Date.now() >= s.expires_at - 60_000) {
    s = await refresh(s.refresh_token);
  }
  return s.access_token;
}
