import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';

const auth = vi.hoisted(() => ({
  signOut: vi.fn(async () => ({ error: null })),
  getSession: vi.fn(async () => ({ data: { session: null }, error: null })),
  onAuthStateChange: vi.fn(() => ({ data: { subscription: { unsubscribe: vi.fn() } } })),
}));

vi.mock('@/lib/supabase', () => ({
  supabase: {
    auth: auth,
    from: () => ({
      select: () => ({ eq: () => ({ eq: () => ({ maybeSingle: async () => ({ data: null, error: null }) }) }) }),
    }),
  },
}));

import { AuthProvider, useAuth } from '@/contexts/AuthContext';
import { queryClient } from '@/lib/query-client';
import { clearAppStorage, APP_STORAGE_PREFIXES } from '@/lib/app-storage';

function SignOutButton() {
  const { signOut, loading } = useAuth();
  return (
    <button disabled={loading} onClick={() => signOut()}>
      sair
    </button>
  );
}

beforeEach(() => {
  queryClient.clear();
  localStorage.clear();
  sessionStorage.clear();
  auth.signOut.mockClear();
});

describe('signOut', () => {
  it('limpa o cache do TanStack Query e as chaves da app, preservando sb-* e crm-theme', async () => {
    queryClient.setQueryData(['team-members'], [{ id: 'm1', tenant_id: 'tenant-a' }]);
    queryClient.setQueryData(['tenant-config', 'tenant-a', ['enabled_modules']], { enabled_modules: '{}' });
    localStorage.setItem('meeting_transcriptions_abc', '[...]');
    localStorage.setItem('whatsapp-draft:lead-1', 'oi');
    localStorage.setItem('calendar-selected-member', 'member-from-tenant-a');
    localStorage.setItem('crm-theme', 'dark');
    localStorage.setItem('sb-xyz-auth-token', '{"fake":true}');
    sessionStorage.setItem('scroll:/comercial', '120');
    sessionStorage.setItem('cockpit-skipped-m1', '[]');

    render(
      <AuthProvider>
        <SignOutButton />
      </AuthProvider>,
    );

    const button = await screen.findByRole('button', { name: 'sair' });
    await waitFor(() => expect(button).not.toBeDisabled());
    fireEvent.click(button);

    await waitFor(() => expect(auth.signOut).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(queryClient.getQueryCache().getAll()).toHaveLength(0));

    expect(localStorage.getItem('meeting_transcriptions_abc')).toBeNull();
    expect(localStorage.getItem('whatsapp-draft:lead-1')).toBeNull();
    expect(localStorage.getItem('calendar-selected-member')).toBeNull();
    expect(sessionStorage.getItem('scroll:/comercial')).toBeNull();
    expect(sessionStorage.getItem('cockpit-skipped-m1')).toBeNull();
    // Não é responsabilidade nossa (Supabase cuida) / preferência visual
    expect(localStorage.getItem('sb-xyz-auth-token')).toBe('{"fake":true}');
    expect(localStorage.getItem('crm-theme')).toBe('dark');
  });
});

describe('clearAppStorage', () => {
  it('remove somente chaves com prefixo da app', () => {
    localStorage.setItem('call_transcription_backup_1', 'x');
    localStorage.setItem('outra-coisa', 'y');
    clearAppStorage();
    expect(localStorage.getItem('call_transcription_backup_1')).toBeNull();
    expect(localStorage.getItem('outra-coisa')).toBe('y');
    expect(APP_STORAGE_PREFIXES).toContain('whatsapp-draft:');
    expect(APP_STORAGE_PREFIXES.some((p) => p.startsWith('sb-'))).toBe(false);
  });
});
