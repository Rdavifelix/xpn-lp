import { useEffect, useState } from "react";
import { Sparkles, Settings as SettingsIcon } from "lucide-react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Separator } from "@/components/ui/separator";
import { toast } from "sonner";
import { useAuth } from "@/contexts/AuthContext";
import { readTenantConfig, writeTenantConfig } from "@/lib/tenant-config";

// ============================================================
// Tom de Voz
// ============================================================

export function ToneOfVoiceDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const [tone, setTone] = useState({
    description: "",
    sample_messages: "",
    forbidden_words: "",
  });
  const [loading, setLoading] = useState(false);
  const [calibrating, setCalibrating] = useState(false);
  const { tenantId } = useAuth();

  useEffect(() => {
    if (!open) return;
    // Override do tenant sobre o valor global em `config`
    readTenantConfig(["social_selling_tone"], tenantId)
      .then((map) => {
        const raw = map["social_selling_tone"];
        if (raw) {
          try {
            setTone(JSON.parse(raw));
          } catch {}
        }
      })
      .catch(() => {});
  }, [open, tenantId]);

  const handleSave = async () => {
    setLoading(true);
    try {
      if (!tenantId) throw new Error("Sem tenant ativo");
      await writeTenantConfig({ social_selling_tone: JSON.stringify(tone) }, tenantId);
      toast.success("Tom de voz salvo");
      onOpenChange(false);
    } catch (e: any) {
      toast.error(`Erro: ${e.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleCalibrate = async () => {
    setCalibrating(true);
    toast.info("Pra calibrar automático, rode no Claude Code: /social-selling-setup", { duration: 5000 });
    setCalibrating(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Sparkles className="h-4 w-4 text-pink-500" />
            Tom de Voz
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <p className="text-xs text-muted-foreground">
            Define como a IA escreve mensagens (DM, comentário, resposta de story). Quanto mais específico, mais
            "humano" sai.
          </p>

          <div className="space-y-2">
            <Label className="text-xs">Como você fala (descreva em texto)</Label>
            <Textarea
              rows={5}
              placeholder="Ex: informal, direto, uso muito 'mano' e 'top'. Frases curtas (3-8 palavras). Emojis 🔥🙏 com moderação. Sem aspas formais. Erro de digitação proposital tipo 'q' em vez de 'que' e 'mt' em vez de 'muito'."
              value={tone.description}
              onChange={(e) => setTone({ ...tone, description: e.target.value })}
            />
          </div>

          <div className="space-y-2">
            <Label className="text-xs">Exemplos de mensagens suas (1 por linha)</Label>
            <Textarea
              rows={4}
              placeholder={"opa mano!\nshow demais 🔥\nkkk vc é maluco\nfechou, abraço"}
              value={tone.sample_messages}
              onChange={(e) => setTone({ ...tone, sample_messages: e.target.value })}
              className="font-mono text-xs"
            />
          </div>

          <div className="space-y-2">
            <Label className="text-xs">Palavras / padrões PROIBIDOS</Label>
            <Input
              placeholder="travessão (—), 'me conta', 'que bom', 'compreendo', 'fique à vontade'"
              value={tone.forbidden_words}
              onChange={(e) => setTone({ ...tone, forbidden_words: e.target.value })}
            />
          </div>

          <Separator />

          <div className="bg-muted/40 rounded-lg p-3 flex items-start gap-3">
            <Sparkles className="h-4 w-4 text-pink-500 shrink-0 mt-0.5" />
            <div className="flex-1">
              <p className="text-sm font-medium">Calibração automática</p>
              <p className="text-xs text-muted-foreground mt-0.5">
                A IA analisa suas últimas DMs no IG e preenche tudo aqui automaticamente.
              </p>
            </div>
            <Button size="sm" variant="outline" onClick={handleCalibrate} disabled={calibrating}>
              Calibrar
            </Button>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancelar
          </Button>
          <Button onClick={handleSave} disabled={loading}>
            Salvar
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ============================================================
// Prompts da IA (qualificacao + cadencia)
// ============================================================

const PROMPT_KEYS = [
  {
    key: "social_selling_prompt_qualificacao",
    label: "Critério de qualificação (IA decide se aprovar lead)",
    placeholder: "Ex: Quero empresários com faturamento >R$100k/mês...",
    rows: 6,
  },
  {
    key: "social_selling_prompt_comentar_post",
    label: "Como gerar comentário público no post",
    placeholder: "Comentário curto (4-12 palavras) reagindo ao tema, citando detalhe específico, sem vender",
    rows: 3,
  },
  {
    key: "social_selling_prompt_responder_story",
    label: "Como gerar resposta no story (DM)",
    placeholder: "1 frase de 4-12 palavras comentando o conteúdo, sem oferecer nada",
    rows: 3,
  },
  {
    key: "social_selling_prompt_enviar_dm",
    label: "Como gerar DM frio de prospecção",
    placeholder: "2-3 frases. Apresenta-se rápido, conecta com algo do perfil, termina com pergunta aberta",
    rows: 4,
  },
];

export function PromptsDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const [prompts, setPrompts] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const { tenantId } = useAuth();

  useEffect(() => {
    if (!open) return;
    readTenantConfig(PROMPT_KEYS.map((p) => p.key), tenantId)
      .then((data) => {
        const map: Record<string, string> = {};
        Object.entries(data).forEach(([key, value]) => {
          map[key] = value || "";
        });
        setPrompts(map);
      })
      .catch(() => {});
  }, [open, tenantId]);

  const handleSave = async () => {
    setLoading(true);
    try {
      if (!tenantId) throw new Error("Sem tenant ativo");
      const entries: Record<string, string> = {};
      for (const p of PROMPT_KEYS) {
        const value = (prompts[p.key] || "").trim();
        if (!value) continue;
        entries[p.key] = value;
      }
      await writeTenantConfig(entries, tenantId);
      toast.success("Prompts salvos");
      onOpenChange(false);
    } catch (e: any) {
      toast.error(`Erro: ${e.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Sparkles className="h-4 w-4 text-pink-500" />
            Prompts da IA
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <p className="text-xs text-muted-foreground">
            Esses prompts controlam como a IA qualifica leads e gera mensagens. Edite pra deixar tudo no
            seu jeito — sem nada hardcoded no código.
          </p>

          {PROMPT_KEYS.map((p) => (
            <div key={p.key} className="space-y-1.5">
              <Label className="text-xs font-medium">{p.label}</Label>
              <Textarea
                rows={p.rows}
                value={prompts[p.key] || ""}
                placeholder={p.placeholder}
                onChange={(e) => setPrompts({ ...prompts, [p.key]: e.target.value })}
                className="text-xs font-mono leading-relaxed"
              />
              <p className="text-[10px] text-muted-foreground font-mono">
                config.key = {p.key}
              </p>
            </div>
          ))}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancelar</Button>
          <Button onClick={handleSave} disabled={loading}>Salvar</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ============================================================
// Rate Limits
// ============================================================

const DEFAULT_LIMITS = {
  total_actions_per_day: 80,
  total_actions_per_hour: 25,
  dms_per_day: 15,
  dms_per_hour: 5,
  comments_per_day: 20,
  likes_per_day: 60,
  delay_min_seconds: 45,
  delay_max_seconds: 120,
  working_hours_start: "09:00",
  working_hours_end: "20:00",
  pause_weekends: false,
};

export function RateLimitsDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const [limits, setLimits] = useState(DEFAULT_LIMITS);
  const [loading, setLoading] = useState(false);
  const { tenantId } = useAuth();

  useEffect(() => {
    if (!open) return;
    readTenantConfig(["social_selling_limits"], tenantId)
      .then((map) => {
        const raw = map["social_selling_limits"];
        if (raw) {
          try {
            setLimits({ ...DEFAULT_LIMITS, ...JSON.parse(raw) });
          } catch {}
        }
      })
      .catch(() => {});
  }, [open, tenantId]);

  const handleSave = async () => {
    setLoading(true);
    try {
      if (!tenantId) throw new Error("Sem tenant ativo");
      await writeTenantConfig({ social_selling_limits: JSON.stringify(limits) }, tenantId);
      toast.success("Rate limits salvos");
      onOpenChange(false);
    } catch (e: any) {
      toast.error(`Erro: ${e.message}`);
    } finally {
      setLoading(false);
    }
  };

  const num = (v: any) => parseInt(String(v)) || 0;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <SettingsIcon className="h-4 w-4" />
            Rate Limits & Horários
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <p className="text-xs text-muted-foreground">
            Limites pra evitar ban no Instagram. Padrões são conservadores e seguros.
          </p>

          <div className="space-y-2">
            <Label className="text-xs uppercase text-muted-foreground">Limites diários</Label>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label className="text-xs">Total ações/dia</Label>
                <Input
                  type="number"
                  className="mt-1"
                  value={limits.total_actions_per_day}
                  onChange={(e) => setLimits({ ...limits, total_actions_per_day: num(e.target.value) })}
                />
              </div>
              <div>
                <Label className="text-xs">DMs frias/dia</Label>
                <Input
                  type="number"
                  className="mt-1"
                  value={limits.dms_per_day}
                  onChange={(e) => setLimits({ ...limits, dms_per_day: num(e.target.value) })}
                />
              </div>
              <div>
                <Label className="text-xs">Comentários/dia</Label>
                <Input
                  type="number"
                  className="mt-1"
                  value={limits.comments_per_day}
                  onChange={(e) => setLimits({ ...limits, comments_per_day: num(e.target.value) })}
                />
              </div>
              <div>
                <Label className="text-xs">Curtidas/dia</Label>
                <Input
                  type="number"
                  className="mt-1"
                  value={limits.likes_per_day}
                  onChange={(e) => setLimits({ ...limits, likes_per_day: num(e.target.value) })}
                />
              </div>
            </div>
          </div>

          <Separator />

          <div className="space-y-2">
            <Label className="text-xs uppercase text-muted-foreground">Delay entre ações</Label>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label className="text-xs">Mínimo (seg)</Label>
                <Input
                  type="number"
                  className="mt-1"
                  value={limits.delay_min_seconds}
                  onChange={(e) => setLimits({ ...limits, delay_min_seconds: num(e.target.value) })}
                />
              </div>
              <div>
                <Label className="text-xs">Máximo (seg)</Label>
                <Input
                  type="number"
                  className="mt-1"
                  value={limits.delay_max_seconds}
                  onChange={(e) => setLimits({ ...limits, delay_max_seconds: num(e.target.value) })}
                />
              </div>
            </div>
            <p className="text-[10px] text-muted-foreground">
              Delay aleatório nesse intervalo. Padrões humanos: 45-120s.
            </p>
          </div>

          <Separator />

          <div className="space-y-2">
            <Label className="text-xs uppercase text-muted-foreground">Horário de funcionamento</Label>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label className="text-xs">Início</Label>
                <Input
                  type="time"
                  className="mt-1"
                  value={limits.working_hours_start}
                  onChange={(e) => setLimits({ ...limits, working_hours_start: e.target.value })}
                />
              </div>
              <div>
                <Label className="text-xs">Fim</Label>
                <Input
                  type="time"
                  className="mt-1"
                  value={limits.working_hours_end}
                  onChange={(e) => setLimits({ ...limits, working_hours_end: e.target.value })}
                />
              </div>
            </div>

            <div className="flex items-center gap-2 pt-2">
              <input
                type="checkbox"
                id="pause-weekends"
                checked={limits.pause_weekends}
                onChange={(e) => setLimits({ ...limits, pause_weekends: e.target.checked })}
                className="rounded"
              />
              <Label htmlFor="pause-weekends" className="cursor-pointer text-sm">
                Pausar fim de semana (sáb/dom)
              </Label>
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancelar
          </Button>
          <Button onClick={handleSave} disabled={loading}>
            Salvar
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
