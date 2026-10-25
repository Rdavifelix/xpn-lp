import { StyleSheet, View } from 'react-native';
import { useRouter } from 'expo-router';

import { useFragrance } from '@/features/fragrances';
import { Avatar, Button, Card, Tag, Text } from '@/components/ui';
import { useTheme } from '@/theme';

import type { Profile } from '../api/profilesApi';
import { useFollowToggle, useIsFollowing } from '../hooks/useProfileQueries';

export interface ProfileHeaderProps {
  profile: Profile;
  viewerId: string | undefined;
  isOwnProfile: boolean;
  onEditPress?: () => void;
  onSignOutPress?: () => void;
}

export function ProfileHeader({ profile, viewerId, isOwnProfile, onEditPress, onSignOutPress }: ProfileHeaderProps) {
  const theme = useTheme();
  const router = useRouter();
  const { data: signatureFragrance } = useFragrance(profile.signature_fragrance_id ?? undefined);
  const { data: alreadyFollowing } = useIsFollowing(viewerId, profile.id);
  const { followMutation, unfollowMutation } = useFollowToggle(viewerId, profile.id);

  return (
    <View style={styles.container}>
      <View style={styles.topRow}>
        <Avatar uri={profile.avatar_url} name={profile.display_name ?? profile.username} size={76} />
        <View style={styles.statsRow}>
          <Stat label="Wears" value={profile.wears_count} />
          <Stat label="Followers" value={profile.followers_count} />
          <Stat label="Following" value={profile.following_count} />
        </View>
      </View>

      <Text variant="h2" style={styles.name}>
        {profile.display_name ?? profile.username}
      </Text>
      <Text variant="caption" color="muted">
        @{profile.username}
        {profile.city ? ` · ${profile.city}` : ''}
      </Text>

      {profile.bio ? (
        <Text variant="body" color="secondary" style={styles.bio}>
          {profile.bio}
        </Text>
      ) : null}

      {signatureFragrance ? (
        <View style={styles.signatureRow}>
          <Text variant="caption" color="muted">
            Signature scent
          </Text>
          <Tag
            label={`${signatureFragrance.name} · ${signatureFragrance.brandName}`}
            color={theme.colors.secondary}
            onPress={() => router.push({ pathname: '/fragrance/[id]', params: { id: signatureFragrance.id } })}
          />
        </View>
      ) : null}

      <View style={styles.actionsRow}>
        {isOwnProfile ? (
          <>
            <Button label="Edit Profile" variant="outline" size="sm" onPress={onEditPress} style={styles.actionButton} />
            <Button label="Sign Out" variant="ghost" size="sm" onPress={onSignOutPress} />
          </>
        ) : viewerId ? (
          <Button
            label={alreadyFollowing ? 'Following' : 'Follow'}
            variant={alreadyFollowing ? 'outline' : 'primary'}
            size="sm"
            loading={followMutation.isPending || unfollowMutation.isPending}
            onPress={() => (alreadyFollowing ? unfollowMutation.mutate() : followMutation.mutate())}
          />
        ) : null}
      </View>

      {!isOwnProfile ? (
        <Card style={styles.privacyNote}>
          <Text variant="caption" color="muted">
            {profile.display_name ?? profile.username}&apos;s full collection is private — only their public wear posts are shown below.
          </Text>
        </Card>
      ) : null}
    </View>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <View style={styles.stat}>
      <Text variant="h3">{value}</Text>
      <Text variant="caption" color="muted">
        {label}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { paddingTop: 8, paddingBottom: 20 },
  topRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 14 },
  statsRow: { flex: 1, flexDirection: 'row', justifyContent: 'space-around' },
  stat: { alignItems: 'center' },
  name: { marginBottom: 2 },
  bio: { marginTop: 10 },
  signatureRow: { marginTop: 14, gap: 6, alignItems: 'flex-start' },
  actionsRow: { flexDirection: 'row', gap: 10, marginTop: 16 },
  actionButton: { flex: 0 },
  privacyNote: { marginTop: 14 },
});
