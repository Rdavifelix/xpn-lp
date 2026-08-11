import type { PropsWithChildren } from 'react';
import { Pressable, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';

import { useTheme } from '@/theme';

export interface CardProps extends PropsWithChildren {
  style?: StyleProp<ViewStyle>;
  onPress?: () => void;
  /** Adds a stronger shadow/border, used for the daily-recommendation hero card. */
  elevated?: boolean;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

/**
 * Warm, rounded surface used for every "block" in the app (feed posts,
 * fragrance tiles, collection items, the daily rec card). When `onPress`
 * is supplied it becomes a tactile, slightly-scaling button.
 */
export function Card({ children, style, onPress, elevated = false }: CardProps) {
  const theme = useTheme();
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const baseStyle: StyleProp<ViewStyle> = [
    styles.card,
    {
      backgroundColor: elevated ? theme.colors.surfaceElevated : theme.colors.surface,
      borderColor: theme.colors.border,
      borderRadius: theme.radius.lg,
      padding: theme.spacing.md,
      shadowColor: theme.colors.shadow,
    },
    elevated && styles.elevatedShadow,
    style,
  ];

  if (!onPress) {
    return <View style={baseStyle}>{children}</View>;
  }

  return (
    <AnimatedPressable
      onPress={onPress}
      onPressIn={() => {
        scale.value = withTiming(0.97, { duration: theme.motion.duration.quick });
      }}
      onPressOut={() => {
        scale.value = withTiming(1, { duration: theme.motion.duration.quick });
      }}
      style={[baseStyle, animatedStyle]}
    >
      {children}
    </AnimatedPressable>
  );
}

const styles = StyleSheet.create({
  card: {
    borderWidth: StyleSheet.hairlineWidth,
  },
  elevatedShadow: {
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 1,
    shadowRadius: 20,
    elevation: 6,
  },
});
