import { useState } from 'react';
import { RefreshControl, ScrollView, StyleSheet, View } from 'react-native';
import { useRouter } from 'expo-router';

import { useAuth } from '@/features/auth';
import { useProfile } from '@/features/profiles';
import { DailyRecCard, useDailyRecommendation, useRefreshDailyRecommendation, useRequestRecommendation } from '@/features/recommendations';
import { useOccasions } from '@/features/fragrances';
import { FeedPostCard, useFeed, useToggleLike } from '@/features/feed';
import { Card, EmptyState, LoadingState, ScreenContainer, Tag, Text } from '@/components/ui';
import { useTheme } from '@/theme';

const QUICK_OCCASIONS = ['date_night', 'office', 'night_out', 'gym'];

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

export default function HomeScreen() {
  const theme = useTheme();
  const router = useRouter();
  const { user } = useAuth();
  const { data: profile } = useProfile(user?.id);
  const { data: dailyRec, isLoading: dailyRecLoading, refetch: refetchDailyRec } = useDailyRecommendation(user?.id, profile);
  const refreshDailyRec = useRefreshDailyRecommendation(user?.id);
  const requestRecommendation = useRequestRecommendation(user?.id, profile);
  const { data: occasions } = useOccasions();

  const { data: feedPages, isLoading: feedLoading, refetch: refetchFeed } = useFeed();
  const toggleLike = useToggleLike();
  const [refreshing, setRefreshing] = useState(false);

  const previewPosts = (feedPages?.pages.flat() ?? []).slice(0, 3);

  const handleRefresh = async () => {
    setRefreshing(true);
    refreshDailyRec();
    await Promise.all([refetchDailyRec(), refetchFeed()]);
    setRefreshing(false);
  };

  const occasionLabel = (slug: string) => occasions?.find((o) => o.slug === slug)?.label ?? slug;

  return (
    <ScreenContainer edges={['top', 'left', 'right']} padded={false}>
      <ScrollView
        contentContainerStyle={styles.scroll}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={handleRefresh} tintColor={theme.colors.accent} />}
      >
        <View style={styles.header}>
          <Text variant="caption" color="muted">
            {getGreeting()}
          </Text>
          <Text variant="display">{profile?.display_name ?? profile?.username ?? 'Welcome'}</Text>
        </View>

        <DailyRecCard recommendation={requestRecommendation.data !== undefined ? requestRecommendation.data : dailyRec} isLoading={dailyRecLoading && requestRecommendation.data === undefined} />

        <View style={styles.quickRequest}>
          <Text variant="label" color="secondary" style={styles.quickRequestLabel}>
            NEED SOMETHING SPECIFIC?
          </Text>
          <View style={styles.chipRow}>
            {QUICK_OCCASIONS.map((slug) => (
              <Tag
                key={slug}
                label={occasionLabel(slug)}
                color={theme.colors.secondary}
                onPress={() => requestRecommendation.mutate(slug)}
                selected={requestRecommendation.variables === slug}
              />
            ))}
          </View>
          {requestRecommendation.data !== undefined ? (
            <Text variant="caption" color="accent" onPress={() => requestRecommendation.reset()} style={styles.resetLink}>
              Back to today&apos;s pick
            </Text>
          ) : null}
        </View>

        <View style={styles.feedSection}>
          <View style={styles.sectionHeader}>
            <Text variant="h3">From the Community</Text>
            <Text variant="caption" color="accent" onPress={() => router.push('/(tabs)/feed')}>
              See all
            </Text>
          </View>

          {feedLoading ? (
            <LoadingState message="Loading the feed…" />
          ) : previewPosts.length > 0 ? (
            <View style={styles.feedList}>
              {previewPosts.map((post) => (
                <FeedPostCard key={post.id} post={post} onToggleLike={() => toggleLike.mutate(post.id)} />
              ))}
            </View>
          ) : (
            <Card>
              <EmptyState
                icon="people-outline"
                title="The feed is quiet"
                message="Be the first to share what you're wearing today."
                actionLabel="Post a wear"
                onAction={() => router.push('/compose')}
              />
            </Card>
          )}
        </View>
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  scroll: { paddingHorizontal: 16, paddingTop: 8, paddingBottom: 32 },
  header: { marginBottom: 20, gap: 2 },
  quickRequest: { marginTop: 20, marginBottom: 8 },
  quickRequestLabel: { marginBottom: 10 },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  resetLink: { marginTop: 10 },
  feedSection: { marginTop: 28 },
  sectionHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 },
  feedList: { gap: 14 },
});
