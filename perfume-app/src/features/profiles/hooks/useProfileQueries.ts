import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { queryKeys } from '@/lib/query';

import {
  follow,
  getFollowers,
  getFollowing,
  getProfile,
  getProfileByUsername,
  isFollowing,
  unfollow,
  updateProfile,
  type ProfileUpdate,
} from '../api/profilesApi';

export function useProfile(userId: string | undefined) {
  return useQuery({
    queryKey: queryKeys.profile(userId ?? ''),
    queryFn: () => getProfile(userId as string),
    enabled: Boolean(userId),
  });
}

export function useProfileByUsername(username: string | undefined) {
  return useQuery({
    queryKey: queryKeys.profileByUsername(username ?? ''),
    queryFn: () => getProfileByUsername(username as string),
    enabled: Boolean(username),
  });
}

export function useUpdateProfile(userId: string | undefined) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (patch: ProfileUpdate) => updateProfile(userId as string, patch),
    onSuccess: (updated) => {
      if (userId) queryClient.setQueryData(queryKeys.profile(userId), updated);
      queryClient.invalidateQueries({ queryKey: queryKeys.profileByUsername(updated.username) });
    },
  });
}

export function useFollowers(userId: string | undefined) {
  return useQuery({
    queryKey: queryKeys.followers(userId ?? ''),
    queryFn: () => getFollowers(userId as string),
    enabled: Boolean(userId),
  });
}

export function useFollowing(userId: string | undefined) {
  return useQuery({
    queryKey: queryKeys.following(userId ?? ''),
    queryFn: () => getFollowing(userId as string),
    enabled: Boolean(userId),
  });
}

export function useIsFollowing(viewerId: string | undefined, targetId: string | undefined) {
  return useQuery({
    queryKey: ['is-following', viewerId ?? '', targetId ?? ''],
    queryFn: () => isFollowing(viewerId as string, targetId as string),
    enabled: Boolean(viewerId) && Boolean(targetId) && viewerId !== targetId,
  });
}

/** Optimistic follow/unfollow toggle — flips the local cache immediately, then reconciles from the server. */
export function useFollowToggle(viewerId: string | undefined, targetId: string) {
  const queryClient = useQueryClient();

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['is-following', viewerId ?? '', targetId] });
    if (viewerId) queryClient.invalidateQueries({ queryKey: queryKeys.profile(viewerId) });
    queryClient.invalidateQueries({ queryKey: queryKeys.profile(targetId) });
  };

  const followMutation = useMutation({
    mutationFn: () => follow(viewerId as string, targetId),
    onMutate: () => queryClient.setQueryData(['is-following', viewerId ?? '', targetId], true),
    onSettled: invalidate,
  });

  const unfollowMutation = useMutation({
    mutationFn: () => unfollow(viewerId as string, targetId),
    onMutate: () => queryClient.setQueryData(['is-following', viewerId ?? '', targetId], false),
    onSettled: invalidate,
  });

  return { followMutation, unfollowMutation };
}
