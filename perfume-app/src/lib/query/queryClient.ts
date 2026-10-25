import { QueryClient } from '@tanstack/react-query';

/**
 * Single shared QueryClient. Defaults tuned for a social feed: data is
 * "fresh enough" for a short window (avoids refetch storms when navigating
 * back and forth between tabs) but Supabase Realtime subscriptions
 * (see features/feed) invalidate relevant queries the moment something
 * actually changes, so this doesn't trade away liveness.
 */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      gcTime: 5 * 60_000,
      retry: 2,
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 0,
    },
  },
});

/** Centralized query key factory — keeps invalidation call sites typo-proof. */
export const queryKeys = {
  profile: (userId: string) => ['profile', userId] as const,
  profileByUsername: (username: string) => ['profile', 'username', username] as const,
  collection: (userId: string, status?: string) => ['collection', userId, status ?? 'all'] as const,
  fragrance: (fragranceId: string) => ['fragrance', fragranceId] as const,
  fragranceFriends: (fragranceId: string) => ['fragrance', fragranceId, 'friends'] as const,
  feed: (scope: 'global' | 'following') => ['feed', scope] as const,
  wear: (wearId: string) => ['wear', wearId] as const,
  wearComments: (wearId: string) => ['wear', wearId, 'comments'] as const,
  search: (query: string, filters?: string) => ['search', query, filters ?? ''] as const,
  brands: () => ['brands'] as const,
  notes: () => ['notes'] as const,
  accords: () => ['accords'] as const,
  occasions: () => ['occasions'] as const,
  dailyRecommendation: (userId: string, date: string) => ['recommendation', userId, date] as const,
  followers: (userId: string) => ['follows', userId, 'followers'] as const,
  following: (userId: string) => ['follows', userId, 'following'] as const,
};
