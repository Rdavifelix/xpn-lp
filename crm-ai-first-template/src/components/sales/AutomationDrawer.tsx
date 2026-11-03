import { useState, useEffect } from "react";
import { Plus, X, ChevronDown } from "lucide-react";
import { Sheet, SheetContent } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Switch } from "@/components/ui/switch";
import { Separator } from "@/components/ui/separator";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import {
  useSaveAutomation,
  ACTION_LABELS,
  TRIGGER_LABELS,
  type SocialSellingAutomation,
  type CadenceDay,
  type CadenceAction,
} from "@/hooks/useSocialSellingAutomations";
import { supabase } from "@/lib/supabase";
import { useQuery } from "@tanstack/react-query";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  automation: SocialSellingAutomation;
}

const ACTION_TYPES: Array<keyof typeof ACTION_LABELS> = [
  "reagir_story",
  "responder_story",
  "curtir_posts",
  "comentar_post",
  "enviar_dm",
  "verificar_resposta",
  "followup_story",
];

export function AutomationDrawer({ open, onOpenChange, automation }: Props) {
  const save = useSaveAutomation();
  const [local, setLocal] = useState(automation);

  useEffect(() => {
    setLocal(automation);
  }, [automation]);

  // Pipeline stages para os selects (trigger — com pipeline_id pra derivação)
  const { data: stages = [] } = useQuery({
    queryKey: ["pipeline-stages-all"],
    queryFn: async () => {
      const { data } = await supabase
        .from("sales_pipeline_stages")
        .select("id, name, position, pipeline_id")
        .order("position");
      return data || [];
    },
  });

  // Pipelines + stages do tenant pra mapeamento destino (trigger=new_follower)
  const { data: pipelines = [] } = useQuery({
    queryKey: ["pipelines-with-stages"],
    queryFn: async () => {
      const { data } = await supabase
        .from("sales_pipelines")
        .select("id, name, position, sales_pipeline_stages(id, name, position)")
        .order("position");
      return (data || []).map((p: any) => ({
        ...p,
        stages: (p.sales_pipeline_stages || []).sort((a: any, b: any) => (a.position || 0) - (b.position || 0)),
      }));
    },
  });

  // Pra trigger=new_follower: aluno escolhe pipeline + etapas
  const targetPipelineId = local.trigger_config?.target_pipeline_id || "";
  const targetStages = (pipelines.find((p: any) => p.id === targetPipelineId)?.stages) || [];

  // Pra trigger=stage_change: pipeline_id é explícito no trigger_config (dropdown próprio)
  // Fallback: deriva da stage caso seja config legada que não tinha pipeline_id
  const triggerStagePipelineId =
    local.trigger_config?.pipeline_id ||
    stages.find((s: any) => s.id === local.trigger_config?.stage_id)?.pipeline_id;
  const sameLineStages = triggerStagePipelineId
    ? (pipelines.find((p: any) => p.id === triggerStagePipelineId)?.stages || [])
    : [];

  const handleSave = async () => {
    try {
      await save.mutateAsync(local as any);
      toast.success("Automação salva");
      onOpenChange(false);
    } catch (e: any) {
      toast.error(`Erro: ${e.message}`);
    }
  };

  const updateTrigger = (config: any) => {
    setLocal({ ...local, trigger_config: { ...local.trigger_config, ...config } });
  };

  const addDay = () => {
    const days = [...(local.cadence_config.days || [])];
    const lastDay = days.length > 0 ? Math.max(...days.map((d) => d.day)) : 0;
    days.push({ day: lastDay + 1, actions: [{ type: "reagir_story" }] });
    setLocal({ ...local, cadence_config: { days } });
  };

  const removeDay = (idx: number) => {
    const days = local.cadence_config.days.filter((_, i) => i !== idx);
    setLocal({ ...local, cadence_config: { days } });
  };

  const updateDay = (idx: number, patch: Partial<CadenceDay>) => {
    const days = local.cadence_config.days.map((d, i) => (i === idx ? { ...d, ...patch } : d));
    setLocal({ ...local, cadence_config: { days } });
  };

  const addAction = (dayIdx: number) => {
    const day = local.cadence_config.days[dayIdx];
    updateDay(dayIdx, { actions: [...day.actions, { type: "reagir_story" }] });
  };

  const removeAction = (dayIdx: number, actionIdx: number) => {
    const day = local.cadence_config.days[dayIdx];
    updateDay(dayIdx, { actions: day.actions.filter((_, i) => i !== actionIdx) });
  };

  const updateAction = (dayIdx: number, actionIdx: number, patch: Partial<CadenceAction>) => {
    const day = local.cadence_config.days[dayIdx];
    updateDay(dayIdx, {
      actions: day.actions.map((a, i) => (i === actionIdx ? { ...a, ...patch } : a)),
    });
  };

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="w-full sm:max-w-3xl p-0 flex flex-col gap-0 overflow-hidden">
        {/* HEADER STICKY — nome+emoji+ativa */}
        <div className="px-6 py-4 border-b shrink-0 bg-background">
          <div className="flex items-center gap-3">
            <Input
              value={local.emoji}
              onChange={(e) => setLocal({ ...local, emoji: e.target.value })}
              className="w-14 h-12 text-2xl text-center shrink-0"
              maxLength={2}
            />
            <Input
              value={local.name}
              onChange={(e) => setLocal({ ...local, name: e.target.value })}
              placeholder="Nome da automação (ex: Aquecer médicos)"
              className="flex-1 h-12 text-base font-medium"
            />
            <div className="flex items-center gap-2 pl-2 border-l">
              <Label htmlFor="active-toggle" className="text-xs cursor-pointer">
                {local.is_active ? "Ativa" : "Pausada"}
              </Label>
              <Switch
                id="active-toggle"
                checked={local.is_active}
                onCheckedChange={(v) => setLocal({ ...local, is_active: v })}
              />
            </div>
          </div>
        </div>

        {/* TABS */}
        <Tabs defaultValue="trigger" className="flex-1 flex flex-col overflow-hidden">
          <div className="px-6 pt-3 shrink-0 border-b bg-muted/30">
            <TabsList className="bg-transparent h-auto p-0 gap-2">
              <TabsTrigger value="trigger" className="data-[state=active]:bg-background data-[state=active]:shadow-sm">⚡ Disparo & Destino</TabsTrigger>
              <TabsTrigger value="cadence" className="data-[state=active]:bg-background data-[state=active]:shadow-sm">📅 Cadência</TabsTrigger>
              <TabsTrigger value="approval" className="data-[state=active]:bg-background data-[state=active]:shadow-sm">✋ Aprovação</TabsTrigger>
              <TabsTrigger value="advanced" className="data-[state=active]:bg-background data-[state=active]:shadow-sm">💬 Pós-resposta</TabsTrigger>
            </TabsList>
          </div>

          <div className="flex-1 overflow-y-auto px-6 py-5">

            {/* ABA 1 — Disparo & Destino */}
            <TabsContent value="trigger" className="mt-0 space-y-6">

          <TabIntro
            title="Disparo & Destino"
            description="Define o ponto de partida da cadência. Aqui você decide: (1) quando o lead começa a receber as ações — pode ser quando um seguidor novo aparece no IG ou quando alguém entra numa etapa específica do seu pipeline; (2) pra qual pipeline/etapa o lead vai cair durante e depois da cadência."
          />

          {/* TRIGGER */}
          <div className="space-y-3">
            <Label className="text-xs uppercase tracking-wide text-muted-foreground">
              ⚡ Quando dispara
            </Label>
            <Select
              value={local.trigger_type}
              onValueChange={(v: any) => setLocal({ ...local, trigger_type: v, trigger_config: {} })}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {Object.entries(TRIGGER_LABELS).map(([k, v]) => (
                  <SelectItem key={k} value={k}>
                    {v}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>

            {/* Config específica por trigger */}
            {local.trigger_type === "stage_change" && (
              <div className="pl-3 border-l-2 border-primary/30 space-y-3">
                {/* 1º: escolhe pipeline */}
                <div>
                  <Label className="text-xs">Pipeline</Label>
                  <Select
                    value={local.trigger_config?.pipeline_id || "__none__"}
                    onValueChange={(v) => {
                      if (v === "__none__") return;
                      // Reset stage quando troca pipeline
                      updateTrigger({ pipeline_id: v, stage_id: null, stage_name: null });
                    }}
                  >
                    <SelectTrigger className="mt-1">
                      <SelectValue placeholder="Escolha o pipeline" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__none__" disabled>Selecione o pipeline...</SelectItem>
                      {pipelines.map((p: any) => (
                        <SelectItem key={p.id} value={p.id}>{p.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* 2º: escolhe etapa (só do pipeline acima) */}
                {local.trigger_config?.pipeline_id && (
                  <div>
                    <Label className="text-xs">Etapa que dispara a cadência</Label>
                    <Select
                      value={local.trigger_config?.stage_id || "__none__"}
                      onValueChange={(v) => {
                        if (v === "__none__") return;
                        const stages = pipelines.find((p: any) => p.id === local.trigger_config?.pipeline_id)?.stages || [];
                        const stage = stages.find((s: any) => s.id === v);
                        updateTrigger({ stage_id: v, stage_name: stage?.name });
                      }}
                    >
                      <SelectTrigger className="mt-1">
                        <SelectValue placeholder="Escolha a etapa" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="__none__" disabled>Selecione a etapa...</SelectItem>
                        {(pipelines.find((p: any) => p.id === local.trigger_config?.pipeline_id)?.stages || []).map((s: any) => (
                          <SelectItem key={s.id} value={s.id}>{s.name}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                )}
              </div>
            )}

            {local.trigger_type === "new_follower" && (
              <div className="pl-3 border-l-2 border-primary/30">
                <Label className="text-xs">Frequência da varredura</Label>
                <Select
                  value={local.trigger_config.scan_frequency || "daily"}
                  onValueChange={(v) => updateTrigger({ scan_frequency: v })}
                >
                  <SelectTrigger className="mt-1">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="daily">1x ao dia</SelectItem>
                    <SelectItem value="hourly">A cada hora</SelectItem>
                    <SelectItem value="weekly">1x por semana</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            )}
          </div>

          <Separator />

          {/* CENÁRIO A — Lead NOVO criado do Instagram (new_follower) */}
          {local.trigger_type === "new_follower" && (
            <>
              <div className="space-y-3">
                <Label className="text-xs uppercase tracking-wide text-muted-foreground">
                  🧱 Pipeline destino & mapeamento de etapas
                </Label>
                <p className="text-xs text-muted-foreground">
                  Os leads novos que a IA qualificar vão cair neste pipeline. Mapeie as etapas que quiser.
                </p>

                <div className="space-y-2">
                  <Label className="text-xs">🎯 Pipeline destino</Label>
                  <Select
                    value={targetPipelineId || "__none__"}
                    onValueChange={(v) => {
                      if (v === "__none__") return;
                      updateTrigger({
                        target_pipeline_id: v,
                        target_stage_id: null,
                        stage_warming_id: null,
                        stage_dm_sent_id: null,
                        stage_replied_id: null,
                      });
                    }}
                  >
                    <SelectTrigger><SelectValue placeholder="Selecione o pipeline" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__none__" disabled>Selecione...</SelectItem>
                      {pipelines.map((p: any) => (
                        <SelectItem key={p.id} value={p.id}>{p.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {targetPipelineId && (
                  <div className="space-y-3 pl-3 border-l-2 border-primary/30">
                    <StageDropdown
                      label="🆕 Etapa inicial (lead recém qualificado)"
                      placeholder="Primeira etapa do pipeline"
                      value={local.trigger_config?.target_stage_id}
                      stages={targetStages}
                      onChange={(v) => updateTrigger({ target_stage_id: v })}
                    />
                    <StageDropdown
                      label="🔥 Quando engajar (curtir/comentar/reagir story)"
                      placeholder="Não move automaticamente"
                      value={local.trigger_config?.stage_warming_id}
                      stages={targetStages}
                      onChange={(v) => updateTrigger({ stage_warming_id: v })}
                    />
                    <StageDropdown
                      label="📩 Quando enviar DM"
                      placeholder="Não move automaticamente"
                      value={local.trigger_config?.stage_dm_sent_id}
                      stages={targetStages}
                      onChange={(v) => updateTrigger({ stage_dm_sent_id: v })}
                    />
                    <StageDropdown
                      label="✅ Quando lead responder"
                      placeholder="Não move automaticamente"
                      value={local.trigger_config?.stage_replied_id}
                      stages={targetStages}
                      onChange={(v) => updateTrigger({ stage_replied_id: v })}
                    />
                  </div>
                )}
              </div>
              <Separator />
            </>
          )}

          {/* CENÁRIO B — Lead JÁ EXISTE (stage_change ou manual) */}
          {local.trigger_type === "stage_change" && (
            <>
              <div className="space-y-3">
                <Label className="text-xs uppercase tracking-wide text-muted-foreground">
                  🔄 Movimento de etapas durante a cadência
                </Label>
                <p className="text-xs text-muted-foreground">
                  O lead <strong>já está</strong> no pipeline {triggerStagePipelineId ? `desta etapa` : "(escolha a etapa de trigger acima)"}.
                  Configure pra qual etapa do mesmo pipeline ele move durante a cadência.
                  Deixe vazio se não quiser mover automaticamente.
                </p>

                {!triggerStagePipelineId ? (
                  <p className="text-xs text-amber-600 dark:text-amber-400 pl-3 border-l-2 border-amber/40">
                    ⚠ Escolha primeiro a etapa que dispara a cadência (em "⚡ Quando dispara" acima).
                  </p>
                ) : (
                  <div className="space-y-3 pl-3 border-l-2 border-primary/30">
                    <StageDropdown
                      label="🔥 Quando engajar (curtir/comentar/reagir story)"
                      placeholder="Não move automaticamente"
                      value={local.trigger_config?.stage_warming_id}
                      stages={sameLineStages}
                      onChange={(v) => updateTrigger({ stage_warming_id: v })}
                    />
                    <StageDropdown
                      label="📩 Quando enviar DM"
                      placeholder="Não move automaticamente"
                      value={local.trigger_config?.stage_dm_sent_id}
                      stages={sameLineStages}
                      onChange={(v) => updateTrigger({ stage_dm_sent_id: v })}
                    />
                    <StageDropdown
                      label="✅ Quando lead responder (recomendado: mover pra etapa de quente)"
                      placeholder="Não move automaticamente"
                      value={local.trigger_config?.stage_replied_id}
                      stages={sameLineStages}
                      onChange={(v) => updateTrigger({ stage_replied_id: v })}
                    />
                  </div>
                )}
              </div>
              <Separator />
            </>
          )}

          {/* QUALIFICAÇÃO via IA (texto livre) */}
          {local.trigger_type === "new_follower" && (
            <>
              <div className="space-y-3">
                <Label className="text-xs uppercase tracking-wide text-muted-foreground">
                  🎯 ICP — quem deve virar lead (qualificação IA)
                </Label>
                <p className="text-xs text-muted-foreground">
                  Descreva em texto quem é seu ICP. A IA vai ler bio + posts do seguidor e decidir se ele passa.
                </p>
                <Textarea
                  rows={5}
                  placeholder="Ex: Empresários reais, donos de empresa de serviço (faturamento 50k-1M/mês). Bio mostra cargo (CEO, fundador, dono). Posts mostram trabalho, escritório, viagens de negócio. NÃO quero influencers, modelos, atletas. Mín 500 seguidores."
                  value={local.qualification_config.ai_prompt || ""}
                  onChange={(e) =>
                    setLocal({
                      ...local,
                      qualification_config: {
                        ...local.qualification_config,
                        ai_prompt: e.target.value,
                      },
                    })
                  }
                />
                {local.qualification_config.ai_prompt && (
                  <div className="flex items-center gap-2">
                    <Label className="text-xs whitespace-nowrap">Score mínimo (0-100):</Label>
                    <Input
                      type="number"
                      min={0}
                      max={100}
                      className="w-20 h-8"
                      value={local.qualification_config.ai_score_min || 70}
                      onChange={(e) =>
                        setLocal({
                          ...local,
                          qualification_config: {
                            ...local.qualification_config,
                            ai_score_min: parseInt(e.target.value) || 70,
                          },
                        })
                      }
                    />
                  </div>
                )}
              </div>
            </>
          )}

            </TabsContent>

            {/* ABA 2 — Cadência */}
            <TabsContent value="cadence" className="mt-0 space-y-4">

          <TabIntro
            title="Cadência (dias × ações)"
            description="A sequência de ações que a IA executa pra cada lead. Cada dia tem uma ou mais ações: curtir um post, reagir a story, comentar, enviar DM. Funciona como uma esteira de aquecimento — o lead vai do contato leve (curtir) pro contato direto (DM) ao longo dos dias. Recomendação: comece com 3-5 dias progressivos."
            example="Ex: Dia 1 → reagir story + curtir 2 posts | Dia 2 → comentar 1 post | Dia 3 → enviar DM"
          />

          {/* CADÊNCIA */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <Label className="text-xs uppercase tracking-wide text-muted-foreground">
                📅 Cadência ({local.cadence_config.days?.length || 0} dias × ações)
              </Label>
              <Button size="sm" variant="outline" onClick={addDay}>
                <Plus className="h-3 w-3 mr-1" />
                Adicionar dia
              </Button>
            </div>

            <div className="space-y-3">
              {(local.cadence_config.days || []).map((day, dayIdx) => (
                <div key={dayIdx} className="border rounded-lg p-3 bg-muted/20">
                  <div className="flex items-center gap-2 mb-2">
                    <Badge variant="outline" className="text-xs">
                      DIA {day.day}
                    </Badge>
                    <Input
                      placeholder="Label opcional (ex: 'Aquecimento')"
                      value={day.label || ""}
                      onChange={(e) => updateDay(dayIdx, { label: e.target.value })}
                      className="flex-1 h-7 text-xs"
                    />
                    <Button
                      size="icon"
                      variant="ghost"
                      className="h-7 w-7 text-red-600"
                      onClick={() => removeDay(dayIdx)}
                    >
                      <X className="h-3 w-3" />
                    </Button>
                  </div>

                  <div className="space-y-1.5">
                    {day.actions.map((action, actionIdx) => (
                      <div key={actionIdx} className="flex items-center gap-1.5">
                        <Select
                          value={action.type}
                          onValueChange={(v: any) => updateAction(dayIdx, actionIdx, { type: v })}
                        >
                          <SelectTrigger className="h-8 text-xs flex-1">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            {ACTION_TYPES.map((t) => (
                              <SelectItem key={t} value={t}>
                                {ACTION_LABELS[t]}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                        {action.type === "curtir_posts" && (
                          <Input
                            type="number"
                            min={1}
                            max={5}
                            placeholder="N"
                            className="h-8 w-14 text-xs text-center"
                            value={action.count || 1}
                            onChange={(e) =>
                              updateAction(dayIdx, actionIdx, { count: parseInt(e.target.value) || 1 })
                            }
                          />
                        )}
                        <Button
                          size="icon"
                          variant="ghost"
                          className="h-7 w-7 text-red-600"
                          onClick={() => removeAction(dayIdx, actionIdx)}
                        >
                          <X className="h-3 w-3" />
                        </Button>
                      </div>
                    ))}
                    <Button
                      size="sm"
                      variant="ghost"
                      className="h-7 text-xs w-full"
                      onClick={() => addAction(dayIdx)}
                    >
                      <Plus className="h-3 w-3 mr-1" />
                      Ação
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          </div>

            </TabsContent>

            {/* ABA 3 — Aprovação de ações */}
            <TabsContent value="approval" className="mt-0 space-y-4">

          <TabIntro
            title="Aprovação de ações"
            description="Decida o que a IA executa sozinha vs o que entra em fila pra você revisar antes."
            example="Recomendação: ações sem texto (curtir, reagir story) podem ser AUTO. Ações com texto (comentário, DM) deixe APROVAR — você revê o que a IA escreveu antes de enviar, evitando soar genérico ou cometer gafes."
          />

          {/* APROVAÇÃO DE AÇÕES (por cadência) */}
          <div className="space-y-3">
            <Label className="text-xs uppercase tracking-wide text-muted-foreground">
              ✋ Aprovação de ações
            </Label>
            <p className="text-xs text-muted-foreground">
              <strong>Auto</strong> = executa direto. <strong>Aprovar</strong> = entra em fila pra você revisar o texto antes de enviar.
              Recomendação: textos (DM, comentário) sempre aprovar; engajamento simples (curtir, reagir) pode ser auto.
            </p>
            {[
              { type: "curtir_posts",     label: "👍 Curtir post",         hint: "sem texto, baixo risco — recomenda auto" },
              { type: "reagir_story",     label: "❤️ Reagir story",         hint: "sem texto, baixo risco — recomenda auto" },
              { type: "verificar_resposta", label: "👀 Verificar inbox",    hint: "só leitura — sempre auto" },
              { type: "comentar_post",    label: "🗣️ Comentar post",       hint: "texto público — recomenda aprovar" },
              { type: "responder_story",  label: "💬 Responder story (DM)", hint: "DM privada — recomenda aprovar" },
              { type: "enviar_dm",        label: "📩 Enviar DM frio",       hint: "primeiro contato — recomenda aprovar" },
              { type: "followup_story",   label: "🔄 Follow-up via story",  hint: "DM em resposta a story" },
            ].map((row) => {
              const current = (local.cadence_config as any)?.action_modes?.[row.type] || (row.type.includes("curtir") || row.type.includes("reagir") || row.type.includes("verificar") ? "auto" : "approve");
              return (
                <div key={row.type} className="flex items-center justify-between gap-3 p-2 rounded-md bg-muted/30 border">
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium">{row.label}</p>
                    <p className="text-[10px] text-muted-foreground">{row.hint}</p>
                  </div>
                  <Select
                    value={current}
                    onValueChange={(v: any) => {
                      const modes = { ...((local.cadence_config as any)?.action_modes || {}), [row.type]: v };
                      setLocal({ ...local, cadence_config: { ...local.cadence_config, action_modes: modes } as any });
                    }}
                  >
                    <SelectTrigger className="w-28 h-8 text-xs"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="auto">Auto</SelectItem>
                      <SelectItem value="approve">Aprovar</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              );
            })}
          </div>

            </TabsContent>

            {/* ABA 4 — Pós-resposta */}
            <TabsContent value="advanced" className="mt-0 space-y-4">

          <TabIntro
            title="Pós-resposta"
            description="O que acontece automaticamente quando o lead responder uma DM ou story. É o momento de virar a chave — passar do modo prospecção pra modo vendedor humano."
            example="Ex: mover o lead pra etapa 'Atender já' do pipeline + disparar notificação WhatsApp pro vendedor entrar no chat antes do lead esfriar."
          />


          {/* QUANDO RESPONDER */}
          <div className="space-y-3">
            <Label className="text-xs uppercase tracking-wide text-muted-foreground">
              💬 Outras configurações pós-resposta
            </Label>

            <div className="space-y-3">
              <Label className="text-xs">Mover lead pra etapa quando responder</Label>
              <p className="text-[11px] text-muted-foreground">
                Escolha pipeline e etapa de destino — recomendado uma etapa quente tipo "Atender agora" pra alertar o vendedor.
              </p>

              <div>
                <Label className="text-xs">Pipeline</Label>
                <Select
                  value={local.on_reply_config.move_to_pipeline_id || "__none__"}
                  onValueChange={(v) =>
                    setLocal({
                      ...local,
                      on_reply_config: {
                        ...local.on_reply_config,
                        move_to_pipeline_id: v === "__none__" ? undefined : v,
                        move_to_stage_id: undefined,
                      },
                    })
                  }
                >
                  <SelectTrigger className="mt-1">
                    <SelectValue placeholder="Manter pipeline atual" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="__none__">Manter pipeline atual</SelectItem>
                    {pipelines.map((p: any) => (
                      <SelectItem key={p.id} value={p.id}>{p.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {local.on_reply_config.move_to_pipeline_id && (
                <div className="pl-3 border-l-2 border-primary/30">
                  <Label className="text-xs">Etapa</Label>
                  <Select
                    value={local.on_reply_config.move_to_stage_id || "__none__"}
                    onValueChange={(v) =>
                      setLocal({
                        ...local,
                        on_reply_config: {
                          ...local.on_reply_config,
                          move_to_stage_id: v === "__none__" ? undefined : v,
                        },
                      })
                    }
                  >
                    <SelectTrigger className="mt-1">
                      <SelectValue placeholder="Manter etapa atual" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__none__">Manter etapa atual</SelectItem>
                      {(pipelines.find((p: any) => p.id === local.on_reply_config.move_to_pipeline_id)?.stages || []).map((s: any) => (
                        <SelectItem key={s.id} value={s.id}>{s.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              )}
            </div>

            <div className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                id="notify-wpp"
                checked={local.on_reply_config.notify_whatsapp || false}
                onChange={(e) =>
                  setLocal({
                    ...local,
                    on_reply_config: { ...local.on_reply_config, notify_whatsapp: e.target.checked },
                  })
                }
                className="rounded"
              />
              <Label htmlFor="notify-wpp" className="cursor-pointer">
                Notificar vendedor por WhatsApp
              </Label>
            </div>
          </div>

            </TabsContent>
          </div>
        </Tabs>

        {/* FOOTER STICKY */}
        <div className="px-6 py-3 border-t bg-background flex justify-end gap-2 shrink-0">
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancelar
          </Button>
          <Button onClick={handleSave} disabled={save.isPending}>
            💾 {save.isPending ? "Salvando..." : "Salvar"}
          </Button>
        </div>
      </SheetContent>
    </Sheet>
  );
}

function TabIntro({ title, description, example }: { title: string; description: string; example?: string }) {
  return (
    <div className="rounded-lg border border-primary/20 bg-primary/[0.04] p-3.5 space-y-2">
      <p className="text-sm font-semibold flex items-center gap-1.5">
        <span className="text-primary">ℹ</span>
        <span>{title}</span>
      </p>
      <p className="text-xs text-muted-foreground leading-relaxed">{description}</p>
      {example && (
        <p className="text-[11px] text-muted-foreground/85 italic border-l-2 border-primary/30 pl-2 mt-1">
          💡 {example}
        </p>
      )}
    </div>
  );
}

function StageDropdown({
  label,
  placeholder,
  value,
  stages,
  onChange,
}: {
  label: string;
  placeholder: string;
  value: string | null | undefined;
  stages: any[];
  onChange: (v: string | null) => void;
}) {
  return (
    <div>
      <Label className="text-xs">{label}</Label>
      <Select
        value={value || "__none__"}
        onValueChange={(v) => onChange(v === "__none__" ? null : v)}
      >
        <SelectTrigger className="mt-1"><SelectValue placeholder={placeholder} /></SelectTrigger>
        <SelectContent>
          <SelectItem value="__none__">— {placeholder.toLowerCase()} —</SelectItem>
          {stages.map((s: any) => <SelectItem key={s.id} value={s.id}>{s.name}</SelectItem>)}
        </SelectContent>
      </Select>
    </div>
  );
}
