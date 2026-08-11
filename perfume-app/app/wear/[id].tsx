import { useState } from 'react';
import { FlatList, KeyboardAvoidingView, Platform, StyleSheet, View } from 'react-native';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';

import { useAuth } from '@/features/auth';
import { FeedPostCard, useAddComment, useComments, useToggleLike, useWear } from '@/features/feed';
import { Avatar, Button, IconButton, LoadingState, ScreenContainer, Text, TextField } from '@/components/ui';
import { useTheme } from '@/theme';
import { formatDistanceToNowStrict } from 'date-fns';

export default function WearDetailScreen() {
  const theme = useTheme();
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { user } = useAuth();
  const { data: post, isLoading } = useWear(id, user?.id);
  const { data: comments } = useComments(id);
  const toggleLike = useToggleLike();
  const addComment = useAddComment(id ?? '');
  const [commentBody, setCommentBody] = useState('');

  const handleSend = () => {
    if (!user || !commentBody.trim()) return;
    addComment.mutate(
      { userId: user.id, body: commentBody.trim() },
      { onSuccess: () => setCommentBody('') },
    );
  };

  if (isLoading || !post) {
    return (
      <ScreenContainer>
        <LoadingState fill message="Loading post…" />
      </ScreenContainer>
    );
  }

  return (
    <ScreenContainer edges={['top', 'left', 'right']}>
      <Stack.Screen
        options={{ headerShown: true, title: 'Post', headerLeft: () => <IconButton name="chevron-back" onPress={() => router.back()} /> }}
      />
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.flex} keyboardVerticalOffset={90}>
        <FlatList
          data={comments ?? []}
          keyExtractor={(item) => item.id}
          ListHeaderComponent={
            <View style={styles.postWrap}>
              <FeedPostCard post={post} onToggleLike={() => toggleLike.mutate(post.id)} linkToDetail={false} />
              <Text variant="label" color="muted" style={styles.commentsLabel}>
                COMMENTS
              </Text>
            </View>
          }
          contentContainerStyle={styles.list}
          renderItem={({ item }) => (
            <View style={styles.commentRow}>
              <Avatar uri={item.author.avatarUrl} name={item.author.displayName ?? item.author.username} size={32} />
              <View style={styles.commentBody}>
                <Text variant="bodyMedium">
                  {item.author.displayName ?? item.author.username}{' '}
                  <Text variant="caption" color="muted">
                    {formatDistanceToNowStrict(new Date(item.createdAt), { addSuffix: true })}
                  </Text>
                </Text>
                <Text variant="body" color="secondary">
                  {item.body}
                </Text>
              </View>
            </View>
          )}
          ListEmptyComponent={
            <Text variant="body" color="muted" style={styles.noComments}>
              No comments yet — be the first to say something.
            </Text>
          }
        />

        {user ? (
          <View style={[styles.inputRow, { borderTopColor: theme.colors.border, backgroundColor: theme.colors.background }]}>
            <View style={styles.inputField}>
              <TextField value={commentBody} onChangeText={setCommentBody} placeholder="Add a comment…" />
            </View>
            <Button label="Send" size="sm" onPress={handleSend} loading={addComment.isPending} disabled={!commentBody.trim()} />
          </View>
        ) : null}
      </KeyboardAvoidingView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  list: { paddingBottom: 16 },
  postWrap: { paddingTop: 8 },
  commentsLabel: { marginTop: 18, marginBottom: 10 },
  commentRow: { flexDirection: 'row', gap: 10, marginBottom: 16 },
  commentBody: { flex: 1, gap: 2 },
  noComments: { paddingVertical: 20, textAlign: 'center' },
  inputRow: { flexDirection: 'row', gap: 10, alignItems: 'center', paddingVertical: 10, borderTopWidth: StyleSheet.hairlineWidth },
  inputField: { flex: 1 },
});
