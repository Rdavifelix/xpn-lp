import { supabase } from '@/lib/supabase';
import type { RecommendationReason, Season } from '@/lib/supabase';

import type { OccasionCalendarEntry } from '../occasions';
import type { ScoringCandidate } from '../scoring';

export async function getOccasionCalendar(): Promise<OccasionCalendarEntry[]> {
  const { data, error } = await supabase
    .from('occasion_calendar')
    .select('slug, name, month, day, is_movable, lead_days, occasion:occasions(slug)');
  if (error) throw error;

  return (data ?? [])
    .filter((row) => row.occasion)
    .map((row) => ({
      slug: row.slug,
      name: row.name,
      month: row.month,
      day: row.day,
      isMovable: row.is_movable,
      occasionSlug: (row.occasion as unknown as { slug: string }).slug,
      leadDays: row.lead_days,
    }));
}

interface CandidateRow {
  fragrance_id: string;
  rating: number | null;
  fragrance: {
    id: string;
    name: string;
    image_url: string | null;
    brand: { name: string } | null;
    fragrance_accords: { intensity: number; accord: { slug: string } | null }[];
    fragrance_seasons: { season: Season; score: number }[];
    fragrance_occasions: { score: number; occasion: { slug: string } | null }[];
  } | null;
}

/** Every fragrance the user OWNS, shaped for scoring.ts — the candidate pool for "Your scent for today". */
export async function getScoringCandidates(userId: string, signatureFragranceId: string | null): Promise<ScoringCandidate[]> {
  const { data, error } = await supabase
    .from('collection_items')
    .select(
      `fragrance_id, rating,
       fragrance:fragrances(
         id, name, image_url,
         brand:brands(name),
         fragrance_accords(intensity, accord:accords(slug)),
         fragrance_seasons(season, score),
         fragrance_occasions(score, occasion:occasions(slug))
       )`,
    )
    .eq('user_id', userId)
    .eq('status', 'owned');
  if (error) throw error;

  const rows = data as unknown as CandidateRow[];

  return rows
    .filter((row) => row.fragrance)
    .map((row) => {
      const f = row.fragrance!;
      const seasons: Record<Season, number> = { spring: 0, summer: 0, fall: 0, winter: 0 };
      for (const s of f.fragrance_seasons) seasons[s.season] = s.score;

      return {
        fragranceId: f.id,
        name: f.name,
        brandName: f.brand?.name ?? 'Unknown House',
        imageUrl: f.image_url,
        accords: f.fragrance_accords.filter((a) => a.accord).map((a) => ({ slug: a.accord!.slug, intensity: a.intensity })),
        seasons,
        occasions: f.fragrance_occasions.filter((o) => o.occasion).map((o) => ({ slug: o.occasion!.slug, score: o.score })),
        personalRating: row.rating,
        isSignature: f.id === signatureFragranceId,
      };
    });
}

/** fragranceId -> days since it was last worn (0 = today), for every fragrance worn in the last `windowDays`. Missing entries mean "not worn recently". */
export async function getRecentWearRecency(userId: string, windowDays = 14): Promise<Record<string, number>> {
  const since = new Date();
  since.setDate(since.getDate() - windowDays);

  const { data, error } = await supabase
    .from('wears')
    .select('fragrance_id, worn_at')
    .eq('user_id', userId)
    .gte('worn_at', since.toISOString())
    .order('worn_at', { ascending: false });
  if (error) throw error;

  const recency: Record<string, number> = {};
  const now = Date.now();
  for (const row of data ?? []) {
    // First (most recent) occurrence per fragrance wins, since results are ordered newest-first.
    if (row.fragrance_id in recency) continue;
    const days = Math.floor((now - new Date(row.worn_at).getTime()) / (24 * 60 * 60 * 1000));
    recency[row.fragrance_id] = Math.max(days, 0);
  }
  return recency;
}

interface DailyRecommendationRow {
  fragrance_id: string;
  score: number;
  reason: RecommendationReason;
}

/** Today's already-computed pick, if one was saved earlier today — avoids recomputing (and re-fetching weather) on every Home screen visit. */
export async function getSavedDailyRecommendation(userId: string, forDate: string): Promise<DailyRecommendationRow | null> {
  const { data, error } = await supabase
    .from('daily_recommendations')
    .select('fragrance_id, score, reason')
    .eq('user_id', userId)
    .eq('for_date', forDate)
    .maybeSingle();
  if (error) throw error;
  return data;
}

export async function saveDailyRecommendation(
  userId: string,
  forDate: string,
  fragranceId: string,
  score: number,
  reason: RecommendationReason,
): Promise<void> {
  const { error } = await supabase
    .from('daily_recommendations')
    .upsert({ user_id: userId, for_date: forDate, fragrance_id: fragranceId, score, reason }, { onConflict: 'user_id,for_date' });
  if (error) throw error;
}
