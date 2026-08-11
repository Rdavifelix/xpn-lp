import { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withDelay, withTiming } from 'react-native-reanimated';

import { useTheme } from '@/theme';

import { Text } from './Text';

export interface AccordDatum {
  id: string;
  label: string;
  /** 0-100 intensity, drives both bar length and sort order upstream. */
  intensity: number;
  color?: string;
}

export interface AccordChartProps {
  data: AccordDatum[];
}

/**
 * Horizontal bar chart of a fragrance's dominant accords. Deliberately not a
 * pie/donut — dominant-accord counts vary per fragrance and bars stay
 * legible from 2 to 8 entries, animate in nicely, and read fine in both
 * themes without a legend.
 */
export function AccordChart({ data }: AccordChartProps) {
  const sorted = [...data].sort((a, b) => b.intensity - a.intensity);

  return (
    <View style={styles.container}>
      {sorted.map((item, index) => (
        <AccordBar key={item.id} datum={item} index={index} />
      ))}
    </View>
  );
}

function AccordBar({ datum, index }: { datum: AccordDatum; index: number }) {
  const theme = useTheme();
  const width = useSharedValue(0);

  useEffect(() => {
    width.value = withDelay(
      index * 60,
      withTiming(datum.intensity, { duration: theme.motion.duration.slow, easing: theme.motion.easing.decelerate }),
    );
  }, [datum.intensity, index, theme.motion.duration.slow, theme.motion.easing.decelerate, width]);

  const animatedStyle = useAnimatedStyle(() => ({
    width: `${width.value}%`,
  }));

  const barColor = datum.color ?? theme.colors.accent;

  return (
    <View style={styles.row}>
      <Text variant="bodyMedium" style={styles.label} numberOfLines={1}>
        {datum.label}
      </Text>
      <View style={[styles.track, { backgroundColor: theme.colors.border, borderRadius: theme.radius.pill }]}>
        <Animated.View style={[styles.fill, { backgroundColor: barColor, borderRadius: theme.radius.pill }, animatedStyle]} />
      </View>
      <Text variant="caption" color="muted" style={styles.value}>
        {Math.round(datum.intensity)}%
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  label: { width: 84 },
  track: { flex: 1, height: 10, overflow: 'hidden' },
  fill: { height: '100%' },
  value: { width: 36, textAlign: 'right' },
});
