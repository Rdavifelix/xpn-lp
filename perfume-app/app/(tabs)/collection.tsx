import { useState } from 'react';
import { FlatList, StyleSheet, View } from 'react-native';
import { useRouter } from 'expo-router';

import { useAuth } from '@/features/auth';
import { StatusSegmentedControl, useCollection } from '@/features/collection';
import { FragranceCard } from '@/features/fragrances';
import { EmptyState, LoadingState, ScreenContainer, Text } from '@/components/ui';
import type { CollectionStatus } from '@/lib/supabase';

export default function CollectionScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const [status, setStatus] = useState<CollectionStatus>('owned');
  const { data: entries, isLoading, refetch, isRefetching } = useCollection(user?.id, status);

  return (
    <ScreenContainer edges={['top', 'left', 'right']}>
      <View style={styles.header}>
        <Text variant="h1">Your Collection</Text>
        <View style={styles.picker}>
          <StatusSegmentedControl value={status} onChange={setStatus} />
        </View>
      </View>

      {isLoading ? (
        <LoadingState fill message="Loading your collection…" />
      ) : (
        <FlatList
          data={entries ?? []}
          keyExtractor={(item) => item.id}
          numColumns={2}
          columnWrapperStyle={styles.row}
          contentContainerStyle={styles.list}
          refreshing={isRefetching}
          onRefresh={refetch}
          renderItem={({ item }) => (
            <FragranceCard fragrance={item.fragrance} onPress={() => router.push({ pathname: '/fragrance/[id]', params: { id: item.fragrance.id } })} />
          )}
          ListEmptyComponent={
            <EmptyState
              icon="flask-outline"
              title={status === 'owned' ? 'No bottles yet' : status === 'wishlist' ? 'Your wishlist is empty' : "You haven't tried anything yet"}
              message="Browse Discover to add fragrances to your collection."
            />
          }
        />
      )}
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { paddingTop: 8, paddingBottom: 16, gap: 14 },
  picker: { flexDirection: 'row' },
  list: { paddingBottom: 24, flexGrow: 1 },
  row: { gap: 12, marginBottom: 12 },
});
