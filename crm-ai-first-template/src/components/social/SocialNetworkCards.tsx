import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { TrendingUp, TrendingDown, AlertTriangle, ExternalLink } from "lucide-react";
import type { DailyMetric, Platform, SocialAccount, SocialPost } from "@/hooks/useSocialPanel";
import { PLATFORMS } from "@/hooks/useSocialPanel";
import { PlatformIcon } from "./PlatformIcon";
import { ACCOUNT_METRICS, FORMAT_LABEL, FORMAT_ORDER, PLATFORM_COLOR, PLATFORM_LABEL, audiencia, fmtMetricaDeConta, fmtNum, fmtPct, fmtVariacao, rotuloDeAudiencia } from "./shared";

interface Props {
  accounts: SocialAccount[] | undefined;
  posts: SocialPost[] | undefined;
  daily: DailyMetric[] | undefined;
  leads: Record<string, { leads: number; qualificados: number }> | undefined;
  isLoading: boolean;
  onSelecionarRede: (p: Platform) => void;
}

/**
 * Um card por rede: seguidores no topo, série de alcance, tabela por tipo de
 * conteúdo e rodapé com posts / alcance / engajamento / leads.
 *
 * YouTube, LinkedIn e TikTok não expõem lista de posts no Zernio (só agregado da
 * conta), então a tabela por tipo fica vazia nessas redes — o card diz isso em vez
 * de mostrar zeros que parecem queda de performance.
 */
export function SocialNetworkCards({ accounts, posts, daily, leads, isLoading, onSelecionarRede }: Props) {
  if (isLoading) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-3">
        {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-[300px]" />)}
      </div>
    );
  }

  return (
    <TooltipProvider>
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-3">
        {PLATFORMS.map((plat) => (
          <CardDeRede
            key={plat}
            plataforma={plat}
            conta={(accounts || []).find((a) => a.platform === plat)}
            posts={(posts || []).filter((p) => p.platform === plat)}
            daily={(daily || []).filter((d) => d.platform === plat)}
            leads={leads?.[plat]?.leads ?? 0}
            onClick={() => onSelecionarRede(plat)}
          />
        ))}
      </div>
    </TooltipProvider>
  );
}

function CardDeRede({
  plataforma, conta, posts, daily, leads, onClick,
}: {
  plataforma: Platform;
  conta: SocialAccount | undefined;
  posts: SocialPost[];
  daily: DailyMetric[];
  leads: number;
  onClick: () => void;
}) {
  const cor = PLATFORM_COLOR[plataforma];
  const conectada = !!conta;

  const comFollowers = daily.filter((d) => d.followers != null);
  const primeiro = comFollowers[0]?.followers ?? null;
  const ultimo = comFollowers[comFollowers.length - 1]?.followers ?? null;
  const seguidores = conta?.followers_count ?? ultimo ?? 0;
  const novos = primeiro != null && ultimo != null ? ultimo - primeiro : null;
  const varPct = novos != null && primeiro ? (novos / primeiro) * 100 : null;

  // Audiência = alcance no IG/LinkedIn, views no YouTube/TikTok (que não reportam alcance).
  const alcance = daily.reduce((s, d) => s + audiencia(plataforma, Number(d.reach || 0), Number(d.views || 0)), 0);
  const interacoes = daily.reduce((s, d) => s + Number(d.likes || 0) + Number(d.comments || 0) + Number(d.shares || 0) + Number(d.saves || 0), 0);
  const engaj = alcance ? (interacoes / alcance) * 100 : 0;
  const qtdPosts = daily.reduce((s, d) => s + Number(d.post_count || 0), 0) || posts.filter((p) => !p.is_story_snapshot).length;

  // Tabela por tipo — só existe onde a API entrega posts individuais.
  const porTipo = FORMAT_ORDER
    .map((f) => {
      const doTipo = posts.filter((p) => p.format === f);
      if (!doTipo.length) return null;
      return {
        formato: f,
        qtd: doTipo.length,
        views: doTipo.reduce((s, p) => s + Number(p.views || 0), 0),
        comentarios: doTipo.reduce((s, p) => s + Number(p.comments || 0), 0),
        temComentario: f !== "story",
      };
    })
    .filter(Boolean) as Array<{ formato: any; qtd: number; views: number; comentarios: number; temComentario: boolean }>;

  const temDadosDePost = porTipo.length > 0;
  const escopo = conta?.metadata?.account_metrics_scope;
  const metricasDeConta = (ACCOUNT_METRICS[plataforma] || [])
    .map((def) => {
      const bruto = conta?.metadata?.account_metrics?.[def.campo];
      if (bruto == null) return null;
      return { rotulo: def.rotulo, valor: fmtMetricaDeConta(Number(bruto), def.formato) };
    })
    .filter(Boolean) as Array<{ rotulo: string; valor: string }>;

  const audienciaDoDia = (d: DailyMetric) => audiencia(plataforma, Number(d.reach || 0), Number(d.views || 0));
  const maxAlcanceDia = Math.max(...daily.map(audienciaDoDia), 1);
  const barras = daily.slice(-24);

  return (
    <Card
      className="overflow-hidden hover:shadow-md transition-shadow cursor-pointer flex flex-col"
      onClick={onClick}
      style={{ borderTop: `3px solid ${cor}` }}
    >
      <CardContent className="p-4 flex flex-col flex-1 gap-3">
        {/* Identidade + variação */}
        <div className="flex items-start justify-between gap-2">
          <div className="flex items-center gap-2 min-w-0">
            <PlatformIcon platform={plataforma} className="h-4 w-4 shrink-0" />
            <span className="font-semibold text-sm truncate">{PLATFORM_LABEL[plataforma]}</span>
            {conta?.needs_reconnection && (
              <Tooltip>
                <TooltipTrigger asChild><AlertTriangle className="h-3.5 w-3.5 text-amber-500 shrink-0" /></TooltipTrigger>
                <TooltipContent className="text-xs">Conta precisa ser reconectada no Zernio</TooltipContent>
              </Tooltip>
            )}
          </div>
          {varPct != null && (
            <span className={`text-xs font-semibold flex items-center gap-0.5 shrink-0 ${varPct >= 0 ? "text-emerald-600" : "text-rose-600"}`}>
              {varPct >= 0 ? <TrendingUp className="h-3 w-3" /> : <TrendingDown className="h-3 w-3" />}
              {fmtVariacao(varPct)}
            </span>
          )}
        </div>

        {!conectada ? (
          <p className="text-xs text-muted-foreground py-8 text-center">Conta ainda não conectada</p>
        ) : (
          <>
            {/* Seguidores */}
            <div>
              <p className="text-3xl font-bold tabular-nums leading-none">{fmtNum(seguidores)}</p>
              <p className="text-[11px] text-muted-foreground mt-1">
                seguidores
                {novos != null && <> · {novos >= 0 ? "+" : "−"}{fmtNum(Math.abs(novos))} novos</>}
              </p>
            </div>

            {/* Alcance dia a dia */}
            {barras.length > 1 && (
              <div className="flex items-end gap-[2px] h-9" aria-hidden="true">
                {barras.map((d) => (
                  <div
                    key={d.metric_date}
                    className="flex-1 rounded-sm min-h-[2px]"
                    style={{
                      height: `${Math.max(4, (audienciaDoDia(d) / maxAlcanceDia) * 100)}%`,
                      backgroundColor: cor,
                      opacity: 0.28 + 0.72 * (audienciaDoDia(d) / maxAlcanceDia),
                    }}
                  />
                ))}
              </div>
            )}

            {/* Conteúdo por tipo — ou métricas da conta, onde não há posts */}
            <div className="flex-1">
              <p className="text-[10px] uppercase tracking-wide text-muted-foreground mb-1.5">
                {porTipo.length === 0 ? "Métricas da conta" : "Conteúdo publicado"}
              </p>
              {porTipo.length === 0 ? (
                metricasDeConta.length === 0 ? (
                  <p className="text-[11px] text-muted-foreground leading-relaxed">Sem métricas disponíveis</p>
                ) : (
                  <div className="space-y-1">
                    {metricasDeConta.map((m) => (
                      <div key={m.rotulo} className="flex items-baseline justify-between text-[11px]">
                        <span className="text-muted-foreground">{m.rotulo}</span>
                        <span className="font-semibold tabular-nums">{m.valor}</span>
                      </div>
                    ))}
                    <p className="text-[10px] text-muted-foreground/70 pt-1 leading-snug">
                      {escopo === "lifetime" ? "Total da conta" : "Últimos 30 dias"} · esta rede não expõe posts individuais na API
                    </p>
                  </div>
                )
              ) : (
                <table className="w-full text-[11px]">
                  <thead>
                    <tr className="text-muted-foreground">
                      <th className="text-left font-medium pb-1">Tipo</th>
                      <th className="text-right font-medium pb-1">Qtd</th>
                      <th className="text-right font-medium pb-1">Views</th>
                      <th className="text-right font-medium pb-1">Com.</th>
                    </tr>
                  </thead>
                  <tbody className="tabular-nums">
                    {porTipo.map((t) => (
                      <tr key={t.formato}>
                        <td className="py-0.5">{FORMAT_LABEL[t.formato]}</td>
                        <td className="text-right">{t.qtd}</td>
                        <td className="text-right">{fmtNum(t.views)}</td>
                        <td className="text-right">{t.temComentario ? fmtNum(t.comentarios) : "—"}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>

            {/* Rodapé — traço onde a rede não reporta o dado, nunca zero.
                Zero se lê como "caiu pra nada"; traço se lê como "não vem". */}
            <div className="grid grid-cols-4 gap-1 pt-2 border-t text-center">
              {[
                { v: temDadosDePost ? fmtNum(qtdPosts) : "—", r: "posts" },
                { v: alcance > 0 ? fmtNum(alcance) : "—", r: rotuloDeAudiencia(plataforma) },
                { v: alcance > 0 ? fmtPct(engaj) : "—", r: "engaj." },
                { v: fmtNum(leads), r: "leads" },
              ].map((x) => (
                <div key={x.r}>
                  <p className={`text-xs font-bold tabular-nums ${x.v === "—" ? "text-muted-foreground/50" : ""}`}>{x.v}</p>
                  <p className="text-[9px] text-muted-foreground">{x.r}</p>
                </div>
              ))}
            </div>

            {conta?.profile_url && (
              <a
                href={conta.profile_url}
                target="_blank"
                rel="noopener noreferrer"
                onClick={(e) => e.stopPropagation()}
                className="text-[10px] text-muted-foreground hover:text-foreground flex items-center gap-1"
              >
                @{conta.username || conta.display_name} <ExternalLink className="h-2.5 w-2.5" />
              </a>
            )}
          </>
        )}
      </CardContent>
    </Card>
  );
}
