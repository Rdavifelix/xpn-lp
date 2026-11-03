import { render, screen, cleanup } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import PlatformTenantsPage from './PlatformTenantsPage';

const mocks = vi.hoisted(() => ({ rpc: vi.fn() }));
vi.mock('@/lib/supabase', () => ({ supabase: { rpc: mocks.rpc } }));
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ tenantId: 'tenant', isSuperAdmin: true, teamMember: { id: 'member' } }) }));
vi.mock('@/components/layout/AppLayout', () => ({ AppLayout: ({ children }: { children: React.ReactNode }) => <div>{children}</div> }));

const open = () => {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={client}><MemoryRouter><PlatformTenantsPage /></MemoryRouter></QueryClientProvider>);
};
beforeEach(() => { vi.resetAllMocks(); });
afterEach(() => { cleanup(); });

describe('painel superadmin de empresas', () => {
  it('mostra acesso negado quando a RPC recusa com 42501', async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: { code: '42501', message: 'Somente superadmin da plataforma' } });
    open();
    expect(await screen.findByRole('alert')).toHaveTextContent('somente o superadmin');
    expect(screen.queryByText('Reativar')).not.toBeInTheDocument();
  });
  it('lista as empresas e o resumo da plataforma', async () => {
    mocks.rpc.mockImplementation((name: string) => Promise.resolve(name === 'platform_overview'
      ? { data: { tenants_total: 2, tenants_active: 1, tenants_suspended: 1, users_active: 7, leads_total: 42, multi_tenant_enabled: true, is_superadmin: true }, error: null }
      : { data: [
          { id: 't1', name: 'Empresa A', slug: 'empresa-a', is_active: true, plan: 'pro', max_users: 10, trial_ends_at: null, suspended_at: null, suspended_reason: null, created_at: '2026-10-01T12:00:00Z', owner_user_id: 'u1', admin_email: 'admin@a.com', active_users: 4, leads_count: 30, deals_count: 3, last_message_at: null },
          { id: 't2', name: 'Empresa B', slug: 'empresa-b', is_active: false, plan: 'trial', max_users: null, trial_ends_at: null, suspended_at: '2026-10-20T12:00:00Z', suspended_reason: 'inadimplência', created_at: '2026-10-02T12:00:00Z', owner_user_id: 'u2', admin_email: 'admin@b.com', active_users: 3, leads_count: 12, deals_count: 0, last_message_at: null },
        ], error: null }));
    open();
    expect(await screen.findByText('Empresa A')).toBeInTheDocument();
    expect(screen.getByText('admin@a.com')).toBeInTheDocument();
    expect(screen.getByText('empresa-b')).toBeInTheDocument();
    expect(screen.getByText('inadimplência')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Reativar' })).toBeInTheDocument();
    expect(screen.getAllByRole('button', { name: 'Suspender' })).toHaveLength(1);
    expect(screen.getByRole('switch', { name: 'Cadastro self-service de empresas' })).toHaveAttribute('aria-checked', 'true');
    expect(screen.getByText('Empresas (2)')).toBeInTheDocument();
    expect(mocks.rpc).toHaveBeenCalledWith('platform_list_tenants', { p_search: null, p_limit: 500 });
  });
});
