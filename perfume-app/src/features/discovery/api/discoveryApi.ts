import { supabase } from '@/lib/supabase';

export interface AccordOption {
  id: string;
  slug: string;
  label: string;
  hexColor: string;
}

export interface NoteOption {
  id: string;
  name: string;
  noteFamily: string;
}

export interface BrandOption {
  id: string;
  name: string;
}

/** Reference data for Discover's filter chip rows. All three are small, rarely-changing catalogs — cached aggressively by the hooks below. */
export async function getAccordOptions(): Promise<AccordOption[]> {
  const { data, error } = await supabase.from('accords').select('id, slug, label, hex_color').order('label');
  if (error) throw error;
  return (data ?? []).map((a) => ({ id: a.id, slug: a.slug, label: a.label, hexColor: a.hex_color }));
}

export async function getNoteOptions(): Promise<NoteOption[]> {
  const { data, error } = await supabase.from('notes').select('id, name, note_family').order('name');
  if (error) throw error;
  return (data ?? []).map((n) => ({ id: n.id, name: n.name, noteFamily: n.note_family }));
}

export async function getBrandOptions(): Promise<BrandOption[]> {
  const { data, error } = await supabase.from('brands').select('id, name').order('name');
  if (error) throw error;
  return data ?? [];
}
