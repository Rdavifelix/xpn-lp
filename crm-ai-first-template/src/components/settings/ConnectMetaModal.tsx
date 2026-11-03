import { useState, useEffect, useMemo } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { useToast } from "@/hooks/use-toast";
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
import { Switch } from "@/components/ui/switch";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Alert, AlertDescription } from "@/components/ui/alert";
import {
  Loader2, Eye, EyeOff, CheckCircle2, AlertTriangle, Link as LinkIcon,
  ArrowLeft, BarChart3, Target, FileText,
} from "lucide-react";

// Modal "Conectar Meta" — token único descobre tudo, cliente escolhe o que ativar.
// Idempotente: assets já cadastrados aparecem com badge "Conectado" e ficam pré-selecionados.

interface ValidateMetaResponse {
  ok: boolean;
  user?: { id: string; name: string };
  permissions_detected?: string[];
  permissions_missing?: string[];
  ad_accounts?: Array<{ account_id: string; account_name: string; account_status?: number; currency?: string }>;
  pages?: Array<{
    page_id: string; page_name: string; page_access_token: string;
    followers?: number;
    forms: Array<{ form_id: string; form_name: string; leads_count: number }>;
  }>;
  error?: string;
}

interface ConnectMetaModalProps {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  onSaved: () => void;
}

export function ConnectMetaModal({ open, onOpenChange, onSaved }: ConnectMetaModalProps) {
  const { tenantId } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const [step, setStep] = useState<1 | 2>(1);
  const [token, setToken] = useState("");
  const [showToken, setShowToken] = useState(false);
  const [validating, setValidating] = useState(false);
  const [saving, setSaving] = useState(false);
  const [discovery, setDiscovery] = useState<ValidateMetaResponse | null>(null);

  // Seleções
  const [selectedAdAccounts, setSelectedAdAccounts] = useState<Set<string>>(new Set());
  const [selectedPages, setSelectedPages] = useState<Set<string>>(new Set());
  const [selectedForms, setSelectedForms] = useState<Set<string>>(new Set());
  const [subscribeLeadgen, setSubscribeLeadgen] = useState(true);

  // O que já tá conectado no tenant (pra marcar badge "Conectado" + pré-selecionar)
  const { data: existing } = useQuery({
    queryKey: ["meta-existing", tenantId, open],
    enabled: open && !!tenantId,
    queryFn: async () => {
      const [accs, pgs, frms] = await Promise.all([
        supabase.from("meta_ads_accounts").select("account_id").eq("tenant_id", tenantId!),
        supabase.from("meta_lead_ads_pages").select("page_id").eq("tenant_id", tenantId!),
        supabase.from("meta_lead_ads_forms").select("form_id").eq("tenant_id", tenantId!),
      ]);
      return {
        accountIds: new Set((accs.data || []).map((a: any) => a.account_id.replace(/^act_/, ""))),
        pageIds: new Set((pgs.data || []).map((p: any) => p.page_id)),
        formIds: new Set((frms.data || []).map((f: any) => f.form_id)),
      };
    },
  });

  // Reset ao abrir
  useEffect(() => {
    if (open) {
      setStep(1);
      setToken("");
      setShowToken(false);
      setDiscovery(null);
      setSelectedAdAccounts(new Set());
      setSelectedPages(new Set());
      setSelectedForms(new Set());
      setSubscribeLeadgen(true);
    }
  }, [open]);

  const handleValidate = async () => {
    if (!token.trim()) {
      toast({ title: "Cole o token primeiro", variant: "destructive" });
      return;
    }
    setValidating(true);
    try {
      const { data, error } = await supabase.functions.invoke("validate-meta-token", {
        body: { access_token: token.trim() },
      });
      if (error) throw error;
      const resp = data as ValidateMetaResponse;
      if (!resp.ok) {
        toast({ title: "Token inválido", description: resp.error, variant: "destructive" });
        return;
      }
      setDiscovery(resp);

      // Pré-selecionar tudo que já tá conectado
      const accSel = new Set<string>();
      (resp.ad_accounts || []).forEach((a) => {
        const norm = a.account_id.replace(/^act_/, "");
        if (existing?.accountIds.has(norm)) accSel.add(a.account_id);
      });
      setSelectedAdAccounts(accSel);

      const pageSel = new Set<string>();
      const formSel = new Set<string>();
      (resp.pages || []).forEach((p) => {
        if (existing?.pageIds.has(p.page_id)) pageSel.add(p.page_id);
        p.forms.forEach((f) => {
          if (existing?.formIds.has(f.form_id)) formSel.add(f.form_id);
        });
      });
      setSelectedPages(pageSel);
      setSelectedForms(formSel);

      setStep(2);
    } catch (err: any) {
      toast({ title: "Erro ao validar token", description: err.message, variant: "destructive" });
    } finally {
      setValidating(false);
    }
  };

  const handleSave = async () => {
    if (!discovery || !tenantId) return;

    const ad_accounts_payload = (discovery.ad_accounts || [])
      .filter((a) => selectedAdAccounts.has(a.account_id))
      .map((a) => ({ account_id: a.account_id, account_name: a.account_name }));

    const pages_payload = (discovery.pages || [])
      .filter((p) => selectedPages.has(p.page_id))
      .map((p) => ({
        page_id: p.page_id,
        page_name: p.page_name,
        page_access_token: p.page_access_token,
        subscribe_leadgen: subscribeLeadgen,
        forms: p.forms.filter((f) => selectedForms.has(f.form_id)),
      }));

    if (ad_accounts_payload.length === 0 && pages_payload.length === 0) {
      toast({ title: "Selecione pelo menos 1 ativo", variant: "destructive" });
      return;
    }

    setSaving(true);
    try {
      const { data, error } = await supabase.functions.invoke("connect-meta", {
        body: {
          tenant_id: tenantId,
          access_token: token.trim(),
          selected_ad_accounts: ad_accounts_payload,
          selected_pages: pages_payload,
        },
      });
      if (error) throw error;
      if (!data?.ok) {
        toast({ title: "Erro", description: data?.error || "Falha desconhecida", variant: "destructive" });
        return;
      }

      const r = data.result;
      const parts: string[] = [];
      if (r.ad_accounts.created || r.ad_accounts.updated) {
        parts.push(`${r.ad_accounts.created + r.ad_accounts.updated} conta${(r.ad_accounts.created + r.ad_accounts.updated) > 1 ? "s" : ""} de anúncio`);
      }
      if (r.pages.created || r.pages.updated) {
        parts.push(`${r.pages.created + r.pages.updated} página${(r.pages.created + r.pages.updated) > 1 ? "s" : ""}`);
      }
      if (r.forms.created || r.forms.updated) {
        parts.push(`${r.forms.created + r.forms.updated} formulário${(r.forms.created + r.forms.updated) > 1 ? "s" : ""}`);
      }
      if (r.webhooks.subscribed) parts.push(`${r.webhooks.subscribed} webhook${r.webhooks.subscribed > 1 ? "s" : ""}`);

      const conflicts = r.ad_accounts.conflicts || [];
      const failedHooks = r.webhooks.failed || [];

      toast({
        title: "Meta conectado!",
        description: parts.length > 0 ? `Cadastrados: ${parts.join(", ")}` : "Nenhuma mudança",
      });

      if (conflicts.length > 0) {
        toast({
          title: `${conflicts.length} conta${conflicts.length > 1 ? "s" : ""} já pertence${conflicts.length > 1 ? "m" : ""} a outro tenant`,
          description: conflicts.join(", "),
          variant: "destructive",
        });
      }
      if (failedHooks.length > 0) {
        toast({
          title: `${failedHooks.length} webhook${failedHooks.length > 1 ? "s" : ""} falhou`,
          description: failedHooks.map((f: any) => `${f.page_id}: ${f.error}`).join(" · "),
          variant: "destructive",
        });
      }

      queryClient.invalidateQueries({ queryKey: ["meta-ads-accounts"] });
      onSaved();
    } catch (err: any) {
      toast({ title: "Erro ao conectar", description: err.message, variant: "destructive" });
    } finally {
      setSaving(false);
    }
  };

  const togglePage = (pageId: string, forms: Array<{ form_id: string }>) => {
    setSelectedPages((prev) => {
      const next = new Set(prev);
      if (next.has(pageId)) {
        next.delete(pageId);
        // remove forms da page também
        setSelectedForms((fp) => {
          const nf = new Set(fp);
          forms.forEach((f) => nf.delete(f.form_id));
          return nf;
        });
      } else {
        next.add(pageId);
        // seleciona todos os forms da page
        setSelectedForms((fp) => {
          const nf = new Set(fp);
          forms.forEach((f) => nf.add(f.form_id));
          return nf;
        });
      }
      return next;
    });
  };

  const totals = useMemo(() => ({
    accs: selectedAdAccounts.size,
    pages: selectedPages.size,
    forms: selectedForms.size,
  }), [selectedAdAccounts, selectedPages, selectedForms]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl max-h-[90vh] overflow-hidden flex flex-col">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <LinkIcon className="h-5 w-5" />
            Conectar Meta {step === 2 && <span className="text-xs font-normal text-muted-foreground">· Step 2 de 2</span>}
          </DialogTitle>
          <DialogDescription>
            {step === 1
              ? "Cole o token do System User. O sistema descobre automaticamente contas, páginas e formulários disponíveis."
              : `Conectado como ${discovery?.user?.name || "—"}. Escolha o que ativar.`}
          </DialogDescription>
        </DialogHeader>

        {step === 1 && (
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label>Access Token (System User) <span className="text-destructive">*</span></Label>
              <div className="flex gap-2">
                <Input
                  type={showToken ? "text" : "password"}
                  placeholder="EAA..."
                  value={token}
                  onChange={(e) => setToken(e.target.value)}
                  className="font-mono text-xs flex-1"
                  onKeyDown={(e) => e.key === "Enter" && handleValidate()}
                />
                <Button variant="outline" size="icon" onClick={() => setShowToken(!showToken)}>
                  {showToken ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </Button>
              </div>
              <p className="text-[10px] text-muted-foreground">
                Como gerar: Meta Business → Configurações → Usuários do sistema → criar System User com permissões
                <code className="text-[9px] bg-muted px-1 mx-0.5 rounded">ads_management</code>
                <code className="text-[9px] bg-muted px-1 mx-0.5 rounded">leads_retrieval</code>
                <code className="text-[9px] bg-muted px-1 mx-0.5 rounded">pages_*</code>
                → atribuir ativos (páginas, contas de anúncio) → Gerar token (sem expiração)
              </p>
            </div>
          </div>
        )}

        {step === 2 && discovery && (
          <ScrollArea className="flex-1 -mx-6 px-6">
            <div className="space-y-5">
              {/* Permissões faltando */}
              {discovery.permissions_missing && discovery.permissions_missing.length > 0 && (
                <Alert variant="destructive">
                  <AlertTriangle className="h-4 w-4" />
                  <AlertDescription>
                    Permissões faltando: <span className="font-mono">{discovery.permissions_missing.join(", ")}</span>
                  </AlertDescription>
                </Alert>
              )}

              {/* AD ACCOUNTS */}
              <Section icon={BarChart3} title="Contas de Anúncio" description="Pra puxar gasto, CPL e creatives no dashboard.">
                {(discovery.ad_accounts || []).length === 0 ? (
                  <EmptyHint message="Nenhuma conta de anúncio acessível por esse token. Atribua no BM → System User → Adicionar ativos." />
                ) : (
                  <div className="space-y-1.5">
                    {discovery.ad_accounts!.map((a) => {
                      const norm = a.account_id.replace(/^act_/, "");
                      const isExisting = existing?.accountIds.has(norm);
                      return (
                        <SelectableRow
                          key={a.account_id}
                          checked={selectedAdAccounts.has(a.account_id)}
                          onChange={(v) => {
                            setSelectedAdAccounts((prev) => {
                              const next = new Set(prev);
                              if (v) next.add(a.account_id);
                              else next.delete(a.account_id);
                              return next;
                            });
                          }}
                          title={a.account_name}
                          subtitle={`${a.account_id}${a.currency ? ` · ${a.currency}` : ""}`}
                          badge={isExisting ? "Conectado" : undefined}
                        />
                      );
                    })}
                  </div>
                )}
              </Section>

              {/* PAGES + FORMS */}
              <Section icon={Target} title="Lead Ads" description="Recebe leads de anúncios automaticamente no CRM.">
                {(discovery.pages || []).length === 0 ? (
                  <EmptyHint message="Nenhuma página acessível por esse token. Atribua no BM → System User → Adicionar ativos → Páginas." />
                ) : (
                  <>
                    <div className="flex items-center justify-between p-2.5 rounded-md bg-muted/40 mb-2">
                      <div className="flex items-start gap-2 min-w-0">
                        <FileText className="h-3.5 w-3.5 text-muted-foreground mt-0.5 shrink-0" />
                        <div>
                          <p className="text-xs font-medium">Subscrever webhook leadgen</p>
                          <p className="text-[10px] text-muted-foreground">Sem isso, leads não chegam automaticamente.</p>
                        </div>
                      </div>
                      <Switch checked={subscribeLeadgen} onCheckedChange={setSubscribeLeadgen} />
                    </div>

                    <div className="space-y-2">
                      {discovery.pages!.map((p) => {
                        const pageExisting = existing?.pageIds.has(p.page_id);
                        return (
                          <div key={p.page_id} className="border rounded-md p-3 space-y-2">
                            <SelectableRow
                              checked={selectedPages.has(p.page_id)}
                              onChange={() => togglePage(p.page_id, p.forms)}
                              title={p.page_name}
                              subtitle={`Page ${p.page_id}${p.followers ? ` · ${p.followers.toLocaleString("pt-BR")} seguidores` : ""}`}
                              badge={pageExisting ? "Conectado" : undefined}
                            />
                            {selectedPages.has(p.page_id) && p.forms.length > 0 && (
                              <div className="pl-7 space-y-1 border-l-2 border-muted ml-2">
                                {p.forms.map((f) => {
                                  const formExisting = existing?.formIds.has(f.form_id);
                                  return (
                                    <SelectableRow
                                      key={f.form_id}
                                      compact
                                      checked={selectedForms.has(f.form_id)}
                                      onChange={(v) => {
                                        setSelectedForms((prev) => {
                                          const next = new Set(prev);
                                          if (v) next.add(f.form_id);
                                          else next.delete(f.form_id);
                                          return next;
                                        });
                                      }}
                                      title={f.form_name}
                                      subtitle={`${f.leads_count} lead${f.leads_count !== 1 ? "s" : ""} captado${f.leads_count !== 1 ? "s" : ""}`}
                                      badge={formExisting ? "Conectado" : undefined}
                                    />
                                  );
                                })}
                              </div>
                            )}
                            {selectedPages.has(p.page_id) && p.forms.length === 0 && (
                              <p className="pl-7 text-[10px] text-muted-foreground italic">Sem formulários nessa página.</p>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  </>
                )}
              </Section>
            </div>
          </ScrollArea>
        )}

        <DialogFooter className="border-t pt-3">
          {step === 1 && (
            <>
              <Button variant="outline" onClick={() => onOpenChange(false)}>Cancelar</Button>
              <Button onClick={handleValidate} disabled={validating || !token.trim()}>
                {validating && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
                Validar token →
              </Button>
            </>
          )}
          {step === 2 && (
            <>
              <Button variant="ghost" size="sm" onClick={() => setStep(1)} className="mr-auto">
                <ArrowLeft className="h-3.5 w-3.5 mr-1" /> Voltar
              </Button>
              <p className="text-[11px] text-muted-foreground mr-3 self-center">
                {totals.accs} conta{totals.accs !== 1 ? "s" : ""} · {totals.pages} página{totals.pages !== 1 ? "s" : ""} · {totals.forms} form{totals.forms !== 1 ? "s" : ""}
              </p>
              <Button variant="outline" onClick={() => onOpenChange(false)}>Cancelar</Button>
              <Button onClick={handleSave} disabled={saving || (totals.accs === 0 && totals.pages === 0)}>
                {saving && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
                Conectar
              </Button>
            </>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function Section({
  icon: Icon, title, description, children,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-2">
      <div className="flex items-start gap-2">
        <Icon className="h-4 w-4 text-muted-foreground mt-0.5" />
        <div>
          <h4 className="text-sm font-semibold">{title}</h4>
          <p className="text-[11px] text-muted-foreground">{description}</p>
        </div>
      </div>
      {children}
    </div>
  );
}

function SelectableRow({
  checked, onChange, title, subtitle, badge, compact,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  title: string;
  subtitle: string;
  badge?: string;
  compact?: boolean;
}) {
  return (
    <label className={`flex items-center gap-2.5 cursor-pointer hover:bg-muted/40 rounded px-2 ${compact ? "py-1" : "py-1.5"}`}>
      <Checkbox checked={checked} onCheckedChange={(v) => onChange(!!v)} />
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className={`${compact ? "text-xs" : "text-sm"} font-medium truncate`}>{title}</span>
          {badge && (
            <Badge variant="outline" className="text-[9px] h-4 px-1 border-emerald-300 text-emerald-700 bg-emerald-50 dark:bg-emerald-950 dark:text-emerald-400">
              <CheckCircle2 className="h-2.5 w-2.5 mr-0.5" /> {badge}
            </Badge>
          )}
        </div>
        <p className="text-[10px] text-muted-foreground font-mono truncate">{subtitle}</p>
      </div>
    </label>
  );
}

function EmptyHint({ message }: { message: string }) {
  return (
    <Alert>
      <AlertTriangle className="h-4 w-4" />
      <AlertDescription className="text-xs">{message}</AlertDescription>
    </Alert>
  );
}
