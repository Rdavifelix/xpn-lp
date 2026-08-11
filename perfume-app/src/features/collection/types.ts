import type { CollectionStatus } from '@/lib/supabase';
import type { FragranceSummary } from '@/features/fragrances';

export interface CollectionItem {
  id: string;
  userId: string;
  fragranceId: string;
  status: CollectionStatus;
  rating: number | null;
  personalNotes: string | null;
  bottleSizeMl: number | null;
  remainingPct: number;
  purchaseDate: string | null;
  purchasePrice: number | null;
  createdAt: string;
  updatedAt: string;
}

export interface CollectionEntry extends CollectionItem {
  fragrance: FragranceSummary;
}
