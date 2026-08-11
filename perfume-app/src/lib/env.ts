/**
 * Central place that reads and validates EXPO_PUBLIC_* env vars. Expo
 * inlines these at build time, so failing fast here (instead of letting a
 * `fetch` to "undefined" fail deep in some screen) makes misconfiguration
 * obvious immediately on app start.
 */

function required(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(
      `Missing environment variable ${name}. Copy .env.example to .env and fill in your Supabase project details.`,
    );
  }
  return value;
}

export const env = {
  supabaseUrl: required('EXPO_PUBLIC_SUPABASE_URL', process.env.EXPO_PUBLIC_SUPABASE_URL),
  supabaseAnonKey: required('EXPO_PUBLIC_SUPABASE_ANON_KEY', process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY),
  weatherProvider: (process.env.EXPO_PUBLIC_WEATHER_PROVIDER ?? 'open-meteo') as 'open-meteo' | 'openweathermap',
  openWeatherMapApiKey: process.env.EXPO_PUBLIC_OPENWEATHERMAP_API_KEY,
};
