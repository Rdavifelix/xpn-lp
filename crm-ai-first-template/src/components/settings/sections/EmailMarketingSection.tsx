import { useEffect, useState } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { useToast } from "@/hooks/use-toast";
import { supabase } from "@/lib/supabase";
import { readTenantConfig } from "@/lib/tenant-config";
import {
  Save,
  Loader2,
  Mail,
  CheckCircle2,
  AlertCircle,
  ExternalLink,
  Copy,
} from "lucide-react";

/**
 * EmailMarketingSection
 *
 * UI dedicada de configuração do Email Marketing (Resend).
 *
 * Onde os dados ficam:
 *  - tenant_config: from_email, from_name, reply_to, company_address, app_url, is_active, domain_verified
 *  - config (key-value): RESEND_API_KEY, RESEND_WEBHOOK_SECRET → setar em /configuracoes?s=api-keys
 *
 * O webhook do Resend aponta pra:
 *   {VITE_SUPABASE_URL}/functions/v1/process-email-event
 */

interface TenantEmailConfig {
  tenant_id: string;
  company_name: string | null;
  email_from_email: string | null;
  email_from_name: string | null;
  email_reply_to: string | null;
  email_company_address: string | null;
  email_app_url: string | null;
  email_is_active: boolean;
  email_domain_verified: boolean;
}

const WEBHOOK_URL = import.meta.env.VITE_SUPABASE_URL
  ? `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/process-email-event`
  : "";

export function EmailMarketingSection() {
  const { toast } = useToast();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [tenantId, setTenantId] = useState<string | null>(null);
  const [cfg, setCfg] = useState<TenantEmailConfig | null>(null);
  const [hasResendKey, setHasResendKey] = useState(false);
  const [hasWebhookSecret, setHasWebhookSecret] = useState(false);

  // Carrega config inicial
  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        const tid = (user?.app_metadata as any)?.tenant_id;
        if (!mounted || !tid) return;
        setTenantId(tid);

        // tenant_config
        const { data: tcfg } = await supabase
          .from("tenant_config")
          .select("tenant_id, company_name, email_from_email, email_from_name, email_reply_to, email_company_address, email_app_url, email_is_active, email_domain_verified")
          .eq("tenant_id", tid)
          .maybeSingle();

        // status das keys (override do tenant sobre o valor global em `config`)
        const keyMap = new Map(
          Object.entries(await readTenantConfig(["RESEND_API_KEY", "RESEND_WEBHOOK_SECRET"], tid))
        );
        if (!mounted) return;

        setHasResendKey(!!keyMap.get("RESEND_API_KEY")?.trim());
        setHasWebhookSecret(!!keyMap.get("RESEND_WEBHOOK_SECRET")?.trim());

        setCfg(tcfg || {
          tenant_id: tid,
          company_name: null,
          email_from_email: null,
          email_from_name: null,
          email_reply_to: null,
          email_company_address: null,
          email_app_url: typeof window !== "undefined" ? window.location.origin : null,
          email_is_active: false,
          email_domain_verified: false,
        });
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => { mounted = false; };
  }, []);

  function set<K extends keyof TenantEmailConfig>(key: K, value: TenantEmailConfig[K]) {
    setCfg((prev) => prev ? { ...prev, [key]: value } : prev);
  }

  async function handleSave() {
    if (!cfg || !tenantId) return;
    setSaving(true);
    try {
      // Verifica se a row existe (tenant_config sempre deveria existir, mas garantia)
      const { data: existing } = await supabase
        .from("tenant_config")
        .select("tenant_id")
        .eq("tenant_id", tenantId)
        .maybeSingle();

      const payload = {
        email_from_email: cfg.email_from_email,
        email_from_name: cfg.email_from_name,
        email_reply_to: cfg.email_reply_to,
        email_company_address: cfg.email_company_address,
        email_app_url: cfg.email_app_url,
        email_is_active: cfg.email_is_active,
        email_domain_verified: cfg.email_domain_verified,
        updated_at: new Date().toISOString(),
      };

      if (existing) {
        // UPDATE — não mexe em company_name (NOT NULL) nem em outras cols não-email
        const { error } = await supabase
          .from("tenant_config")
          .update(payload)
          .eq("tenant_id", tenantId);
        if (error) throw error;
      } else {
        // INSERT — precisa de company_name (NOT NULL). Usa from_name como fallback.
        const { error } = await supabase
          .from("tenant_config")
          .insert({
            tenant_id: tenantId,
            company_name: cfg.email_from_name || "Empresa",
            ...payload,
          });
        if (error) throw error;
      }

      toast({ title: "Configurações salvas", description: "Email Marketing atualizado." });
    } catch (err: any) {
      toast({ title: "Erro ao salvar", description: err.message, variant: "destructive" });
    } finally {
      setSaving(false);
    }
  }

  async function copyWebhook() {
    try {
      await navigator.clipboard.writeText(WEBHOOK_URL);
      toast({ title: "URL copiada", description: "Cole no Resend > Webhooks." });
    } catch {
      toast({ title: "Não foi possível copiar", variant: "destructive" });
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center p-12">
        <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (!cfg) {
    return (
      <Card>
        <CardContent className="p-6 text-sm text-muted-foreground">
          Não foi possível carregar configuração. Verifique se você tem tenant_id no JWT.
        </CardContent>
      </Card>
    );
  }

  const allReady = hasResendKey && cfg.email_from_email && cfg.email_is_active;

  return (
    <div className="space-y-6 max-w-3xl">
      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div>
          <h2 className="text-lg font-semibold flex items-center gap-2">
            <Mail className="h-5 w-5 text-primary" />
            Email Marketing
          </h2>
          <p className="text-sm text-muted-foreground mt-1">
            Configurações de envio via Resend (campanhas, automações, transacional).
          </p>
        </div>
        <Badge variant={allReady ? "default" : "secondary"} className="gap-1">
          {allReady ? <CheckCircle2 className="h-3 w-3" /> : <AlertCircle className="h-3 w-3" />}
          {allReady ? "Pronto pra enviar" : "Configuração incompleta"}
        </Badge>
      </div>

      {/* Status das credenciais */}
      <Card>
        <CardContent className="p-5 space-y-4">
          <div>
            <h3 className="text-sm font-semibold mb-3">Credenciais Resend</h3>
            <p className="text-xs text-muted-foreground mb-3">
              Cadastre a API key e o webhook secret na aba <a href="/configuracoes?s=api-keys" className="text-primary underline">API Keys</a>.
            </p>
            <div className="grid gap-2 text-sm">
              <div className="flex items-center justify-between p-3 bg-muted/40 rounded-md">
                <span className="font-mono text-xs">RESEND_API_KEY</span>
                {hasResendKey ? (
                  <Badge variant="default" className="gap-1 text-[10px]"><CheckCircle2 className="h-3 w-3" />Configurada</Badge>
                ) : (
                  <Badge variant="destructive" className="gap-1 text-[10px]"><AlertCircle className="h-3 w-3" />Não configurada</Badge>
                )}
              </div>
              <div className="flex items-center justify-between p-3 bg-muted/40 rounded-md">
                <span className="font-mono text-xs">RESEND_WEBHOOK_SECRET</span>
                {hasWebhookSecret ? (
                  <Badge variant="default" className="gap-1 text-[10px]"><CheckCircle2 className="h-3 w-3" />Configurada</Badge>
                ) : (
                  <Badge variant="secondary" className="gap-1 text-[10px]">Opcional (recomendado)</Badge>
                )}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Webhook URL */}
      <Card>
        <CardContent className="p-5 space-y-3">
          <div>
            <h3 className="text-sm font-semibold mb-1">URL do Webhook (Resend Dashboard)</h3>
            <p className="text-xs text-muted-foreground">
              Cole essa URL em <a href="https://resend.com/webhooks" target="_blank" rel="noreferrer" className="text-primary underline inline-flex items-center gap-1">resend.com/webhooks <ExternalLink className="h-3 w-3" /></a> e habilite os eventos: <code className="text-[10px] bg-muted px-1 rounded">email.sent · delivered · opened · clicked · bounced · complained</code>.
            </p>
          </div>
          <div className="flex items-center gap-2">
            <Input value={WEBHOOK_URL} readOnly className="font-mono text-xs" />
            <Button size="sm" variant="outline" onClick={copyWebhook}>
              <Copy className="h-3.5 w-3.5" />
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Remetente / Branding */}
      <Card>
        <CardContent className="p-5 space-y-4">
          <div>
            <h3 className="text-sm font-semibold mb-3">Remetente padrão</h3>
            <p className="text-xs text-muted-foreground mb-4">
              ⚠️ O email precisa estar em um domínio verificado no Resend (resend.com/domains).
              Em modo sandbox, só envia pra emails da própria conta Resend.
            </p>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label htmlFor="from-email">Email "From"</Label>
                <Input
                  id="from-email"
                  type="email"
                  placeholder="contato@seudominio.com.br"
                  value={cfg.email_from_email ?? ""}
                  onChange={(e) => set("email_from_email", e.target.value)}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="from-name">Nome "From"</Label>
                <Input
                  id="from-name"
                  placeholder="Sua Contabilidade"
                  value={cfg.email_from_name ?? ""}
                  onChange={(e) => set("email_from_name", e.target.value)}
                />
              </div>
              <div className="space-y-1.5 col-span-2">
                <Label htmlFor="reply-to">Reply-to (opcional)</Label>
                <Input
                  id="reply-to"
                  type="email"
                  placeholder="atendimento@seudominio.com.br"
                  value={cfg.email_reply_to ?? ""}
                  onChange={(e) => set("email_reply_to", e.target.value)}
                />
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* LGPD / Compliance */}
      <Card>
        <CardContent className="p-5 space-y-4">
          <div>
            <h3 className="text-sm font-semibold mb-3">Conformidade (LGPD/CAN-SPAM)</h3>
            <p className="text-xs text-muted-foreground mb-4">
              Esses dados aparecem no footer de todos os emails de marketing — exigido por lei.
            </p>
            <div className="space-y-3">
              <div className="space-y-1.5">
                <Label htmlFor="company-address">Endereço da empresa (footer)</Label>
                <Textarea
                  id="company-address"
                  placeholder="Rua das Flores, 123 - Sala 45 - Centro - São Paulo/SP - CEP 01234-567"
                  rows={2}
                  value={cfg.email_company_address ?? ""}
                  onChange={(e) => set("email_company_address", e.target.value)}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="app-url">URL do CRM (base do link de descadastro)</Label>
                <Input
                  id="app-url"
                  placeholder="https://crm.seudominio.com.br"
                  value={cfg.email_app_url ?? ""}
                  onChange={(e) => set("email_app_url", e.target.value)}
                />
                <p className="text-[11px] text-muted-foreground">
                  Os links de descadastro são gerados como <code className="text-[10px]">{`{app_url}/unsubscribe?token=...`}</code>.
                </p>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Status flags */}
      <Card>
        <CardContent className="p-5 space-y-4">
          <h3 className="text-sm font-semibold">Status</h3>
          <div className="flex items-start justify-between gap-4">
            <div className="space-y-0.5">
              <Label htmlFor="domain-verified" className="text-sm">Domínio verificado no Resend</Label>
              <p className="text-xs text-muted-foreground">Confirma que o domínio do "From" passou na verificação DNS (SPF, DKIM, DMARC).</p>
            </div>
            <Switch
              id="domain-verified"
              checked={cfg.email_domain_verified}
              onCheckedChange={(v) => set("email_domain_verified", v)}
            />
          </div>
          <div className="flex items-start justify-between gap-4">
            <div className="space-y-0.5">
              <Label htmlFor="is-active" className="text-sm">Email Marketing ativo</Label>
              <p className="text-xs text-muted-foreground">
                Quando desligado, edge functions de envio retornam erro. Ative só depois de configurar tudo.
              </p>
            </div>
            <Switch
              id="is-active"
              checked={cfg.email_is_active}
              onCheckedChange={(v) => set("email_is_active", v)}
            />
          </div>
        </CardContent>
      </Card>

      {/* Save */}
      <div className="flex justify-end">
        <Button onClick={handleSave} disabled={saving} className="gap-2">
          {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
          Salvar configurações
        </Button>
      </div>
    </div>
  );
}
