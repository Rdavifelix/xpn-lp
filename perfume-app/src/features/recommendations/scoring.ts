import type { RecommendationReason, Season, WeatherSnapshot } from '@/lib/supabase';

import { getWeatherAccordAffinity } from './weatherProfile';
import type { UpcomingOccasion } from './occasions';

/**
 * A fragrance from the user's OWNED collection, shaped for scoring —
 * everything the scoring function needs and nothing it doesn't (built by
 * api/recommendationsApi.ts's getScoringCandidates()).
 */
export interface ScoringCandidate {
  fragranceId: string;
  name: string;
  brandName: string;
  imageUrl: string | null;
  /** accord slug -> intensity (0-100), from fragrance_accords. */
  accords: { slug: string; intensity: number }[];
  /** season -> suitability score (0-100), from fragrance_seasons. */
  seasons: Record<Season, number>;
  /** occasion slug -> suitability score (0-100), from fragrance_occasions. */
  occasions: { slug: string; score: number }[];
  /** The user's own 0-10 rating for this bottle, or null if unrated. */
  personalRating: number | null;
  /** True if this is the user's declared signature scent. */
  isSignature: boolean;
}

export interface ScoringWeights {
  /** How well the fragrance's accords suit the current weather (temperature/condition). */
  weather: number;
  /** How well the fragrance suits the current meteorological season. */
  season: number;
  /** How well the fragrance suits any active occasion (calendar-detected holiday, or a user-requested one like "date night"). */
  occasion: number;
  /** The user's own rating for this bottle — a strong signal they simply like it. */
  personalRating: number;
  /** Multiplier applied to the freshness penalty (see scoreFragrance) before subtracting it from the positive score. */
  freshnessPenalty: number;
  /** Flat bonus point added when the fragrance is the user's declared signature scent. */
  signatureBias: number;
}

/**
 * Default weights. weather + season + occasion + personalRating are
 * fractional and sum to 1.0 — they blend into a single 0-100 "positive"
 * score. freshnessPenalty and signatureBias sit outside that sum: the
 * penalty subtracts up to (freshnessPenalty * 100) points, and the bias
 * adds a small flat bonus. Exported (not hardcoded into scoreFragrance) so
 * a product experiment can tune the balance — e.g. a "surprise me" mode
 * could zero out personalRating to favor variety.
 */
export const DEFAULT_WEIGHTS: ScoringWeights = {
  weather: 0.3,
  season: 0.2,
  occasion: 0.3,
  personalRating: 0.2,
  freshnessPenalty: 0.25,
  signatureBias: 4,
};

export interface ScoringContext {
  weather: WeatherSnapshot | null;
  currentSeason: Season;
  /** Active occasions with a 0-1 weight — either calendar-detected holidays, or a single user-requested occasion at weight 1. */
  activeOccasions: UpcomingOccasion[];
  /** fragranceId -> days since it was last worn, or null if never worn / no recent history. */
  daysSinceLastWorn: Record<string, number | null>;
  weights?: ScoringWeights;
}

export interface ScoreBreakdown {
  weather: number;
  season: number;
  occasion: number;
  personalRating: number;
  freshnessPenalty: number;
  signatureBias: number;
}

export interface ScoringResult {
  fragranceId: string;
  score: number;
  breakdown: ScoreBreakdown;
}

function clamp(value: number, min = 0, max = 100): number {
  return Math.max(min, Math.min(max, value));
}

/** Weighted mean of weather affinity across a fragrance's accords, weighted by each accord's intensity. Neutral (50) if the fragrance has no accord data. */
function computeWeatherFit(candidate: ScoringCandidate, weatherAffinity: Record<string, number> | null): number {
  if (!weatherAffinity || candidate.accords.length === 0) return 50;

  let weightedSum = 0;
  let totalIntensity = 0;
  for (const { slug, intensity } of candidate.accords) {
    const affinity = weatherAffinity[slug];
    if (affinity === undefined) continue;
    weightedSum += affinity * intensity;
    totalIntensity += intensity;
  }
  return totalIntensity > 0 ? weightedSum / totalIntensity : 50;
}

/** The fragrance's own season score for the current meteorological season, defaulting to neutral if that season has no data. */
function computeSeasonFit(candidate: ScoringCandidate, currentSeason: Season): number {
  const score = candidate.seasons[currentSeason];
  return score ?? 50;
}

/**
 * How well the fragrance suits whatever's currently "active" — a holiday
 * inside its lead window, or (when the user explicitly asked for a
 * recommendation) a single requested occasion at full weight. Takes the
 * best-weighted match across all active occasions, so a fragrance great
 * for "date_night" still scores well even if "festive" is also active but
 * this bottle isn't tagged for it. Falls back to the fragrance's "daily"
 * occasion score when nothing is active, so an ordinary day still produces
 * a meaningful (not arbitrary) baseline instead of a flat constant.
 */
function computeOccasionFit(candidate: ScoringCandidate, activeOccasions: UpcomingOccasion[]): number {
  if (activeOccasions.length === 0) {
    const daily = candidate.occasions.find((o) => o.slug === 'daily');
    return daily?.score ?? 50;
  }

  let best = 0;
  for (const active of activeOccasions) {
    const match = candidate.occasions.find((o) => o.slug === active.occasionSlug);
    if (!match) continue;
    best = Math.max(best, match.score * active.weight);
  }
  return best;
}

/** 0-100, scaled from the user's own 0-10 rating. Neutral (50) if unrated — an unrated bottle shouldn't be penalized relative to a middling one. */
function computePersonalRatingFit(candidate: ScoringCandidate): number {
  return candidate.personalRating === null ? 50 : candidate.personalRating * 10;
}

/**
 * Discourages repeating the exact same fragrance too many days in a row —
 * part of what makes the "daily" card feel alive rather than static. Peaks
 * at 100 for "worn today/yesterday" and decays linearly to 0 by 5+ days
 * out, so a favorite is fully eligible again well within a week.
 */
function computeFreshnessPenalty(daysSinceLastWorn: number | null): number {
  if (daysSinceLastWorn === null) return 0;
  const FRESHNESS_WINDOW_DAYS = 5;
  return clamp(100 * (1 - daysSinceLastWorn / FRESHNESS_WINDOW_DAYS));
}

/**
 * Scores one fragrance from the user's collection against the current
 * context (weather, season, active occasions, wear history). This is the
 * heart of "Your scent for today": rankFragrances() below just calls this
 * for every owned fragrance and sorts by score.
 */
export function scoreFragrance(candidate: ScoringCandidate, context: ScoringContext): ScoringResult {
  const weights = context.weights ?? DEFAULT_WEIGHTS;
  const weatherAffinity = context.weather ? getWeatherAccordAffinity(context.weather) : null;

  const breakdown: ScoreBreakdown = {
    weather: computeWeatherFit(candidate, weatherAffinity),
    season: computeSeasonFit(candidate, context.currentSeason),
    occasion: computeOccasionFit(candidate, context.activeOccasions),
    personalRating: computePersonalRatingFit(candidate),
    freshnessPenalty: computeFreshnessPenalty(context.daysSinceLastWorn[candidate.fragranceId] ?? null),
    signatureBias: candidate.isSignature ? weights.signatureBias : 0,
  };

  const positive =
    weights.weather * breakdown.weather +
    weights.season * breakdown.season +
    weights.occasion * breakdown.occasion +
    weights.personalRating * breakdown.personalRating;

  const score = clamp(positive - weights.freshnessPenalty * breakdown.freshnessPenalty + breakdown.signatureBias);

  return { fragranceId: candidate.fragranceId, score: Math.round(score * 100) / 100, breakdown };
}

/** Scores every candidate and returns them sorted best-first. */
export function rankFragrances(candidates: ScoringCandidate[], context: ScoringContext): ScoringResult[] {
  return candidates.map((c) => scoreFragrance(c, context)).sort((a, b) => b.score - a.score);
}

/**
 * Builds the human-readable explanation stored alongside the score
 * (daily_recommendations.reason) and shown on the "Your scent for today"
 * card — so the UI never has to re-derive "why" from raw numbers.
 */
export function buildRecommendationReason(
  candidateName: string,
  breakdown: ScoreBreakdown,
  weather: WeatherSnapshot | null,
  activeOccasions: UpcomingOccasion[],
): RecommendationReason {
  const weatherSummary = weather
    ? `${Math.round(weather.temp_c)}°C and ${weather.condition}${weather.city ? ` in ${weather.city}` : ''} — ${candidateName} tends to suit conditions like this.`
    : null;

  const topOccasion = activeOccasions[0];
  const occasionSummary = topOccasion
    ? topOccasion.daysUntil === 0
      ? `Today is ${topOccasion.holidayName} — a great match for the occasion.`
      : `${topOccasion.holidayName} is coming up in ${topOccasion.daysUntil} day${topOccasion.daysUntil === 1 ? '' : 's'}.`
    : null;

  const headline =
    breakdown.signatureBias > 0
      ? `${candidateName} — your signature scent`
      : weatherSummary
        ? `${candidateName} for today's weather`
        : `${candidateName} is a great pick today`;

  return {
    headline,
    weather_summary: weatherSummary,
    occasion_summary: occasionSummary,
    score_breakdown: {
      weather: breakdown.weather,
      season: breakdown.season,
      occasion: breakdown.occasion,
      personalRating: breakdown.personalRating,
      freshnessPenalty: breakdown.freshnessPenalty,
      signatureBias: breakdown.signatureBias,
    },
  };
}
