import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@/contexts/AuthContext";
import { supabase } from "@/lib/supabase";
import { getPreviousRange, type DateRange } from "@/hooks/useMarketingDashboard";

export type { DateRange };

export type Platform = "instagram" | "youtube" | "linkedin" | "tiktok";
export type Format = "reel" | "story" | "carousel" | "image" | "video" | "short" | "article" | "text" | "unknown";

export const PLATFORMS: Platform[] = ["instagram", "youtube", "linkedin", "tiktok"];

export interface SocialAccount {
  id: string;
  zernio_account_id: string;
  platform: Platform;
  username: string | null;
  display_name: string | null;
  profile_picture: string | null;
  profile_url: string | null;
  followers_count: number | null;
  needs_reconnection: boolean;
  metadata: {
    account_metrics?: Record<string, number>;
    account_metrics_scope?: "lifetime" | "periodo";
    account_metrics_at?: string;
  };
}

export interface SocialPost {
  id: string;
  zernio_post_id: string;
  platform_post_id: string | null;
  platform: Platform;
  format: Format;
  format_confidence: "exact" | "inferred";
  content: string | null;
  permalink: string | null;
  thumbnail_url: string | null;
  published_at: string | null;
  impressions: number;
  reach: number;
  views: number;
  likes: number;
  comments: number;
  shares: number;
  saves: number;
  follows: number;
  engagement_rate: number | null;
  is_story_snapshot: boolean;
}

export interface DailyMetric {
  metric_date: string;
  platform: Platform;
  post_count: number;
  impressions: number;
  reach: number;
  views: number;
  likes: number;
  comments: number;
  shares: number;
  saves: number;
  followers: number | null;
}

/**
 * Data em YYYY-MM-DD no fuso LOCAL.
 * `toISOString()` converte pra UTC antes de cortar, então no Brasil (UTC-3) qualquer
 * horário depois das 21h vira o dia seguinte — "hoje" traria dados de amanhã.
 */
export function diaISO(d: Date): string {
  const mes = String(d.getMonth() + 1).padStart(2, "0");
  const dia = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${mes}-${dia}`;
}

/** Período imediatamente anterior, de mesmo tamanho — base das comparações. */
export function periodoAnterior(range: DateRange): DateRange {
  return getPreviousRange(range);
}

export function useSocialAccounts() {
  const {tenantId}=useAuth();
  return useQuery({
    enabled: !!tenantId,
    queryKey: [tenantId, "social-accounts"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("social_accounts" as any)
        .select("*").eq("tenant_id",tenantId)
        .eq("is_active", true)
        .order("followers_count", { ascending: false });
      if (error) throw error;
      return (data || []) as SocialAccount[];
    },
  });
}

export function useSocialPosts(range: DateRange, platform?: Platform, format?: Format) {
  const {tenantId}=useAuth();
  const desde = diaISO(range.from);
  const ate = diaISO(range.to);
  return useQuery({
    enabled: !!tenantId,
    queryKey: [tenantId, "social-posts", desde, ate, platform ?? "all", format ?? "all"],
    queryFn: async () => {
      let q = supabase
        .from("social_posts" as any)
        .select("*").eq("tenant_id",tenantId)
        // `ate` + 1 dia: published_at é timestamp e `lt` no dia seguinte inclui o dia
        // inteiro escolhido, o que `lte` na data crua não faria.
        .gte("published_at", desde)
        .lt("published_at", diaISO(new Date(range.to.getTime() + 86400000)))
        .order("published_at", { ascending: false })
        .limit(1000);
      if (platform) q = q.eq("platform", platform);
      if (format) q = q.eq("format", format);
      const { data, error } = await q;
      if (error) throw error;
      return (data || []) as SocialPost[];
    },
  });
}

/**
 * Série diária cobrindo o período E o anterior — os KPIs precisam dos dois pra
 * comparar, e uma consulta só evita um segundo round-trip a cada troca de filtro.
 */
export function useSocialDaily(range: DateRange) {
  const {tenantId}=useAuth();
  const anterior = periodoAnterior(range);
  const desde = diaISO(anterior.from);
  const ate = diaISO(range.to);
  return useQuery({
    enabled: !!tenantId,
    queryKey: [tenantId, "social-daily", desde, ate],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("social_metrics_daily" as any)
        .select("metric_date, platform, post_count, impressions, reach, views, likes, comments, shares, saves, followers").eq("tenant_id",tenantId)
        .gte("metric_date", desde)
        .lte("metric_date", ate)
        .order("metric_date", { ascending: true });
      if (error) throw error;
      return (data || []) as DailyMetric[];
    },
  });
}

/** Leads por rede — vem do CRM (utm_source), nao da API social. */
export function useSocialLeads(range: DateRange) {
  const {tenantId}=useAuth();
  const desde = diaISO(range.from);
  const ate = diaISO(range.to);
  return useQuery({
    enabled: !!tenantId,
    queryKey: [tenantId, "social-leads", desde, ate],
    queryFn: async () => {
      const { data, error } = await supabase.rpc("social_leads_por_rede" as any, { p_desde: desde, p_ate: ate });
      if (error) throw error;
      const mapa: Record<string, { leads: number; qualificados: number }> = {};
      for (const r of (data || []) as any[]) {
        mapa[r.platform] = { leads: Number(r.leads), qualificados: Number(r.leads_qualificados) };
      }
      return mapa;
    },
  });
}

export function useSyncSocial() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async () => {
      const { data, error } = await supabase.functions.invoke("sync-social-zernio", { body: {} });
      if (error) throw error;
      if (data?.error) throw new Error(data.error);
      return data;
    },
    onSuccess: () => {
      for (const k of ["social-accounts", "social-posts", "social-daily", "social-leads"]) {
        qc.invalidateQueries({ predicate: q => q.queryKey.includes(k) });
      }
    },
  });
}
