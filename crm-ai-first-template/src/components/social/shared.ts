import type { Format, Platform } from "@/hooks/useSocialPanel";

export const PLATFORM_LABEL: Record<Platform, string> = {
  instagram: "Instagram",
  youtube: "YouTube",
  linkedin: "LinkedIn",
  tiktok: "TikTok",
};

/** Cor de marca por rede. Usada só no acento — o resto do card segue o tema. */
export const PLATFORM_COLOR: Record<Platform, string> = {
  instagram: "#E1306C",
  youtube: "#FF0033",
  linkedin: "#0A66C2",
  tiktok: "#00F2EA",
};

export const FORMAT_LABEL: Record<Format, string> = {
  reel: "Reels",
  story: "Stories",
  carousel: "Carrossel",
  image: "Post",
  // "Vídeo" e não "Vídeo longo": o Zernio não devolve duração, então não dá
  // pra separar Short de vídeo longo no YouTube. Rotular de longo seria chutar.
  video: "Vídeo",
  short: "Shorts",
  article: "Artigo",
  text: "Texto",
  unknown: "Outro",
};

/** Ordem em que os tipos aparecem nos chips e nas tabelas dos cards. */
export const FORMAT_ORDER: Format[] = ["reel", "story", "carousel", "image", "short", "video", "article", "text", "unknown"];

export function fmtNum(n: number | null | undefined): string {
  const v = Number(n || 0);
  if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(1).replace(".", ",")} M`;
  if (v >= 1_000) return `${(v / 1_000).toFixed(1).replace(".", ",")} K`;
  return v.toLocaleString("pt-BR");
}

export function fmtPct(n: number | null | undefined, casas = 1): string {
  return `${Number(n || 0).toFixed(casas).replace(".", ",")}%`;
}

export function fmtData(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("pt-BR", { day: "2-digit", month: "short" });
}

/** Variação percentual entre dois períodos. null quando não há base de comparação. */
export function variacao(atual: number, anterior: number): number | null {
  if (!anterior) return null;
  return ((atual - anterior) / anterior) * 100;
}

/**
 * Formata a variação com teto de 999%. Em janelas curtas o período anterior pode
 * ser quase zero e a conta cospe "+21428,9%" — matematicamente certo, mas ilegível
 * e sem informação: acima de 999% o que importa é "explodiu", não o dígito exato.
 */
export function fmtVariacao(delta: number, emPontos = false): string {
  const sinal = delta >= 0 ? "+" : "−";
  const abs = Math.abs(delta);
  if (!emPontos && abs > 999) return `${sinal}999%+`;
  return `${sinal}${abs.toFixed(1).replace(".", ",")}${emPontos ? " p.p." : "%"}`;
}

/**
 * Métricas de conta das redes que não expõem posts individuais.
 * O Zernio nomeia os campos diferente em cada uma — este mapa traduz para rótulos
 * legíveis e diz quais são do período e quais são acumulado de vida da conta.
 */
export const ACCOUNT_METRICS: Record<string, Array<{ campo: string; rotulo: string; formato?: "horasDeMinutos" | "pct" }>> = {
  youtube: [
    { campo: "views", rotulo: "views" },
    { campo: "estimatedMinutesWatched", rotulo: "assistido", formato: "horasDeMinutos" },
    { campo: "subscribersGained", rotulo: "inscritos" },
  ],
  tiktok: [
    { campo: "video_count", rotulo: "vídeos" },
    { campo: "likes_count", rotulo: "curtidas" },
    { campo: "follower_count", rotulo: "seguidores" },
  ],
  linkedin: [
    { campo: "impressions", rotulo: "impressões" },
    { campo: "reactions", rotulo: "reações" },
    { campo: "engagementRate", rotulo: "engaj.", formato: "pct" },
  ],
};

export function fmtMetricaDeConta(valor: number, formato?: "horasDeMinutos" | "pct"): string {
  if (formato === "horasDeMinutos") return `${fmtNum(Math.round(valor / 60))} h`;
  if (formato === "pct") return fmtPct(valor, 2);
  return fmtNum(valor);
}

/**
 * Instagram reporta alcance (pessoas únicas). YouTube e TikTok não — só views.
 * Somar os dois campos como se fossem a mesma coisa seria errado, e mostrar
 * "alcance 0" nessas redes faz parecer que não performaram. Cada rede usa a métrica
 * de audiência que ela de fato publica, com o rótulo certo.
 */
export const REPORTA_ALCANCE: Record<Platform, boolean> = {
  instagram: true,
  linkedin: true,
  youtube: false,
  tiktok: false,
};

export function rotuloDeAudiencia(p: Platform): string {
  return REPORTA_ALCANCE[p] ? "alcance" : "views";
}

/** Audiência da rede: alcance onde existe, views onde a plataforma não reporta alcance. */
export function audiencia(p: Platform, alcance: number, views: number): number {
  return REPORTA_ALCANCE[p] ? alcance : views;
}
