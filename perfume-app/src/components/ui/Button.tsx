import { ActivityIndicator, Pressable, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';
import * as Haptics from 'expo-haptics';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';

import { useTheme } from '@/theme';

import { Text } from './Text';

export type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps {
  label: string;
  onPress?: () => void;
  variant?: ButtonVariant;
  size?: ButtonSize;
  disabled?: boolean;
  loading?: boolean;
  icon?: React.ReactNode;
  fullWidth?: boolean;
  style?: StyleProp<ViewStyle>;
  haptics?: boolean;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

const sizeConfig: Record<ButtonSize, { paddingVertical: number; paddingHorizontal: number; fontVariant: 'body' | 'bodyMedium' | 'subtitle' }> = {
  sm: { paddingVertical: 8, paddingHorizontal: 14, fontVariant: 'bodyMedium' },
  md: { paddingVertical: 13, paddingHorizontal: 20, fontVariant: 'subtitle' },
  lg: { paddingVertical: 17, paddingHorizontal: 24, fontVariant: 'subtitle' },
};

/**
 * Primary interactive control. Variants map to the warm palette rather than
 * generic blue — `primary` is the gold accent, `secondary` the wine accent,
 * `outline`/`ghost` for lower-emphasis actions, `danger` for destructive
 * confirmations (e.g. removing a collection item).
 */
export function Button({
  label,
  onPress,
  variant = 'primary',
  size = 'md',
  disabled = false,
  loading = false,
  icon,
  fullWidth = false,
  style,
  haptics = true,
}: ButtonProps) {
  const theme = useTheme();
  const scale = useSharedValue(1);
  const cfg = sizeConfig[size];

  const { backgroundColor, borderColor, textColor } = resolveVariantColors(theme, variant, disabled);

  const animatedStyle = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));
  const isInteractive = !disabled && !loading;

  return (
    <AnimatedPressable
      disabled={!isInteractive}
      onPress={() => {
        if (haptics) Haptics.selectionAsync().catch(() => {});
        onPress?.();
      }}
      onPressIn={() => {
        if (isInteractive) scale.value = withTiming(0.96, { duration: theme.motion.duration.quick });
      }}
      onPressOut={() => {
        scale.value = withTiming(1, { duration: theme.motion.duration.quick });
      }}
      style={[
        styles.base,
        {
          backgroundColor,
          borderColor,
          borderWidth: variant === 'outline' ? 1.5 : 0,
          borderRadius: theme.radius.pill,
          paddingVertical: cfg.paddingVertical,
          paddingHorizontal: cfg.paddingHorizontal,
          opacity: disabled ? 0.5 : 1,
          width: fullWidth ? '100%' : undefined,
        },
        animatedStyle,
        style,
      ]}
    >
      <View style={styles.content}>
        {loading ? (
          <ActivityIndicator color={textColor} />
        ) : (
          <>
            {icon}
            <Text variant={cfg.fontVariant} style={{ color: textColor }}>
              {label}
            </Text>
          </>
        )}
      </View>
    </AnimatedPressable>
  );
}

function resolveVariantColors(theme: ReturnType<typeof useTheme>, variant: ButtonVariant, disabled: boolean) {
  const { colors } = theme;
  switch (variant) {
    case 'primary':
      return { backgroundColor: colors.accent, borderColor: colors.accent, textColor: colors.textOnAccent };
    case 'secondary':
      return { backgroundColor: colors.secondary, borderColor: colors.secondary, textColor: '#FFF8F0' };
    case 'outline':
      return { backgroundColor: 'transparent', borderColor: colors.borderStrong, textColor: colors.textPrimary };
    case 'ghost':
      return { backgroundColor: 'transparent', borderColor: 'transparent', textColor: colors.textPrimary };
    case 'danger':
      return { backgroundColor: disabled ? colors.danger : colors.danger, borderColor: colors.danger, textColor: '#FFF8F0' };
    default:
      return { backgroundColor: colors.accent, borderColor: colors.accent, textColor: colors.textOnAccent };
  }
}

const styles = StyleSheet.create({
  base: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
});
