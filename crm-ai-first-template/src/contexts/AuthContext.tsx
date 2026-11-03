import { createContext, useContext, useEffect, useState, useCallback, useRef, ReactNode } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';
import { queryClient } from '@/lib/query-client';
import { clearAppStorage } from '@/lib/app-storage';

import type { CrmTeamMemberRow } from '@/types/crm-schema';
export type TeamMember = CrmTeamMemberRow;

interface AuthContextType {
  user: User | null;
  session: Session | null;
  teamMember: TeamMember | null;
  loading: boolean;
  isPasswordRecovery: boolean;
  signIn: (email: string, password: string) => Promise<{ error: Error | null }>;
  signUp: (email: string, password: string, name: string) => Promise<{ error: Error | null }>;
  signOut: () => Promise<void>;
  tenantId: string | null;
  isAdmin: boolean;
  isSuperAdmin: boolean;
  isCS: boolean;
  isComercial: boolean;
  canAccessSettings: boolean;
  canAccessHR: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [teamMember, setTeamMember] = useState<TeamMember | null>(null);
  const [loading, setLoading] = useState(true);
  const [isPasswordRecovery, setIsPasswordRecovery] = useState(false);
  const sessionRef = useRef<Session | null>(null);
  const previousTenantIdRef = useRef<string | null>(null);

  /** Identidade relevante para o ProtectedRoute: user id + claim tenant_id do JWT. */
  const identityOf = (s: Session | null) => ({
    userId: s?.user?.id ?? null,
    tenantId: (s?.user?.app_metadata as Record<string, unknown> | undefined)?.tenant_id ?? null,
  });

  // Busca teamMember via select direto (mais rápido que RPC — sem overhead de function call)
  const fetchTeamMember = useCallback(async (authUserId: string): Promise<TeamMember | null> => {
    try {
      const { data, error } = await supabase
        .from('team_members')
        .select('id, email, name, role, team, phone, avatar_url, is_active, auth_user_id, whatsapp_instance_id, google_calendar_connected, google_calendar_watch_channel_id, google_calendar_watch_expiration, tenant_id, focus_mode_enabled, created_at, is_superadmin')
        .eq('auth_user_id', authUserId)
        .eq('is_active', true)
        .maybeSingle();

      if (error) throw error;
      return data as TeamMember;
    } catch (err) {
      console.error('[AuthContext] fetchTeamMember error:', err);
      return null;
    }
  }, []);

  useEffect(() => {
    let isMounted = true;

    // Flag para diferenciar login real de token refresh (SIGNED_IN após TOKEN_REFRESHED)
    let hasInitiallySignedIn = false;

    // Refresh de token / SIGNED_IN tardio: atualizar o ref sempre, mas só re-renderizar
    // (setUser/setSession + refetch do teamMember) se o user id ou o claim
    // app_metadata.tenant_id mudaram — é isso que o ProtectedRoute compara.
    const syncRefreshedSession = async (newSession: Session | null) => {
      const prev = identityOf(sessionRef.current);
      const next = identityOf(newSession);
      sessionRef.current = newSession;
      if (prev.userId === next.userId && prev.tenantId === next.tenantId) return;

      setSession(newSession);
      setUser(newSession?.user ?? null);
      if (newSession?.user?.id) {
        const tm = await fetchTeamMember(newSession.user.id);
        if (isMounted) setTeamMember(tm);
      } else if (isMounted) {
        setTeamMember(null);
      }
    };

    // 1. Inicialização: getSession() lê do localStorage (sem rede) — rápido e determinístico
    const initAuth = async () => {
      const { data: { session: initialSession } } = await supabase.auth.getSession();

      if (!isMounted) return;

      setSession(initialSession);
      setUser(initialSession?.user ?? null);
      sessionRef.current = initialSession;

      if (initialSession?.user?.email) {
        hasInitiallySignedIn = true; // Já tem sessão — próximos SIGNED_IN são refreshes
        const tm = await fetchTeamMember(initialSession.user.id);
        if (isMounted && tm) {
          setTeamMember(tm);
        }
      }

      if (isMounted) {
        setLoading(false);
      }
    };

    initAuth();

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, newSession) => {
      if (!isMounted) return;

      // INITIAL_SESSION já foi tratado por initAuth() acima — ignorar
      if (event === 'INITIAL_SESSION') return;

      // TOKEN_REFRESHED: o token já está atualizado no client. Só re-renderizar se a
      // identidade (user id / tenant_id do JWT) mudou — caso comum: zero re-render.
      if (event === 'TOKEN_REFRESHED') {
        await syncRefreshedSession(newSession);
        return;
      }

      // SIGNED_IN após TOKEN_REFRESHED: é só o refresh, não um login real
      // Só processar SIGNED_IN completo se for o primeiro login da sessão
      if (event === 'SIGNED_IN') {
        if (hasInitiallySignedIn) {
          // Refresh de token — barato: só propaga se user/tenant mudaram
          await syncRefreshedSession(newSession);
          return;
        }
        hasInitiallySignedIn = true;

        console.log('[AuthContext] Auth event: SIGNED_IN (primeiro login)');
        sessionRef.current = newSession;
        setSession(newSession);
        setUser(newSession?.user ?? null);

        if (newSession?.user?.email) {
          const tm = await fetchTeamMember(newSession.user.id);
          if (isMounted && tm) {
            setTeamMember(tm);
          }
        }
        if (isMounted) setLoading(false);
        return;
      }

      // PASSWORD_RECOVERY: user clicked reset link from email
      if (event === 'PASSWORD_RECOVERY') {
        console.log('[AuthContext] Auth event: PASSWORD_RECOVERY');
        setIsPasswordRecovery(true);
        sessionRef.current = newSession;
        setSession(newSession);
        setUser(newSession?.user ?? null);
        setLoading(false);
        // Redirect to reset password page
        window.location.href = '/reset-password';
        return;
      }

      if (event === 'SIGNED_OUT') {
        console.log('[AuthContext] Auth event: SIGNED_OUT');
        hasInitiallySignedIn = false;
        sessionRef.current = null;
        // Nenhum dado em cache pode sobreviver ao usuário anterior na mesma aba
        queryClient.clear();
        setIsPasswordRecovery(false);
        setSession(null);
        setUser(null);
        setTeamMember(null);
        setLoading(false);
      }
    });

    return () => {
      isMounted = false;
      subscription.unsubscribe();
    };
  }, [fetchTeamMember]);

  // Health check: ao voltar pra aba, Supabase auto-refresh já cuida do token.
  // Só precisamos forçar logout se a sessão sumiu completamente (ex: storage limpo).
  useEffect(() => {
    if (!user) return;

    const handleVisibilityChange = () => {
      if (document.visibilityState !== 'visible') return;
      // getSession() retorna do cache local (rápido) — se a session existir,
      // o auto-refresh do Supabase cuida do resto. Não chamar refreshSession() manualmente.
      supabase.auth.getSession().then(({ data, error }) => {
        if (error || !data.session) {
          console.warn('[AuthContext] Sessão perdida ao retornar à aba');
          setUser(null);
          setSession(null);
          setTeamMember(null);
        }
      }).catch(() => {});
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, [user]);

  // Higiene cross-tenant: se o tenant do teamMember mudou de um valor para outro
  // (ex.: outro usuário logou na mesma aba), nada do cache anterior pode ser servido.
  const currentTenantId = teamMember?.tenant_id ?? null;
  useEffect(() => {
    const prev = previousTenantIdRef.current;
    if (prev && currentTenantId && prev !== currentTenantId) {
      queryClient.clear();
    }
    if (currentTenantId) previousTenantIdRef.current = currentTenantId;
  }, [currentTenantId]);

  const signIn = async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    return { error: error as Error | null };
  };

  const signUp = async (email: string, password: string, name: string) => {
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { name }
      }
    });
    return { error: error as Error | null };
  };

  const signOut = async () => {
    await supabase.auth.signOut();
    sessionRef.current = null;
    setUser(null);
    setSession(null);
    setTeamMember(null);
    // Cache do TanStack Query + chaves da app em local/sessionStorage: nada do
    // usuário/tenant anterior fica para o próximo login na mesma aba.
    // (As chaves `sb-*` do Supabase são removidas pelo próprio signOut acima.)
    queryClient.clear();
    clearAppStorage();
  };

  const tenantId = teamMember?.tenant_id ?? null;
  const isAdmin = teamMember?.role === 'admin';
  const isSuperAdmin = teamMember?.is_superadmin === true;
  const isCS = teamMember?.role === 'cs' || teamMember?.team === 'cs';
  const isComercial = teamMember?.role === 'comercial' || teamMember?.role === 'closer' || teamMember?.role === 'sdr' || teamMember?.team === 'comercial';
  const canAccessSettings = teamMember?.role === 'admin' || teamMember?.role === 'comercial';
  const canAccessHR = teamMember?.role !== 'closer' && teamMember?.role !== 'sdr';

  return (
    <AuthContext.Provider value={{
      user,
      session,
      teamMember,
      loading,
      isPasswordRecovery,
      signIn,
      signUp,
      signOut,
      tenantId,
      isAdmin,
      isSuperAdmin,
      isCS,
      isComercial,
      canAccessSettings,
      canAccessHR,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
