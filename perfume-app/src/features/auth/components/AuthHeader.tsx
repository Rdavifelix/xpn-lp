import { StyleSheet, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { Text } from '@/components/ui';
import { useTheme } from '@/theme';

export function AuthHeader({ title, subtitle }: { title: string; subtitle: string }) {
  const theme = useTheme();

  return (
    <View style={styles.container}>
      <View style={[styles.mark, { backgroundColor: theme.colors.accentSoft }]}>
        <Ionicons name="flower-outline" size={30} color={theme.colors.accent} />
      </View>
      <Text variant="display" style={styles.title}>
        {title}
      </Text>
      <Text variant="body" color="secondary" style={styles.subtitle}>
        {subtitle}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', marginBottom: 32, gap: 6 },
  mark: { width: 64, height: 64, borderRadius: 32, alignItems: 'center', justifyContent: 'center', marginBottom: 8 },
  title: { textAlign: 'center' },
  subtitle: { textAlign: 'center' },
});
