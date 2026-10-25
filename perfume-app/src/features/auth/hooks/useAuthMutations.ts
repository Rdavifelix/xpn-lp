import { useMutation } from '@tanstack/react-query';

import { signInWithEmail, signOut, signUpWithEmail } from '../api/authApi';

export function useSignIn() {
  return useMutation({
    mutationFn: ({ email, password }: { email: string; password: string }) => signInWithEmail(email, password),
  });
}

export function useSignUp() {
  return useMutation({
    mutationFn: ({ email, password }: { email: string; password: string }) => signUpWithEmail(email, password),
  });
}

export function useSignOut() {
  return useMutation({
    mutationFn: signOut,
  });
}
