import { useMemo } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { ResponsiveContainer, AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip as ReTooltip, Legend } from "recharts";
import { Clock } from "lucide-react";
import type { DailyMetric, SocialPost } from "@/hooks/useSocialPanel";
import { PLATFORMS } from "@/hooks/useSocialPanel";
import { PLATFORM_COLOR, PLATFORM_LABEL, audiencia, fmtNum, fmtPct } from "./shared";

/** Alcance dia a dia, empilhado por rede. */
export function SocialReachChart({ daily, isLoading }: { daily: DailyMetric[] | undefined; isLoading: boolean }) {
  const dados = useMemo(() => {
    const porDia = new Map<string, any>();
    for (const d of daily || []) {
      const linha = porDia.get(d.metric_date) || { data: d.metric_date };
      linha[d.platform] = (linha[d.platform] || 0) + audiencia(d.platform, Number(d.reach || 0), Number(d.views || 0));
      porDia.set(d.metric_date, linha);
    }
    return [...porDia.values()].sort((a, b) => a.data.localeCompare(b.data));
  }, [daily]);

  if (isLoading) {
    return <Card><CardHeader><CardTitle className="text-base">Audiência por rede</CardTitle></CardHeader><CardContent><Skeleton className="h-[260px]" /></CardContent></Card>;
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-base">Audiência por rede</CardTitle>
        <p className="text-xs text-muted-foreground">Alcance por dia no Instagram e LinkedIn · views no YouTube e TikTok, que não reportam alcance</p>
      </CardHeader>
      <CardContent>
        {dados.length < 2 ? (
          <p className="text-sm text-muted-foreground text-center py-16">Dados insuficientes no período</p>
        ) : (
          <ResponsiveContainer width="100%" height={260}>
            <AreaChart data={dados} margin={{ top: 5, right: 8, left: -12, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" className="stroke-muted" vertical={false} />
              <XAxis
                dataKey="data" tick={{ fontSize: 10 }} tickLine={false} axisLine={false}
                tickFormatter={(v) => new Date(v + "T00:00:00").toLocaleDateString("pt-BR", { day: "2-digit", month: "short" })}
                minTickGap={28}
              />
              <YAxis tick={{ fontSize: 10 }} tickLine={false} axisLine={false} tickFormatter={(v) => fmtNum(v)} width={52} />
              <ReTooltip
                contentStyle={{ fontSize: 12, borderRadius: 8, background: "hsl(var(--popover))", border: "1px solid hsl(var(--border))", color: "hsl(var(--popover-foreground))" }}
                labelFormatter={(v) => new Date(v + "T00:00:00").toLocaleDateString("pt-BR", { day: "2-digit", month: "long" })}
                formatter={(valor: any, nome: any) => [fmtNum(Number(valor)), PLATFORM_LABEL[nome as keyof typeof PLATFORM_LABEL] ?? nome]}
              />
              <Legend wrapperStyle={{ fontSize: 11 }} formatter={(v) => PLATFORM_LABEL[v as keyof typeof PLATFORM_LABEL] ?? v} />
              {PLATFORMS.map((p) => (
                <Area key={p} type="monotone" dataKey={p} stackId="1" stroke={PLATFORM_COLOR[p]} fill={PLATFORM_COLOR[p]} fillOpacity={0.22} strokeWidth={1.5} />
              ))}
            </AreaChart>
          </ResponsiveContainer>
        )}
      </CardContent>
    </Card>
  );
}

const DIAS = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];
const FAIXAS = [
  { rotulo: "00-06", de: 0, ate: 6 },
  { rotulo: "06-09", de: 6, ate: 9 },
  { rotulo: "09-12", de: 9, ate: 12 },
  { rotulo: "12-15", de: 12, ate: 15 },
  { rotulo: "15-18", de: 15, ate: 18 },
  { rotulo: "18-21", de: 18, ate: 21 },
  { rotulo: "21-24", de: 21, ate: 24 },
];

/**
 * Mapa de calor dia × faixa horária, medido em views médias por post.
 * Média (e não soma) porque senão o horário em que se publica mais sempre vence,
 * o que responde "quando eu posto" em vez de "quando funciona".
 */
export function SocialBestTimes({ posts, isLoading }: { posts: SocialPost[] | undefined; isLoading: boolean }) {
  const { celulas, melhor } = useMemo(() => {
    const acc = new Map<string, { soma: number; n: number }>();
    for (const p of posts || []) {
      if (!p.published_at || p.is_story_snapshot) continue;
      const d = new Date(p.published_at);
      const faixa = FAIXAS.findIndex((f) => d.getHours() >= f.de && d.getHours() < f.ate);
      if (faixa < 0) continue;
      const k = `${d.getDay()}|${faixa}`;
      const at = acc.get(k) || { soma: 0, n: 0 };
      at.soma += Number(p.views || p.reach || 0);
      at.n += 1;
      acc.set(k, at);
    }
    const celulas = new Map<string, { media: number; n: number }>();
    let melhor: { dia: number; faixa: number; media: number; n: number } | null = null;
    for (const [k, v] of acc) {
      const media = v.soma / v.n;
      celulas.set(k, { media, n: v.n });
      // 2 posts é o mínimo pra não coroar um acaso.
      if (v.n >= 2 && (!melhor || media > melhor.media)) {
        const [dia, faixa] = k.split("|").map(Number);
        melhor = { dia, faixa, media, n: v.n };
      }
    }
    return { celulas, melhor };
  }, [posts]);

  if (isLoading) {
    return <Card><CardHeader><CardTitle className="text-base">Melhor horário pra postar</CardTitle></CardHeader><CardContent><Skeleton className="h-[260px]" /></CardContent></Card>;
  }

  const maxMedia = Math.max(...[...celulas.values()].map((c) => c.media), 1);

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-base flex items-center gap-2">
          <Clock className="h-4 w-4 text-muted-foreground" />
          Melhor horário pra postar
        </CardTitle>
        <p className="text-xs text-muted-foreground">Views médias por post — não o total, pra não premiar só o horário mais usado</p>
      </CardHeader>
      <CardContent>
        {celulas.size === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-16">Sem conteúdo suficiente no período</p>
        ) : (
          <>
            <div className="overflow-x-auto">
              <div className="min-w-[420px]">
                <div className="grid grid-cols-[42px_repeat(7,1fr)] gap-1 mb-1">
                  <span />
                  {FAIXAS.map((f) => (
                    <span key={f.rotulo} className="text-[9px] text-muted-foreground text-center">{f.rotulo}</span>
                  ))}
                </div>
                {DIAS.map((nome, dia) => (
                  <div key={nome} className="grid grid-cols-[42px_repeat(7,1fr)] gap-1 mb-1">
                    <span className="text-[10px] text-muted-foreground self-center">{nome}</span>
                    {FAIXAS.map((f, faixa) => {
                      const c = celulas.get(`${dia}|${faixa}`);
                      const intensidade = c ? c.media / maxMedia : 0;
                      const destaque = melhor && melhor.dia === dia && melhor.faixa === faixa;
                      return (
                        <div
                          key={f.rotulo}
                          title={c ? `${nome} ${f.rotulo}h · ${fmtNum(Math.round(c.media))} views médias · ${c.n} ${c.n === 1 ? "post" : "posts"}` : `${nome} ${f.rotulo}h · sem post`}
                          className={`h-7 rounded-sm ${destaque ? "ring-2 ring-orange-500" : ""}`}
                          style={{
                            backgroundColor: c ? `hsl(var(--primary) / ${0.12 + intensidade * 0.85})` : "hsl(var(--muted))",
                          }}
                        />
                      );
                    })}
                  </div>
                ))}
              </div>
            </div>
            {melhor && (
              <p className="text-xs text-muted-foreground mt-3">
                Melhor janela: <strong className="text-foreground">{DIAS[melhor.dia]} das {FAIXAS[melhor.faixa].rotulo}h</strong>
                {" "}· {fmtNum(Math.round(melhor.media))} views médias em {melhor.n} posts
              </p>
            )}
          </>
        )}
      </CardContent>
    </Card>
  );
}
