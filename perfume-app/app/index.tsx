import { Redirect } from 'expo-router';

import { useAuth } from '@/features/auth';
import { LoadingState, ScreenContainer } from '@/components/ui';

/**
 * The app's true entry point. `(auth)` and `(tabs)` are both route groups
 * (no bare `/` route of their own), so this is what decides which one a
 * cold start actually lands in, based on whether a Supabase session exists.
 */
export default function Index() {
  const { session, initializing } = useAuth();

  if (initializing) {
    return (
      <ScreenContainer>
        <LoadingState fill />
      </ScreenContainer>
    );
  }

  return <Redirect href={session ? '/(tabs)' : '/(auth)/sign-in'} />;
}
