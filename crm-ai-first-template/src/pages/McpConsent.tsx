import { useEffect, useState, type FormEvent } from 'react';
import { useSearchParams } from 'react-router-dom';
import type { OAuthAuthorizationDetails } from '@supabase/supabase-js';
import { z } from 'zod';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Building2, CheckCircle2, Loader2 } from 'lucide-react';
import ConnectionShell, { flowInput, flowButton, flowSecondary } from '@/components/mcp/ConnectionShell';

const infoSchema = z.object({ tenant_name: z.string(), can_write: z.boolean() });
function redirectToClient(raw: string) {
  // O destino vem exclusivamente da resposta do Auth, nunca de query do navegador.
  const url = new URL(raw);
  if (url.protocol !== 'https:' && !(url.protocol === 'http:' && ['localhost','127.0.0.1','[::1]'].includes(url.hostname))) throw new Error('Endereço de retorno inválido.');
  window.location.assign(url.href);
}

export default function McpConsent() {
  const [params] = useSearchParams();
  const authorizationId = params.get('authorization_id');
  const [details, setDetails] = useState<OAuthAuthorizationDetails | null>(null);
  const [info, setInfo] = useState<z.infer<typeof infoSchema> | null>(null);
  const [needsLogin, setNeedsLogin] = useState(false);
  const [needsCompany, setNeedsCompany] = useState(false);
  const [signup, setSignup] = useState(false);
  const [signupEnabled, setSignupEnabled] = useState(false);
  const [notice, setNotice] = useState('');
  const [companyName, setCompanyName] = useState('');
  const [email, setEmail] = useState('');
  useEffect(() => {
    let active=true;
    supabase.from('config').select('value').eq('key','multi_tenant_enabled').maybeSingle().then(({data})=>{ if(active) setSignupEnabled(data?.value==='true'); });
    return ()=>{ active=false; };
  }, []);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true); setError(''); setDetails(null); setInfo(null); setNeedsCompany(false);
      try {
        if (!authorizationId) throw new Error('Solicitação ausente. Inicie a conexão pelo Claude ou ChatGPT.');
        const { data: { user } } = await supabase.auth.getUser();
        if (cancelled) return;
        if (!user) { setNeedsLogin(true); return; }
        setNeedsLogin(false); setEmail(user.email ?? '');
        const { data, error: authError } = await supabase.auth.oauth.getAuthorizationDetails(authorizationId);
        if (cancelled) return;
        if (authError || !data) throw new Error('Solicitação inválida ou expirada. Reinicie a conexão na sua IA.');
        if (!user.app_metadata?.tenant_id) { setNeedsCompany(true); return; }
        if ('redirect_url' in data) { redirectToClient(data.redirect_url); return; }
        setDetails(data);
        // Nova RPC da migration MCP; os tipos gerados ainda não incluem esta função.
        const { data: permission, error: permissionError } = await supabase.rpc('mcp_authorization_info' as never, { p_client_id: data.client.id } as never);
        if (cancelled) return;
        if (permissionError) throw new Error(permissionError.code === '42501' ? permissionError.message : 'Não foi possível verificar esta conexão. Tente novamente em instantes.');
        setInfo(infoSchema.parse(permission));
      } catch (e) { if (!cancelled) setError(e instanceof Error ? e.message : 'Não foi possível carregar a conexão.'); }
      finally { if (!cancelled) setLoading(false); }
    }
    void load();
    return () => { cancelled = true; };
  }, [authorizationId, attempt]);

  async function authenticate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (!authorizationId || (signup && !signupEnabled)) return;
    setBusy(true); setError(''); setNotice('');
    const fields = new FormData(event.currentTarget);
    const credentials={email:String(fields.get('email')).trim(),password:String(fields.get('password'))};
    try {
      if (signup) {
        const {data,error:signupError}=await supabase.auth.signUp({...credentials,options:{
          data:{name:String(fields.get('name')).trim()},
          emailRedirectTo:`${window.location.origin}/oauth/consent?authorization_id=${encodeURIComponent(authorizationId)}`,
        }});
        if(signupError) throw new Error(signupError.message);
        if(!data.session) { setNotice('Confira seu e-mail para confirmar a conta e continuar esta conexão. Se você já tem conta, entre com sua senha.'); return; }
      } else {
        const {error:loginError}=await supabase.auth.signInWithPassword(credentials);
        if(loginError) throw new Error('Não foi possível entrar. Confira seu e-mail e senha.');
      }
      setAttempt(value=>value+1);
    } catch(e) { setError(e instanceof Error?e.message:'Falha de conexão. Tente novamente.'); }
    finally { setBusy(false); }
  }
  async function createCompany(event:FormEvent) {
    event.preventDefault(); if(!signupEnabled) return;
    setBusy(true);setError('');
    try {
      const {error:createError}=await supabase.rpc('tenant_onboard' as never,{p_organization_name:companyName.trim()} as never);
      if(createError) throw new Error(createError.message);
      const {error:refreshError}=await supabase.auth.refreshSession();
      if(refreshError) throw new Error('Sua empresa foi criada. Entre novamente para atualizar seu acesso e continuar.');
      setAttempt(value=>value+1);
    } catch(e) { setError(e instanceof Error?e.message:'Não foi possível preparar sua empresa. Tente novamente.'); }
    finally { setBusy(false); }
  }
  async function changeAccount() {
    setBusy(true);
    try { await supabase.auth.signOut();setAttempt(value=>value+1); }
    finally {setBusy(false);}
  }
  async function decide(approve: boolean) {
    if (!authorizationId || (approve && !info)) return;
    setBusy(true); setError('');
    try {
      const result = approve
        ? await supabase.auth.oauth.approveAuthorization(authorizationId, { skipBrowserRedirect: true })
        : await supabase.auth.oauth.denyAuthorization(authorizationId, { skipBrowserRedirect: true });
      if (result.error || !result.data) throw new Error('Não foi possível concluir. Reinicie a conexão na sua IA.');
      redirectToClient(result.data.redirect_url);
    } catch (e) { setError(e instanceof Error ? e.message : 'Falha ao concluir.'); setBusy(false); }
  }
  const step=needsLogin?1:needsCompany?2:3;
  return <ConnectionShell step={step} title={needsLogin?(signup?'Comece pela sua conta':'Bom ter você por aqui'):needsCompany?'Dê um nome à sua empresa':'Você está no controle'} description={needsLogin?'Entre ou crie sua conta para continuar a conexão com sua IA.':needsCompany?'Vamos preparar um ambiente exclusivo para sua operação.':'Confira o ambiente e escolha se deseja autorizar esta conexão.'}>
    {loading && <p role="status" className="flex items-center gap-2 text-sm text-slate-400"><Loader2 className="animate-spin" size={17}/> Conferindo sua conexão…</p>}
    {error && <p role="alert" className="rounded-xl border border-red-400/20 bg-red-400/10 p-4 text-sm leading-6 text-red-200">{error}</p>}
    {notice && <p role="status" className="rounded-xl border border-amber-400/20 bg-amber-400/10 p-4 text-sm leading-6 text-amber-200">{notice}</p>}
    {needsLogin && !loading && <>
      {signupEnabled && <div className="flex rounded-xl bg-black/25 p-1" aria-label="Acesso à conta">{[false,true].map(create=><button key={String(create)} type="button" disabled={busy} onClick={()=>{setSignup(create);setError('');setNotice('');}} className={`flex-1 rounded-lg py-2.5 text-sm font-medium transition-colors ${signup===create?'bg-white/10 text-white':'text-slate-500 hover:text-white'}`}>{create?'Criar conta':'Já tenho conta'}</button>)}</div>}
      <form onSubmit={authenticate} className="space-y-4">
        {signup && <div className="space-y-2"><Label htmlFor="mcp-name">Seu nome</Label><Input className={flowInput} id="mcp-name" name="name" autoComplete="name" placeholder="Como podemos chamar você?" maxLength={120} required/></div>}
        <div className="space-y-2"><Label htmlFor="mcp-email">E-mail</Label><Input className={flowInput} id="mcp-email" name="email" type="email" autoComplete="username" placeholder="voce@empresa.com.br" required /></div>
        <div className="space-y-2"><Label htmlFor="mcp-password">Senha</Label><Input className={flowInput} id="mcp-password" name="password" type="password" minLength={signup?8:undefined} autoComplete={signup?'new-password':'current-password'} placeholder={signup?'Pelo menos 8 caracteres':'Sua senha do CRM'} required /></div>
        <Button className={flowButton} disabled={busy} type="submit">{busy?'Preparando…':signup?'Criar conta e continuar':'Entrar e continuar'}</Button>
        <p className="text-center text-xs leading-5 text-slate-500">Você confere e autoriza o acesso da IA na última etapa.</p>
      </form>
    </>}
    {needsCompany && !loading && <>
      <div className="flex items-center gap-3 rounded-xl bg-white/5 p-4"><Building2 size={20} className="text-amber-400"/><p className="break-all text-sm text-slate-300">{email}</p></div>
      {signupEnabled?<form onSubmit={createCompany} className="space-y-4"><div className="space-y-2"><Label htmlFor="mcp-company">Nome da empresa</Label><Input className={flowInput} id="mcp-company" value={companyName} onChange={e=>setCompanyName(e.target.value)} placeholder="Ex.: Costa Consultoria" minLength={2} maxLength={120} required/></div><Button className={flowButton} disabled={busy} type="submit">{busy?'Criando seu ambiente…':'Criar empresa e continuar'}</Button></form>:<p role="status" className="text-sm text-slate-400">O cadastro de empresas ainda não foi liberado. Solicite o vínculo da sua conta ao administrador.</p>}
      <Button className={flowSecondary} variant="outline" disabled={busy} onClick={changeAccount}>Entrar com outra conta</Button>
    </>}
    {details && !loading && <>
      <p className="text-sm text-slate-300"><strong className="text-white">{details.client.name}</strong> solicita acesso ao seu CRM. Autorize somente se você iniciou esta conexão no aplicativo que deseja usar.</p>
      {info && <div className="space-y-5 rounded-2xl border border-white/10 bg-white/[.025] p-5">
        <div className="flex items-center gap-3"><span className="rounded-xl bg-amber-400/10 p-3 text-amber-400"><Building2 size={22}/></span><div><p className="text-xs text-slate-500">Ambiente conectado</p><p className="font-semibold">{info.tenant_name}</p></div></div>
        <div className="space-y-3 text-sm text-slate-300"><p className="flex gap-2"><CheckCircle2 className="shrink-0 text-amber-400" size={17}/> Consultar sua empresa, funis e agentes.</p>{info.can_write && <p className="flex gap-2"><CheckCircle2 className="shrink-0 text-amber-400" size={17}/> Criar novos funis, etapas e rascunhos de agentes.</p>}</div>
        {details.scope && <p className="border-t border-white/10 pt-3 text-xs text-slate-500">Dados de identidade solicitados: {details.scope}</p>}
      </div>}
      <Button className={flowButton} disabled={busy || !info} onClick={()=>decide(true)}>{busy?'Conectando…':'Autorizar conexão'}</Button>
      <div className="flex items-center justify-between"><Button className={flowSecondary} variant="outline" disabled={busy} onClick={()=>decide(false)}>Recusar</Button><button className="text-xs text-slate-500 hover:text-white" disabled={busy} onClick={changeAccount}>Trocar conta</button></div>
      <p className="text-center text-xs leading-5 text-slate-500">Você pode desconectar sua IA a qualquer momento.</p>
    </>}
  </ConnectionShell>;
}
