import { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import Animated, { useAnimatedStyle, useSharedValue, withDelay, withTiming } from 'react-native-reanimated';

import { Button, Card, LoadingState, Text } from '@/components/ui';
import { useTheme } from '@/theme';

import type { DailyRecommendation } from '../hooks/useDailyRecommendation';

export interface DailyRecCardProps {
  recommendation: DailyRecommendation | null | undefined;
  isLoading: boolean;
}

/**
 * The home screen's anchor: "Your scent for today". Animates in on mount so
 * it reads as a considered reveal rather than just another list item — this
 * is the single most important card in the app, so it gets the most polish.
 */
export function DailyRecCard({ recommendation, isLoading }: DailyRecCardProps) {
  const theme = useTheme();
  const router = useRouter();
  const opacity = useSharedValue(0);
  const translateY = useSharedValue(16);

  useEffect(() => {
    if (recommendation) {
      opacity.value = withDelay(100, withTiming(1, { duration: theme.motion.duration.slow }));
      translateY.value = withDelay(100, withTiming(0, { duration: theme.motion.duration.slow, easing: theme.motion.easing.decelerate }));
    }
  }, [recommendation, opacity, translateY, theme.motion.duration.slow, theme.motion.easing.decelerate]);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ translateY: translateY.value }],
  }));

  if (isLoading) {
    return (
      <Card elevated style={styles.card}>
        <LoadingState message="Finding today's scent…" />
      </Card>
    );
  }

  if (!recommendation) {
    return (
      <Card elevated style={styles.card}>
        <Text variant="label" color="accent">
          YOUR SCENT FOR TODAY
        </Text>
        <Text variant="h3" style={styles.emptyTitle}>
          Add fragrances to your collection
        </Text>
        <Text variant="body" color="secondary">
          Once you mark a few as owned, we&apos;ll recommend one each day based on the weather and what&apos;s coming up.
        </Text>
        <Button label="Browse Fragrances" size="sm" onPress={() => router.push('/(tabs)/discover')} style={styles.emptyButton} />
      </Card>
    );
  }

  const { fragrance, reason } = recommendation;

  return (
    <Animated.View style={animatedStyle}>
      <Card elevated style={styles.card} onPress={() => router.push({ pathname: '/fragrance/[id]', params: { id: fragrance.id } })}>
        <Text variant="label" color="accent">
          YOUR SCENT FOR TODAY
        </Text>

        <View style={styles.body}>
          <View style={[styles.imageWrap, { backgroundColor: theme.colors.accentSoft, borderRadius: theme.radius.md }]}>
            {fragrance.imageUrl ? (
              <Image source={{ uri: fragrance.imageUrl }} style={styles.image} contentFit="cover" />
            ) : (
              <Ionicons name="flower-outline" size={30} color={theme.colors.accent} />
            )}
          </View>
          <View style={styles.info}>
            <Text variant="caption" color="muted">
              {fragrance.brandName.toUpperCase()}
            </Text>
            <Text variant="h2" numberOfLines={2}>
              {fragrance.name}
            </Text>
          </View>
        </View>

        <Text variant="quote" color="secondary" style={styles.headline}>
          {reason.headline}
        </Text>

        {reason.weather_summary ? (
          <View style={styles.reasonRow}>
            <Ionicons name="partly-sunny-outline" size={14} color={theme.colors.textMuted} />
            <Text variant="caption" color="muted" style={styles.reasonText}>
              {reason.weather_summary}
            </Text>
          </View>
        ) : null}

        {reason.occasion_summary ? (
          <View style={styles.reasonRow}>
            <Ionicons name="sparkles-outline" size={14} color={theme.colors.textMuted} />
            <Text variant="caption" color="muted" style={styles.reasonText}>
              {reason.occasion_summary}
            </Text>
          </View>
        ) : null}
      </Card>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  card: { gap: 4 },
  body: { flexDirection: 'row', alignItems: 'center', gap: 14, marginTop: 10, marginBottom: 14 },
  imageWrap: { width: 64, height: 64, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  image: { width: '100%', height: '100%' },
  info: { flex: 1, gap: 2 },
  headline: { marginBottom: 10 },
  reasonRow: { flexDirection: 'row', alignItems: 'flex-start', gap: 6, marginBottom: 4 },
  reasonText: { flex: 1 },
  emptyTitle: { marginTop: 10, marginBottom: 6 },
  emptyButton: { marginTop: 14, alignSelf: 'flex-start' },
});
