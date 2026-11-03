import { Instagram, MessageCircle, Pause } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";
import { useActiveEnrollmentsByLead } from "@/hooks/useSocialSelling";

interface Props {
  leadId: string | null | undefined;
  variant?: "compact" | "full";
}

export function SocialSellingBadge({ leadId, variant = "compact" }: Props) {
  const { data: byLead } = useActiveEnrollmentsByLead();
  if (!leadId) return null;
  const enrollment = byLead?.[leadId];
  if (!enrollment) return null;

  const isReplied = enrollment.status === "replied";
  const isPaused = enrollment.status === "paused";

  const Icon = isReplied ? MessageCircle : isPaused ? Pause : Instagram;
  const tooltip = isReplied
    ? `Lead respondeu no Instagram (@${enrollment.instagram_username})`
    : isPaused
    ? `Fluxo pausado · @${enrollment.instagram_username}`
    : `Social Selling — Dia ${enrollment.current_day}/${enrollment.total_days} · @${enrollment.instagram_username}`;

  const colorClass = isReplied
    ? "bg-blue-500/15 text-blue-700 border-blue-200 dark:text-blue-300 dark:border-blue-900"
    : isPaused
    ? "bg-amber-500/15 text-amber-700 border-amber-200 dark:text-amber-300 dark:border-amber-900"
    : "bg-pink-500/15 text-pink-700 border-pink-200 dark:text-pink-300 dark:border-pink-900";

  const content = (
    <Badge variant="outline" className={cn("gap-1 text-[10px] h-5 px-1.5", colorClass)}>
      <Icon className="h-3 w-3" />
      {variant === "compact"
        ? isReplied
          ? "Respondeu"
          : `D${enrollment.current_day}/${enrollment.total_days}`
        : isReplied
        ? "Respondeu no IG"
        : `Social Selling · D${enrollment.current_day}/${enrollment.total_days}`}
    </Badge>
  );

  return (
    <TooltipProvider>
      <Tooltip>
        <TooltipTrigger asChild>{content}</TooltipTrigger>
        <TooltipContent side="top">
          <p className="text-xs">{tooltip}</p>
          {enrollment.last_action_at && (
            <p className="text-[10px] text-muted-foreground mt-0.5">
              Última ação: {new Date(enrollment.last_action_at).toLocaleString("pt-BR")}
            </p>
          )}
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  );
}
