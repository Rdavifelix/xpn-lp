import { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { Link, useRouter } from 'expo-router';

import { useSignUp } from '@/features/auth';
import { AuthHeader } from '@/features/auth/components/AuthHeader';
import { Button, EmptyState, ScreenContainer, Text, TextField } from '@/components/ui';

export default function SignUpScreen() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [checkEmailNotice, setCheckEmailNotice] = useState(false);
  const signUp = useSignUp();

  const passwordsMatch = password.length > 0 && password === confirmPassword;
  const passwordTooShort = password.length > 0 && password.length < 8;

  const handleSubmit = () => {
    signUp.mutate(
      { email: email.trim(), password },
      {
        onSuccess: (data) => {
          if (data.session) {
            // Email confirmation is disabled on this project — we're
            // already signed in, straight into onboarding.
            router.replace('/(auth)/onboarding');
          } else {
            // Email confirmation required before a session exists.
            setCheckEmailNotice(true);
          }
        },
      },
    );
  };

  if (checkEmailNotice) {
    return (
      <ScreenContainer edges={['top', 'left', 'right', 'bottom']}>
        <EmptyState
          icon="mail-outline"
          title="Check your inbox"
          message={`We sent a confirmation link to ${email.trim()}. Once confirmed, come back and sign in.`}
          actionLabel="Back to sign in"
          onAction={() => router.replace('/(auth)/sign-in')}
        />
      </ScreenContainer>
    );
  }

  return (
    <ScreenContainer edges={['top', 'left', 'right', 'bottom']}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.flex}>
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          <AuthHeader title="Join Sillage" subtitle="A home for your fragrance collection and community" />

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
              autoComplete="new-password"
              placeholder="At least 8 characters"
              error={passwordTooShort ? 'Password must be at least 8 characters.' : undefined}
            />
            <TextField
              label="Confirm password"
              value={confirmPassword}
              onChangeText={setConfirmPassword}
              secureTextEntry
              autoCapitalize="none"
              autoComplete="new-password"
              placeholder="Re-enter your password"
              error={confirmPassword.length > 0 && !passwordsMatch ? 'Passwords don’t match.' : undefined}
            />

            {signUp.isError ? (
              <Text variant="caption" color="danger">
                {signUp.error instanceof Error ? signUp.error.message : 'Something went wrong. Please try again.'}
              </Text>
            ) : null}

            <Button
              label="Create Account"
              onPress={handleSubmit}
              loading={signUp.isPending}
              disabled={!email.trim() || !passwordsMatch || passwordTooShort}
              fullWidth
              size="lg"
              style={styles.submit}
            />
          </View>

          <View style={styles.footer}>
            <Text variant="body" color="secondary">
              Already have an account?
            </Text>
            <Link href="/(auth)/sign-in" replace>
              <Text variant="bodyMedium" color="accent">
                {' '}
                Sign in
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
