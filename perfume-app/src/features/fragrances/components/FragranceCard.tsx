import { StyleSheet, View } from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';

import { Card, Tag, Text } from '@/components/ui';
import { useTheme } from '@/theme';

import type { FragranceSummary } from '../types';

export interface FragranceCardProps {
  fragrance: FragranceSummary;
  onPress?: () => void;
  /** Compact grid tile (Collection/Discover) vs a wider row (search results). */
  variant?: 'grid' | 'row';
}

export function FragranceCard({ fragrance, onPress, variant = 'grid' }: FragranceCardProps) {
  const theme = useTheme();
  const isGrid = variant === 'grid';

  return (
    <Card onPress={onPress} style={isGrid ? styles.gridCard : styles.rowCard}>
      <View style={isGrid ? styles.gridContent : styles.rowContent}>
        <View
          style={[
            styles.imageWrap,
            isGrid ? styles.gridImage : styles.rowImage,
            { backgroundColor: theme.colors.accentSoft, borderRadius: theme.radius.md },
          ]}
        >
          {fragrance.imageUrl ? (
            <Image source={{ uri: fragrance.imageUrl }} style={styles.image} contentFit="cover" transition={150} />
          ) : (
            <Ionicons name="flask-outline" size={isGrid ? 28 : 22} color={theme.colors.accent} />
          )}
        </View>

        <View style={isGrid ? styles.gridInfo : styles.rowInfo}>
          <Text variant="caption" color="muted" numberOfLines={1}>
            {fragrance.brandName}
          </Text>
          <Text variant="bodyMedium" numberOfLines={isGrid ? 2 : 1}>
            {fragrance.name}
          </Text>
          <View style={styles.metaRow}>
            {fragrance.avgRating > 0 ? (
              <View style={styles.ratingRow}>
                <Ionicons name="star" size={12} color={theme.colors.accent} />
                <Text variant="caption" color="muted">
                  {fragrance.avgRating.toFixed(1)}
                </Text>
              </View>
            ) : null}
            {fragrance.topAccord ? <Tag label={fragrance.topAccord.label} color={fragrance.topAccord.hexColor} size="sm" /> : null}
          </View>
        </View>
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  gridCard: { flex: 1, padding: 10 },
  rowCard: { padding: 10 },
  gridContent: { gap: 8 },
  rowContent: { flexDirection: 'row', gap: 12, alignItems: 'center' },
  imageWrap: { alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  gridImage: { width: '100%', aspectRatio: 1 },
  rowImage: { width: 56, height: 56 },
  image: { width: '100%', height: '100%' },
  gridInfo: { gap: 2 },
  rowInfo: { flex: 1, gap: 2 },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: 4, flexWrap: 'wrap' },
  ratingRow: { flexDirection: 'row', alignItems: 'center', gap: 2 },
});
