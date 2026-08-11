import { Pressable, StyleSheet, type StyleProp, type ViewStyle } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import Animated, { useAnimatedStyle, useSharedValue, withSpring } from 'react-native-reanimated';

import { useTheme } from '@/theme';

export interface IconButtonProps {
  name: keyof typeof Ionicons.glyphMap;
  onPress?: () => void;
  size?: number;
  color?: string;
  active?: boolean;
  activeColor?: string;
  backgroundColor?: string;
  haptics?: boolean;
  style?: StyleProp<ViewStyle>;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

/** Circular icon-only tap target — used for like/comment/share, back buttons, etc. */
export function IconButton({
  name,
  onPress,
  size = 22,
  color,
  active = false,
  activeColor,
  backgroundColor,
  haptics = false,
  style,
}: IconButtonProps) {
  const theme = useTheme();
  const scale = useSharedValue(1);
  const animatedStyle = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));

  const resolvedColor = active ? (activeColor ?? theme.colors.like) : (color ?? theme.colors.textSecondary);

  return (
    <AnimatedPressable
      onPress={() => {
        if (haptics) Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
        scale.value = withSpring(1.2, { damping: 8, stiffness: 300 }, () => {
          scale.value = withSpring(1);
        });
        onPress?.();
      }}
      hitSlop={10}
      style={[
        styles.base,
        { backgroundColor: backgroundColor ?? 'transparent', width: size + 16, height: size + 16, borderRadius: (size + 16) / 2 },
        animatedStyle,
        style,
      ]}
    >
      <Ionicons name={name} size={size} color={resolvedColor} />
    </AnimatedPressable>
  );
}

const styles = StyleSheet.create({
  base: { alignItems: 'center', justifyContent: 'center' },
});
