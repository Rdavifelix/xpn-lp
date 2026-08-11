import type { WeatherSnapshot, WearVisibility } from '@/lib/supabase';

export interface FeedAuthor {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
}

export interface FeedPost {
  id: string;
  fragranceId: string;
  wornAt: string;
  photoUrl: string | null;
  caption: string | null;
  occasionId: string | null;
  mood: string | null;
  weather: WeatherSnapshot | null;
  likesCount: number;
  commentsCount: number;
  likedByMe: boolean;
  author: FeedAuthor;
  fragrance: { name: string; brandName: string; imageUrl: string | null };
}

export interface Comment {
  id: string;
  wearId: string;
  body: string;
  createdAt: string;
  author: FeedAuthor;
}

export interface CreateWearInput {
  fragranceId: string;
  caption?: string;
  photoUrl?: string;
  occasionId?: string;
  mood?: string;
  weather?: WeatherSnapshot;
  visibility?: WearVisibility;
}
