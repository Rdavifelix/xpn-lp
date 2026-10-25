import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';

import { supabase } from '@/lib/supabase';
import { queryKeys } from '@/lib/query';

/**
 * Subscribes to Supabase Realtime for new wears/likes/comments and
 * invalidates the feed query so it refetches — this is what makes "someone
 * just posted" / like-count changes show up live without a manual pull to
 * refresh. Invalidation (rather than manually patching cache from the
 * payload) keeps this simple and correct even though it means an extra
 * network round-trip per event; the feed's staleTime keeps that cheap.
 */
export function useRealtimeFeed() {
  const queryClient = useQueryClient();

  useEffect(() => {
    const channel = supabase
      .channel('public:feed')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'wears' }, () => {
        queryClient.invalidateQueries({ queryKey: queryKeys.feed('global') });
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'wears' }, (payload) => {
        const wearId = (payload.new as { id?: string } | null)?.id;
        queryClient.invalidateQueries({ queryKey: queryKeys.feed('global') });
        if (wearId) queryClient.invalidateQueries({ queryKey: queryKeys.wear(wearId) });
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'comments' }, (payload) => {
        const wearId = (payload.new as { wear_id?: string } | null)?.wear_id ?? (payload.old as { wear_id?: string } | null)?.wear_id;
        if (wearId) queryClient.invalidateQueries({ queryKey: queryKeys.wearComments(wearId) });
        queryClient.invalidateQueries({ queryKey: queryKeys.feed('global') });
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [queryClient]);
}
