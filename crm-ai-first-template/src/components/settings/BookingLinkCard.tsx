import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/contexts/AuthContext";
import { useToast } from "@/hooks/use-toast";
import { supabase } from "@/lib/supabase";
import { CalendarCheck, Copy, RefreshCw } from "lucide-react";

const TOKEN_KEY = "BOOKING_PUBLIC_TOKEN";

/** 48 caracteres hex, gerados no navegador (crypto). */
function randomToken(): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(24)), (b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Link público de agendamento por empresa (/agendar/:token). O token fica em
 * tenant_config_overrides (key BOOKING_PUBLIC_TOKEN) e a função book-meeting
 * resolve o tenant por ele. Só admins leem/alteram overrides do próprio tenant.
 */
export function BookingLinkCard() {
  const { tenantId, isAdmin } = useAuth();
  const { toast } = useToast();
  const qc = useQueryClient();
  const [saving, setSaving] = useState(false);
  const tokenQuery = useQuery({
    queryKey: ["booking-public-token", tenantId],
    enabled: !!tenantId && isAdmin,
    queryFn: async () => {
      // tenant_config_overrides ainda não está nos tipos gerados do client.
      const { data, error } = await (supabase as any)
        .from("tenant_config_overrides").select("value")
        .eq("tenant_id", tenantId).eq("key", TOKEN_KEY).maybeSingle();
      if (error) throw error;
      return (data?.value as string | undefined) || "";
    },
  });
  if (!isAdmin || !tenantId) return null;
  const token = tokenQuery.data || "";
  const link = token ? `${window.location.origin}/agendar/${token}` : "";

  const regenerate = async () => {
    if (token && !window.confirm("Gerar um novo token invalida o link atual já divulgado. Continuar?")) return;
    setSaving(true);
    try {
      const { error } = await (supabase as any)
        .from("tenant_config_overrides")
        .upsert({ tenant_id: tenantId, key: TOKEN_KEY, value: randomToken() }, { onConflict: "tenant_id,key" });
      if (error) throw error;
      await qc.invalidateQueries({ queryKey: ["booking-public-token", tenantId] });
      toast({ title: token ? "Novo link de agendamento gerado" : "Link de agendamento criado" });
    } catch (err) {
      toast({ title: "Erro ao gerar token", description: (err as Error).message, variant: "destructive" });
    } finally {
      setSaving(false);
    }
  };

  return (
    <Card>
      <CardContent className="pt-4 pb-4 space-y-3">
        <div className="flex items-center gap-2">
          <CalendarCheck className="h-4 w-4 text-primary" />
          <h3 className="text-sm font-medium">Link público de agendamento</h3>
        </div>
        <p className="text-xs text-muted-foreground">
          Página pública onde leads escolhem um horário na agenda do responsável padrão (DEFAULT_MEETING_OWNER_ID). O link é exclusivo da sua empresa.
        </p>
        {tokenQuery.isLoading ? (
          <p className="text-xs text-muted-foreground" role="status">Carregando…</p>
        ) : tokenQuery.error ? (
          <p className="text-xs text-destructive" role="alert">{(tokenQuery.error as Error).message}</p>
        ) : link ? (
          <div className="flex items-center gap-2">
            <code className="flex-1 bg-muted px-2 py-1.5 rounded font-mono text-[11px] break-all">{link}</code>
            <Button variant="outline" size="sm" className="h-7 shrink-0" onClick={() => { navigator.clipboard.writeText(link); toast({ title: "Link copiado!" }); }}>
              <Copy className="h-3.5 w-3.5 mr-1" /> Copiar
            </Button>
          </div>
        ) : (
          <p className="text-xs text-muted-foreground">Nenhum token gerado ainda para esta empresa.</p>
        )}
        <Button variant="outline" size="sm" disabled={saving} onClick={regenerate}>
          <RefreshCw className={`h-3.5 w-3.5 mr-1 ${saving ? "animate-spin" : ""}`} /> {token ? "Gerar novo token" : "Gerar token"}
        </Button>
      </CardContent>
    </Card>
  );
}
