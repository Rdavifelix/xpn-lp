import { useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { Button, Card, RatingStars, Text, TextField } from '@/components/ui';
import { useTheme } from '@/theme';

import { useAddToCollection, useCollectionItemForFragrance, useRemoveFromCollection, useUpdateCollectionItem } from '../hooks/useCollectionQueries';
import { StatusSegmentedControl } from './StatusSegmentedControl';
import type { CollectionStatus } from '@/lib/supabase';

export function CollectionEditor({ userId, fragranceId }: { userId: string; fragranceId: string }) {
  const theme = useTheme();
  const { data: item, isLoading } = useCollectionItemForFragrance(userId, fragranceId);
  const addMutation = useAddToCollection(userId);
  const updateMutation = useUpdateCollectionItem(userId);
  const removeMutation = useRemoveFromCollection(userId);

  const [bottleSize, setBottleSize] = useState('');
  const [notes, setNotes] = useState('');
  const [editingNotes, setEditingNotes] = useState(false);

  if (isLoading) return null;

  if (!item) {
    return (
      <Card>
        <Text variant="subtitle" style={styles.title}>
          Add to your collection
        </Text>
        <View style={styles.row}>
          {(['owned', 'wishlist', 'tried'] as CollectionStatus[]).map((status) => (
            <Button
              key={status}
              label={status === 'owned' ? 'I own this' : status === 'wishlist' ? 'Wishlist' : 'I tried it'}
              variant={status === 'owned' ? 'primary' : 'outline'}
              size="sm"
              loading={addMutation.isPending}
              onPress={() => addMutation.mutate({ fragranceId, input: { status } })}
            />
          ))}
        </View>
      </Card>
    );
  }

  const notesValue = editingNotes ? notes : (item.personalNotes ?? '');

  return (
    <Card>
      <View style={styles.headerRow}>
        <Text variant="subtitle">Your collection</Text>
        <Button
          label="Remove"
          variant="ghost"
          size="sm"
          loading={removeMutation.isPending}
          onPress={() => removeMutation.mutate(item.id)}
        />
      </View>

      <StatusSegmentedControl value={item.status} onChange={(status) => updateMutation.mutate({ itemId: item.id, input: { status } })} />

      <View style={styles.ratingRow}>
        <Text variant="bodyMedium" color="secondary">
          Your rating
        </Text>
        <RatingStars value={item.rating ?? 0} onChange={(rating) => updateMutation.mutate({ itemId: item.id, input: { rating } })} size={22} />
      </View>

      <TextField
        label="Bottle size (ml)"
        keyboardType="number-pad"
        value={bottleSize || (item.bottleSizeMl ? String(item.bottleSizeMl) : '')}
        onChangeText={setBottleSize}
        onBlur={() => {
          const parsed = Number(bottleSize);
          if (bottleSize && !Number.isNaN(parsed)) {
            updateMutation.mutate({ itemId: item.id, input: { bottleSizeMl: parsed } });
          }
        }}
        placeholder="e.g. 100"
      />

      <TextField
        label="Personal notes"
        value={notesValue}
        onChangeText={(v) => {
          setEditingNotes(true);
          setNotes(v);
        }}
        onBlur={() => {
          if (editingNotes) updateMutation.mutate({ itemId: item.id, input: { personalNotes: notes } });
        }}
        placeholder="How does it wear on you? Any memories tied to it?"
        multiline
        numberOfLines={3}
        style={{ minHeight: 70, textAlignVertical: 'top', color: theme.colors.textPrimary }}
      />
    </Card>
  );
}

const styles = StyleSheet.create({
  title: { marginBottom: 12 },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 },
  row: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  ratingRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginVertical: 14 },
});
