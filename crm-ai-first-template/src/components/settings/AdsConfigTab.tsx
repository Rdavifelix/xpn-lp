import { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { useToast } from "@/hooks/use-toast";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from "@/components/ui/dialog";
import {
  Tabs, TabsContent, TabsList, TabsTrigger,
} from "@/components/ui/tabs";
import {
  Plus, Pencil, Trash2, Loader2, Eye, EyeOff, RefreshCw, CheckCircle2, XCircle, ExternalLink, Play, Link as LinkIcon,
} from "lucide-react";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { ConnectMetaModal } from "./ConnectMetaModal";

// ============================================================
// Configuração Meta Ads + Google Ads — per tenant
// ============================================================

interface MetaAdsAccount {
  id: string;
  account_id: string;
  account_name: string | null;
  access_token: string | null;
  is_active: boolean;
  last_synced_date: string | null;
  tenant_id: string;
}

interface GoogleAdsAccount {
  id: string;
  account_id: string;
  account_name: string | null;
  access_token: string | null;
  developer_token: string | null;
  manager_account_id: string | null;
  is_active: boolean;
  last_synced_date: string | null;
  tenant_id: string;
}

function SyncButton({ tenantId }: { tenantId: string }) {
  const { toast } = useToast();
  const [syncing, setSyncing] = useState(false);

  const handleSync = async () => {
    setSyncing(true);
    try {
      const { data, error } = await supabase.functions.invoke("sync-ads-data", {
        body: { tenant_id: tenantId, days_back: 7 },
      });
      if (error) throw error;
      const ok = (data?.results || []).filter((r: any) => r.status === "ok").length;
      const errs = (data?.results || []).filter((r: any) => r.status === "error").length;
      toast({
        title: `Sync concluído: ${ok} contas OK${errs ? `, ${errs} com erro` : ""}`,
        variant: errs ? "destructive" : "default",
      });
    } catch (err: any) {
      toast({ title: "Erro no sync", description: err.message, variant: "destructive" });
    } finally { setSyncing(false); }
  };

  return (
    <Button variant="outline" size="sm" onClick={handleSync} disabled={syncing}>
      {syncing ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <RefreshCw className="h-4 w-4 mr-2" />}
      {syncing ? "Sincronizando..." : "Sincronizar métricas agora"}
    </Button>
  );
}

export function AdsConfigTab() {
  const { tenantId } = useAuth();

  return (
    <div className="space-y-4">
      {tenantId && <SyncButton tenantId={tenantId} />}
      <Tabs defaultValue="meta" className="space-y-4">
      <TabsList>
        <TabsTrigger value="meta" className="flex items-center gap-2">
          <svg className="h-4 w-4" viewBox="0 0 24 24" fill="currentColor"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg>
          Meta Ads
        </TabsTrigger>
        <TabsTrigger value="google" className="flex items-center gap-2">
          <svg className="h-4 w-4" viewBox="0 0 24 24" fill="currentColor"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 01-2.2 3.32v2.76h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>
          Google Ads
        </TabsTrigger>
      </TabsList>

      <TabsContent value="meta">
        <MetaAdsSection />
      </TabsContent>
      <TabsContent value="google">
        <GoogleAdsSection />
      </TabsContent>
    </Tabs>
    </div>
  );
}

// ============================================================
// META ADS SECTION
// ============================================================

function MetaAdsSection() {
  const { tenantId } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [modalOpen, setModalOpen] = useState(false);
  const [connectOpen, setConnectOpen] = useState(false);
  const [editing, setEditing] = useState<MetaAdsAccount | null>(null);

  const { data: accounts = [], isLoading } = useQuery({
    queryKey: ["meta-ads-accounts", tenantId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("meta_ads_accounts")
        .select("*")
        .eq("tenant_id", tenantId!)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data || []) as MetaAdsAccount[];
    },
    enabled: !!tenantId,
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("meta_ads_accounts").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["meta-ads-accounts"] });
      toast({ title: "Conta removida" });
    },
  });

  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between gap-4">
        <div>
          <CardTitle className="text-base">Contas Meta Ads</CardTitle>
          <CardDescription>
            Use <b>Conectar Meta</b> (recomendado): cola o token e o sistema descobre contas, páginas e formulários
            automaticamente. Ou cadastre manual em "Nova conta".
          </CardDescription>
        </div>
        <div className="flex gap-2 shrink-0">
          <Button size="sm" onClick={() => setConnectOpen(true)}>
            <LinkIcon className="h-4 w-4 mr-2" /> Conectar Meta
          </Button>
          <Button size="sm" variant="outline" onClick={() => { setEditing(null); setModalOpen(true); }}>
            <Plus className="h-4 w-4 mr-2" /> Nova conta
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="text-center py-6 text-muted-foreground text-sm"><Loader2 className="h-4 w-4 animate-spin inline mr-2" />Carregando...</div>
        ) : accounts.length === 0 ? (
          <div className="text-center py-8 text-muted-foreground text-sm">Nenhuma conta cadastrada</div>
        ) : (
          <div className="space-y-3">
            {accounts.map((acc) => (
              <AccountRow
                key={acc.id}
                name={acc.account_name || acc.account_id}
                accountId={acc.account_id}
                isActive={acc.is_active}
                lastSynced={acc.last_synced_date}
                hasToken={!!acc.access_token}
                provider="meta"
                onEdit={() => { setEditing(acc); setModalOpen(true); }}
                onDelete={() => { if (confirm("Remover esta conta?")) deleteMutation.mutate(acc.id); }}
              />
            ))}
          </div>
        )}
      </CardContent>

      <MetaAdsFormModal
        open={modalOpen}
        onOpenChange={setModalOpen}
        account={editing}
        tenantId={tenantId!}
        onSaved={() => {
          queryClient.invalidateQueries({ queryKey: ["meta-ads-accounts"] });
          setModalOpen(false);
        }}
      />

      <ConnectMetaModal
        open={connectOpen}
        onOpenChange={setConnectOpen}
        onSaved={() => {
          queryClient.invalidateQueries({ queryKey: ["meta-ads-accounts"] });
          setConnectOpen(false);
        }}
      />
    </Card>
  );
}

// ============================================================
// GOOGLE ADS SECTION
// ============================================================

function GoogleAdsSection() {
  const { tenantId } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<GoogleAdsAccount | null>(null);

  const { data: accounts = [], isLoading } = useQuery({
    queryKey: ["google-ads-accounts", tenantId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("google_ads_accounts")
        .select("*")
        .eq("tenant_id", tenantId!)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data || []) as GoogleAdsAccount[];
    },
    enabled: !!tenantId,
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("google_ads_accounts").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["google-ads-accounts"] });
      toast({ title: "Conta removida" });
    },
  });

  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between gap-4">
        <div>
          <CardTitle className="text-base">Contas Google Ads</CardTitle>
          <CardDescription>Contas de anúncio do Google pra puxar métricas no dashboard.</CardDescription>
        </div>
        <Button size="sm" onClick={() => { setEditing(null); setModalOpen(true); }}>
          <Plus className="h-4 w-4 mr-2" /> Nova conta
        </Button>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="text-center py-6 text-muted-foreground text-sm"><Loader2 className="h-4 w-4 animate-spin inline mr-2" />Carregando...</div>
        ) : accounts.length === 0 ? (
          <div className="text-center py-8 text-muted-foreground text-sm">Nenhuma conta cadastrada</div>
        ) : (
          <div className="space-y-3">
            {accounts.map((acc) => (
              <AccountRow
                key={acc.id}
                name={acc.account_name || acc.account_id}
                accountId={acc.account_id}
                isActive={acc.is_active}
                lastSynced={acc.last_synced_date}
                hasToken={!!acc.access_token}
                provider="google"
                onEdit={() => { setEditing(acc); setModalOpen(true); }}
                onDelete={() => { if (confirm("Remover esta conta?")) deleteMutation.mutate(acc.id); }}
              />
            ))}
          </div>
        )}
      </CardContent>

      <GoogleAdsFormModal
        open={modalOpen}
        onOpenChange={setModalOpen}
        account={editing}
        tenantId={tenantId!}
        onSaved={() => {
          queryClient.invalidateQueries({ queryKey: ["google-ads-accounts"] });
          setModalOpen(false);
        }}
      />
    </Card>
  );
}

// ============================================================
// SHARED: Account Row
// ============================================================

function AccountRow({ name, accountId, isActive, lastSynced, hasToken, provider, onEdit, onDelete }: {
  name: string; accountId: string; isActive: boolean; lastSynced: string | null; hasToken: boolean;
  provider: "meta" | "google"; onEdit: () => void; onDelete: () => void;
}) {
  return (
    <div className="flex items-center justify-between p-3 border rounded-lg bg-card">
      <div className="flex items-center gap-3 min-w-0 flex-1">
        <div className={`h-8 w-8 rounded-md flex items-center justify-center shrink-0 ${provider === "meta" ? "bg-blue-50 text-blue-600" : "bg-red-50 text-red-600"}`}>
          {provider === "meta" ? "M" : "G"}
        </div>
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <span className="font-medium text-sm truncate">{name}</span>
            {isActive ? (
              <Badge variant="outline" className="text-[10px] bg-green-50 text-green-700 border-green-200">Ativo</Badge>
            ) : (
              <Badge variant="outline" className="text-[10px]">Inativo</Badge>
            )}
            {hasToken ? (
              <CheckCircle2 className="h-3 w-3 text-green-500" />
            ) : (
              <XCircle className="h-3 w-3 text-red-400" />
            )}
          </div>
          <div className="text-[11px] text-muted-foreground font-mono">{accountId}</div>
          {lastSynced && <div className="text-[10px] text-muted-foreground">Último sync: {lastSynced}</div>}
        </div>
      </div>
      <div className="flex gap-1 shrink-0">
        <Button variant="ghost" size="icon" onClick={onEdit}><Pencil className="h-3.5 w-3.5" /></Button>
        <Button variant="ghost" size="icon" onClick={onDelete}><Trash2 className="h-3.5 w-3.5 text-destructive" /></Button>
      </div>
    </div>
  );
}

// ============================================================
// META ADS FORM MODAL
// ============================================================

function MetaAdsFormModal({ open, onOpenChange, account, tenantId, onSaved }: {
  open: boolean; onOpenChange: (v: boolean) => void; account: MetaAdsAccount | null;
  tenantId: string; onSaved: () => void;
}) {
  const { toast } = useToast();
  const [accountId, setAccountId] = useState("");
  const [accountName, setAccountName] = useState("");
  const [accessToken, setAccessToken] = useState("");
  const [saving, setSaving] = useState(false);
  const [showToken, setShowToken] = useState(false);

  useEffect(() => {
    if (!open) return;
    setAccountId(account?.account_id || "");
    setAccountName(account?.account_name || "");
    setAccessToken(account?.access_token || "");
    setShowToken(false);
  }, [open, account.id, account?.account_id, account?.account_name, account?.access_token]);

  const handleSave = async () => {
    if (!accountId.trim()) { toast({ title: "Account ID obrigatório", variant: "destructive" }); return; }
    setSaving(true);
    try {
      if (account) {
        const { error } = await supabase.from("meta_ads_accounts").update({
          account_id: accountId.trim(), account_name: accountName.trim() || null,
          access_token: accessToken.trim() || null,
        }).eq("id", account.id).eq("tenant_id", tenantId);
        if (error) throw error;
      } else {
        const { error } = await supabase.from("meta_ads_accounts").insert({
          tenant_id: tenantId, account_id: accountId.trim(),
          account_name: accountName.trim() || null, access_token: accessToken.trim() || null,
        });
        if (error) throw error;
      }
      toast({ title: account ? "Conta atualizada" : "Conta cadastrada" });
      onSaved();
    } catch (err: any) {
      toast({ title: "Erro", description: err.message, variant: "destructive" });
    } finally { setSaving(false); }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[480px]">
        <DialogHeader>
          <DialogTitle>{account ? "Editar conta Meta Ads" : "Nova conta Meta Ads"}</DialogTitle>
          <DialogDescription>
            Pegue o Account ID em{" "}
            <a href="https://adsmanager.facebook.com/adsmanager/manage/accounts" target="_blank" rel="noopener noreferrer" className="text-accent hover:underline">
              Meta Ads Manager <ExternalLink className="h-3 w-3 inline" />
            </a>
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4 py-2">
          <div className="space-y-2">
            <Label>Account ID <span className="text-destructive">*</span></Label>
            <Input placeholder="884652616778712" value={accountId} onChange={(e) => setAccountId(e.target.value)} className="font-mono" />
          </div>
          <div className="space-y-2">
            <Label>Nome (identificação)</Label>
            <Input placeholder="Ex: BM Vagas - Principal" value={accountName} onChange={(e) => setAccountName(e.target.value)} />
          </div>
          <div className="space-y-2">
            <Label>Access Token (System User)</Label>
            <div className="flex gap-2">
              <Input
                type={showToken ? "text" : "password"}
                placeholder="EAA..." value={accessToken}
                onChange={(e) => setAccessToken(e.target.value)} className="font-mono text-xs flex-1"
              />
              <Button variant="outline" size="icon" onClick={() => setShowToken(!showToken)}>
                {showToken ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </Button>
            </div>
            <p className="text-[10px] text-muted-foreground">
              Gere em Meta Business → Configurações → Usuários do sistema → Gerar token (permissões: ads_read, ads_management)
            </p>
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancelar</Button>
          <Button onClick={handleSave} disabled={saving || !accountId.trim()}>
            {saving && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
            {account ? "Salvar" : "Cadastrar"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ============================================================
// GOOGLE ADS FORM MODAL
// ============================================================

function GoogleAdsFormModal({ open, onOpenChange, account, tenantId, onSaved }: {
  open: boolean; onOpenChange: (v: boolean) => void; account: GoogleAdsAccount | null;
  tenantId: string; onSaved: () => void;
}) {
  const { toast } = useToast();
  const [accountId, setAccountId] = useState("");
  const [accountName, setAccountName] = useState("");
  const [accessToken, setAccessToken] = useState("");
  const [developerToken, setDeveloperToken] = useState("");
  const [managerAccountId, setManagerAccountId] = useState("");
  const [saving, setSaving] = useState(false);
  const [showToken, setShowToken] = useState(false);

  useEffect(() => {
    if (!open) return;
    setAccountId(account?.account_id || "");
    setAccountName(account?.account_name || "");
    setAccessToken(account?.access_token || "");
    setDeveloperToken(account?.developer_token || "");
    setManagerAccountId(account?.manager_account_id || "");
    setShowToken(false);
  }, [open, account.id, account?.account_id, account?.account_name, account?.access_token, account?.developer_token, account?.manager_account_id]);

  const handleSave = async () => {
    if (!accountId.trim()) { toast({ title: "Customer ID obrigatório", variant: "destructive" }); return; }
    setSaving(true);
    try {
      if (account) {
        const { error } = await supabase.from("google_ads_accounts").update({
          account_id: accountId.trim(), account_name: accountName.trim() || null,
          access_token: accessToken.trim() || null, developer_token: developerToken.trim() || null,
          manager_account_id: managerAccountId.trim() || null,
        }).eq("id", account.id).eq("tenant_id", tenantId);
        if (error) throw error;
      } else {
        const { error } = await supabase.from("google_ads_accounts").insert({
          tenant_id: tenantId, account_id: accountId.trim(),
          account_name: accountName.trim() || null, access_token: accessToken.trim() || null,
          developer_token: developerToken.trim() || null, manager_account_id: managerAccountId.trim() || null,
        });
        if (error) throw error;
      }
      toast({ title: account ? "Conta atualizada" : "Conta cadastrada" });
      onSaved();
    } catch (err: any) {
      toast({ title: "Erro", description: err.message, variant: "destructive" });
    } finally { setSaving(false); }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[480px]">
        <DialogHeader>
          <DialogTitle>{account ? "Editar conta Google Ads" : "Nova conta Google Ads"}</DialogTitle>
          <DialogDescription>
            Pegue o Customer ID em{" "}
            <a href="https://ads.google.com" target="_blank" rel="noopener noreferrer" className="text-accent hover:underline">
              Google Ads <ExternalLink className="h-3 w-3 inline" />
            </a>
            {" "}(formato: 619-288-5386)
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4 py-2">
          <div className="space-y-2">
            <Label>Customer ID <span className="text-destructive">*</span></Label>
            <Input placeholder="619-288-5386" value={accountId} onChange={(e) => setAccountId(e.target.value)} className="font-mono" />
          </div>
          <div className="space-y-2">
            <Label>Nome (identificação)</Label>
            <Input placeholder="Ex: BM Vagas - Google" value={accountName} onChange={(e) => setAccountName(e.target.value)} />
          </div>
          <div className="space-y-2">
            <Label>Developer Token</Label>
            <div className="flex gap-2">
              <Input
                type={showToken ? "text" : "password"}
                placeholder="Token do Google Ads API" value={developerToken}
                onChange={(e) => setDeveloperToken(e.target.value)} className="font-mono text-xs flex-1"
              />
              <Button variant="outline" size="icon" onClick={() => setShowToken(!showToken)}>
                {showToken ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </Button>
            </div>
          </div>
          <div className="space-y-2">
            <Label>Manager Account ID (MCC)</Label>
            <Input placeholder="Opcional — formato: 123-456-7890" value={managerAccountId} onChange={(e) => setManagerAccountId(e.target.value)} className="font-mono" />
          </div>
          <div className="space-y-2">
            <Label>OAuth Refresh Token</Label>
            <Input
              type="password" placeholder="Refresh token OAuth"
              value={accessToken} onChange={(e) => setAccessToken(e.target.value)} className="font-mono text-xs"
            />
            <p className="text-[10px] text-muted-foreground">
              Gerado via OAuth flow do Google Ads API. Necessário pra puxar métricas automaticamente.
            </p>
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancelar</Button>
          <Button onClick={handleSave} disabled={saving || !accountId.trim()}>
            {saving && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
            {account ? "Salvar" : "Cadastrar"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
