import { FlatList, StyleSheet, View } from 'react-native';
import { useRouter } from 'expo-router';

import { FeedPostCard, useFeed, useRealtimeFeed, useToggleLike } from '@/features/feed';
import { EmptyState, IconButton, LoadingState, ScreenContainer, Text } from '@/components/ui';
import { useTheme } from '@/theme';

export default function FeedScreen() {
  const theme = useTheme();
  const router = useRouter();
  const { data, isLoading, fetchNextPage, hasNextPage, isFetchingNextPage, refetch, isRefetching } = useFeed();
  const toggleLike = useToggleLike();
  useRealtimeFeed();

  const posts = data?.pages.flat() ?? [];

  return (
    <ScreenContainer edges={['top', 'left', 'right']}>
      <View style={styles.header}>
        <Text variant="h1">Feed</Text>
        <IconButton name="create-outline" onPress={() => router.push('/compose')} backgroundColor={theme.colors.accentSoft} color={theme.colors.accent} />
      </View>

      {isLoading ? (
        <LoadingState fill message="Loading the feed…" />
      ) : (
        <FlatList
          data={posts}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          refreshing={isRefetching}
          onRefresh={refetch}
          onEndReachedThreshold={0.4}
          onEndReached={() => {
            if (hasNextPage && !isFetchingNextPage) fetchNextPage();
          }}
          renderItem={({ item }) => <FeedPostCard post={item} onToggleLike={() => toggleLike.mutate(item.id)} />}
          ItemSeparatorComponent={() => <View style={styles.separator} />}
          ListEmptyComponent={
            <EmptyState
              icon="people-outline"
              title="No wears yet"
              message="Follow other fragrance lovers or post what you're wearing today to get the feed going."
              actionLabel="Post a wear"
              onAction={() => router.push('/compose')}
            />
          }
          ListFooterComponent={isFetchingNextPage ? <LoadingState /> : null}
        />
      )}
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 8 },
  list: { paddingBottom: 24, paddingTop: 4, flexGrow: 1 },
  separator: { height: 14 },
});
