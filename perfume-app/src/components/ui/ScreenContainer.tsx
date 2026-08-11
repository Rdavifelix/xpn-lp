import type { PropsWithChildren } from 'react';
import { StyleSheet, View, type ViewStyle } from 'react-native';
import { SafeAreaView, type Edge } from 'react-native-safe-area-context';

import { useTheme } from '@/theme';

export interface ScreenContainerProps extends PropsWithChildren {
  edges?: Edge[];
  style?: ViewStyle;
  /** Set false for screens that manage their own scrolling/background (e.g. a feed FlashList). */
  padded?: boolean;
}

/**
 * Baseline wrapper for every screen: themed background + safe-area
 * handling. Keeps individual screens from re-deriving the same
 * boilerplate.
 */
export function ScreenContainer({ children, edges = ['top', 'left', 'right'], style, padded = true }: ScreenContainerProps) {
  const theme = useTheme();

  return (
    <SafeAreaView
      edges={edges}
      style={[styles.flex, { backgroundColor: theme.colors.background }]}
    >
      <View style={[styles.flex, padded && { paddingHorizontal: theme.spacing.md }, style]}>{children}</View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
});
