import { Pressable, StyleSheet, View } from 'react-native';
import { Image } from 'expo-image';
import { formatDistanceToNowStrict } from 'date-fns';
import { useRouter } from 'expo-router';

import { Avatar, Card, IconButton, Tag, Text } from '@/components/ui';
import { useTheme } from '@/theme';

import type { FeedPost } from '../types';
import { WeatherChip } from './WeatherChip';

export interface FeedPostCardProps {
  post: FeedPost;
  onToggleLike: () => void;
  /** Hide the comment/expand affordance when already on the wear detail screen. */
  linkToDetail?: boolean;
}

export function FeedPostCard({ post, onToggleLike, linkToDetail = true }: FeedPostCardProps) {
  const theme = useTheme();
  const router = useRouter();

  const goToDetail = () => {
    if (linkToDetail) router.push({ pathname: '/wear/[id]', params: { id: post.id } });
  };

  const goToProfile = () => router.push({ pathname: '/user/[username]', params: { username: post.author.username } });

  return (
    <Card style={styles.card}>
      <Pressable onPress={goToProfile} style={styles.header}>
        <Avatar uri={post.author.avatarUrl} name={post.author.displayName ?? post.author.username} size={38} />
        <View style={styles.headerText}>
          <Text variant="bodyMedium">{post.author.displayName ?? post.author.username}</Text>
          <Text variant="caption" color="muted">
            wearing {post.fragrance.name} · {formatDistanceToNowStrict(new Date(post.wornAt), { addSuffix: true })}
          </Text>
        </View>
      </Pressable>

      <Pressable onPress={goToDetail}>
        {post.photoUrl ? <Image source={{ uri: post.photoUrl }} style={styles.photo} contentFit="cover" transition={150} /> : null}

        {post.caption ? (
          <Text variant="body" style={styles.caption}>
            {post.caption}
          </Text>
        ) : null}

        <View style={styles.metaRow}>
          {post.mood ? <Tag label={post.mood} size="sm" color={theme.colors.secondary} /> : null}
          {post.weather ? <WeatherChip weather={post.weather} /> : null}
        </View>
      </Pressable>

      <View style={styles.actionsRow}>
        <View style={styles.actionGroup}>
          <IconButton name={post.likedByMe ? 'heart' : 'heart-outline'} active={post.likedByMe} onPress={onToggleLike} haptics />
          <Text variant="caption" color="secondary">
            {post.likesCount}
          </Text>
        </View>
        <Pressable onPress={goToDetail} style={styles.actionGroup}>
          <IconButton name="chatbubble-outline" onPress={goToDetail} />
          <Text variant="caption" color="secondary">
            {post.commentsCount}
          </Text>
        </Pressable>
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  card: { padding: 0, overflow: 'hidden' },
  header: { flexDirection: 'row', alignItems: 'center', gap: 10, padding: 14, paddingBottom: 10 },
  headerText: { flex: 1 },
  photo: { width: '100%', aspectRatio: 1.1 },
  caption: { paddingHorizontal: 14, paddingTop: 10 },
  metaRow: { flexDirection: 'row', gap: 8, paddingHorizontal: 14, paddingTop: 10, paddingBottom: 4, flexWrap: 'wrap' },
  actionsRow: { flexDirection: 'row', gap: 20, paddingHorizontal: 10, paddingVertical: 6, paddingBottom: 10 },
  actionGroup: { flexDirection: 'row', alignItems: 'center', gap: 2 },
});
