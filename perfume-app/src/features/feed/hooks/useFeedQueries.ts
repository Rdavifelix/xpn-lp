import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { queryKeys } from '@/lib/query';

import { addComment, createWear, deleteComment, getComments, getFeed, getUserWears, getWear, toggleLike } from '../api/feedApi';
import type { CreateWearInput, FeedPost } from '../types';

const FEED_PAGE_SIZE = 20;

export function useFeed() {
  return useInfiniteQuery({
    queryKey: queryKeys.feed('global'),
    queryFn: ({ pageParam }) => getFeed(pageParam),
    initialPageParam: null as string | null,
    getNextPageParam: (lastPage) => {
      if (lastPage.length < FEED_PAGE_SIZE) return undefined;
      return lastPage[lastPage.length - 1]?.wornAt ?? undefined;
    },
  });
}

export function useWear(wearId: string | undefined, currentUserId: string | undefined) {
  return useQuery({
    queryKey: queryKeys.wear(wearId ?? ''),
    queryFn: () => getWear(wearId as string, currentUserId),
    enabled: Boolean(wearId),
  });
}

export function useUserWears(userId: string | undefined, currentUserId: string | undefined) {
  return useQuery({
    queryKey: ['wears', 'user', userId ?? '', currentUserId ?? ''],
    queryFn: () => getUserWears(userId as string, currentUserId),
    enabled: Boolean(userId),
  });
}

/** Optimistically flips the like state/count in every cached feed page and the single-wear cache. */
export function useToggleLike() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (wearId: string) => toggleLike(wearId),
    onMutate: async (wearId: string) => {
      await queryClient.cancelQueries({ queryKey: queryKeys.feed('global') });

      const applyOptimisticFlip = (post: FeedPost): FeedPost =>
        post.id === wearId
          ? { ...post, likedByMe: !post.likedByMe, likesCount: post.likesCount + (post.likedByMe ? -1 : 1) }
          : post;

      queryClient.setQueriesData<{ pages: FeedPost[][]; pageParams: unknown[] } | undefined>({ queryKey: queryKeys.feed('global') }, (old) => {
        if (!old) return old;
        return { ...old, pages: old.pages.map((page) => page.map(applyOptimisticFlip)) };
      });

      queryClient.setQueryData<FeedPost | undefined>(queryKeys.wear(wearId), (old) => (old ? applyOptimisticFlip(old) : old));
    },
    onSettled: (_data, _error, wearId) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.feed('global') });
      queryClient.invalidateQueries({ queryKey: queryKeys.wear(wearId) });
    },
  });
}

export function useComments(wearId: string | undefined) {
  return useQuery({
    queryKey: queryKeys.wearComments(wearId ?? ''),
    queryFn: () => getComments(wearId as string),
    enabled: Boolean(wearId),
  });
}

export function useAddComment(wearId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ userId, body }: { userId: string; body: string }) => addComment(wearId, userId, body),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.wearComments(wearId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.wear(wearId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.feed('global') });
    },
  });
}

export function useDeleteComment(wearId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (commentId: string) => deleteComment(commentId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.wearComments(wearId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.wear(wearId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.feed('global') });
    },
  });
}

export function useCreateWear(userId: string | undefined) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: CreateWearInput) => createWear(userId as string, input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.feed('global') });
      if (userId) queryClient.invalidateQueries({ queryKey: queryKeys.profile(userId) });
    },
  });
}
