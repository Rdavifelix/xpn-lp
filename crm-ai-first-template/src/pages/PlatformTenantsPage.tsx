import { useMemo, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { AppLayout } from '@/components/layout/AppLayout';
import { Button } from '@/components/ui/button';
import { Switch } from '@/components/ui/switch';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { supabase } from '@/lib/supabase';

const field = 'w-full rounded-md border bg-background px-3 py-2 text-sm';

export interface PlatformTenant {
  id: string; name: string; slug: string | null; is_active: boolean; plan: string | null; max_users: number | null;
  trial_ends_at: string | null; suspended_at: string | null; suspended_reason: string | null; created_at: string;
  owner_user_id: string | null; admin_email: string | null; active_users: number; leads_count: number; deals_count: number; last_message_at: string | null;
}
interface PlatformOverview { tenants_total: number; tenants_active: number; tenants_suspended: number; users_active: number; leads_total: number; multi_tenant_enabled: boolean | null; is_superadmin: boolean }
type RpcError = { code?: string; message: string };

/** RPCs de plataforma: executáveis por qualquer autenticado, mas o servidor exige superadmin (42501). */
async function platformRpc<T>(name: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await supabase.rpc(name as never, args as never);
  if (error) throw error;
  return data as T;
}
const isDenied = (e: unknown) => !!e && typeof e === 'object' && ((e as RpcError).code === '42501' || /superadmin/i.test((e as RpcError).message ?? ''));
const fmtDate = (v: string | null | undefined) => (v ? new Date(v).toLocaleDateString('pt-BR') : '—');
const toInputDate = (v: string | null | undefined) => (v ? new Date(v).toISOString().slice(0, 10) : '');

export default function PlatformTenantsPage() {
  const qc = useQueryClient();
  const overview = useQuery({ queryKey: ['platform-overview'], queryFn: () => platformRpc<PlatformOverview>('platform_overview'), retry: false });
  const tenants = useQuery({ queryKey: ['platform-tenants'], queryFn: () => platformRpc<PlatformTenant[]>('platform_list_tenants', { p_search: null, p_limit: 500 }), retry: false });
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [dialog, setDialog] = useState<{ mode: 'edit' | 'suspend'; tenant: PlatformTenant } | null>(null);

  const denied = isDenied(overview.error) || isDenied(tenants.error);
  const rows = useMemo(() => {
    const list = Array.isArray(tenants.data) ? tenants.data : [];
    const q = search.trim().toLowerCase();
    return q ? list.filter((t) => [t.name, t.slug, t.admin_email].some((v) => (v ?? '').toLowerCase().includes(q))) : list;
  }, [tenants.data, search]);

  async function run(fn: () => Promise<unknown>) {
    setBusy(true); setError('');
    try { await fn(); await Promise.all([qc.invalidateQueries({ queryKey: ['platform-overview'] }), qc.invalidateQueries({ queryKey: ['platform-tenants'] })]); setDialog(null); }
    catch (e) { setError((e as Error).message); }
    finally { setBusy(false); }
  }
  const updateTenant = (id: string, data: Record<string, unknown>) => run(() => platformRpc('platform_update_tenant', { p_tenant_id: id, p_data: data }));

  return <AppLayout><main className="max-w-6xl mx-auto p-6 space-y-6">
    <div><h1 className="text-2xl font-semibold">Superadmin · Empresas</h1><p className="text-muted-foreground">Visão geral da plataforma, cadastro self-service e gestão das empresas (tenants).</p></div>
    {denied ? <p role="alert" className="rounded-xl border border-destructive/40 bg-destructive/10 p-4 text-destructive">Acesso restrito: somente o superadmin da plataforma pode ver e administrar as empresas.</p>
    : overview.isLoading || tenants.isLoading ? <p role="status">Carregando…</p> : <>
      {(overview.error || tenants.error) && <p role="alert" className="text-destructive">{(overview.error ?? tenants.error)?.message}</p>}
      {overview.data && <>
        <section className="grid gap-3 grid-cols-2 md:grid-cols-5">
          {([['Empresas', overview.data.tenants_total], ['Ativas', overview.data.tenants_active], ['Suspensas', overview.data.tenants_suspended], ['Usuários ativos', overview.data.users_active], ['Leads', overview.data.leads_total]] as const).map(([label, value]) => (
            <div key={label} className="rounded-xl border bg-card p-4"><p className="text-xs text-muted-foreground">{label}</p><p className="text-2xl font-semibold">{value ?? 0}</p></div>
          ))}
        </section>
        <section className="rounded-xl border bg-card p-5 flex flex-wrap items-center justify-between gap-4">
          <div><h2 className="font-semibold">Cadastro self-service de empresas</h2><p className="text-sm text-muted-foreground">Quando ligado, qualquer pessoa pode criar conta e abrir uma nova empresa na tela de login (modo SaaS). Desligado, novos usuários precisam ser convidados por um administrador.</p></div>
          <label className="flex items-center gap-2 text-sm"><Switch aria-label="Cadastro self-service de empresas" disabled={busy} checked={overview.data.multi_tenant_enabled === true} onCheckedChange={(v) => run(() => platformRpc('platform_set_multi_tenant', { p_enabled: v }))} />{overview.data.multi_tenant_enabled ? 'Ligado' : 'Desligado'}</label>
        </section>
      </>}
      <section className="space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-3"><h2 className="font-semibold">Empresas ({rows.length})</h2><input className={`${field} md:max-w-xs`} value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Buscar por nome, slug ou e-mail" aria-label="Buscar empresa" /></div>
        <div className="rounded-xl border bg-card overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="text-left text-xs text-muted-foreground border-b"><tr><th className="p-3">Empresa</th><th className="p-3">Admin</th><th className="p-3">Plano</th><th className="p-3">Usuários</th><th className="p-3">Leads</th><th className="p-3">Criada em</th><th className="p-3">Status</th><th className="p-3 text-right">Ações</th></tr></thead>
            <tbody>
              {rows.length === 0 && <tr><td colSpan={8} className="p-6 text-center text-muted-foreground">Nenhuma empresa encontrada.</td></tr>}
              {rows.map((t) => <tr key={t.id} className="border-b last:border-0 align-top">
                <td className="p-3"><p className="font-medium">{t.name}</p><p className="text-xs text-muted-foreground">{t.slug ?? '—'}</p></td>
                <td className="p-3">{t.admin_email ?? '—'}</td>
                <td className="p-3">{t.plan ?? '—'}{t.trial_ends_at && <p className="text-xs text-muted-foreground">até {fmtDate(t.trial_ends_at)}</p>}</td>
                <td className="p-3">{t.active_users}{t.max_users != null && <span className="text-muted-foreground"> / {t.max_users}</span>}</td>
                <td className="p-3">{t.leads_count}</td>
                <td className="p-3">{fmtDate(t.created_at)}</td>
                <td className="p-3">{t.is_active ? <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-xs text-emerald-600">ativo</span> : <><span className="rounded-full bg-destructive/10 px-2 py-0.5 text-xs text-destructive">suspenso</span>{t.suspended_reason && <p className="text-xs text-muted-foreground mt-1">{t.suspended_reason}</p>}</>}</td>
                <td className="p-3"><div className="flex justify-end gap-2">
                  <Button size="sm" variant="outline" disabled={busy} onClick={() => setDialog({ mode: 'edit', tenant: t })}>Editar</Button>
                  {t.is_active ? <Button size="sm" variant="outline" disabled={busy} onClick={() => setDialog({ mode: 'suspend', tenant: t })}>Suspender</Button>
                    : <Button size="sm" disabled={busy} onClick={() => updateTenant(t.id, { is_active: true })}>Reativar</Button>}
                </div></td>
              </tr>)}
            </tbody>
          </table>
        </div>
      </section>
    </>}
    {error && <p role="alert" className="text-destructive">{error}</p>}
    {dialog && <TenantDialog key={dialog.tenant.id + dialog.mode} mode={dialog.mode} tenant={dialog.tenant} busy={busy} onClose={() => setDialog(null)} onSave={(data) => updateTenant(dialog.tenant.id, data)} />}
  </main></AppLayout>;
}

function TenantDialog({ mode, tenant: t, busy, onClose, onSave }: { mode: 'edit' | 'suspend'; tenant: PlatformTenant; busy: boolean; onClose: () => void; onSave: (data: Record<string, unknown>) => void }) {
  const [name, setName] = useState(t.name);
  const [plan, setPlan] = useState(t.plan ?? 'trial');
  const [maxUsers, setMaxUsers] = useState(t.max_users == null ? '' : String(t.max_users));
  const [trial, setTrial] = useState(toInputDate(t.trial_ends_at));
  const [reason, setReason] = useState('');
  const suspend = mode === 'suspend';
  return <Dialog open onOpenChange={(o) => { if (!o) onClose(); }}>
    <DialogContent>
      <DialogHeader><DialogTitle>{suspend ? `Suspender ${t.name}` : `Editar ${t.name}`}</DialogTitle><DialogDescription>{suspend ? 'A empresa perde o acesso até ser reativada. Informe o motivo para registro.' : 'Nome, plano, limite de usuários e validade do período de teste.'}</DialogDescription></DialogHeader>
      {suspend ? <label className="text-sm">Motivo<textarea className={field} rows={3} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Ex.: inadimplência, solicitação do cliente…" /></label>
      : <div className="grid gap-3">
        <label className="text-sm">Nome<input className={field} value={name} onChange={(e) => setName(e.target.value)} minLength={2} maxLength={120} /></label>
        <div className="grid grid-cols-3 gap-3">
          <label className="text-sm">Plano<select className={field} value={plan} onChange={(e) => setPlan(e.target.value)}><option value="trial">trial</option><option value="starter">starter</option><option value="pro">pro</option><option value="enterprise">enterprise</option></select></label>
          <label className="text-sm">Máx. usuários<input type="number" min={1} className={field} value={maxUsers} onChange={(e) => setMaxUsers(e.target.value)} placeholder="ilimitado" /></label>
          <label className="text-sm">Fim do teste<input type="date" className={field} value={trial} onChange={(e) => setTrial(e.target.value)} /></label>
        </div>
      </div>}
      <DialogFooter>
        <Button variant="outline" disabled={busy} onClick={onClose}>Cancelar</Button>
        {suspend ? <Button variant="destructive" disabled={busy || reason.trim().length < 3} onClick={() => onSave({ is_active: false, suspended_reason: reason.trim() })}>Suspender</Button>
        : <Button disabled={busy || name.trim().length < 2} onClick={() => onSave({ name: name.trim(), plan, max_users: maxUsers ? Number(maxUsers) : null, trial_ends_at: trial ? new Date(`${trial}T23:59:59`).toISOString() : null })}>Salvar</Button>}
      </DialogFooter>
    </DialogContent>
  </Dialog>;
}
