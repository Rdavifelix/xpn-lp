import type { Season } from '@/lib/supabase';

/**
 * Holiday/season detection. Pure date math — no network calls — so it's
 * cheap to unit test and to re-run every time the daily recommendation is
 * computed.
 */

export interface OccasionCalendarEntry {
  slug: string;
  name: string;
  month: number | null;
  day: number | null;
  isMovable: boolean;
  occasionSlug: string;
  leadDays: number;
}

export interface UpcomingOccasion {
  /** occasions.slug — what fragrance_occasions rows are scored against. */
  occasionSlug: string;
  holidayName: string;
  daysUntil: number;
  /** 1.0 on the day itself, decaying linearly to ~0 at the edge of the lead window. */
  weight: number;
}

// --- Movable holiday date math ---------------------------------------------

/**
 * Easter Sunday (Western/Gregorian) via the classic "anonymous Gregorian
 * algorithm" (Meeus/Jones/Butcher). Every other US movable holiday we
 * support is a simple "Nth weekday of a month" rule; Easter is the one
 * that needs real astronomical-calendar math, so it gets its own function.
 */
function computeEasterDate(year: number): { month: number; day: number } {
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return { month, day };
}

/**
 * The date of the Nth occurrence of a weekday in a given month/year, e.g.
 * "2nd Sunday of May" (Mother's Day) or "4th Thursday of November"
 * (Thanksgiving). `weekday` is 0=Sunday..6=Saturday, matching Date#getDay().
 */
function computeNthWeekdayOfMonth(year: number, month: number, weekday: number, n: number): { month: number; day: number } {
  const first = new Date(Date.UTC(year, month - 1, 1));
  const firstWeekday = first.getUTCDay();
  const offset = (weekday - firstWeekday + 7) % 7;
  const day = 1 + offset + (n - 1) * 7;
  return { month, day };
}

const MOVABLE_HOLIDAY_RESOLVERS: Record<string, (year: number) => { month: number; day: number }> = {
  easter: computeEasterDate,
  mothers_day: (year) => computeNthWeekdayOfMonth(year, 5, 0, 2), // 2nd Sunday of May (US)
  fathers_day: (year) => computeNthWeekdayOfMonth(year, 6, 0, 3), // 3rd Sunday of June (US)
  thanksgiving: (year) => computeNthWeekdayOfMonth(year, 11, 4, 4), // 4th Thursday of November (US)
};

function resolveEntryDateForYear(entry: OccasionCalendarEntry, year: number): { month: number; day: number } | null {
  if (!entry.isMovable) {
    if (entry.month == null || entry.day == null) return null;
    return { month: entry.month, day: entry.day };
  }
  const resolver = MOVABLE_HOLIDAY_RESOLVERS[entry.slug];
  return resolver ? resolver(year) : null;
}

function daysBetween(from: Date, to: Date): number {
  const msPerDay = 24 * 60 * 60 * 1000;
  const fromUtc = Date.UTC(from.getFullYear(), from.getMonth(), from.getDate());
  const toUtc = Date.UTC(to.getFullYear(), to.getMonth(), to.getDate());
  return Math.round((toUtc - fromUtc) / msPerDay);
}

/**
 * Which calendar occasions are "active" today — i.e. today falls within
 * `leadDays` before the holiday (or on it). Checks both this year's and
 * next year's occurrence so a lead window spanning a year boundary (e.g.
 * New Year's Eve checked from late December) still resolves correctly.
 */
export function getUpcomingOccasions(calendar: OccasionCalendarEntry[], today: Date = new Date()): UpcomingOccasion[] {
  const results: UpcomingOccasion[] = [];

  for (const entry of calendar) {
    for (const year of [today.getFullYear(), today.getFullYear() + 1]) {
      const resolved = resolveEntryDateForYear(entry, year);
      if (!resolved) continue;

      const holidayDate = new Date(year, resolved.month - 1, resolved.day);
      const daysUntil = daysBetween(today, holidayDate);

      if (daysUntil >= 0 && daysUntil <= entry.leadDays) {
        const weight = entry.leadDays === 0 ? 1 : 1 - daysUntil / (entry.leadDays + 1);
        results.push({ occasionSlug: entry.occasionSlug, holidayName: entry.name, daysUntil, weight });
        break; // found the relevant occurrence for this entry — don't also match next year's
      }
    }
  }

  return results.sort((a, b) => b.weight - a.weight);
}

// --- Meteorological season --------------------------------------------------

const NORTHERN_HEMISPHERE_SEASONS: Season[] = [
  'winter', 'winter', 'spring', 'spring', 'spring', 'summer', // Jan Feb Mar Apr May Jun
  'summer', 'summer', 'fall', 'fall', 'fall', 'winter', // Jul Aug Sep Oct Nov Dec
];

const SOUTHERN_HEMISPHERE_OFFSET: Record<Season, Season> = {
  winter: 'summer',
  summer: 'winter',
  spring: 'fall',
  fall: 'spring',
};

/**
 * Meteorological (not astronomical) season for a date — Dec/Jan/Feb =
 * winter in the Northern hemisphere, flipped 6 months for the Southern
 * hemisphere. `latitude` comes from the user's profile or device location;
 * null defaults to Northern hemisphere.
 */
export function getMeteorologicalSeason(date: Date, latitude: number | null): Season {
  const base = NORTHERN_HEMISPHERE_SEASONS[date.getMonth()];
  return latitude !== null && latitude < 0 ? SOUTHERN_HEMISPHERE_OFFSET[base] : base;
}
