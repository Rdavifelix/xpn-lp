import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";

export interface SocialSellingEnrollment {
  id: string;
  lead_id: string;
  flow_name: string;
  flow_config: Record<string, any>;
  current_day: number;
  total_days: number;
  status: "active" | "paused" | "replied" | "completed" | "failed" | "cancelled";
  instagram_username: string | null;
  started_at: string;
  last_action_at: string | null;
  next_action_at: string | null;
  completed_at: string | null;
  pause_reason: string | null;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface SocialSellingInteraction {
  id: string;
  lead_id: string;
  enrollment_id: string | null;
  action_type:
    | "reagir_story"
    | "responder_story"
    | "curtir_posts"
    | "comentar_post"
    | "enviar_dm"
    | "verificar_resposta"
    | "followup_story";
  day_number: number | null;
  content: string | null;
  instagram_target: string | null;
  status: "success" | "failed" | "skipped" | "rate_limited";
  error_message: string | null;
  metadata: Record<string, any>;
  executed_at: string;
  created_at: string;
}

export const ACTION_LABELS: Record<string, string> = {
  reagir_story: "Reagiu ao story",
  responder_story: "Respondeu ao story",
  curtir_posts: "Curtiu posts",
  comentar_post: "Comentou em post",
  enviar_dm: "Enviou DM",
  verificar_resposta: "Verificou resposta",
  followup_story: "Follow-up via story",
};

export const ACTION_ICONS: Record<string, string> = {
  reagir_story: "❤️",
  responder_story: "💬",
  curtir_posts: "👍",
  comentar_post: "🗣️",
  enviar_dm: "📩",
  verificar_resposta: "👀",
  followup_story: "🔄",
};

export function useSocialSellingEnrollment(leadId: string | null | undefined) {
  return useQuery({
    queryKey: ["social-selling-enrollment", leadId],
    queryFn: async () => {
      if (!leadId) return null;
      const { data, error } = await supabase
        .from("social_selling_enrollments")
        .select("*")
        .eq("lead_id", leadId)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (error) throw error;
      return data as SocialSellingEnrollment | null;
    },
    enabled: !!leadId,
  });
}

export function useSocialSellingInteractions(leadId: string | null | undefined) {
  return useQuery({
    queryKey: ["social-selling-interactions", leadId],
    queryFn: async () => {
      if (!leadId) return [];
      const { data, error } = await supabase
        .from("social_selling_interactions")
        .select("*")
        .eq("lead_id", leadId)
        .order("executed_at", { ascending: false });
      if (error) throw error;
      return (data || []) as SocialSellingInteraction[];
    },
    enabled: !!leadId,
  });
}

export function useUpdateEnrollment() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      id,
      status,
      pause_reason,
    }: {
      id: string;
      status: SocialSellingEnrollment["status"];
      pause_reason?: string;
    }) => {
      const { data, error } = await supabase
        .from("social_selling_enrollments")
        .update({ status, pause_reason: pause_reason ?? null })
        .eq("id", id)
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["social-selling-enrollment"] });
    },
  });
}

export function useEnrollLead() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      lead_id,
      instagram_username,
      automation_id,
      flow_name = "Aquecimento Padrão",
      total_days,
    }: {
      lead_id: string;
      instagram_username: string;
      automation_id?: string;
      flow_name?: string;
      total_days?: number;
    }) => {
      // Se não passou automation_id, pega a 1ª cadência ATIVA
      let resolvedAutomationId = automation_id;
      let resolvedTotalDays = total_days;
      if (!resolvedAutomationId || !resolvedTotalDays) {
        const { data: auto } = await supabase
          .from("social_selling_automations")
          .select("id, cadence_config")
          .eq("is_active", true)
          .order("created_at")
          .limit(1)
          .maybeSingle();
        if (auto) {
          resolvedAutomationId = resolvedAutomationId || auto.id;
          const days = (auto.cadence_config as any)?.days || [];
          resolvedTotalDays = resolvedTotalDays || days.length || 7;
        }
      }
      if (!resolvedAutomationId) {
        throw new Error(
          "Nenhuma cadência ativa encontrada. Ative pelo menos uma em Configurações → Comercial → Prospecção Social."
        );
      }

      const { data, error } = await supabase
        .from("social_selling_enrollments")
        .insert({
          lead_id,
          instagram_username,
          automation_id: resolvedAutomationId,
          flow_name,
          total_days: resolvedTotalDays,
          current_day: 1, // cadências começam em day:1 (não 0) — pack v2
          status: "active",
          next_action_at: new Date().toISOString(),
        })
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["social-selling-enrollment"] });
    },
  });
}

export function useActiveEnrollmentsByLead() {
  return useQuery({
    queryKey: ["social-selling-enrollments-by-lead"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("social_selling_enrollments")
        .select("id, lead_id, status, current_day, total_days, instagram_username, last_action_at")
        .in("status", ["active", "paused", "replied"]);
      if (error) throw error;
      const byLead: Record<string, any> = {};
      for (const e of data || []) {
        if (!byLead[e.lead_id]) byLead[e.lead_id] = e;
      }
      return byLead;
    },
    refetchInterval: 60_000,
    staleTime: 30_000,
  });
}

export function useSocialSellingMetrics() {
  return useQuery({
    queryKey: ["social-selling-metrics"],
    queryFn: async () => {
      const [enrollmentsRes, interactionsRes] = await Promise.all([
        supabase.from("social_selling_enrollments").select("status, created_at"),
        supabase
          .from("social_selling_interactions")
          .select("action_type, status, executed_at")
          .gte("executed_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()),
      ]);

      const enrollments = enrollmentsRes.data || [];
      const interactions = interactionsRes.data || [];

      return {
        active: enrollments.filter((e: any) => e.status === "active").length,
        replied: enrollments.filter((e: any) => e.status === "replied").length,
        completed: enrollments.filter((e: any) => e.status === "completed").length,
        actions_24h: interactions.length,
        actions_failed_24h: interactions.filter((i: any) => i.status !== "success").length,
        reply_rate:
          enrollments.length > 0
            ? Math.round(
                (enrollments.filter((e: any) => e.status === "replied").length / enrollments.length) * 100
              )
            : 0,
      };
    },
    refetchInterval: 60_000,
  });
}
