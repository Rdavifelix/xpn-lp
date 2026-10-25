import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { useRouter } from 'expo-router';
import * as Location from 'expo-location';
import { Ionicons } from '@expo/vector-icons';
import { useMutation } from '@tanstack/react-query';

import { useAuth } from '@/features/auth';
import { AuthHeader } from '@/features/auth/components/AuthHeader';
import { isUsernameAvailable, updateProfile } from '@/features/profiles';
import { Button, ScreenContainer, Text, TextField } from '@/components/ui';
import { useTheme } from '@/theme';

type UsernameStatus = 'idle' | 'checking' | 'available' | 'taken' | 'invalid';

const USERNAME_PATTERN = /^[a-zA-Z0-9_.]{3,30}$/;

export default function OnboardingScreen() {
  const theme = useTheme();
  const router = useRouter();
  const { user } = useAuth();

  const [username, setUsername] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [bio, setBio] = useState('');
  const [city, setCity] = useState('');
  const [country, setCountry] = useState('');
  const [coords, setCoords] = useState<{ latitude: number; longitude: number } | null>(null);
  const [locating, setLocating] = useState(false);
  const [locationError, setLocationError] = useState<string | null>(null);

  // Result of the last resolved availability check, keyed by the username it
  // was resolved for — lets us derive the display status at render time
  // (below) instead of syncing it via effect, so the effect itself only
  // ever calls setState from inside its async callback.
  const [resolved, setResolved] = useState<{ username: string; available: boolean } | null>(null);
  const formatValid = username.length > 0 && USERNAME_PATTERN.test(username);

  // Debounced live username-availability check.
  useEffect(() => {
    if (!formatValid) return;
    const handle = setTimeout(() => {
      isUsernameAvailable(username, user?.id)
        .then((available) => setResolved({ username, available }))
        .catch(() => {});
    }, 400);
    return () => clearTimeout(handle);
  }, [username, formatValid, user?.id]);

  const usernameStatus: UsernameStatus =
    username.length === 0
      ? 'idle'
      : !formatValid
        ? 'invalid'
        : resolved?.username === username
          ? resolved.available
            ? 'available'
            : 'taken'
          : 'checking';

  const saveProfile = useMutation({
    mutationFn: () => {
      if (!user) throw new Error('Not signed in.');
      return updateProfile(user.id, {
        username,
        display_name: displayName.trim() || username,
        bio: bio.trim() || null,
        city: city.trim() || null,
        country: country.trim() || null,
        latitude: coords?.latitude ?? null,
        longitude: coords?.longitude ?? null,
      });
    },
    onSuccess: () => router.replace('/(tabs)'),
  });

  const handleUseLocation = async () => {
    setLocationError(null);
    setLocating(true);
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        setLocationError('Location permission denied — you can still type your city manually.');
        return;
      }
      const position = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
      setCoords({ latitude: position.coords.latitude, longitude: position.coords.longitude });

      const [place] = await Location.reverseGeocodeAsync(position.coords);
      if (place) {
        setCity(place.city ?? place.subregion ?? '');
        setCountry(place.country ?? '');
      }
    } catch {
      setLocationError('Couldn’t detect your location — you can still type your city manually.');
    } finally {
      setLocating(false);
    }
  };

  const usernameHelper: Record<UsernameStatus, string | undefined> = {
    idle: 'Letters, numbers, underscores and dots — 3 to 30 characters.',
    checking: 'Checking availability…',
    available: 'Username is available.',
    taken: 'That username is already taken.',
    invalid: 'Only letters, numbers, underscores and dots (3-30 chars).',
  };

  const canSubmit = usernameStatus === 'available' && !saveProfile.isPending;

  return (
    <ScreenContainer edges={['top', 'left', 'right', 'bottom']}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.flex}>
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          <AuthHeader title="Set up your profile" subtitle="This is how the community will find you" />

          <View style={styles.form}>
            <TextField
              label="Username"
              value={username}
              onChangeText={(v) => setUsername(v.toLowerCase())}
              autoCapitalize="none"
              autoComplete="off"
              placeholder="e.g. scent_of_jane"
              hint={usernameStatus === 'idle' || usernameStatus === 'checking' || usernameStatus === 'available' ? usernameHelper[usernameStatus] : undefined}
              error={usernameStatus === 'taken' || usernameStatus === 'invalid' ? usernameHelper[usernameStatus] : undefined}
            />
            <TextField label="Display name" value={displayName} onChangeText={setDisplayName} placeholder="How you'll appear on posts" />
            <TextField
              label="Bio"
              value={bio}
              onChangeText={setBio}
              placeholder="Fragrance lover, always chasing the next signature scent..."
              multiline
              numberOfLines={3}
              style={styles.bioInput}
            />

            <View style={styles.locationRow}>
              <View style={styles.locationFields}>
                <TextField label="City" value={city} onChangeText={setCity} placeholder="e.g. Lisbon" />
              </View>
              <Button
                label={locating ? 'Locating…' : 'Use my location'}
                variant="outline"
                size="sm"
                onPress={handleUseLocation}
                loading={locating}
                icon={<Ionicons name="locate-outline" size={16} color={theme.colors.textPrimary} />}
                style={styles.locateButton}
              />
            </View>
            {locationError ? (
              <Text variant="caption" color="muted">
                {locationError}
              </Text>
            ) : null}
            <Text variant="caption" color="muted">
              Your city and coordinates power weather-aware recommendations — you can change this anytime in your profile.
            </Text>

            <Button label="Enter Sillage" onPress={() => saveProfile.mutate()} loading={saveProfile.isPending} disabled={!canSubmit} fullWidth size="lg" style={styles.submit} />
            {saveProfile.isError ? (
              <Text variant="caption" color="danger">
                {saveProfile.error instanceof Error ? saveProfile.error.message : 'Could not save your profile.'}
              </Text>
            ) : null}
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  scroll: { flexGrow: 1, justifyContent: 'center', paddingVertical: 32 },
  form: { gap: 16 },
  bioInput: { minHeight: 76, textAlignVertical: 'top' },
  locationRow: { flexDirection: 'row', alignItems: 'flex-end', gap: 10 },
  locationFields: { flex: 1 },
  locateButton: { marginBottom: 2 },
  submit: { marginTop: 8 },
});
