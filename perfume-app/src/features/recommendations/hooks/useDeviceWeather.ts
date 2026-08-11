import { useCallback, useState } from 'react';
import * as Location from 'expo-location';

import type { WeatherSnapshot } from '@/lib/supabase';

import { getCurrentWeather } from '../api/weatherApi';

export interface DeviceWeatherState {
  weather: WeatherSnapshot | null;
  loading: boolean;
  error: string | null;
}

/**
 * Requests location permission, reads the device's current coordinates,
 * fetches live weather for them, and reverse-geocodes a city name for
 * display — used by Compose (weather snapshot on a wear post) and the
 * home screen's daily recommendation card.
 */
export function useDeviceWeather() {
  const [state, setState] = useState<DeviceWeatherState>({ weather: null, loading: false, error: null });

  const refresh = useCallback(async (fallback?: { latitude: number; longitude: number; city?: string | null }) => {
    setState({ weather: null, loading: true, error: null });
    try {
      let coords = fallback ?? null;

      if (!coords) {
        const { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== 'granted') {
          throw new Error('Location permission denied.');
        }
        const position = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
        coords = { latitude: position.coords.latitude, longitude: position.coords.longitude };
      }

      const weather = await getCurrentWeather(coords.latitude, coords.longitude);

      let city = coords.city ?? null;
      if (!city) {
        try {
          const [place] = await Location.reverseGeocodeAsync({ latitude: coords.latitude, longitude: coords.longitude });
          city = place?.city ?? place?.subregion ?? null;
        } catch {
          // Reverse geocoding is a nice-to-have — weather itself still succeeded.
        }
      }

      setState({ weather: { ...weather, city }, loading: false, error: null });
      return { ...weather, city };
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Could not fetch weather.';
      setState({ weather: null, loading: false, error: message });
      return null;
    }
  }, []);

  return { ...state, refresh };
}
