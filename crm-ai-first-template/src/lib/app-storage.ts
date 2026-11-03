// Chaves de localStorage/sessionStorage escritas pela aplicação.
// Usadas no sign-out para não deixar dados de um tenant/usuário (transcrições,
// rascunhos de WhatsApp, preferências com IDs de membros) para o próximo login
// na mesma aba. As chaves `sb-*` do Supabase Auth NÃO entram aqui — o próprio
// `supabase.auth.signOut()` cuida delas. `crm-theme` também fica de fora: é
// preferência visual sem dado de negócio.
export const APP_STORAGE_PREFIXES: readonly string[] = [
  // localStorage
  'crm-demo-mode',
  'crm_active_meeting',
  'crm_dismissed_meeting',
  'crm_notifications_muted',
  'meeting_transcriptions_',
  'call_transcription_backup_',
  'whatsapp-draft:',
  'task_reminder_dismissed',
  'task_critical_dismissed',
  'ai_transfer_alert_dismissed',
  'daily-activity-banner-expanded',
  'focus-banner-data',
  'agenda-v2-prefs',
  'social_panel_preset',
  'calendar-view-mode',
  'calendar-selected-member',
  'calendar-my-tasks-only',
  'event_app_token',
  // sessionStorage
  'pipeline_',
  'sales-inbox-',
  'scroll:',
  'cockpit-skipped-',
  'dashv3-',
];

function removeMatching(storage: Storage | undefined, prefixes: readonly string[]) {
  if (!storage) return;
  const toRemove: string[] = [];
  for (let i = 0; i < storage.length; i++) {
    const key = storage.key(i);
    if (key && prefixes.some((p) => key.startsWith(p))) toRemove.push(key);
  }
  toRemove.forEach((key) => storage.removeItem(key));
}

/** Remove todas as chaves da aplicação (prefixos acima) de localStorage e sessionStorage. */
export function clearAppStorage(prefixes: readonly string[] = APP_STORAGE_PREFIXES) {
  if (typeof window === 'undefined') return;
  try { removeMatching(window.localStorage, prefixes); } catch { /* storage indisponível */ }
  try { removeMatching(window.sessionStorage, prefixes); } catch { /* storage indisponível */ }
}
