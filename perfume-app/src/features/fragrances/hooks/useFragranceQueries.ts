import { useQuery } from '@tanstack/react-query';

import { queryKeys } from '@/lib/query';

import { getFragrance, getFriendsWhoOwn, getOccasions, listFragrances, type ListFragrancesFilters } from '../api/fragrancesApi';

export function useFragrance(id: string | undefined) {
  return useQuery({
    queryKey: queryKeys.fragrance(id ?? ''),
    queryFn: () => getFragrance(id as string),
    enabled: Boolean(id),
  });
}

export function useFriendsWhoOwn(fragranceId: string | undefined) {
  return useQuery({
    queryKey: queryKeys.fragranceFriends(fragranceId ?? ''),
    queryFn: () => getFriendsWhoOwn(fragranceId as string),
    enabled: Boolean(fragranceId),
  });
}

export function useFragranceList(filters: ListFragrancesFilters) {
  return useQuery({
    queryKey: ['fragrances', 'list', filters],
    queryFn: () => listFragrances(filters),
  });
}

export function useOccasions() {
  return useQuery({
    queryKey: queryKeys.occasions(),
    queryFn: getOccasions,
    staleTime: 60 * 60_000, // reference data — rarely changes
  });
}
