import { useEffect, useState } from 'react';
import { ActivityIndicator, KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

import { useAuth } from '@/features/auth';
import { useFragrance, useFragranceList, useOccasions } from '@/features/fragrances';
import { useCreateWear } from '@/features/feed';
import { useDeviceWeather } from '@/features/recommendations';
import { uploadImage } from '@/lib/storage';
import { Button, Card, IconButton, ScreenContainer, Tag, Text, TextField } from '@/components/ui';
import { useTheme } from '@/theme';

const MOODS = ['Confident', 'Cozy', 'Fresh', 'Romantic', 'Playful', 'Bold', 'Relaxed'];

export default function ComposeScreen() {
  const theme = useTheme();
  const router = useRouter();
  const { fragranceId: initialFragranceId } = useLocalSearchParams<{ fragranceId?: string }>();
  const { user } = useAuth();

  const [selectedFragranceId, setSelectedFragranceId] = useState<string | undefined>(initialFragranceId);
  const [fragranceQuery, setFragranceQuery] = useState('');
  const [caption, setCaption] = useState('');
  const [mood, setMood] = useState<string | null>(null);
  const [occasionId, setOccasionId] = useState<string | null>(null);
  const [visibility, setVisibility] = useState<'public' | 'followers'>('public');
  const [photoUri, setPhotoUri] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const { data: selectedFragrance } = useFragrance(selectedFragranceId);
  const { data: searchResults } = useFragranceList({ query: fragranceQuery, limit: 8 });
  const { data: occasions } = useOccasions();
  const { weather, loading: weatherLoading, refresh: refreshWeather } = useDeviceWeather();
  const createWear = useCreateWear(user?.id);

  useEffect(() => {
    refreshWeather();
    // Weather is captured once when the composer opens — refreshWeather is stable across renders.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const pickPhoto = async () => {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.85,
    });
    if (!result.canceled && result.assets[0]) setPhotoUri(result.assets[0].uri);
  };

  const handleSubmit = async () => {
    if (!user || !selectedFragranceId) return;
    setSubmitting(true);
    setSubmitError(null);
    try {
      let photoUrl: string | undefined;
      if (photoUri) {
        photoUrl = await uploadImage('wear-photos', photoUri, user.id);
      }

      await createWear.mutateAsync({
        fragranceId: selectedFragranceId,
        caption: caption.trim() || undefined,
        photoUrl,
        occasionId: occasionId ?? undefined,
        mood: mood ?? undefined,
        weather: weather ?? undefined,
        visibility,
      });

      router.replace('/(tabs)/feed');
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Could not post — please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ScreenContainer edges={['top', 'left', 'right', 'bottom']}>
      <Stack.Screen
        options={{
          headerShown: true,
          title: 'What are you wearing?',
          headerLeft: () => <IconButton name="close" onPress={() => router.back()} />,
        }}
      />
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.flex}>
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          {/* Fragrance picker */}
          {selectedFragrance ? (
            <Card style={styles.selectedFragrance}>
              <Text variant="caption" color="muted">
                {selectedFragrance.brandName.toUpperCase()}
              </Text>
              <Text variant="h3">{selectedFragrance.name}</Text>
              <Pressable onPress={() => setSelectedFragranceId(undefined)} style={styles.changeLink}>
                <Text variant="caption" color="accent">
                  Change fragrance
                </Text>
              </Pressable>
            </Card>
          ) : (
            <View style={styles.section}>
              <TextField
                label="Which fragrance?"
                value={fragranceQuery}
                onChangeText={setFragranceQuery}
                placeholder="Search your collection or the catalog…"
              />
              {searchResults && searchResults.length > 0 ? (
                <View style={styles.resultsList}>
                  {searchResults.map((f) => (
                    <Pressable key={f.id} onPress={() => setSelectedFragranceId(f.id)} style={[styles.resultRow, { borderColor: theme.colors.border }]}>
                      <Text variant="bodyMedium">{f.name}</Text>
                      <Text variant="caption" color="muted">
                        {f.brandName}
                      </Text>
                    </Pressable>
                  ))}
                </View>
              ) : null}
            </View>
          )}

          {/* Photo */}
          <View style={styles.section}>
            {photoUri ? (
              <View style={styles.photoWrap}>
                <Image source={{ uri: photoUri }} style={[styles.photo, { borderRadius: theme.radius.md }]} contentFit="cover" />
                <IconButton name="close-circle" backgroundColor={theme.colors.surfaceElevated} onPress={() => setPhotoUri(null)} style={styles.removePhoto} />
              </View>
            ) : (
              <Pressable
                onPress={pickPhoto}
                style={[styles.photoPlaceholder, { borderColor: theme.colors.border, borderRadius: theme.radius.md }]}
              >
                <Ionicons name="camera-outline" size={26} color={theme.colors.textMuted} />
                <Text variant="caption" color="muted">
                  Add a photo (optional)
                </Text>
              </Pressable>
            )}
          </View>

          <View style={styles.section}>
            <TextField
              label="Caption"
              value={caption}
              onChangeText={setCaption}
              placeholder="What's the occasion? How does it feel today?"
              multiline
              numberOfLines={3}
              style={styles.captionInput}
            />
          </View>

          <View style={styles.section}>
            <Text variant="label" color="secondary" style={styles.fieldLabel}>
              MOOD
            </Text>
            <View style={styles.chipWrap}>
              {MOODS.map((m) => (
                <Tag key={m} label={m} selected={mood === m} onPress={() => setMood(mood === m ? null : m)} />
              ))}
            </View>
          </View>

          {occasions && occasions.length > 0 ? (
            <View style={styles.section}>
              <Text variant="label" color="secondary" style={styles.fieldLabel}>
                OCCASION
              </Text>
              <View style={styles.chipWrap}>
                {occasions.map((o) => (
                  <Tag key={o.id} label={o.label} color={theme.colors.secondary} selected={occasionId === o.id} onPress={() => setOccasionId(occasionId === o.id ? null : o.id)} />
                ))}
              </View>
            </View>
          ) : null}

          <View style={styles.section}>
            <View style={styles.weatherRow}>
              <Text variant="label" color="secondary">
                WEATHER
              </Text>
              {weatherLoading ? (
                <ActivityIndicator size="small" color={theme.colors.accent} />
              ) : weather ? (
                <Text variant="caption" color="secondary">
                  {Math.round(weather.temp_c)}°C, {weather.condition}
                  {weather.city ? ` in ${weather.city}` : ''}
                </Text>
              ) : (
                <Pressable onPress={() => refreshWeather()}>
                  <Text variant="caption" color="accent">
                    Detect weather
                  </Text>
                </Pressable>
              )}
            </View>
          </View>

          <View style={styles.section}>
            <Text variant="label" color="secondary" style={styles.fieldLabel}>
              WHO CAN SEE THIS
            </Text>
            <View style={styles.chipWrap}>
              <Tag label="Everyone" selected={visibility === 'public'} onPress={() => setVisibility('public')} />
              <Tag label="Followers only" selected={visibility === 'followers'} onPress={() => setVisibility('followers')} />
            </View>
          </View>

          {submitError ? (
            <Text variant="caption" color="danger" style={styles.section}>
              {submitError}
            </Text>
          ) : null}

          <Button
            label="Post"
            onPress={handleSubmit}
            loading={submitting}
            disabled={!selectedFragranceId}
            fullWidth
            size="lg"
            style={styles.submit}
          />
        </ScrollView>
      </KeyboardAvoidingView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  scroll: { paddingVertical: 16, paddingBottom: 48 },
  section: { marginBottom: 20 },
  fieldLabel: { marginBottom: 10 },
  selectedFragrance: { marginBottom: 20 },
  changeLink: { marginTop: 8, alignSelf: 'flex-start' },
  resultsList: { marginTop: 10, gap: 2 },
  resultRow: { paddingVertical: 10, borderBottomWidth: StyleSheet.hairlineWidth },
  photoWrap: { position: 'relative' },
  photo: { width: '100%', aspectRatio: 1 },
  removePhoto: { position: 'absolute', top: 8, right: 8 },
  photoPlaceholder: { aspectRatio: 2, borderWidth: 1.5, borderStyle: 'dashed', alignItems: 'center', justifyContent: 'center', gap: 6 },
  captionInput: { minHeight: 70, textAlignVertical: 'top' },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  weatherRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  submit: { marginTop: 8 },
});
