import { env } from '@/lib/env';
import type { WeatherSnapshot } from '@/lib/supabase';

/**
 * Weather provider abstraction. Open-Meteo needs no API key and is the
 * default; EXPO_PUBLIC_WEATHER_PROVIDER=openweathermap switches to
 * OpenWeatherMap (EXPO_PUBLIC_OPENWEATHERMAP_API_KEY required) without any
 * call-site changes — every caller just imports getCurrentWeather().
 */

// WMO weather codes (used by Open-Meteo) collapsed down to the small
// vocabulary WeatherChip/scoring understands. https://open-meteo.com/en/docs
function wmoCodeToCondition(code: number): string {
  if (code === 0) return 'clear';
  if ([1, 2, 3].includes(code)) return 'clouds';
  if ([45, 48].includes(code)) return 'fog';
  if ([51, 53, 55, 56, 57].includes(code)) return 'drizzle';
  if ([61, 63, 65, 66, 67, 80, 81, 82].includes(code)) return 'rain';
  if ([71, 73, 75, 77, 85, 86].includes(code)) return 'snow';
  if ([95, 96, 99].includes(code)) return 'thunderstorm';
  return 'clouds';
}

async function fetchFromOpenMeteo(latitude: number, longitude: number): Promise<WeatherSnapshot> {
  const url = new URL('https://api.open-meteo.com/v1/forecast');
  url.searchParams.set('latitude', String(latitude));
  url.searchParams.set('longitude', String(longitude));
  url.searchParams.set('current', 'temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code');
  url.searchParams.set('timezone', 'auto');

  const response = await fetch(url.toString());
  if (!response.ok) throw new Error(`Open-Meteo request failed with status ${response.status}`);
  const json = await response.json();
  const current = json.current;

  return {
    temp_c: current.temperature_2m,
    feels_like_c: current.apparent_temperature,
    condition: wmoCodeToCondition(current.weather_code),
    humidity: current.relative_humidity_2m,
    wind_kph: current.wind_speed_10m,
    city: null,
  };
}

// OpenWeatherMap's condition "main" field (Clear/Clouds/Rain/...) maps
// almost 1:1 onto our lowercase vocabulary already — just lowercase it.
async function fetchFromOpenWeatherMap(latitude: number, longitude: number): Promise<WeatherSnapshot> {
  if (!env.openWeatherMapApiKey) {
    throw new Error('EXPO_PUBLIC_OPENWEATHERMAP_API_KEY is not set but EXPO_PUBLIC_WEATHER_PROVIDER=openweathermap.');
  }
  const url = new URL('https://api.openweathermap.org/data/2.5/weather');
  url.searchParams.set('lat', String(latitude));
  url.searchParams.set('lon', String(longitude));
  url.searchParams.set('units', 'metric');
  url.searchParams.set('appid', env.openWeatherMapApiKey);

  const response = await fetch(url.toString());
  if (!response.ok) throw new Error(`OpenWeatherMap request failed with status ${response.status}`);
  const json = await response.json();

  return {
    temp_c: json.main.temp,
    feels_like_c: json.main.feels_like,
    condition: String(json.weather?.[0]?.main ?? 'clouds').toLowerCase(),
    humidity: json.main.humidity,
    wind_kph: json.wind.speed * 3.6,
    city: json.name ?? null,
  };
}

export async function getCurrentWeather(latitude: number, longitude: number): Promise<WeatherSnapshot> {
  return env.weatherProvider === 'openweathermap' ? fetchFromOpenWeatherMap(latitude, longitude) : fetchFromOpenMeteo(latitude, longitude);
}
