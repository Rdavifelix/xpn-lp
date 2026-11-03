import { useState } from "react";
import { format, formatDistanceToNow } from "date-fns";
import { ptBR } from "date-fns/locale";
import { Instagram, Play, Pause, X, Calendar, AlertCircle, CheckCircle2, MessageCircle, Image as ImageIcon } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Progress } from "@/components/ui/progress";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import {
  useSocialSellingEnrollment,
  useSocialSellingInteractions,
  useUpdateEnrollment,
  useEnrollLead,
  ACTION_LABELS,
  ACTION_ICONS,
  type SocialSellingEnrollment,
} from "@/hooks/useSocialSelling";
import { supabase } from "@/lib/supabase";
import { useQueryClient } from "@tanstack/react-query";
import { InstagramProfileSection } from "@/components/sales/InstagramProfileSection";

interface Props {
  leadId: string;
  leadName?: string;
  instagramUsername?: string | null;
}

const STATUS_CONFIG: Record<SocialSellingEnrollment["status"], { label: string; color: string; icon: any }> = {
  active: { label: "Ativo", color: "bg-emerald-500/15 text-emerald-700 border-emerald-200", icon: Play },
  paused: { label: "Pausado", color: "bg-amber-500/15 text-amber-700 border-amber-200", icon: Pause },
  replied: { label: "Respondeu", color: "bg-blue-500/15 text-blue-700 border-blue-200", icon: MessageCircle },
  completed: { label: "Concluído", color: "bg-zinc-500/15 text-zinc-700 border-zinc-200", icon: CheckCircle2 },
  failed: { label: "Falhou", color: "bg-red-500/15 text-red-700 border-red-200", icon: AlertCircle },
  cancelled: { label: "Cancelado", color: "bg-zinc-500/15 text-zinc-700 border-zinc-200", icon: X },
};

export function SocialSellingTab({ leadId, instagramUsername }: Props) {
  const qc = useQueryClient();
  const { data: enrollment, isLoading } = useSocialSellingEnrollment(leadId);
  const { data: interactions = [] } = useSocialSellingInteractions(leadId);
  const updateEnrollment = useUpdateEnrollment();
  const enrollLead = useEnrollLead();

  const [igInput, setIgInput] = useState(instagramUsername || "");

  const handlePause = async () => {
    if (!enrollment) return;
    await updateEnrollment.mutateAsync({ id: enrollment.id, status: "paused", pause_reason: "Pausado manualmente" });
    toast.success("Fluxo pausado");
  };

  const handleResume = async () => {
    if (!enrollment) return;
    await updateEnrollment.mutateAsync({ id: enrollment.id, status: "active" });
    toast.success("Fluxo retomado");
  };

  const handleCancel = async () => {
    if (!enrollment) return;
    if (!confirm("Cancelar o fluxo de social selling? Pode iniciar de novo depois.")) return;
    await updateEnrollment.mutateAsync({ id: enrollment.id, status: "cancelled" });
    toast.success("Fluxo cancelado");
  };

  const handleEnroll = async () => {
    if (!igInput.trim()) {
      toast.error("Informe o @ do Instagram");
      return;
    }
    const handle = igInput.replace("@", "").trim();
    if (handle !== instagramUsername) {
      await supabase.from("leads").update({ instagram_username: handle }).eq("id", leadId);
    }
    await enrollLead.mutateAsync({ lead_id: leadId, instagram_username: handle });
    qc.invalidateQueries({ queryKey: ["lead", leadId] });
    toast.success(`Fluxo iniciado para @${handle}`);
  };

  if (isLoading) {
    return <div className="text-sm text-muted-foreground py-8 text-center">Carregando...</div>;
  }

  if (!enrollment || enrollment.status === "cancelled" || enrollment.status === "completed") {
    return (
      <div className="space-y-4">
        {instagramUsername && <InstagramProfileSection username={instagramUsername} />}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <Instagram className="h-4 w-4" />
              {enrollment ? "Iniciar novo fluxo" : "Iniciar fluxo de Social Selling"}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="space-y-2">
              <Label className="text-xs">@ do Instagram do lead</Label>
              <div className="flex gap-2">
                <Input
                  value={igInput}
                  onChange={(e) => setIgInput(e.target.value)}
                  placeholder="ex: frank.costa"
                  className="flex-1"
                />
                <Button onClick={handleEnroll} disabled={enrollLead.isPending || !igInput.trim()}>
                  <Play className="h-4 w-4 mr-2" />
                  Iniciar
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                O fluxo padrão é de 7 dias com aquecimento progressivo (curtir → reagir → comentar → DM).
              </p>
            </div>
          </CardContent>
        </Card>

        {enrollment && (
          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Histórico anterior</CardTitle>
            </CardHeader>
            <CardContent>
              <InteractionsList interactions={interactions} />
            </CardContent>
          </Card>
        )}
      </div>
    );
  }

  const statusCfg = STATUS_CONFIG[enrollment.status];
  const StatusIcon = statusCfg.icon;
  const progressPct = Math.min(100, ((enrollment.current_day ?? 0) / (enrollment.total_days || 7)) * 100);

  const cadenceAndHistory = (
    <>
      <Card>
        <CardHeader className="pb-3">
          <div className="flex items-start justify-between">
            <div>
              <CardTitle className="text-base flex items-center gap-2">
                <Instagram className="h-4 w-4 text-pink-500" />
                {enrollment.flow_name}
              </CardTitle>
              <p className="text-xs text-muted-foreground mt-1">
                @{enrollment.instagram_username} ·{" "}
                Iniciado {formatDistanceToNow(new Date(enrollment.started_at), { locale: ptBR, addSuffix: true })}
              </p>
            </div>
            <Badge variant="outline" className={cn("gap-1", statusCfg.color)}>
              <StatusIcon className="h-3 w-3" />
              {statusCfg.label}
            </Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-muted-foreground">
                Dia {enrollment.current_day} de {enrollment.total_days}
              </span>
              <span className="font-medium">{Math.round(progressPct)}%</span>
            </div>
            <Progress value={progressPct} className="h-2" />
          </div>

          {enrollment.status === "active" && enrollment.next_action_at && (
            <div className="flex items-center gap-2 text-sm bg-muted/40 rounded-lg p-3">
              <Calendar className="h-4 w-4 text-muted-foreground shrink-0" />
              <span className="text-muted-foreground">
                Próxima ação{" "}
                <span className="font-medium text-foreground">
                  {formatDistanceToNow(new Date(enrollment.next_action_at), { locale: ptBR, addSuffix: true })}
                </span>
              </span>
            </div>
          )}

          {enrollment.status === "replied" && (
            <div className="flex items-center gap-2 text-sm bg-blue-500/10 text-blue-700 rounded-lg p-3">
              <MessageCircle className="h-4 w-4 shrink-0" />
              <span>
                <span className="font-medium">Lead respondeu!</span> O fluxo foi pausado e o lead foi movido pra{" "}
                <span className="font-medium">Em Qualificação</span>.
              </span>
            </div>
          )}

          <div className="flex gap-2">
            {enrollment.status === "active" && (
              <Button variant="outline" size="sm" onClick={handlePause}>
                <Pause className="h-4 w-4 mr-2" />
                Pausar
              </Button>
            )}
            {enrollment.status === "paused" && (
              <Button variant="outline" size="sm" onClick={handleResume}>
                <Play className="h-4 w-4 mr-2" />
                Retomar
              </Button>
            )}
            {(enrollment.status === "active" || enrollment.status === "paused") && (
              <Button variant="outline" size="sm" onClick={handleCancel} className="text-red-600 hover:text-red-700">
                <X className="h-4 w-4 mr-2" />
                Cancelar fluxo
              </Button>
            )}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-sm flex items-center justify-between">
            Histórico de interações
            <Badge variant="secondary" className="text-xs">
              {interactions.length}
            </Badge>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <InteractionsList interactions={interactions} />
        </CardContent>
      </Card>
    </>
  );

  return (
    <div className="space-y-4">
      {(enrollment.instagram_username || instagramUsername) ? (
        <InstagramProfileSection
          username={enrollment.instagram_username || instagramUsername!}
          afterHeader={cadenceAndHistory}
        />
      ) : (
        cadenceAndHistory
      )}
    </div>
  );
}

function InteractionsList({ interactions }: { interactions: any[] }) {
  if (interactions.length === 0) {
    return (
      <div className="text-center py-8 text-sm text-muted-foreground">
        <ImageIcon className="h-8 w-8 mx-auto mb-2 opacity-30" />
        Nenhuma interação ainda. As ações executadas pelo Playwright vão aparecer aqui.
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {interactions.map((it: any) => {
        const icon = ACTION_ICONS[it.action_type] || "📷";
        const label = ACTION_LABELS[it.action_type] || it.action_type;
        const statusColor =
          it.status === "success"
            ? "text-emerald-700 bg-emerald-500/10"
            : it.status === "failed"
            ? "text-red-700 bg-red-500/10"
            : it.status === "rate_limited"
            ? "text-amber-700 bg-amber-500/10"
            : "text-zinc-700 bg-zinc-500/10";

        return (
          <div key={it.id} className="flex gap-3 items-start border-b border-border/40 pb-3 last:border-0 last:pb-0">
            <div className="text-xl shrink-0">{icon}</div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <span className="text-sm font-medium">{label}</span>
                <Badge variant="outline" className={cn("text-[10px] h-5", statusColor)}>
                  {it.status}
                </Badge>
                {it.day_number != null && (
                  <Badge variant="secondary" className="text-[10px] h-5">
                    Dia {it.day_number}
                  </Badge>
                )}
              </div>
              {it.content && (
                <p className="text-sm text-muted-foreground mt-1 line-clamp-2">
                  "{it.content}"
                </p>
              )}
              {it.error_message && (
                <p className="text-xs text-red-600 mt-1">{it.error_message}</p>
              )}
              <p className="text-xs text-muted-foreground mt-1">
                {format(new Date(it.executed_at), "dd/MM 'às' HH:mm", { locale: ptBR })}
              </p>
            </div>
          </div>
        );
      })}
    </div>
  );
}
