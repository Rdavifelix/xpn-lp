import type { Concentration, Gender, Season } from '@/lib/supabase';
import type { PyramidNote } from '@/components/ui/NotePyramid';
import type { AccordDatum } from '@/components/ui/AccordChart';

export interface FragranceSummary {
  id: string;
  name: string;
  brandName: string;
  gender: Gender;
  concentration: Concentration;
  imageUrl: string | null;
  avgRating: number;
  ratingsCount: number;
  /** Highest-intensity accord — used to tint the summary card. */
  topAccord: { label: string; hexColor: string } | null;
}

export interface FragranceDetail extends FragranceSummary {
  releaseYear: number | null;
  description: string | null;
  longevity: number | null;
  sillage: number | null;
  wearsCount: number;
  notes: {
    top: PyramidNote[];
    middle: PyramidNote[];
    base: PyramidNote[];
  };
  accords: AccordDatum[];
  seasons: Record<Season, number>;
  occasions: { id: string; slug: string; label: string; icon: string | null; score: number }[];
}
