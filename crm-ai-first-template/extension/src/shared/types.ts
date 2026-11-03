// ============================================================
// Tipos compartilhados entre background, content scripts, popup, options
// CONFIG = local (por device). Tudo de comportamento mora no CRM.
// ============================================================

export type ActionType =
  | 'curtir_posts'
  | 'comentar_post'
  | 'reagir_story'
  | 'responder_story'
  | 'enviar_dm'
  | 'followup_story'
  | 'verificar_resposta';

export type ActionMode = 'auto' | 'approve';

export interface ExtensionConfig {
  /** URL base do CRM web. Vem do .env (VITE_CRM_URL). Sobrescrevível em runtime. */
  crmBaseUrl?: string;
  /** @ da conta Instagram que este device prospecta (sem o @). */
  ownerUsername?: string;
  /** Notificação push do Chrome quando uma ação precisa de aprovação. */
  notifyOnApprovalNeeded: boolean;
}

export const DEFAULT_CONFIG: ExtensionConfig = {
  crmBaseUrl: '',
  ownerUsername: '',
  notifyOnApprovalNeeded: true,
};

/** Item do plano de ações vindo da edge function social-selling-plan-day */
export interface PlanItem {
  enrollment_id: string;
  lead_id: string;
  instagram_username: string;
  day: number;
  action_type: ActionType;
  /** Modo definido na cadência do CRM (auto/approve). Default approve pra textos. */
  action_mode?: ActionMode;
  target_url?: string;
  target_id?: string;
  delay_after_seconds: number;
  generated_message?: string;
  context_preview?: string;
  lead?: { name?: string; avatar_url?: string; instagram?: string };
}

/** Item da fila local da extensão (pendente de aprovação ou já executado) */
export interface QueueItem extends PlanItem {
  local_id: string;
  state: 'pending_approval' | 'auto_ready' | 'executing' | 'success' | 'failed' | 'skipped';
  edited_message?: string;
  created_at: number;
  executed_at?: number;
  executing_started_at?: number;
  error_message?: string;
}

/** Mensagens entre background ↔ content ↔ popup */
export type ExtMessage =
  | { kind: 'EXECUTE_ACTION'; item: QueueItem }
  | { kind: 'ACTION_RESULT'; local_id: string; success: boolean; error?: string }
  | { kind: 'CAPTURE_STORY_CONTENT'; username: string }
  | { kind: 'STORY_CONTENT_RESULT'; ok: boolean; story_content?: string; error?: string }
  | { kind: 'CAPTURE_FOLLOWERS_API'; target_username: string; limit: number; stop_on_known: string[] }
  | { kind: 'GET_QUEUE' }
  | { kind: 'QUEUE_RESPONSE'; queue: QueueItem[] }
  | { kind: 'APPROVE_ITEM'; local_id: string; edited_message?: string }
  | { kind: 'SKIP_ITEM'; local_id: string }
  | { kind: 'REGENERATE_MESSAGE'; local_id: string }
  | { kind: 'RUN_NOW'; enrollment_ids?: string[] }
  | { kind: 'PAUSE_ALL' }
  | { kind: 'GET_CONFIG' }
  | { kind: 'CONFIG_RESPONSE'; config: ExtensionConfig }
  | { kind: 'SAVE_CONFIG'; config: ExtensionConfig };

// ============================================================
// CRM base URL — setado no bootstrap do popup a partir do config.
// ============================================================
let _crmBase = '';
export function setCrmBaseUrl(u?: string) { _crmBase = (u || '').replace(/\/+$/, ''); }
export function crmLeadUrl(leadId?: string): string {
  if (!_crmBase) return '';
  return leadId ? `${_crmBase}/comercial/leads/${leadId}` : `${_crmBase}/comercial/leads`;
}
