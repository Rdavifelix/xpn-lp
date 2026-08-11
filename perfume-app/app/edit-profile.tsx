import { useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import * as ImagePicker from 'expo-image-picker';

import { useAuth } from '@/features/auth';
import { isUsernameAvailable, useProfile, useUpdateProfile, type Profile } from '@/features/profiles';
import { uploadImage } from '@/lib/storage';
import { Avatar, Button, IconButton, LoadingState, ScreenContainer, Text, TextField } from '@/components/ui';

const USERNAME_PATTERN = /^[a-zA-Z0-9_.]{3,30}$/;

export default function EditProfileScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const { data: profile } = useProfile(user?.id);

  return (
    <ScreenContainer edges={['top', 'left', 'right', 'bottom']}>
      <Stack.Screen
        options={{ headerShown: true, title: 'Edit Profile', headerLeft: () => <IconButton name="close" onPress={() => router.back()} /> }}
      />
      {profile ? <EditProfileForm profile={profile} /> : <LoadingState fill message="Loading your profile…" />}
    </ScreenContainer>
  );
}

/**
 * Rendered only once `profile` has loaded, so every field's initial state
 * comes straight from props on first render — no effect needed to sync it
 * in after the fact.
 */
function EditProfileForm({ profile }: { profile: Profile }) {
  const router = useRouter();
  const { user } = useAuth();
  const updateProfile = useUpdateProfile(user?.id);

  const [username, setUsername] = useState(profile.username);
  const [displayName, setDisplayName] = useState(profile.display_name ?? '');
  const [bio, setBio] = useState(profile.bio ?? '');
  const [city, setCity] = useState(profile.city ?? '');
  const [avatarUrl, setAvatarUrl] = useState<string | null>(profile.avatar_url);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [usernameError, setUsernameError] = useState<string | null>(null);

  const pickAvatar = async () => {
    if (!user) return;
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], allowsEditing: true, aspect: [1, 1], quality: 0.85 });
    if (result.canceled || !result.assets[0]) return;

    setUploadingAvatar(true);
    try {
      const url = await uploadImage('avatars', result.assets[0].uri, user.id);
      setAvatarUrl(url);
    } finally {
      setUploadingAvatar(false);
    }
  };

  const handleSave = async () => {
    if (!user) return;
    setUsernameError(null);

    if (!USERNAME_PATTERN.test(username)) {
      setUsernameError('Only letters, numbers, underscores and dots (3-30 chars).');
      return;
    }
    const available = await isUsernameAvailable(username, user.id);
    if (!available) {
      setUsernameError('That username is already taken.');
      return;
    }

    updateProfile.mutate(
      {
        username,
        display_name: displayName.trim() || username,
        bio: bio.trim() || null,
        city: city.trim() || null,
        avatar_url: avatarUrl,
      },
      { onSuccess: () => router.back() },
    );
  };

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.flex}>
      <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        <Pressable onPress={pickAvatar} style={styles.avatarWrap}>
          <Avatar uri={avatarUrl} name={displayName || username || '?'} size={88} />
          <Text variant="caption" color="accent" style={styles.avatarLabel}>
            {uploadingAvatar ? 'Uploading…' : 'Change photo'}
          </Text>
        </Pressable>

        <View style={styles.form}>
          <TextField
            label="Username"
            value={username}
            onChangeText={(v) => setUsername(v.toLowerCase())}
            autoCapitalize="none"
            error={usernameError ?? undefined}
          />
          <TextField label="Display name" value={displayName} onChangeText={setDisplayName} />
          <TextField label="Bio" value={bio} onChangeText={setBio} multiline numberOfLines={3} style={styles.bioInput} />
          <TextField label="City" value={city} onChangeText={setCity} />

          {updateProfile.isError ? (
            <Text variant="caption" color="danger">
              {updateProfile.error instanceof Error ? updateProfile.error.message : 'Could not save your profile.'}
            </Text>
          ) : null}

          <Button label="Save Changes" onPress={handleSave} loading={updateProfile.isPending} fullWidth size="lg" style={styles.saveButton} />
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  scroll: { paddingVertical: 24, paddingBottom: 48 },
  avatarWrap: { alignItems: 'center', marginBottom: 24, gap: 8 },
  avatarLabel: { marginTop: 4 },
  form: { gap: 16 },
  bioInput: { minHeight: 70, textAlignVertical: 'top' },
  saveButton: { marginTop: 8 },
});
