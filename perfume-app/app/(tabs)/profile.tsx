import { ScrollView } from 'react-native';
import { useRouter } from 'expo-router';

import { useAuth, useSignOut } from '@/features/auth';
import { ProfileScreenContent, useProfile } from '@/features/profiles';
import { LoadingState, ScreenContainer } from '@/components/ui';

export default function OwnProfileScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const { data: profile, isLoading } = useProfile(user?.id);
  const signOut = useSignOut();

  if (isLoading || !profile) {
    return (
      <ScreenContainer>
        <LoadingState fill message="Loading your profile…" />
      </ScreenContainer>
    );
  }

  return (
    <ScreenContainer edges={['top', 'left', 'right']}>
      <ScrollView showsVerticalScrollIndicator={false}>
        <ProfileScreenContent
          profile={profile}
          viewerId={user?.id}
          isOwnProfile
          onEditPress={() => router.push('/edit-profile')}
          onSignOutPress={() => signOut.mutate(undefined, { onSuccess: () => router.replace('/(auth)/sign-in') })}
        />
      </ScrollView>
    </ScreenContainer>
  );
}
