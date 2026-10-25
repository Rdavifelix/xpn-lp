import { Stack } from 'expo-router';

import { useTheme } from '@/theme';

// Deliberately no "already signed in -> redirect to tabs" guard here: a
// freshly-signed-up user has a session but is meant to land on onboarding
// (still part of this group) before ever reaching the tabs. sign-in.tsx and
// sign-up.tsx already router.replace() on success, so this only matters for
// someone manually navigating back to sign-in while authenticated — an edge
// case not worth the risk of a layout-level guard misfiring on onboarding.
export default function AuthLayout() {
  const theme = useTheme();

  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: theme.colors.background },
        animation: 'fade',
      }}
    >
      <Stack.Screen name="sign-in" />
      <Stack.Screen name="sign-up" />
      <Stack.Screen name="onboarding" options={{ gestureEnabled: false }} />
    </Stack>
  );
}
