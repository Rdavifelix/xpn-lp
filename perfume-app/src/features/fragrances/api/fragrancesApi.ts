import { supabase } from '@/lib/supabase';
import type { Season } from '@/lib/supabase';
import type { Profile } from '@/features/profiles';

import type { FragranceDetail, FragranceSummary } from '../types';

const SUMMARY_SELECT = `
  id, name, gender, concentration, image_url, avg_rating, ratings_count,
  brand:brands(name),
  fragrance_accords(intensity, accord:accords(label, hex_color))
`;

const DETAIL_SELECT = `
  *,
  brand:brands(name),
  fragrance_notes(pyramid_level, position, note:notes(id, name, note_family)),
  fragrance_accords(intensity, accord:accords(id, slug, label, hex_color)),
  fragrance_seasons(season, score),
  fragrance_occasions(score, occasion:occasions(id, slug, label, icon))
`;

// The nested-select shapes below are hand-typed rather than inferred from
// the generic .select() string (Supabase's string-based embed inference is
// version-sensitive and doesn't handle deeply nested aliases well) — these
// match exactly what SUMMARY_SELECT / DETAIL_SELECT request.
interface SummaryRow {
  id: string;
  name: string;
  gender: FragranceSummary['gender'];
  concentration: FragranceSummary['concentration'];
  image_url: string | null;
  avg_rating: number;
  ratings_count: number;
  brand: { name: string } | null;
  fragrance_accords: { intensity: number; accord: { label: string; hex_color: string } | null }[];
}

interface DetailRow extends SummaryRow {
  release_year: number | null;
  description: string | null;
  longevity: number | null;
  sillage: number | null;
  wears_count: number;
  fragrance_notes: {
    pyramid_level: 'top' | 'middle' | 'base';
    position: number;
    note: { id: string; name: string; note_family: string } | null;
  }[];
  fragrance_seasons: { season: Season; score: number }[];
  fragrance_occasions: { score: number; occasion: { id: string; slug: string; label: string; icon: string | null } | null }[];
}

function toSummary(row: SummaryRow): FragranceSummary {
  const sortedAccords = [...row.fragrance_accords].sort((a, b) => b.intensity - a.intensity);
  const top = sortedAccords[0]?.accord;

  return {
    id: row.id,
    name: row.name,
    brandName: row.brand?.name ?? 'Unknown House',
    gender: row.gender,
    concentration: row.concentration,
    imageUrl: row.image_url,
    avgRating: row.avg_rating,
    ratingsCount: row.ratings_count,
    topAccord: top ? { label: top.label, hexColor: top.hex_color } : null,
  };
}

function toDetail(row: DetailRow): FragranceDetail {
  const notesByTier = { top: [] as FragranceDetail['notes']['top'], middle: [] as FragranceDetail['notes']['middle'], base: [] as FragranceDetail['notes']['base'] };
  for (const fn of [...row.fragrance_notes].sort((a, b) => a.position - b.position)) {
    if (!fn.note) continue;
    notesByTier[fn.pyramid_level].push({ id: fn.note.id, name: fn.note.name, noteFamily: fn.note.note_family });
  }

  const seasons: Record<Season, number> = { spring: 0, summer: 0, fall: 0, winter: 0 };
  for (const s of row.fragrance_seasons) seasons[s.season] = s.score;

  return {
    ...toSummary(row),
    releaseYear: row.release_year,
    description: row.description,
    longevity: row.longevity,
    sillage: row.sillage,
    wearsCount: row.wears_count,
    notes: notesByTier,
    accords: row.fragrance_accords
      .filter((fa) => fa.accord)
      .map((fa) => ({ id: fa.accord!.hex_color + fa.accord!.label, label: fa.accord!.label, intensity: fa.intensity, color: fa.accord!.hex_color })),
    seasons,
    occasions: row.fragrance_occasions
      .filter((fo) => fo.occasion)
      .map((fo) => ({ id: fo.occasion!.id, slug: fo.occasion!.slug, label: fo.occasion!.label, icon: fo.occasion!.icon, score: fo.score })),
  };
}

export async function getFragrance(id: string): Promise<FragranceDetail> {
  const { data, error } = await supabase.from('fragrances').select(DETAIL_SELECT).eq('id', id).single();
  if (error) throw error;
  return toDetail(data as unknown as DetailRow);
}

export async function getFragrancesByIds(ids: string[]): Promise<FragranceSummary[]> {
  if (ids.length === 0) return [];
  const { data, error } = await supabase.from('fragrances').select(SUMMARY_SELECT).in('id', ids);
  if (error) throw error;
  return (data as unknown as SummaryRow[]).map(toSummary);
}

export interface ListFragrancesFilters {
  query?: string;
  gender?: FragranceSummary['gender'];
  noteId?: string;
  accordSlug?: string;
  occasionSlug?: string;
  brandId?: string;
  limit?: number;
}

/**
 * Browse/search entry point for Discovery. Full-text/fuzzy queries go
 * through the search_fragrances() RPC; note/accord/occasion filters use
 * direct joins since those need an exact relational match, not fuzzy text.
 */
export async function listFragrances(filters: ListFragrancesFilters = {}): Promise<FragranceSummary[]> {
  const { query, gender, noteId, accordSlug, occasionSlug, brandId, limit = 40 } = filters;

  if (query && query.trim().length > 0) {
    const { data, error } = await supabase.rpc('search_fragrances', { p_query: query.trim(), p_limit: limit });
    if (error) throw error;
    const ids = (data ?? []).map((f) => f.id);
    const summaries = await getFragrancesByIds(ids);
    // search_fragrances already ranks by relevance — preserve that order.
    const byId = new Map(summaries.map((s) => [s.id, s]));
    return ids.map((id) => byId.get(id)).filter((s): s is FragranceSummary => Boolean(s));
  }

  if (noteId) {
    const { data, error } = await supabase.from('fragrance_notes').select('fragrance_id').eq('note_id', noteId);
    if (error) throw error;
    return getFragrancesByIds([...new Set((data ?? []).map((r) => r.fragrance_id))]);
  }

  if (accordSlug) {
    const { data, error } = await supabase
      .from('fragrance_accords')
      .select('fragrance_id, accord:accords!inner(slug)')
      .eq('accord.slug', accordSlug);
    if (error) throw error;
    return getFragrancesByIds([...new Set((data ?? []).map((r) => r.fragrance_id))]);
  }

  if (occasionSlug) {
    const { data, error } = await supabase
      .from('fragrance_occasions')
      .select('fragrance_id, occasion:occasions!inner(slug)')
      .eq('occasion.slug', occasionSlug)
      .gte('score', 50);
    if (error) throw error;
    return getFragrancesByIds([...new Set((data ?? []).map((r) => r.fragrance_id))]);
  }

  let q = supabase.from('fragrances').select(SUMMARY_SELECT).order('wears_count', { ascending: false }).limit(limit);
  if (gender) q = q.eq('gender', gender);
  if (brandId) q = q.eq('brand_id', brandId);
  const { data, error } = await q;
  if (error) throw error;
  return (data as unknown as SummaryRow[]).map(toSummary);
}

export async function getFriendsWhoOwn(fragranceId: string): Promise<Profile[]> {
  const { data, error } = await supabase.rpc('friends_who_own', { p_fragrance_id: fragranceId });
  if (error) throw error;
  return data ?? [];
}

export interface Occasion {
  id: string;
  slug: string;
  label: string;
  icon: string | null;
}

/** Reference data (occasions.slug/label/icon) — used by Discover's filter chips and Compose's occasion picker. */
export async function getOccasions(): Promise<Occasion[]> {
  const { data, error } = await supabase.from('occasions').select('id, slug, label, icon').order('label');
  if (error) throw error;
  return data ?? [];
}
