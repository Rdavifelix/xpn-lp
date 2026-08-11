import { ScrollView } from 'react-native';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';

import { useAuth } from '@/features/auth';
import { ProfileScreenContent, useProfileByUsername } from '@/features/profiles';
import { IconButton, LoadingState, ScreenContainer, Text } from '@/components/ui';

export default function UserProfileScreen() {
  const router = useRouter();
  const { username } = useLocalSearchParams<{ username: string }>();
  const { user } = useAuth();
  const { data: profile, isLoading, error } = useProfileByUsername(username);

  return (
    <ScreenContainer edges={['top', 'left', 'right']}>
      <Stack.Screen
        options={{ headerShown: true, title: username ? `@${username}` : '', headerLeft: () => <IconButton name="chevron-back" onPress={() => router.back()} /> }}
      />
      {isLoading ? (
        <LoadingState fill message="Loading profile…" />
      ) : error || !profile ? (
        <Text variant="body" color="muted">
          Couldn&apos;t find that profile.
        </Text>
      ) : (
        <ScrollView showsVerticalScrollIndicator={false}>
          <ProfileScreenContent profile={profile} viewerId={user?.id} isOwnProfile={user?.id === profile.id} />
        </ScrollView>
      )}
    </ScreenContainer>
  );
}
