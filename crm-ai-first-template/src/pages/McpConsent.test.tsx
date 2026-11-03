import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import McpConsent from './McpConsent';
import McpConnect from './McpConnect';

const mocks = vi.hoisted(() => ({ getUser: vi.fn(), getDetails: vi.fn(), rpc: vi.fn(), approve: vi.fn(), deny: vi.fn(), signUp:vi.fn(), signIn:vi.fn(), refresh:vi.fn(), signOut:vi.fn() }));
vi.mock('@/lib/supabase', () => ({ supabase: { from:()=>({select:()=>({eq:()=>({maybeSingle:()=>Promise.resolve({data:{value:'true'}})})})}), rpc: mocks.rpc, auth: { getUser: mocks.getUser, signUp:mocks.signUp,signInWithPassword:mocks.signIn,refreshSession:mocks.refresh,signOut:mocks.signOut, oauth: {
  getAuthorizationDetails: mocks.getDetails, approveAuthorization: mocks.approve, denyAuthorization: mocks.deny,
} } } }));
const details = { authorization_id: 'request', client: { id: 'client', name: 'Cliente da imersão' }, scope: 'openid' };
const open = (path = '/oauth/consent?authorization_id=request') => render(<MemoryRouter initialEntries={[path]}><McpConsent /></MemoryRouter>);
beforeEach(() => {
  vi.resetAllMocks();
  mocks.getUser.mockResolvedValue({ data: { user: { id: 'user', app_metadata:{tenant_id:'tenant'} } } });
  mocks.getDetails.mockResolvedValue({ data: details, error: null });
});
afterEach(() => { cleanup(); vi.unstubAllEnvs(); });
describe('consentimento MCP', () => {
  it('não permite aprovar uma conexão sem vínculo/cliente autorizado', async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: { code: '42501', message: 'Este aplicativo está bloqueado ou possui um endereço de retorno inválido.' } });
    open();
    expect(await screen.findByRole('alert')).toHaveTextContent('Este aplicativo está bloqueado');
    expect(screen.getByRole('button', { name: 'Autorizar conexão' })).toBeDisabled();
    expect(mocks.approve).not.toHaveBeenCalled();
  });
  it('mostra empresa e permissão de leitura; só aprova após clique', async () => {
    mocks.rpc.mockResolvedValue({ data: { tenant_name: 'Empresa A', can_write: false }, error: null });
    mocks.approve.mockResolvedValue({ data: null, error: { message: 'expired' } });
    open();
    expect(await screen.findByText('Empresa A')).toBeInTheDocument();
    expect(screen.queryByText(/Criar novos funis/)).not.toBeInTheDocument();
    expect(mocks.approve).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole('button', { name: 'Autorizar conexão' }));
    expect(mocks.approve).toHaveBeenCalledWith('request', { skipBrowserRedirect: true });
    expect(await screen.findByRole('alert')).toHaveTextContent('Reinicie');
  });
  it('sem authorization_id não consulta nem autoriza o provedor', async () => {
    open('/oauth/consent');
    expect(await screen.findByRole('alert')).toHaveTextContent('Solicitação ausente');
    expect(mocks.getDetails).not.toHaveBeenCalled();
  });
  it('cria conta, provisiona empresa e retoma o mesmo pedido sem autorizar automaticamente', async () => {
    mocks.getUser.mockResolvedValueOnce({data:{user:null}}).mockResolvedValueOnce({data:{user:{id:'new',email:'nova@example.com',app_metadata:{}}}}).mockResolvedValue({data:{user:{id:'new',app_metadata:{tenant_id:'new-tenant'}}}});
    mocks.signUp.mockResolvedValue({data:{session:{access_token:'test'}},error:null});
    mocks.refresh.mockResolvedValue({error:null});
    mocks.rpc.mockImplementation((name)=>Promise.resolve(name==='tenant_onboard'?{data:{tenant_id:'new-tenant'},error:null}:{data:{tenant_name:'Minha empresa',can_write:true},error:null}));
    open();
    fireEvent.click(await screen.findByRole('button',{name:'Criar conta',exact:true}));
    fireEvent.change(screen.getByLabelText('Seu nome'),{target:{value:'Pessoa Nova'}});
    fireEvent.change(screen.getByLabelText('E-mail'),{target:{value:'nova@example.com'}});
    fireEvent.change(screen.getByLabelText('Senha'),{target:{value:'senha-de-teste-123'}});
    fireEvent.click(screen.getByRole('button',{name:'Criar conta e continuar'}));
    fireEvent.change(await screen.findByLabelText('Nome da empresa'),{target:{value:'Minha empresa'}});
    expect(mocks.approve).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole('button',{name:'Criar empresa e continuar'}));
    expect(await screen.findByText('Minha empresa')).toBeInTheDocument();
    expect(mocks.rpc).toHaveBeenCalledWith('tenant_onboard',{p_organization_name:'Minha empresa'});
    expect(mocks.signUp.mock.calls[0][0].options.emailRedirectTo).toContain('/oauth/consent?authorization_id=request');
    expect(mocks.getDetails.mock.calls.every(([id])=>id==='request')).toBe(true);
    expect(mocks.approve).not.toHaveBeenCalled();
    expect(screen.getByRole('button',{name:'Autorizar conexão'})).toBeEnabled();
  });
  it('conta existente sem empresa pode concluir onboarding sem repetir cadastro', async () => {
    mocks.getUser.mockResolvedValue({data:{user:{id:'new',email:'nova@example.com',app_metadata:{}}}});
    mocks.rpc.mockResolvedValue({error:{message:'Falha temporária no cadastro'}});
    open();
    fireEvent.change(await screen.findByLabelText('Nome da empresa'),{target:{value:'Empresa'}});
    fireEvent.click(screen.getByRole('button',{name:'Criar empresa e continuar'}));
    expect(await screen.findByRole('alert')).toHaveTextContent('Falha temporária');
    expect(screen.getByRole('button',{name:'Criar empresa e continuar'})).toBeEnabled();
    expect(mocks.signUp).not.toHaveBeenCalled();expect(mocks.approve).not.toHaveBeenCalled();
  });
  it('sem domínio publicado apresenta preparação, sem endereço inventado', () => {
    vi.stubEnv('VITE_MCP_PUBLIC_URL', '');
    render(<MemoryRouter><McpConnect /></MemoryRouter>);
    expect(screen.getByRole('status')).toHaveTextContent('em preparação');
    expect(screen.queryByRole('button', { name: 'Copiar endereço' })).not.toBeInTheDocument();
  });
});
