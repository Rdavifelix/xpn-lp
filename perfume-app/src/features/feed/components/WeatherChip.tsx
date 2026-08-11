import { StyleSheet, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { Text } from '@/components/ui';
import { useTheme } from '@/theme';
import type { WeatherSnapshot } from '@/lib/supabase';

const CONDITION_ICON: Record<string, keyof typeof Ionicons.glyphMap> = {
  clear: 'sunny-outline',
  clouds: 'cloudy-outline',
  rain: 'rainy-outline',
  drizzle: 'rainy-outline',
  snow: 'snow-outline',
  thunderstorm: 'thunderstorm-outline',
  fog: 'reader-outline',
};

export function WeatherChip({ weather }: { weather: WeatherSnapshot }) {
  const theme = useTheme();
  const icon = CONDITION_ICON[weather.condition.toLowerCase()] ?? 'partly-sunny-outline';

  return (
    <View style={[styles.chip, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border, borderRadius: theme.radius.pill }]}>
      <Ionicons name={icon} size={13} color={theme.colors.textSecondary} />
      <Text variant="caption" color="secondary">
        {Math.round(weather.temp_c)}°{weather.city ? ` · ${weather.city}` : ''}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  chip: { flexDirection: 'row', alignItems: 'center', gap: 5, paddingHorizontal: 10, paddingVertical: 4, borderWidth: StyleSheet.hairlineWidth },
});
