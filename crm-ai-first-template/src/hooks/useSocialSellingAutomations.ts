import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";

export type TriggerType = "stage_change" | "new_follower";

export interface CadenceAction {
  type:
    | "reagir_story"
    | "responder_story"
    | "curtir_posts"
    | "comentar_post"
    | "enviar_dm"
    | "verificar_resposta"
    | "followup_story";
  count?: number;
  notes?: string;
}

export interface CadenceDay {
  day: number;
  label?: string;
  actions: CadenceAction[];
}

export interface QualificationConfig {
  /** Descrição em texto livre do ICP. A IA lê o perfil e analisa baseada nisso. */
  ai_prompt?: string;
  /** Score mínimo (0-100) que a IA precisa dar pro lead passar */
  ai_score_min?: number;
}

export interface OnReplyConfig {
  move_to_pipeline_id?: string;
  move_to_stage_id?: string;
  notify_whatsapp?: boolean;
  add_tag?: string;
}

export interface SocialSellingAutomation {
  id: string;
  name: string;
  emoji: string;
  is_active: boolean;
  trigger_type: TriggerType;
  trigger_config: Record<string, any>;
  qualification_config: QualificationConfig;
  cadence_config: { days: CadenceDay[] };
  on_reply_config: OnReplyConfig;
  rate_limit_overrides: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export const TRIGGER_LABELS: Record<TriggerType, string> = {
  stage_change: "🔄 Cadência (lead entra em etapa)",
  new_follower: "🌐 Seguidores novos no Instagram",
};

export const ACTION_LABELS: Record<string, string> = {
  reagir_story: "❤️ Reagir story",
  responder_story: "💬 Responder story",
  curtir_posts: "👍 Curtir posts",
  comentar_post: "🗣️ Comentar post",
  enviar_dm: "📩 Enviar DM",
  verificar_resposta: "👀 Verificar resposta",
  followup_story: "🔄 Follow-up story",
};

// ==================== TEMPLATES ====================

export const AUTOMATION_TEMPLATES: Array<Partial<SocialSellingAutomation> & { name: string; emoji: string; description: string }> = [
  {
    name: "Cadência de aquecimento",
    emoji: "🔄",
    description: "Quando lead entra numa etapa do funil, dispara sequência de aquecimento no Instagram",
    trigger_type: "stage_change",
    trigger_config: {},
    cadence_config: {
      days: [
        { day: 1, label: "Primeiro contato", actions: [{ type: "reagir_story" }, { type: "curtir_posts", count: 2 }] },
        { day: 2, label: "Engajamento", actions: [{ type: "responder_story" }, { type: "curtir_posts", count: 1 }] },
        { day: 3, label: "Comentário público", actions: [{ type: "comentar_post" }] },
        { day: 4, label: "Descanso ativo", actions: [{ type: "reagir_story" }] },
        { day: 5, label: "Abordagem", actions: [{ type: "reagir_story" }, { type: "enviar_dm" }] },
        { day: 7, label: "Follow-up", actions: [{ type: "followup_story" }] },
      ],
    },
    on_reply_config: { notify_whatsapp: true },
  },
  {
    name: "Prospecção de novos seguidores",
    emoji: "🌐",
    description: "Varre novos seguidores, qualifica via IA pelo seu ICP e dispara cadência de boas-vindas",
    trigger_type: "new_follower",
    trigger_config: { scan_frequency: "daily" },
    qualification_config: {
      ai_prompt: "Quero empresários reais — donos de empresa, CEOs, fundadores. Bio e posts devem mostrar atividade profissional/empresarial (não influencer, não fanpage, não modelo). Min 500 seguidores. Posts mostram trabalho, escritório, viagem de negócio, lifestyle empresarial.",
      ai_score_min: 70,
    },
    cadence_config: {
      days: [
        { day: 1, actions: [{ type: "reagir_story" }, { type: "curtir_posts", count: 2 }] },
        { day: 3, actions: [{ type: "comentar_post" }] },
        { day: 7, actions: [{ type: "enviar_dm" }] },
      ],
    },
  },
];

// ==================== HOOKS ====================

export function useAutomations() {
  return useQuery({
    queryKey: ["social-selling-automations"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("social_selling_automations")
        .select("*")
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data || []) as SocialSellingAutomation[];
    },
  });
}

export function useSaveAutomation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (data: Partial<SocialSellingAutomation> & { id?: string }) => {
      const { id, ...rest } = data;
      if (id) {
        const { data: row, error } = await supabase
          .from("social_selling_automations")
          .update(rest)
          .eq("id", id)
          .select()
          .single();
        if (error) throw error;
        return row;
      } else {
        const { data: row, error } = await supabase
          .from("social_selling_automations")
          .insert(rest)
          .select()
          .single();
        if (error) throw error;
        return row;
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["social-selling-automations"] });
    },
  });
}

export function useDeleteAutomation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("social_selling_automations").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["social-selling-automations"] });
    },
  });
}

export function useToggleAutomation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, is_active }: { id: string; is_active: boolean }) => {
      const { error } = await supabase
        .from("social_selling_automations")
        .update({ is_active })
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["social-selling-automations"] });
    },
  });
}
