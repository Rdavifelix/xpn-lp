import { ActivityIndicator, StyleSheet, View } from 'react-native';

import { useTheme } from '@/theme';

import { Text } from './Text';

export interface LoadingStateProps {
  message?: string;
  /** Fills the parent instead of just wrapping its content — use for full-screen loads. */
  fill?: boolean;
}

export function LoadingState({ message, fill = false }: LoadingStateProps) {
  const theme = useTheme();

  return (
    <View style={[styles.container, fill && styles.fill]}>
      <ActivityIndicator color={theme.colors.accent} />
      {message ? (
        <Text variant="caption" color="muted" style={styles.message}>
          {message}
        </Text>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', justifyContent: 'center', paddingVertical: 24, gap: 8 },
  fill: { flex: 1 },
  message: { marginTop: 4 },
});
