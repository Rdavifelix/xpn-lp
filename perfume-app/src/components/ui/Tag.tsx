import { Pressable, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';

import { useTheme } from '@/theme';

import { Text } from './Text';

export interface TagProps {
  label: string;
  /** Optional explicit color (e.g. an accord family color) — falls back to the theme accent. */
  color?: string;
  selected?: boolean;
  onPress?: () => void;
  size?: 'sm' | 'md';
  style?: StyleProp<ViewStyle>;
}

/**
 * Pill chip used for accords, notes, occasions and filters. Accepts a raw
 * hex `color` so accord chips can be tinted per scent family
 * (see theme/colors.ts ACCORD_FAMILY_COLORS).
 */
export function Tag({ label, color, selected = false, onPress, size = 'md', style }: TagProps) {
  const theme = useTheme();
  const tintColor = color ?? theme.colors.accent;
  const isSmall = size === 'sm';

  const content = (
    <View
      style={[
        styles.tag,
        {
          backgroundColor: selected ? tintColor : withAlpha(tintColor, 0.14),
          borderColor: selected ? tintColor : withAlpha(tintColor, 0.3),
          paddingVertical: isSmall ? 4 : 7,
          paddingHorizontal: isSmall ? 10 : 14,
          borderRadius: theme.radius.pill,
        },
        style,
      ]}
    >
      <Text variant={isSmall ? 'caption' : 'bodyMedium'} style={{ color: selected ? '#FFFDF9' : tintColor }}>
        {label}
      </Text>
    </View>
  );

  if (!onPress) return content;

  return <Pressable onPress={onPress}>{content}</Pressable>;
}

function withAlpha(hex: string, alpha: number): string {
  const sanitized = hex.replace('#', '');
  if (sanitized.length !== 6) return hex;
  const r = parseInt(sanitized.slice(0, 2), 16);
  const g = parseInt(sanitized.slice(2, 4), 16);
  const b = parseInt(sanitized.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

const styles = StyleSheet.create({
  tag: {
    borderWidth: 1,
    alignSelf: 'flex-start',
  },
});
