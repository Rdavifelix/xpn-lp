/**
 * Hand-written counterpart to `supabase gen types typescript`.
 *
 * In a real project, run:
 *   npx supabase gen types typescript --project-id <ref> > src/lib/supabase/database.types.ts
 * (or use the Supabase MCP `generate_typescript_types` tool) once the
 * migrations in supabase/migrations have been applied, to replace this file
 * with a guaranteed-accurate one. This version is kept hand-in-sync with
 * those migrations so the app is fully typed from the start.
 */

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Gender = 'masculine' | 'feminine' | 'unisex';
export type Concentration = 'edc' | 'edt' | 'edp' | 'parfum' | 'extrait' | 'oil';
export type PyramidLevel = 'top' | 'middle' | 'base';
export type Season = 'spring' | 'summer' | 'fall' | 'winter';
export type CollectionStatus = 'owned' | 'wishlist' | 'tried';
export type WearVisibility = 'public' | 'followers';

export interface WeatherSnapshot {
  temp_c: number;
  feels_like_c: number;
  condition: string;
  humidity: number;
  wind_kph: number;
  city: string | null;
}

export interface RecommendationReason {
  headline: string;
  weather_summary: string | null;
  occasion_summary: string | null;
  score_breakdown: {
    weather: number;
    season: number;
    occasion: number;
    personalRating: number;
    freshnessPenalty: number;
    signatureBias: number;
  };
}

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          username: string;
          display_name: string | null;
          avatar_url: string | null;
          bio: string | null;
          city: string | null;
          country: string | null;
          latitude: number | null;
          longitude: number | null;
          signature_fragrance_id: string | null;
          followers_count: number;
          following_count: number;
          wears_count: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          username: string;
          display_name?: string | null;
          avatar_url?: string | null;
          bio?: string | null;
          city?: string | null;
          country?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          signature_fragrance_id?: string | null;
        };
        Update: Partial<Database['public']['Tables']['profiles']['Insert']>;
      };
      brands: {
        Row: {
          id: string;
          name: string;
          country: string | null;
          founded_year: number | null;
          logo_url: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          country?: string | null;
          founded_year?: number | null;
          logo_url?: string | null;
        };
        Update: Partial<Database['public']['Tables']['brands']['Insert']>;
      };
      notes: {
        Row: {
          id: string;
          name: string;
          note_family: string;
          description: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          note_family: string;
          description?: string | null;
        };
        Update: Partial<Database['public']['Tables']['notes']['Insert']>;
      };
      accords: {
        Row: {
          id: string;
          slug: string;
          label: string;
          hex_color: string;
        };
        Insert: {
          id?: string;
          slug: string;
          label: string;
          hex_color: string;
        };
        Update: Partial<Database['public']['Tables']['accords']['Insert']>;
      };
      occasions: {
        Row: {
          id: string;
          slug: string;
          label: string;
          icon: string | null;
        };
        Insert: {
          id?: string;
          slug: string;
          label: string;
          icon?: string | null;
        };
        Update: Partial<Database['public']['Tables']['occasions']['Insert']>;
      };
      fragrances: {
        Row: {
          id: string;
          brand_id: string;
          name: string;
          release_year: number | null;
          gender: Gender;
          concentration: Concentration;
          description: string | null;
          image_url: string | null;
          longevity: number | null;
          sillage: number | null;
          avg_rating: number;
          ratings_count: number;
          wears_count: number;
          created_at: string;
        };
        Insert: {
          id?: string;
          brand_id: string;
          name: string;
          release_year?: number | null;
          gender: Gender;
          concentration: Concentration;
          description?: string | null;
          image_url?: string | null;
          longevity?: number | null;
          sillage?: number | null;
        };
        Update: Partial<Database['public']['Tables']['fragrances']['Insert']>;
      };
      fragrance_notes: {
        Row: {
          fragrance_id: string;
          note_id: string;
          pyramid_level: PyramidLevel;
          position: number;
        };
        Insert: {
          fragrance_id: string;
          note_id: string;
          pyramid_level: PyramidLevel;
          position?: number;
        };
        Update: Partial<Database['public']['Tables']['fragrance_notes']['Insert']>;
      };
      fragrance_accords: {
        Row: {
          fragrance_id: string;
          accord_id: string;
          intensity: number;
        };
        Insert: {
          fragrance_id: string;
          accord_id: string;
          intensity: number;
        };
        Update: Partial<Database['public']['Tables']['fragrance_accords']['Insert']>;
      };
      fragrance_seasons: {
        Row: {
          fragrance_id: string;
          season: Season;
          score: number;
        };
        Insert: {
          fragrance_id: string;
          season: Season;
          score: number;
        };
        Update: Partial<Database['public']['Tables']['fragrance_seasons']['Insert']>;
      };
      fragrance_occasions: {
        Row: {
          fragrance_id: string;
          occasion_id: string;
          score: number;
        };
        Insert: {
          fragrance_id: string;
          occasion_id: string;
          score: number;
        };
        Update: Partial<Database['public']['Tables']['fragrance_occasions']['Insert']>;
      };
      collection_items: {
        Row: {
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
        };
        Insert: {
          id?: string;
          user_id: string;
          fragrance_id: string;
          status?: CollectionStatus;
          rating?: number | null;
          personal_notes?: string | null;
          bottle_size_ml?: number | null;
          remaining_pct?: number;
          purchase_date?: string | null;
          purchase_price?: number | null;
        };
        Update: Partial<Database['public']['Tables']['collection_items']['Insert']>;
      };
      follows: {
        Row: {
          follower_id: string;
          following_id: string;
          created_at: string;
        };
        Insert: {
          follower_id: string;
          following_id: string;
        };
        Update: Partial<Database['public']['Tables']['follows']['Insert']>;
      };
      wears: {
        Row: {
          id: string;
          user_id: string;
          fragrance_id: string;
          worn_at: string;
          photo_url: string | null;
          caption: string | null;
          occasion_id: string | null;
          mood: string | null;
          weather: WeatherSnapshot | null;
          likes_count: number;
          comments_count: number;
          visibility: WearVisibility;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          fragrance_id: string;
          worn_at?: string;
          photo_url?: string | null;
          caption?: string | null;
          occasion_id?: string | null;
          mood?: string | null;
          weather?: WeatherSnapshot | null;
          visibility?: WearVisibility;
        };
        Update: Partial<Database['public']['Tables']['wears']['Insert']>;
      };
      likes: {
        Row: {
          user_id: string;
          wear_id: string;
          created_at: string;
        };
        Insert: {
          user_id: string;
          wear_id: string;
        };
        Update: Partial<Database['public']['Tables']['likes']['Insert']>;
      };
      comments: {
        Row: {
          id: string;
          wear_id: string;
          user_id: string;
          body: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          wear_id: string;
          user_id: string;
          body: string;
        };
        Update: Partial<Database['public']['Tables']['comments']['Insert']>;
      };
      occasion_calendar: {
        Row: {
          id: string;
          slug: string;
          name: string;
          month: number | null;
          day: number | null;
          is_movable: boolean;
          country_code: string | null;
          occasion_id: string;
          lead_days: number;
        };
        Insert: {
          id?: string;
          slug: string;
          name: string;
          month?: number | null;
          day?: number | null;
          is_movable?: boolean;
          country_code?: string | null;
          occasion_id: string;
          lead_days?: number;
        };
        Update: Partial<Database['public']['Tables']['occasion_calendar']['Insert']>;
      };
      daily_recommendations: {
        Row: {
          id: string;
          user_id: string;
          for_date: string;
          fragrance_id: string;
          score: number;
          reason: RecommendationReason;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          for_date: string;
          fragrance_id: string;
          score: number;
          reason: RecommendationReason;
        };
        Update: Partial<Database['public']['Tables']['daily_recommendations']['Insert']>;
      };
    };
    Views: Record<string, never>;
    Functions: {
      toggle_like: {
        Args: { p_wear_id: string };
        Returns: boolean;
      };
      search_fragrances: {
        Args: { p_query: string; p_limit?: number };
        Returns: Database['public']['Tables']['fragrances']['Row'][];
      };
      friends_who_own: {
        Args: { p_fragrance_id: string };
        Returns: Database['public']['Tables']['profiles']['Row'][];
      };
      get_feed: {
        Args: { p_limit?: number; p_before?: string | null };
        Returns: FeedRow[];
      };
    };
  };
}

/** Shape returned by the get_feed() RPC — a wear joined with its author + fragrance. */
export interface FeedRow {
  id: string;
  user_id: string;
  fragrance_id: string;
  worn_at: string;
  photo_url: string | null;
  caption: string | null;
  occasion_id: string | null;
  mood: string | null;
  weather: WeatherSnapshot | null;
  likes_count: number;
  comments_count: number;
  author_username: string;
  author_display_name: string | null;
  author_avatar_url: string | null;
  fragrance_name: string;
  fragrance_brand_name: string;
  fragrance_image_url: string | null;
  liked_by_me: boolean;
}
