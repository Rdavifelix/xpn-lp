import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { queryKeys } from '@/lib/query';
import type { CollectionStatus } from '@/lib/supabase';

import {
  addToCollection,
  getCollection,
  getCollectionItemForFragrance,
  removeFromCollection,
  updateCollectionItem,
  type UpsertCollectionInput,
} from '../api/collectionApi';

export function useCollection(userId: string | undefined, status?: CollectionStatus) {
  return useQuery({
    queryKey: queryKeys.collection(userId ?? '', status),
    queryFn: () => getCollection(userId as string, status),
    enabled: Boolean(userId),
  });
}

export function useCollectionItemForFragrance(userId: string | undefined, fragranceId: string | undefined) {
  return useQuery({
    queryKey: ['collection-item', userId ?? '', fragranceId ?? ''],
    queryFn: () => getCollectionItemForFragrance(userId as string, fragranceId as string),
    enabled: Boolean(userId) && Boolean(fragranceId),
  });
}

/** Invalidates every collection-related cache entry for a user after a mutation. */
function invalidateCollection(queryClient: ReturnType<typeof useQueryClient>, userId: string) {
  queryClient.invalidateQueries({ queryKey: ['collection', userId] });
  queryClient.invalidateQueries({ queryKey: ['collection-item'] });
}

export function useAddToCollection(userId: string | undefined) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ fragranceId, input }: { fragranceId: string; input?: UpsertCollectionInput }) =>
      addToCollection(userId as string, fragranceId, input),
    onSuccess: () => {
      if (userId) invalidateCollection(queryClient, userId);
    },
  });
}

export function useUpdateCollectionItem(userId: string | undefined) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ itemId, input }: { itemId: string; input: UpsertCollectionInput }) => updateCollectionItem(itemId, input),
    onSuccess: () => {
      if (userId) invalidateCollection(queryClient, userId);
    },
  });
}

export function useRemoveFromCollection(userId: string | undefined) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (itemId: string) => removeFromCollection(itemId),
    onSuccess: () => {
      if (userId) invalidateCollection(queryClient, userId);
    },
  });
}
