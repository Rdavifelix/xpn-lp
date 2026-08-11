import { AppState } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
// Supabase's JS client assumes `URL`/`fetch` globals shaped like a browser's;
// React Native's are close but not identical, so this polyfill (applied for
// its side effect) patches URL parsing before the client is constructed.
import 'react-native-url-polyfill/auto';

import { env } from '@/lib/env';

import type { Database } from './database.types';

export const supabase: SupabaseClient<Database> = createClient<Database>(env.supabaseUrl, env.supabaseAnonKey, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});

// Supabase's auto-refresh only ticks while something is actively polling.
// On native, that polling should pause while the app is backgrounded (to
// avoid needless work/battery drain) and resume immediately on foreground
// so a stale token doesn't cause a flash of "logged out" — this is the
// pattern from Supabase's own React Native guide.
AppState.addEventListener('change', (state) => {
  if (state === 'active') {
    supabase.auth.startAutoRefresh();
  } else {
    supabase.auth.stopAutoRefresh();
  }
});
