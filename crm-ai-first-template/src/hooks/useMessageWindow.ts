import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";

/**
 * Janela de mensagens livre WhatsApp (lógica limpa portada do CHEIRINCRM):
 *  - CSW (Customer Service Window): 24h após última msg do lead
 *  - CTWA (Click-to-WhatsApp Ads): 72h após msg do lead que veio de ad
 *
 * Fora da janela → só template aprovado.
 *
 * ADAPTAÇÃO (nosso schema):
 *  - NÃO existe tabela `tenant_config` no nosso CRM → settings fixos (DEFAULT_SETTINGS).
 *  - `whatsapp_messages` tem `tenant_id`, `is_from_me`, `sent_at`, `ctwa_referral` (jsonb).
 *  - `tenantId` vem do AuthContext.
 */

export type WindowState =
  | { type: "free"; expiresAt: Date; reason: "csw_24h" | "ctwa_72h"; hoursLeft: number; ctwa?: any }
  | { type: "template_only"; reason: "window_closed" | "no_history"; lastIncomingAt?: Date };

interface WASettings {
  lead_no_history_policy: "template_only" | "allow_free";
  csw_window_hours: number;
  ctwa_window_hours: number;
}

// Sem tabela tenant_config no nosso schema — usamos defaults fixos.
const DEFAULT_SETTINGS: WASettings = {
  lead_no_history_policy: "template_only",
  csw_window_hours: 24,
  ctwa_window_hours: 72,
};

export function useMessageWindow(leadId: string | undefined | null) {
  const { tenantId } = useAuth();

  return useQuery({
    queryKey: ["message-window", tenantId, leadId],
    queryFn: async (): Promise<WindowState> => {
      if (!leadId) return { type: "template_only", reason: "no_history" };

      const settings = DEFAULT_SETTINGS;

      // 1. Última msg INCOMING (is_from_me = false) com tenant_id explícito
      const { data: lastIncoming } = await supabase
        .from("whatsapp_messages")
        .select("sent_at, ctwa_referral")
        .eq("tenant_id", tenantId!)
        .eq("lead_id", leadId)
        .eq("is_from_me", false)
        .order("sent_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (!lastIncoming) {
        // Lead sem msg recebida — política configurável (default: template_only)
        if (settings.lead_no_history_policy === "allow_free") {
          const expiresAt = new Date(Date.now() + settings.csw_window_hours * 3600 * 1000);
          return { type: "free", expiresAt, reason: "csw_24h", hoursLeft: settings.csw_window_hours };
        }
        return { type: "template_only", reason: "no_history" };
      }

      // 2. Última msg com ctwa_referral (CTWA chega normalmente na 1ª msg —
      //    msgs subsequentes vem com referral=null, então buscar separadamente)
      const { data: lastCtwaMsg } = await supabase
        .from("whatsapp_messages")
        .select("sent_at, ctwa_referral")
        .eq("tenant_id", tenantId!)
        .eq("lead_id", leadId)
        .eq("is_from_me", false)
        .not("ctwa_referral", "is", null)
        .order("sent_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      const lastIncomingAt = new Date((lastIncoming as any).sent_at);
      const now = new Date();

      // Janela CSW (24h a partir da última msg do lead)
      const cswExpires = new Date(lastIncomingAt.getTime() + settings.csw_window_hours * 3600 * 1000);
      const cswHoursLeft = (cswExpires.getTime() - now.getTime()) / (3600 * 1000);

      // Janela CTWA (72h a partir do último click no anúncio) — se existir
      let ctwaHoursLeft = -1;
      let ctwaExpires: Date | null = null;
      if (lastCtwaMsg) {
        const lastCtwaAt = new Date((lastCtwaMsg as any).sent_at);
        ctwaExpires = new Date(lastCtwaAt.getTime() + settings.ctwa_window_hours * 3600 * 1000);
        ctwaHoursLeft = (ctwaExpires.getTime() - now.getTime()) / (3600 * 1000);
      }

      // Aplica a janela mais permissiva: se CTWA aberta, prevalece (72h cobre CSW 24h)
      if (ctwaHoursLeft > 0) {
        return {
          type: "free",
          expiresAt: ctwaExpires!,
          reason: "ctwa_72h",
          hoursLeft: ctwaHoursLeft,
          ctwa: (lastCtwaMsg as any).ctwa_referral,
        };
      }

      if (cswHoursLeft > 0) {
        return {
          type: "free",
          expiresAt: cswExpires,
          reason: "csw_24h",
          hoursLeft: cswHoursLeft,
        };
      }

      return { type: "template_only", reason: "window_closed", lastIncomingAt };
    },
    enabled: !!tenantId && !!leadId,
    staleTime: 60_000,
  });
}

export function formatWindowBadge(state: WindowState | undefined): {
  label: string;
  tone: "open" | "ctwa" | "closed" | "loading";
} {
  if (!state) return { label: "Verificando...", tone: "loading" };
  if (state.type === "template_only") {
    return state.reason === "no_history"
      ? { label: "Sem histórico", tone: "closed" }
      : { label: "Janela fechada", tone: "closed" };
  }
  const h = Math.floor(state.hoursLeft);
  // Formato curto: "23h", "2d 14h", "45m"
  let formatted: string;
  if (h >= 24) formatted = `${Math.floor(h / 24)}d ${h % 24}h`;
  else if (h >= 1) formatted = `${h}h`;
  else formatted = `${Math.floor(state.hoursLeft * 60)}m`;
  return state.reason === "ctwa_72h"
    ? { label: `CTWA · ${formatted}`, tone: "ctwa" }
    : { label: `Aberta · ${formatted}`, tone: "open" };
}
