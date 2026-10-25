import { useQuery } from '@tanstack/react-query';

import { getAccordOptions, getBrandOptions, getNoteOptions } from '../api/discoveryApi';

// Filter chip data is reference/catalog data — long staleTime avoids
// refetching it every time Discover mounts.
const REFERENCE_STALE_TIME = 60 * 60_000;

export function useAccordOptions() {
  return useQuery({ queryKey: ['discovery', 'accords'], queryFn: getAccordOptions, staleTime: REFERENCE_STALE_TIME });
}

export function useNoteOptions() {
  return useQuery({ queryKey: ['discovery', 'notes'], queryFn: getNoteOptions, staleTime: REFERENCE_STALE_TIME });
}

export function useBrandOptions() {
  return useQuery({ queryKey: ['discovery', 'brands'], queryFn: getBrandOptions, staleTime: REFERENCE_STALE_TIME });
}
