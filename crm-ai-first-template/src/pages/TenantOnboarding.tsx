import { useEffect, useState, type FormEvent } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import ConnectionShell, { flowInput, flowButton, flowSecondary } from '@/components/mcp/ConnectionShell';

export default function TenantOnboarding() {
  const { user, loading, teamMember, signOut } = useAuth();
  const location = useLocation();
  const [name, setName] = useState(typeof location.state?.organizationName === 'string' ? location.state.organizationName : '');
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [createdSlug, setCreatedSlug] = useState('');
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let active = true;
    setEnabled(null); setError('');
    supabase.from('config').select('value').eq('key','multi_tenant_enabled').maybeSingle()
      .then(({data,error: configError}) => {
        if (!active) return;
        setEnabled(!configError && data?.value === 'true');
        if (configError) setError('Não foi possível verificar a liberação do cadastro. Tente novamente.');
      });
    return () => { active=false; };
  }, [attempt]);
  if (loading) return <p className="p-8" role="status">Carregando sua conta…</p>;
  if (!user) return <Navigate to="/login" replace />;
  if (teamMember?.is_active && teamMember.tenant_id === user.app_metadata?.tenant_id) return <Navigate to="/conectar-ia" replace />;

  async function submit(event: FormEvent) {
    event.preventDefault(); if (!enabled) return;
    setBusy(true); setError('');
    try {
      const { data, error: createError } = await supabase.rpc('tenant_onboard' as never, { p_organization_name:name.trim() } as never);
      if (createError) throw new Error(createError.message);
      const slug = typeof (data as { slug?: unknown } | null)?.slug === 'string' ? (data as { slug: string }).slug : '';
      const { error: refreshError } = await supabase.auth.refreshSession();
      if (refreshError) throw new Error('Empresa criada. Saia e entre novamente para atualizar seu acesso.');
      if (slug) { setCreatedSlug(slug); await new Promise(r => setTimeout(r, 1500)); }
      window.location.assign('/conectar-ia');
    } catch (e) { setError(e instanceof Error ? e.message : 'Não foi possível criar sua empresa. Você pode tentar novamente.'); }
    finally { setBusy(false); }
  }
  return <ConnectionShell step={2} title="Seu ambiente no CRM" description="Um espaço exclusivo para organizar sua operação e conectar sua inteligência.">
    <p>Conta: {user.email}</p>
    {createdSlug && <p role="status" className="rounded-xl bg-emerald-400/10 p-4 text-sm text-emerald-200">Ambiente <strong>{createdSlug}</strong> criado. Redirecionando…</p>}
    {enabled === null ? <p role="status">Verificando disponibilidade…</p> : enabled ? <form onSubmit={submit} className="space-y-4">
      <p>Crie o ambiente da sua empresa para começar a configurar seu processo.</p>
      <Label htmlFor="company-name">Nome da empresa</Label>
      <Input className={flowInput} id="company-name" value={name} onChange={e=>setName(e.target.value)} minLength={2} maxLength={120} required />
      <Button className={flowButton} type="submit" disabled={busy}>{busy ? 'Preparando seu ambiente…' : 'Criar minha empresa'}</Button>
    </form> : <div className="space-y-3">
      <p role="status">A conta <strong>{user.email}</strong> ainda não está vinculada a nenhuma empresa, e o cadastro self-service de novas empresas está desativado nesta instalação. Peça ao administrador para convidar você ou liberar o cadastro — depois, tente novamente.</p>
      <Button className={flowSecondary} variant="outline" type="button" disabled={busy} onClick={()=>setAttempt(a=>a+1)}>Tentar novamente</Button>
    </div>}
    {error && <p role="alert" className="rounded-xl bg-red-400/10 p-4 text-sm text-red-200">{error}</p>}
    <Button className={flowSecondary} variant="outline" disabled={busy} onClick={()=>signOut()}>Sair da conta</Button>
  </ConnectionShell>;
}
