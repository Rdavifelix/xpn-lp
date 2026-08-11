import { supabase } from '@/lib/supabase';
import type { FeedRow } from '@/lib/supabase';

import type { Comment, CreateWearInput, FeedPost } from '../types';

function toFeedPost(row: FeedRow): FeedPost {
  return {
    id: row.id,
    fragranceId: row.fragrance_id,
    wornAt: row.worn_at,
    photoUrl: row.photo_url,
    caption: row.caption,
    occasionId: row.occasion_id,
    mood: row.mood,
    weather: row.weather,
    likesCount: row.likes_count,
    commentsCount: row.comments_count,
    likedByMe: row.liked_by_me,
    author: { id: row.user_id, username: row.author_username, displayName: row.author_display_name, avatarUrl: row.author_avatar_url },
    fragrance: { name: row.fragrance_name, brandName: row.fragrance_brand_name, imageUrl: row.fragrance_image_url },
  };
}

export async function getFeed(before?: string | null): Promise<FeedPost[]> {
  const { data, error } = await supabase.rpc('get_feed', { p_limit: 20, p_before: before ?? null });
  if (error) throw error;
  return (data ?? []).map(toFeedPost);
}

interface WearDetailRow {
  id: string;
  user_id: string;
  fragrance_id: string;
  worn_at: string;
  photo_url: string | null;
  caption: string | null;
  occasion_id: string | null;
  mood: string | null;
  weather: FeedRow['weather'];
  likes_count: number;
  comments_count: number;
  author: { username: string; display_name: string | null; avatar_url: string | null } | null;
  fragrance: { name: string; image_url: string | null; brand: { name: string } | null } | null;
}

export async function getWear(wearId: string, currentUserId?: string): Promise<FeedPost> {
  const { data, error } = await supabase
    .from('wears')
    .select(
      `id, user_id, fragrance_id, worn_at, photo_url, caption, occasion_id, mood, weather, likes_count, comments_count,
       author:profiles!wears_user_id_fkey(username, display_name, avatar_url),
       fragrance:fragrances(name, image_url, brand:brands(name))`,
    )
    .eq('id', wearId)
    .single();
  if (error) throw error;

  const row = data as unknown as WearDetailRow;
  let likedByMe = false;
  if (currentUserId) {
    const { data: likeRow } = await supabase.from('likes').select('user_id').eq('wear_id', wearId).eq('user_id', currentUserId).maybeSingle();
    likedByMe = Boolean(likeRow);
  }

  return {
    id: row.id,
    fragranceId: row.fragrance_id,
    wornAt: row.worn_at,
    photoUrl: row.photo_url,
    caption: row.caption,
    occasionId: row.occasion_id,
    mood: row.mood,
    weather: row.weather,
    likesCount: row.likes_count,
    commentsCount: row.comments_count,
    likedByMe,
    author: {
      id: row.user_id,
      username: row.author?.username ?? 'unknown',
      displayName: row.author?.display_name ?? null,
      avatarUrl: row.author?.avatar_url ?? null,
    },
    fragrance: {
      name: row.fragrance?.name ?? 'Unknown fragrance',
      brandName: row.fragrance?.brand?.name ?? 'Unknown House',
      imageUrl: row.fragrance?.image_url ?? null,
    },
  };
}

export async function toggleLike(wearId: string): Promise<boolean> {
  const { data, error } = await supabase.rpc('toggle_like', { p_wear_id: wearId });
  if (error) throw error;
  return data;
}

interface CommentRow {
  id: string;
  wear_id: string;
  body: string;
  created_at: string;
  user_id: string;
  author: { username: string; display_name: string | null; avatar_url: string | null } | null;
}

export async function getComments(wearId: string): Promise<Comment[]> {
  const { data, error } = await supabase
    .from('comments')
    .select('id, wear_id, body, created_at, user_id, author:profiles!comments_user_id_fkey(username, display_name, avatar_url)')
    .eq('wear_id', wearId)
    .order('created_at', { ascending: true });
  if (error) throw error;

  return (data as unknown as CommentRow[]).map((row) => ({
    id: row.id,
    wearId: row.wear_id,
    body: row.body,
    createdAt: row.created_at,
    author: {
      id: row.user_id,
      username: row.author?.username ?? 'unknown',
      displayName: row.author?.display_name ?? null,
      avatarUrl: row.author?.avatar_url ?? null,
    },
  }));
}

export async function addComment(wearId: string, userId: string, body: string): Promise<void> {
  const { error } = await supabase.from('comments').insert({ wear_id: wearId, user_id: userId, body });
  if (error) throw error;
}

export async function deleteComment(commentId: string): Promise<void> {
  const { error } = await supabase.from('comments').delete().eq('id', commentId);
  if (error) throw error;
}

export async function createWear(userId: string, input: CreateWearInput): Promise<{ id: string }> {
  const { data, error } = await supabase
    .from('wears')
    .insert({
      user_id: userId,
      fragrance_id: input.fragranceId,
      caption: input.caption,
      photo_url: input.photoUrl,
      occasion_id: input.occasionId,
      mood: input.mood,
      weather: input.weather,
      visibility: input.visibility ?? 'public',
    })
    .select('id')
    .single();
  if (error) throw error;
  return data;
}
