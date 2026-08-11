import { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { Link, useRouter } from 'expo-router';

import { useSignIn } from '@/features/auth';
import { AuthHeader } from '@/features/auth/components/AuthHeader';
import { Button, ScreenContainer, Text, TextField } from '@/components/ui';

export default function SignInScreen() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const signIn = useSignIn();

  const handleSubmit = () => {
    signIn.mutate(
      { email: email.trim(), password },
      {
        onSuccess: () => router.replace('/(tabs)'),
      },
    );
  };

  return (
    <ScreenContainer edges={['top', 'left', 'right', 'bottom']}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.flex}>
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          <AuthHeader title="Welcome back" subtitle="Sign in to your fragrance wardrobe" />

          <View style={styles.form}>
            <TextField
              label="Email"
              value={email}
              onChangeText={setEmail}
              autoCapitalize="none"
              autoComplete="email"
              keyboardType="email-address"
              placeholder="you@example.com"
            />
            <TextField
              label="Password"
              value={password}
              onChangeText={setPassword}
              secureTextEntry
              autoCapitalize="none"
              autoComplete="password"
              placeholder="••••••••"
            />

            {signIn.isError ? (
              <Text variant="caption" color="danger">
                {signIn.error instanceof Error ? signIn.error.message : 'Something went wrong. Please try again.'}
              </Text>
            ) : null}

            <Button
              label="Sign In"
              onPress={handleSubmit}
              loading={signIn.isPending}
              disabled={!email.trim() || !password}
              fullWidth
              size="lg"
              style={styles.submit}
            />
          </View>

          <View style={styles.footer}>
            <Text variant="body" color="secondary">
              New to Sillage?
            </Text>
            <Link href="/(auth)/sign-up" replace>
              <Text variant="bodyMedium" color="accent">
                {' '}
                Create an account
              </Text>
            </Link>
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
  submit: { marginTop: 8 },
  footer: { flexDirection: 'row', justifyContent: 'center', marginTop: 28 },
});
