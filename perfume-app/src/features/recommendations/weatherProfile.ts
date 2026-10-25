import type { WeatherSnapshot } from '@/lib/supabase';

/**
 * Maps live weather onto a 0-100 "affinity" score per accord family — how
 * well that accord tends to perform/read in the current conditions.
 * Classic fragrance-community wisdom: light citrus/aquatic/green scents
 * feel fresh and project well in heat, while heavy amber/gourmand/woody/
 * resin scents "bloom" and feel cozy in cold weather without becoming
 * overpowering. This isn't perfumery science — it's a product heuristic —
 * but it's a real, commonly-cited one.
 *
 * Each accord has a `cold` anchor (affinity at ~0°C) and a `hot` anchor
 * (affinity at ~32°C); getWeatherAccordAffinity() linearly interpolates
 * between them by actual temperature, so the score is a smooth curve
 * rather than a handful of discrete buckets.
 */
const ACCORD_TEMPERATURE_ANCHORS: Record<string, { cold: number; hot: number }> = {
  citrus: { cold: 35, hot: 95 },
  floral: { cold: 55, hot: 70 },
  woody: { cold: 85, hot: 45 },
  oriental: { cold: 90, hot: 25 },
  fresh: { cold: 45, hot: 90 },
  gourmand: { cold: 80, hot: 30 },
  spicy: { cold: 70, hot: 45 },
  green: { cold: 50, hot: 75 },
  aquatic: { cold: 30, hot: 95 },
  musk: { cold: 65, hot: 55 },
  leather: { cold: 85, hot: 30 },
  resin: { cold: 85, hot: 25 },
  powdery: { cold: 60, hot: 55 },
  amber: { cold: 90, hot: 25 },
  fruity: { cold: 45, hot: 75 },
  aromatic: { cold: 60, hot: 70 },
  chypre: { cold: 70, hot: 55 },
  earthy: { cold: 75, hot: 45 },
  vanilla: { cold: 85, hot: 35 },
  smoky: { cold: 85, hot: 25 },
  tobacco: { cold: 85, hot: 25 },
  boozy: { cold: 80, hot: 30 },
  white_floral: { cold: 50, hot: 70 },
  sweet: { cold: 75, hot: 40 },
};

const COLD_ANCHOR_C = 0;
const HOT_ANCHOR_C = 32;

/** Secondary condition-based nudges layered on top of the temperature curve — kept small (±8) so temperature stays the dominant signal. */
const CONDITION_MODIFIERS: Record<string, Partial<Record<string, number>>> = {
  rain: { aquatic: 8, fresh: 6, green: 4, powdery: -6 },
  drizzle: { aquatic: 6, fresh: 4, powdery: -4 },
  thunderstorm: { woody: 6, smoky: 6, aquatic: 4 },
  fog: { musk: 6, powdery: 6, citrus: -4 },
  snow: { vanilla: 8, amber: 6, gourmand: 6, citrus: -8 },
};

/**
 * Returns a 0-100 affinity score for every accord family given the current
 * weather. Consumed by scoring.ts's weatherFit term, which takes a
 * weighted average of a candidate fragrance's own accords against this map.
 */
export function getWeatherAccordAffinity(weather: WeatherSnapshot): Record<string, number> {
  const clampedTemp = Math.max(COLD_ANCHOR_C, Math.min(HOT_ANCHOR_C, weather.temp_c));
  const heatBlend = (clampedTemp - COLD_ANCHOR_C) / (HOT_ANCHOR_C - COLD_ANCHOR_C); // 0 = cold anchor, 1 = hot anchor

  const modifiers = CONDITION_MODIFIERS[weather.condition.toLowerCase()] ?? {};

  const affinity: Record<string, number> = {};
  for (const [slug, anchors] of Object.entries(ACCORD_TEMPERATURE_ANCHORS)) {
    const interpolated = anchors.cold * (1 - heatBlend) + anchors.hot * heatBlend;
    const nudged = interpolated + (modifiers[slug] ?? 0);
    affinity[slug] = Math.max(0, Math.min(100, nudged));
  }
  return affinity;
}
