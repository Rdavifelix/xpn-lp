import { useState } from "react";
import { Plus, Trash2, Pencil, ChevronRight, Sparkles, Settings, Instagram } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  DropdownMenuLabel,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import {
  useAutomations,
  useSaveAutomation,
  useDeleteAutomation,
  useToggleAutomation,
  AUTOMATION_TEMPLATES,
  TRIGGER_LABELS,
  type SocialSellingAutomation,
} from "@/hooks/useSocialSellingAutomations";
import { AutomationDrawer } from "@/components/sales/AutomationDrawer";
import { ToneOfVoiceDialog, RateLimitsDialog, PromptsDialog } from "@/components/sales/SocialSellingSettingsDialogs";

export default function SocialSellingConfig() {
  const { data: automations = [], isLoading } = useAutomations();
  const saveAutomation = useSaveAutomation();
  const deleteAutomation = useDeleteAutomation();
  const toggleAutomation = useToggleAutomation();

  const [editingAutomation, setEditingAutomation] = useState<SocialSellingAutomation | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [toneOpen, setToneOpen] = useState(false);
  const [limitsOpen, setLimitsOpen] = useState(false);
  const [promptsOpen, setPromptsOpen] = useState(false);

  const handleNewFromTemplate = async (template: typeof AUTOMATION_TEMPLATES[number]) => {
    try {
      const created = await saveAutomation.mutateAsync({
        name: template.name,
        emoji: template.emoji,
        is_active: false,
        trigger_type: template.trigger_type!,
        trigger_config: template.trigger_config || {},
        qualification_config: template.qualification_config || {},
        cadence_config: template.cadence_config || { days: [] },
        on_reply_config: template.on_reply_config || {},
        rate_limit_overrides: {},
      } as any);
      toast.success("Automação criada! Configure e ative.");
      setEditingAutomation(created as any);
      setDrawerOpen(true);
    } catch (e: any) {
      toast.error(`Erro: ${e.message}`);
    }
  };

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Deletar automação "${name}"?`)) return;
    await deleteAutomation.mutateAsync(id);
    toast.success("Automação deletada");
  };

  const handleToggle = async (id: string, is_active: boolean) => {
    await toggleAutomation.mutateAsync({ id, is_active });
    toast.success(is_active ? "Automação ativada" : "Automação pausada");
  };

  return (
    <div className="container mx-auto p-6 max-w-4xl space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            <Instagram className="h-6 w-6 text-pink-500" />
            Social Selling
          </h1>
          <p className="text-sm text-muted-foreground mt-1">
            Automações de aquecimento e prospecção no Instagram
          </p>
        </div>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button>
              <Plus className="h-4 w-4 mr-2" />
              Nova Automação
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-80">
            <DropdownMenuLabel>Escolha um template</DropdownMenuLabel>
            <DropdownMenuSeparator />
            {AUTOMATION_TEMPLATES.map((t) => (
              <DropdownMenuItem
                key={t.name}
                onClick={() => handleNewFromTemplate(t)}
                className="flex items-start gap-3 py-3 cursor-pointer"
              >
                <span className="text-2xl">{t.emoji}</span>
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-sm">{t.name}</p>
                  <p className="text-xs text-muted-foreground line-clamp-2">{t.description}</p>
                </div>
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      {/* Automações */}
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-base">Automações ({automations.length})</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          {isLoading ? (
            <div className="text-center py-8 text-sm text-muted-foreground">Carregando...</div>
          ) : automations.length === 0 ? (
            <div className="text-center py-12">
              <Sparkles className="h-10 w-10 mx-auto mb-3 opacity-30" />
              <p className="text-sm font-medium mb-1">Nenhuma automação ainda</p>
              <p className="text-xs text-muted-foreground mb-4">
                Use um template pra começar em 1 clique
              </p>
            </div>
          ) : (
            automations.map((a) => (
              <AutomationRow
                key={a.id}
                automation={a}
                onEdit={() => {
                  setEditingAutomation(a);
                  setDrawerOpen(true);
                }}
                onToggle={(checked) => handleToggle(a.id, checked)}
                onDelete={() => handleDelete(a.id, a.name)}
              />
            ))
          )}
        </CardContent>
      </Card>

      {/* Settings rápidos no rodapé */}
      <div className="flex items-center justify-center gap-6 text-sm text-muted-foreground border-t pt-6">
        <button
          className="hover:text-foreground transition-colors flex items-center gap-1.5"
          onClick={() => setToneOpen(true)}
        >
          <Sparkles className="h-3.5 w-3.5" />
          Tom de voz
        </button>
        <span className="opacity-30">·</span>
        <button
          className="hover:text-foreground transition-colors flex items-center gap-1.5"
          onClick={() => setPromptsOpen(true)}
        >
          <Sparkles className="h-3.5 w-3.5" />
          Prompts da IA
        </button>
        <span className="opacity-30">·</span>
        <button
          className="hover:text-foreground transition-colors flex items-center gap-1.5"
          onClick={() => setLimitsOpen(true)}
        >
          <Settings className="h-3.5 w-3.5" />
          Rate limits
        </button>
      </div>

      <ToneOfVoiceDialog open={toneOpen} onOpenChange={setToneOpen} />
      <RateLimitsDialog open={limitsOpen} onOpenChange={setLimitsOpen} />
      <PromptsDialog open={promptsOpen} onOpenChange={setPromptsOpen} />

      {/* Drawer de edição */}
      {editingAutomation && (
        <AutomationDrawer
          open={drawerOpen}
          onOpenChange={(open) => {
            setDrawerOpen(open);
            if (!open) setEditingAutomation(null);
          }}
          automation={editingAutomation}
        />
      )}
    </div>
  );
}

function AutomationRow({
  automation,
  onEdit,
  onToggle,
  onDelete,
}: {
  automation: SocialSellingAutomation;
  onEdit: () => void;
  onToggle: (checked: boolean) => void;
  onDelete: () => void;
}) {
  const totalDays = automation.cadence_config.days?.length ?? 0;
  const totalActions = automation.cadence_config.days?.reduce(
    (sum, d) => sum + (d.actions?.length ?? 0),
    0
  ) ?? 0;

  // Resumo do trigger
  let triggerSummary = TRIGGER_LABELS[automation.trigger_type];
  if (automation.trigger_type === "stage_change" && automation.trigger_config.stage_name) {
    triggerSummary = `Lead entra em "${automation.trigger_config.stage_name}"`;
  } else if (automation.trigger_type === "no_reply" && automation.trigger_config.days_since_last_reply) {
    triggerSummary = `Sem responder há ${automation.trigger_config.days_since_last_reply} dias`;
  } else if (automation.trigger_type === "tag_added" && automation.trigger_config.tag) {
    triggerSummary = `Lead recebe tag "${automation.trigger_config.tag}"`;
  } else if (automation.trigger_type === "new_follower") {
    triggerSummary = "Novo seguidor no Instagram";
  }

  return (
    <div
      className={cn(
        "flex items-center gap-3 p-3 rounded-lg border transition-all hover:bg-muted/40 cursor-pointer group",
        !automation.is_active && "opacity-60"
      )}
      onClick={onEdit}
    >
      <span className="text-2xl shrink-0">{automation.emoji || "🎯"}</span>

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 mb-1">
          <p className="font-medium text-sm truncate">{automation.name}</p>
          <Badge variant="secondary" className="text-[10px] h-5">
            {totalDays}d · {totalActions} ações
          </Badge>
        </div>
        <p className="text-xs text-muted-foreground truncate">{triggerSummary}</p>
      </div>

      <div className="flex items-center gap-1 shrink-0" onClick={(e) => e.stopPropagation()}>
        <Switch checked={automation.is_active} onCheckedChange={onToggle} />
        <Button variant="ghost" size="icon" className="h-8 w-8" onClick={onEdit}>
          <Pencil className="h-3.5 w-3.5" />
        </Button>
        <Button
          variant="ghost"
          size="icon"
          className="h-8 w-8 text-red-600 hover:text-red-700 opacity-0 group-hover:opacity-100"
          onClick={onDelete}
        >
          <Trash2 className="h-3.5 w-3.5" />
        </Button>
      </div>
    </div>
  );
}
