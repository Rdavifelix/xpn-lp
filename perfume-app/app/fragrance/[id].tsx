import { ScrollView, StyleSheet, View } from 'react-native';
import { Image } from 'expo-image';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

import { useAuth } from '@/features/auth';
import { useFragrance, useFriendsWhoOwn } from '@/features/fragrances';
import { CollectionEditor } from '@/features/collection';
import { AccordChart, Avatar, Button, Card, IconButton, LoadingState, NotePyramid, ScreenContainer, Tag, Text } from '@/components/ui';
import { useTheme } from '@/theme';
import type { Season } from '@/lib/supabase';

const SEASON_LABELS: Record<Season, string> = { spring: 'Spring', summer: 'Summer', fall: 'Fall', winter: 'Winter' };

export default function FragranceDetailScreen() {
  const theme = useTheme();
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { user } = useAuth();
  const { data: fragrance, isLoading } = useFragrance(id);
  const { data: friends } = useFriendsWhoOwn(id);

  if (isLoading || !fragrance) {
    return (
      <ScreenContainer>
        <LoadingState fill message="Loading fragrance…" />
      </ScreenContainer>
    );
  }

  return (
    <ScreenContainer padded={false} edges={['top', 'left', 'right']}>
      <Stack.Screen
        options={{
          headerShown: true,
          title: '',
          headerTransparent: true,
          headerLeft: () => <IconButton name="chevron-back" onPress={() => router.back()} backgroundColor={theme.colors.surfaceElevated} />,
        }}
      />
      <ScrollView contentContainerStyle={styles.scroll}>
        <View style={[styles.hero, { backgroundColor: theme.colors.accentSoft }]}>
          {fragrance.imageUrl ? (
            <Image source={{ uri: fragrance.imageUrl }} style={styles.heroImage} contentFit="cover" />
          ) : (
            <Ionicons name="flask-outline" size={64} color={theme.colors.accent} />
          )}
        </View>

        <View style={styles.body}>
          <Text variant="caption" color="muted">
            {fragrance.brandName.toUpperCase()}
          </Text>
          <Text variant="display" style={styles.name}>
            {fragrance.name}
          </Text>

          <View style={styles.tagRow}>
            <Tag label={fragrance.gender} size="sm" />
            <Tag label={fragrance.concentration.toUpperCase()} size="sm" />
            {fragrance.releaseYear ? <Tag label={String(fragrance.releaseYear)} size="sm" /> : null}
          </View>

          {fragrance.description ? (
            <Text variant="body" color="secondary" style={styles.description}>
              {fragrance.description}
            </Text>
          ) : null}

          <View style={styles.statsRow}>
            <StatBar label="Longevity" value={fragrance.longevity} />
            <StatBar label="Sillage" value={fragrance.sillage} />
          </View>

          {user ? (
            <Button
              label="Log this fragrance"
              icon={<Ionicons name="create-outline" size={18} color={theme.colors.textOnAccent} />}
              onPress={() => router.push({ pathname: '/compose', params: { fragranceId: fragrance.id } })}
              style={styles.logButton}
            />
          ) : null}

          {fragrance.accords.length > 0 ? (
            <Card style={styles.section}>
              <Text variant="h3" style={styles.sectionTitle}>
                Scent Profile
              </Text>
              <AccordChart data={fragrance.accords} />
            </Card>
          ) : null}

          <Card style={styles.section}>
            <Text variant="h3" style={styles.sectionTitle}>
              Fragrance Pyramid
            </Text>
            <NotePyramid top={fragrance.notes.top} middle={fragrance.notes.middle} base={fragrance.notes.base} />
          </Card>

          <Card style={styles.section}>
            <Text variant="h3" style={styles.sectionTitle}>
              Best Suited For
            </Text>
            <View style={styles.chipWrap}>
              {(Object.keys(SEASON_LABELS) as Season[])
                .filter((s) => fragrance.seasons[s] >= 50)
                .sort((a, b) => fragrance.seasons[b] - fragrance.seasons[a])
                .map((s) => (
                  <Tag key={s} label={SEASON_LABELS[s]} size="sm" />
                ))}
              {fragrance.occasions
                .filter((o) => o.score >= 50)
                .sort((a, b) => b.score - a.score)
                .map((o) => (
                  <Tag key={o.id} label={o.label} color={theme.colors.secondary} size="sm" />
                ))}
            </View>
          </Card>

          {friends && friends.length > 0 ? (
            <Card style={styles.section}>
              <Text variant="h3" style={styles.sectionTitle}>
                Friends Who Own This
              </Text>
              <View style={styles.friendsRow}>
                {friends.map((friend) => (
                  <View key={friend.id} style={styles.friendItem}>
                    <Avatar uri={friend.avatar_url} name={friend.display_name ?? friend.username} size={44} />
                    <Text variant="caption" color="secondary" numberOfLines={1} style={styles.friendName}>
                      {friend.display_name ?? friend.username}
                    </Text>
                  </View>
                ))}
              </View>
            </Card>
          ) : null}

          {user ? (
            <View style={styles.section}>
              <CollectionEditor userId={user.id} fragranceId={fragrance.id} />
            </View>
          ) : null}
        </View>
      </ScrollView>
    </ScreenContainer>
  );
}

function StatBar({ label, value }: { label: string; value: number | null }) {
  const theme = useTheme();
  const filled = value ?? 0;

  return (
    <View style={styles.statBar}>
      <Text variant="caption" color="muted">
        {label}
      </Text>
      <View style={styles.statDots}>
        {[1, 2, 3, 4, 5].map((n) => (
          <View
            key={n}
            style={[
              styles.dot,
              { backgroundColor: n <= filled ? theme.colors.accent : theme.colors.border },
            ]}
          />
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: { paddingBottom: 48 },
  hero: { width: '100%', aspectRatio: 1.3, alignItems: 'center', justifyContent: 'center' },
  heroImage: { width: '100%', height: '100%' },
  body: { paddingHorizontal: 16, paddingTop: 20 },
  name: { marginTop: 2, marginBottom: 12 },
  tagRow: { flexDirection: 'row', gap: 8, marginBottom: 14 },
  description: { marginBottom: 16 },
  statsRow: { flexDirection: 'row', gap: 28, marginBottom: 20 },
  statBar: { gap: 6 },
  statDots: { flexDirection: 'row', gap: 4 },
  dot: { width: 16, height: 6, borderRadius: 3 },
  logButton: { marginBottom: 20 },
  section: { marginBottom: 16 },
  sectionTitle: { marginBottom: 14 },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  friendsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 16 },
  friendItem: { alignItems: 'center', width: 56 },
  friendName: { marginTop: 4 },
});
