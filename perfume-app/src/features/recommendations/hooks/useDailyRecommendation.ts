import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { queryKeys } from '@/lib/query';
import type { RecommendationReason } from '@/lib/supabase';
import { getFragrancesByIds, type FragranceSummary } from '@/features/fragrances';
import type { Profile } from '@/features/profiles';

import {
  getOccasionCalendar,
  getRecentWearRecency,
  getScoringCandidates,
  getSavedDailyRecommendation,
  saveDailyRecommendation,
} from '../api/recommendationsApi';
import { resolveWeatherForRecommendation } from '../api/weatherApi';
import { getMeteorologicalSeason, getUpcomingOccasions, type UpcomingOccasion } from '../occasions';
import { buildRecommendationReason, rankFragrances, type ScoringContext } from '../scoring';

export interface DailyRecommendation {
  fragrance: FragranceSummary;
  score: number;
  reason: RecommendationReason;
}

function todayDateString(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

/**
 * Computes (or reuses today's already-saved) "Your scent for today" pick
 * from the user's OWNED collection. This is the orchestration layer around
 * scoring.ts: gather weather + season + active occasions + wear history,
 * rank every owned fragrance, persist the winner so revisiting Home today
 * doesn't recompute (or re-prompt for location) again.
 */
async function computeDailyRecommendation(userId: string, profile: Profile): Promise<DailyRecommendation | null> {
  const forDate = todayDateString();

  const saved = await getSavedDailyRecommendation(userId, forDate);
  if (saved) {
    const [fragrance] = await getFragrancesByIds([saved.fragrance_id]);
    if (fragrance) return { fragrance, score: saved.score, reason: saved.reason };
  }

  const candidates = await getScoringCandidates(userId, profile.signature_fragrance_id);
  if (candidates.length === 0) return null;

  const [weather, calendar, recency] = await Promise.all([
    resolveWeatherForRecommendation({ latitude: profile.latitude, longitude: profile.longitude }),
    getOccasionCalendar(),
    getRecentWearRecency(userId),
  ]);

  const currentSeason = getMeteorologicalSeason(new Date(), profile.latitude);
  const activeOccasions: UpcomingOccasion[] = getUpcomingOccasions(calendar);

  const context: ScoringContext = {
    weather,
    currentSeason,
    activeOccasions,
    daysSinceLastWorn: Object.fromEntries(candidates.map((c) => [c.fragranceId, recency[c.fragranceId] ?? null])),
  };

  const [top] = rankFragrances(candidates, context);
  const winner = candidates.find((c) => c.fragranceId === top.fragranceId)!;
  const reason = buildRecommendationReason(winner.name, top.breakdown, weather, activeOccasions);

  await saveDailyRecommendation(userId, forDate, top.fragranceId, top.score, reason);

  const [fragrance] = await getFragrancesByIds([top.fragranceId]);
  return fragrance ? { fragrance, score: top.score, reason } : null;
}

export function useDailyRecommendation(userId: string | undefined, profile: Profile | undefined) {
  return useQuery({
    queryKey: queryKeys.dailyRecommendation(userId ?? '', todayDateString()),
    queryFn: () => computeDailyRecommendation(userId as string, profile as Profile),
    enabled: Boolean(userId) && Boolean(profile),
    staleTime: 5 * 60_000,
  });
}

/** Lets the Home screen force a fresh computation (e.g. after adding fragrances, or a "shuffle" action) instead of waiting for the cached-for-today result. */
export function useRefreshDailyRecommendation(userId: string | undefined) {
  const queryClient = useQueryClient();
  return () => {
    if (userId) queryClient.invalidateQueries({ queryKey: queryKeys.dailyRecommendation(userId, todayDateString()) });
  };
}

/**
 * On-demand recommendation for a specific event ("date night", "office",
 * ...) requested explicitly by the user — reuses the exact same scoring
 * engine as the daily card, but with the requested occasion forced to full
 * weight instead of auto-detecting calendar holidays, and isn't persisted
 * to daily_recommendations (that table is specifically "today's" pick).
 */
export function useRequestRecommendation(userId: string | undefined, profile: Profile | undefined) {
  return useMutation({
    mutationFn: async (occasionSlug: string): Promise<DailyRecommendation | null> => {
      if (!userId) throw new Error('Not signed in.');

      const candidates = await getScoringCandidates(userId, profile?.signature_fragrance_id ?? null);
      if (candidates.length === 0) return null;

      const [weather, recency] = await Promise.all([
        resolveWeatherForRecommendation({ latitude: profile?.latitude ?? null, longitude: profile?.longitude ?? null }),
        getRecentWearRecency(userId),
      ]);
      const currentSeason = getMeteorologicalSeason(new Date(), profile?.latitude ?? null);
      const requestedOccasion: UpcomingOccasion = { occasionSlug, holidayName: '', daysUntil: 0, weight: 1 };

      const context: ScoringContext = {
        weather,
        currentSeason,
        activeOccasions: [requestedOccasion],
        daysSinceLastWorn: Object.fromEntries(candidates.map((c) => [c.fragranceId, recency[c.fragranceId] ?? null])),
      };

      const [top] = rankFragrances(candidates, context);
      const winner = candidates.find((c) => c.fragranceId === top.fragranceId)!;
      const reason = buildRecommendationReason(winner.name, top.breakdown, weather, []);

      const [fragrance] = await getFragrancesByIds([top.fragranceId]);
      return fragrance ? { fragrance, score: top.score, reason } : null;
    },
  });
}
