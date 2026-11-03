import { useAuth } from "@/contexts/AuthContext";
import { useEffect, useMemo, useState, useRef } from "react";
import { Link } from "react-router-dom";
import { format } from "date-fns";
import { ptBR } from "date-fns/locale";
import { AppLayout } from "@/components/layout/AppLayout";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { useToast } from "@/hooks/use-toast";
import { Radio, RefreshCw, Instagram, CalendarIcon } from "lucide-react";
import { getDateRange, type DateRange, type DateRangePreset } from "@/hooks/useMarketingDashboard";
import {
  useSocialAccounts, useSocialDaily, useSocialLeads, useSocialPosts, useSyncSocial,
  diaISO, type Platform,
} from "@/hooks/useSocialPanel";
import { SocialKPIs } from "@/components/social/SocialKPIs";
import { SocialNetworkCards } from "@/components/social/SocialNetworkCards";
import { SocialContentList } from "@/components/social/SocialContentList";
import { SocialReachChart, SocialBestTimes } from "@/components/social/SocialCharts";


const PRESETS: { value: DateRangePreset; label: string }[] = [
  { value: "today", label: "Hoje" },
  { value: "yesterday", label: "Ontem" },
  { value: "7d", label: "7 dias" },
  { value: "30d", label: "30 dias" },
  { value: "90d", label: "90 dias" },
  { value: "6m", label: "6 meses" },
  { value: "1y", label: "1 ano" },
  { value: "all", label: "Tudo" },
];

const STORAGE_KEY = "social_panel_preset";

function carregarPreset(): DateRangePreset {
  try {
    const salvo = localStorage.getItem(STORAGE_KEY) as DateRangePreset | null;
    if (salvo && PRESETS.some((p) => p.value === salvo)) return salvo;
  } catch { /* localStorage bloqueado: cai no padrão */ }
  return "30d";
}

export default function SocialCommand() {
  const [preset, setPreset] = useState<DateRangePreset>(carregarPreset);
  const [personalizado, setPersonalizado] = useState<{ from?: Date; to?: Date }>({});
  const [calendarioAberto, setCalendarioAberto] = useState(false);
  const [rede, setRede] = useState<Platform | null>(null);
  const { toast } = useToast();

  useEffect(() => {
    // "custom" não é reconstituível sem as datas, então só persistimos presets.
    if (preset !== "custom") {
      try { localStorage.setItem(STORAGE_KEY, preset); } catch { /* ignora */ }
    }
  }, [preset]);

  // Recalcula só quando o recorte muda — sem isso um objeto novo a cada render
  // invalidaria as queries continuamente.
  const range: DateRange = useMemo(
    () =>
      preset === "custom" && personalizado.from && personalizado.to
        ? { from: personalizado.from, to: personalizado.to }
        : getDateRange(preset),
    [preset, personalizado.from, personalizado.to]
  );

  const { data: accounts, isLoading: loadContas, error: accountsError } = useSocialAccounts();
  const { data: daily, isLoading: loadDaily, error: dailyError } = useSocialDaily(range);
  const { data: posts, isLoading: loadPosts, error: postsError } = useSocialPosts(range);
  const { data: leads } = useSocialLeads(range);
  const sync = useSyncSocial();
  const { tenantId, isAdmin } = useAuth();
  const syncedTenant = useRef<string | null>(null);
  useEffect(() => {
    if (!tenantId || !isAdmin || syncedTenant.current === tenantId) return;
    syncedTenant.current = tenantId;
    sync.mutate();
  }, [tenantId, isAdmin, sync.mutate]);

  // Os cards e gráficos mostram só o período escolhido; a série vem maior porque
  // os KPIs precisam do período anterior pra comparar.
  const dailyDoPeriodo = useMemo(() => {
    const de = diaISO(range.from);
    const ate = diaISO(range.to);
    return (daily || []).filter((d) => d.metric_date >= de && d.metric_date <= ate);
  }, [daily, range]);

  function sincronizar() {
    sync.mutate(undefined, {
      onSuccess: (d: any) =>
        toast({
          title: d.warnings?.length ? "Sincronização incompleta" : "Redes sincronizadas",
          description: d.warnings?.length ? `Confira a conexão de: ${d.warnings.join(", ")}. Alguns dados não puderam ser atualizados.` : `${d.posts} conteúdos · ${d.dias} dias de métricas · ${d.contas} contas`,
        }),
      onError: (e) =>
        toast({ title: "Erro ao sincronizar", description: String(e), variant: "destructive" }),
    });
  }

  const mesmoDia = diaISO(range.from) === diaISO(range.to);
  const legendaPeriodo = mesmoDia
    ? format(range.from, "dd 'de' MMMM", { locale: ptBR })
    : `${format(range.from, "dd MMM", { locale: ptBR })} – ${format(range.to, "dd MMM yyyy", { locale: ptBR })}`;

  return (
    <AppLayout>
      <div className="space-y-5">
        {/* Cabeçalho */}
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-gradient-to-br from-orange-500 to-pink-500 rounded-lg">
              <Radio className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-2xl font-bold">Redes sociais</h1>
              <p className="text-sm text-muted-foreground">
                Instagram, YouTube, LinkedIn e TikTok · {legendaPeriodo}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2 flex-wrap justify-end">
            <div className="flex gap-1 flex-wrap">
              {PRESETS.map((p) => (
                <Button
                  key={p.value}
                  size="sm"
                  variant={preset === p.value ? "default" : "outline"}
                  className="h-8 text-xs"
                  onClick={() => setPreset(p.value)}
                >
                  {p.label}
                </Button>
              ))}

              <Popover open={calendarioAberto} onOpenChange={setCalendarioAberto}>
                <PopoverTrigger asChild>
                  <Button
                    size="sm"
                    variant={preset === "custom" ? "default" : "outline"}
                    className="h-8 text-xs gap-1.5"
                  >
                    <CalendarIcon className="h-3.5 w-3.5" />
                    {preset === "custom" ? legendaPeriodo : "Escolher datas"}
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-auto p-0" align="end">
                  <Calendar
                    mode="range"
                    selected={personalizado.from ? { from: personalizado.from, to: personalizado.to } : undefined}
                    onSelect={(r) => {
                      if (r?.from) setPersonalizado({ from: r.from, to: r.to });
                      // Só aplica com as duas pontas: com uma só, o intervalo
                      // ficaria aberto e as consultas rodariam com dado pela metade.
                      if (r?.from && r?.to) {
                        setPreset("custom");
                        setCalendarioAberto(false);
                      }
                    }}
                    // Abre no mês anterior + o atual. Sem isso o react-day-picker
                    // começa no mês corrente e o segundo painel fica todo no futuro,
                    // desabilitado — metade do calendário virava espaço morto.
                    defaultMonth={new Date(new Date().getFullYear(), new Date().getMonth() - 1, 1)}
                    disabled={{ after: new Date() }}
                    locale={ptBR}
                    numberOfMonths={2}
                  />
                </PopoverContent>
              </Popover>
            </div>

            <Button asChild size="sm" variant="ghost" className="h-8 text-xs gap-1.5">
              <Link to="/configuracoes?s=zernio">
                <Instagram className="h-3.5 w-3.5" />
                Conectar redes
              </Link>
            </Button>
            <Button size="sm" variant="ghost" className="h-8 text-xs gap-1.5" onClick={sincronizar} disabled={sync.isPending || !isAdmin}>
              <RefreshCw className={`h-3.5 w-3.5 ${sync.isPending ? "animate-spin" : ""}`} />
              {sync.isPending ? "Sincronizando…" : "Sincronizar"}
            </Button>
          </div>
        </div>

        {(accountsError || dailyError || postsError) && <p role="alert" className="text-sm text-destructive">Não foi possível carregar suas redes. Recarregue a página para tentar novamente.</p>}
        <p className="text-xs text-muted-foreground">A sincronização busca até 90 dias de conteúdos. O histórico salvo permanece disponível nos filtros.</p>
        {(accounts?.length === 0) && <div className="rounded-xl border p-6 text-sm text-muted-foreground">Conecte suas redes para acompanhar seus conteúdos e resultados. As métricas serão carregadas automaticamente.</div>}
        {sync.isError && <p role="alert" className="text-sm text-destructive">Não foi possível atualizar as métricas. Confira a conexão da conta e tente sincronizar novamente.</p>}
        {!loadDaily && !sync.isPending && !!accounts?.length && !dailyDoPeriodo.length && <p className="text-sm text-muted-foreground">A rede ainda não disponibilizou o histórico diário deste período. As métricas acumuladas dos conteúdos aparecem abaixo.</p>}
        <SocialKPIs
          daily={daily}
          posts={posts}
          leads={leads}
          range={range}
          isLoading={loadDaily || loadPosts}
        />

        <SocialNetworkCards
          accounts={accounts}
          posts={posts}
          daily={dailyDoPeriodo}
          leads={leads}
          isLoading={loadContas || loadDaily}
          onSelecionarRede={(p) => setRede((atual) => (atual === p ? null : p))}
        />

        <SocialContentList
          posts={posts}
          isLoading={loadPosts}
          rede={rede}
          onMudarRede={setRede}
        />

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <SocialReachChart daily={dailyDoPeriodo} isLoading={loadDaily} />
          <SocialBestTimes posts={posts} isLoading={loadPosts} />
        </div>
      </div>


    </AppLayout>
  );
}
