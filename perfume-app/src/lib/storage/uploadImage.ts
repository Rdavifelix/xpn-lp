import * as FileSystem from 'expo-file-system/legacy';
import { decode } from 'base64-arraybuffer';

import { supabase } from '@/lib/supabase';

export type StorageBucket = 'avatars' | 'wear-photos' | 'fragrance-images';

/**
 * Uploads a local image URI (from expo-image-picker) to a Supabase Storage
 * bucket and returns its public URL. Buckets are created + made public via
 * the storage migration (supabase/migrations/0009_storage.sql).
 */
export async function uploadImage(bucket: StorageBucket, localUri: string, pathPrefix: string): Promise<string> {
  const base64 = await FileSystem.readAsStringAsync(localUri, { encoding: 'base64' });
  const extension = localUri.split('.').pop()?.toLowerCase() ?? 'jpg';
  const path = `${pathPrefix}/${Date.now()}.${extension}`;

  const { error } = await supabase.storage.from(bucket).upload(path, decode(base64), {
    contentType: `image/${extension === 'jpg' ? 'jpeg' : extension}`,
    upsert: false,
  });

  if (error) throw error;

  const { data } = supabase.storage.from(bucket).getPublicUrl(path);
  return data.publicUrl;
}
