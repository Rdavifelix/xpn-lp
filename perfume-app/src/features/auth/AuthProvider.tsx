import { createContext, useContext, useEffect, useState, type PropsWithChildren } from 'react';
import type { Session, User } from '@supabase/supabase-js';

import { supabase } from '@/lib/supabase';

export interface AuthContextValue {
  session: Session | null;
  user: User | null;
  /** True until the very first getSession() call resolves — gates the splash/redirect logic in app/_layout.tsx. */
  initializing: boolean;
}

const AuthContext = createContext<AuthContextValue>({ session: null, user: null, initializing: true });

/**
 * Wraps the app, keeps the Supabase session in sync with React state, and
 * exposes it via useAuth(). The root layout (app/_layout.tsx) reads
 * `session`/`initializing` from this to redirect between the (auth) and
 * (tabs) route groups.
 */
export function AuthProvider({ children }: PropsWithChildren) {
  const [session, setSession] = useState<Session | null>(null);
  const [initializing, setInitializing] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setInitializing(false);
    });

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
    });

    return () => subscription.subscription.unsubscribe();
  }, []);

  return (
    <AuthContext.Provider value={{ session, user: session?.user ?? null, initializing }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  return useContext(AuthContext);
}
