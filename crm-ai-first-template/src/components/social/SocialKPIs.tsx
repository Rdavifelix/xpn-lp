import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { TrendingUp, TrendingDown, Eye, Heart, PlayCircle, UserPlus, Target, Info } from "lucide-react";
import type { DailyMetric, DateRange, SocialPost } from "@/hooks/useSocialPanel";
import { diaISO, periodoAnterior } from "@/hooks/useSocialPanel";
import { audiencia, fmtNum, fmtPct, fmtVariacao, variacao } from "./shared";

interface Props {
  daily: DailyMetric[] | undefined;
  posts: SocialPost[] | undefined;
  leads: Record<string, { leads: number; qualificados: number }> | undefined;
  range: DateRange;
  isLoading: boolean;
}

/**
 * 5 indicadores do topo. Cada um compara o período escolhido com o período
 * imediatamente anterior de mesmo tamanho — é a única comparação honesta quando
 * o usuário troca entre 7/30/90 dias.
 */
export function SocialKPIs({ daily, posts, leads, range, isLoading }: Props) {
  if (isLoading) {
    return (
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
        {Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="h-[104px]" />)}
      </div>
    );
  }

  const linhas = daily || [];
  const inicio = diaISO(range.from);
  const fim = diaISO(range.to);
  const janelaAnterior = periodoAnterior(range);
  const inicioAnterior = diaISO(janelaAnterior.from);

  const atual = linhas.filter((d) => d.metric_date >= inicio && d.metric_date <= fim);
  const anterior = linhas.filter((d) => d.metric_date >= inicioAnterior && d.metric_date < inicio);

  const soma = (arr: DailyMetric[], campo: keyof DailyMetric) =>
    arr.reduce((s, d) => s + Number(d[campo] || 0), 0);

  // Alcance real onde a rede reporta; views onde não reporta (YouTube, TikTok).
  const somaAudiencia = (arr: DailyMetric[]) =>
    arr.reduce((s, d) => s + audiencia(d.platform, Number(d.reach || 0), Number(d.views || 0)), 0);
  const alcance = somaAudiencia(atual);
  const alcanceAnt = somaAudiencia(anterior);
  const views = soma(atual, "views");
  const viewsAnt = soma(anterior, "views");

  const interacoes = soma(atual, "likes") + soma(atual, "comments") + soma(atual, "shares") + soma(atual, "saves");
  const interacoesAnt = soma(anterior, "likes") + soma(anterior, "comments") + soma(anterior, "shares") + soma(anterior, "saves");
  const engaj = alcance ? (interacoes / alcance) * 100 : 0;
  const engajAnt = alcanceAnt ? (interacoesAnt / alcanceAnt) * 100 : 0;

  // Seguidores: diferença entre o primeiro e o último ponto de cada rede no período.
  const ganhoSeguidores = (janela: DailyMetric[]) => {
    const porRede = new Map<string, { primeiro: number; ultimo: number }>();
    for (const d of janela) {
      if (d.followers == null) continue;
      const atualRede = porRede.get(d.platform);
      if (!atualRede) porRede.set(d.platform, { primeiro: d.followers, ultimo: d.followers });
      else atualRede.ultimo = d.followers;
    }
    return [...porRede.values()].reduce((s, v) => s + (v.ultimo - v.primeiro), 0);
  };
  const novos = ganhoSeguidores(atual);
  const novosAnt = ganhoSeguidores(anterior);

  const totalLeads = Object.values(leads || {}).reduce((s, v) => s + v.leads, 0);
  const publicados = (posts || []).filter((p) => !p.is_story_snapshot).length;

  const cards = [
    {
      icone: Eye, cor: "text-sky-600", rotulo: "Alcance total",
      valor: atual.length ? fmtNum(alcance) : "—", delta: atual.length && anterior.length ? variacao(alcance, alcanceAnt) : null,
      nota: "alcance no IG · views no YouTube e TikTok",
    },
    {
      icone: Heart, cor: "text-rose-600", rotulo: "Engajamento",
      valor: atual.length && alcance ? fmtPct(engaj) : "—", delta: engajAnt ? engaj - engajAnt : null, deltaEmPontos: true,
      nota: "interações ÷ alcance",
    },
    {
      icone: PlayCircle, cor: "text-violet-600", rotulo: "Visualizações",
      valor: atual.length ? fmtNum(views) : "—", delta: atual.length && anterior.length ? variacao(views, viewsAnt) : null,
      nota: `${publicados} conteúdos no período`,
    },
    {
      icone: UserPlus, cor: "text-emerald-600", rotulo: "Novos seguidores",
      valor: atual.filter(d=>d.followers!=null).length>1 ? (novos >= 0 ? "+" : "−") + fmtNum(Math.abs(novos)) : "—", delta: variacao(novos, novosAnt),
      nota: "saldo do período",
    },
    {
      icone: Target, cor: "text-amber-600", rotulo: "Leads gerados",
      valor: fmtNum(totalLeads), delta: null,
      nota: "atribuídos por UTM no CRM",
      ajuda: "Nenhuma API de rede social entrega lead nem clique por post — o número vem do utm_source dos leads no próprio CRM.",
    },
  ];

  return (
    <TooltipProvider>
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
        {cards.map((c) => {
          const Icone = c.icone;
          const subiu = (c.delta ?? 0) >= 0;
          return (
            <Card key={c.rotulo}>
              <CardContent className="p-4">
                <div className="flex items-center gap-2 mb-2">
                  <Icone className={`h-4 w-4 ${c.cor}`} />
                  <span className="text-xs font-medium text-muted-foreground">{c.rotulo}</span>
                  {c.ajuda && (
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-3 w-3 text-muted-foreground/60 shrink-0" />
                      </TooltipTrigger>
                      <TooltipContent className="max-w-[240px] text-xs">{c.ajuda}</TooltipContent>
                    </Tooltip>
                  )}
                </div>
                <div className="flex items-baseline gap-2 flex-wrap">
                  <span className="text-2xl font-bold tabular-nums">{c.valor}</span>
                  {c.delta != null && (
                    <span className={`text-xs font-semibold flex items-center gap-0.5 ${subiu ? "text-emerald-600" : "text-rose-600"}`}>
                      {subiu ? <TrendingUp className="h-3 w-3" /> : <TrendingDown className="h-3 w-3" />}
                      {fmtVariacao(c.delta, c.deltaEmPontos)}
                    </span>
                  )}
                </div>
                <p className="text-[11px] text-muted-foreground mt-1">{c.nota}</p>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </TooltipProvider>
  );
}
