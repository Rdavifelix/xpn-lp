import { supabase } from '@/lib/supabase';
import type { CollectionStatus } from '@/lib/supabase';
import { getFragrancesByIds } from '@/features/fragrances';

import type { CollectionEntry, CollectionItem } from '../types';

interface CollectionRow {
  id: string;
  user_id: string;
  fragrance_id: string;
  status: CollectionStatus;
  rating: number | null;
  personal_notes: string | null;
  bottle_size_ml: number | null;
  remaining_pct: number;
  purchase_date: string | null;
  purchase_price: number | null;
  created_at: string;
  updated_at: string;
}

function toItem(row: CollectionRow): CollectionItem {
  return {
    id: row.id,
    userId: row.user_id,
    fragranceId: row.fragrance_id,
    status: row.status,
    rating: row.rating,
    personalNotes: row.personal_notes,
    bottleSizeMl: row.bottle_size_ml,
    remainingPct: row.remaining_pct,
    purchaseDate: row.purchase_date,
    purchasePrice: row.purchase_price,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/** Full collection (optionally filtered by status), each row joined with its fragrance summary for the grid view. */
export async function getCollection(userId: string, status?: CollectionStatus): Promise<CollectionEntry[]> {
  let q = supabase.from('collection_items').select('*').eq('user_id', userId).order('created_at', { ascending: false });
  if (status) q = q.eq('status', status);
  const { data, error } = await q;
  if (error) throw error;

  const items = (data as CollectionRow[]).map(toItem);
  const fragrances = await getFragrancesByIds(items.map((i) => i.fragranceId));
  const byId = new Map(fragrances.map((f) => [f.id, f]));

  return items.map((item) => ({ ...item, fragrance: byId.get(item.fragranceId)! })).filter((entry) => Boolean(entry.fragrance));
}

/** The current user's collection_item for one fragrance, if any — powers the "add/edit" UI on the detail page. */
export async function getCollectionItemForFragrance(userId: string, fragranceId: string): Promise<CollectionItem | null> {
  const { data, error } = await supabase
    .from('collection_items')
    .select('*')
    .eq('user_id', userId)
    .eq('fragrance_id', fragranceId)
    .maybeSingle();
  if (error) throw error;
  return data ? toItem(data as CollectionRow) : null;
}

export interface UpsertCollectionInput {
  status?: CollectionStatus;
  rating?: number | null;
  personalNotes?: string | null;
  bottleSizeMl?: number | null;
  remainingPct?: number;
  purchaseDate?: string | null;
  purchasePrice?: number | null;
}

export async function addToCollection(userId: string, fragranceId: string, input: UpsertCollectionInput = {}): Promise<CollectionItem> {
  const { data, error } = await supabase
    .from('collection_items')
    .insert({
      user_id: userId,
      fragrance_id: fragranceId,
      status: input.status ?? 'owned',
      rating: input.rating,
      personal_notes: input.personalNotes,
      bottle_size_ml: input.bottleSizeMl,
      remaining_pct: input.remainingPct,
      purchase_date: input.purchaseDate,
      purchase_price: input.purchasePrice,
    })
    .select('*')
    .single();
  if (error) throw error;
  return toItem(data as CollectionRow);
}

export async function updateCollectionItem(itemId: string, input: UpsertCollectionInput): Promise<CollectionItem> {
  const { data, error } = await supabase
    .from('collection_items')
    .update({
      status: input.status,
      rating: input.rating,
      personal_notes: input.personalNotes,
      bottle_size_ml: input.bottleSizeMl,
      remaining_pct: input.remainingPct,
      purchase_date: input.purchaseDate,
      purchase_price: input.purchasePrice,
    })
    .eq('id', itemId)
    .select('*')
    .single();
  if (error) throw error;
  return toItem(data as CollectionRow);
}

export async function removeFromCollection(itemId: string): Promise<void> {
  const { error } = await supabase.from('collection_items').delete().eq('id', itemId);
  if (error) throw error;
}
