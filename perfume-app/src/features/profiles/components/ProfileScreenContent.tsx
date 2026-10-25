import { StyleSheet, View } from 'react-native';
import { useRouter } from 'expo-router';

import { useCollection } from '@/features/collection';
import { FragranceCard } from '@/features/fragrances';
import { FeedPostCard, useToggleLike, useUserWears } from '@/features/feed';
import { EmptyState, LoadingState, Text } from '@/components/ui';

import type { Profile } from '../api/profilesApi';
import { ProfileHeader } from './ProfileHeader';

export interface ProfileScreenContentProps {
  profile: Profile;
  viewerId: string | undefined;
  isOwnProfile: boolean;
  onEditPress?: () => void;
  onSignOutPress?: () => void;
}

/**
 * Shared body for both the own-profile tab and any /user/[username] page.
 * Collection is only rendered for the owner — collection_items RLS is
 * owner-only by design (see supabase/migrations/0004_collection.sql), so
 * another viewer genuinely has no data to show there beyond the signature
 * scent already surfaced in the header.
 */
export function ProfileScreenContent({ profile, viewerId, isOwnProfile, onEditPress, onSignOutPress }: ProfileScreenContentProps) {
  const router = useRouter();
  const { data: collection } = useCollection(isOwnProfile ? profile.id : undefined, 'owned');
  const { data: wears, isLoading: wearsLoading } = useUserWears(profile.id, viewerId);
  const toggleLike = useToggleLike();

  return (
    <View>
      <ProfileHeader profile={profile} viewerId={viewerId} isOwnProfile={isOwnProfile} onEditPress={onEditPress} onSignOutPress={onSignOutPress} />

      {isOwnProfile ? (
        <View style={styles.section}>
          <Text variant="h3" style={styles.sectionTitle}>
            Your Collection
          </Text>
          {collection && collection.length > 0 ? (
            <View style={styles.grid}>
              {collection.slice(0, 6).map((entry) => (
                <View key={entry.id} style={styles.gridItem}>
                  <FragranceCard fragrance={entry.fragrance} onPress={() => router.push({ pathname: '/fragrance/[id]', params: { id: entry.fragrance.id } })} />
                </View>
              ))}
            </View>
          ) : (
            <Text variant="body" color="muted">
              You haven&apos;t added anything yet — browse Discover to start your collection.
            </Text>
          )}
        </View>
      ) : null}

      <View style={styles.section}>
        <Text variant="h3" style={styles.sectionTitle}>
          Recent Wears
        </Text>
        {wearsLoading ? (
          <LoadingState message="Loading wears…" />
        ) : wears && wears.length > 0 ? (
          <View style={styles.wearsList}>
            {wears.map((post) => (
              <FeedPostCard key={post.id} post={post} onToggleLike={() => toggleLike.mutate(post.id)} />
            ))}
          </View>
        ) : (
          <EmptyState icon="shirt-outline" title="No wears yet" message={isOwnProfile ? 'Post what you\'re wearing today from the Feed tab.' : undefined} />
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  section: { marginTop: 8, marginBottom: 8 },
  sectionTitle: { marginBottom: 12 },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  gridItem: { width: '47%' },
  wearsList: { gap: 14 },
});
