import { Pressable, StyleSheet, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { useTheme } from '@/theme';

export interface RatingStarsProps {
  /** 0-10 scale (half-star precision), matching collection_items.rating in the schema. */
  value: number;
  onChange?: (value: number) => void;
  size?: number;
  max?: number;
}

/** Star rating display/input. Read-only when `onChange` is omitted. */
export function RatingStars({ value, onChange, size = 18, max = 5 }: RatingStarsProps) {
  const theme = useTheme();
  // value is 0-10; render against `max` stars (default 5) at half-star precision.
  const starValue = value / (10 / max);
  const interactive = Boolean(onChange);

  return (
    <View style={styles.row}>
      {Array.from({ length: max }, (_, i) => {
        const diff = starValue - i;
        const iconName = diff >= 1 ? 'star' : diff >= 0.5 ? 'star-half' : 'star-outline';

        const star = <Ionicons key={i} name={iconName} size={size} color={theme.colors.accent} />;

        if (!interactive) return star;

        return (
          <Pressable
            key={i}
            hitSlop={4}
            onPress={() => onChange?.(Math.round((i + 1) * (10 / max)))}
          >
            {star}
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', gap: 2 },
});
