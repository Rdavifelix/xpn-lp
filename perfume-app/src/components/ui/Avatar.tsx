import { StyleSheet, View } from 'react-native';
import { Image } from 'expo-image';

import { useTheme } from '@/theme';

import { Text } from './Text';

export interface AvatarProps {
  uri?: string | null;
  name: string;
  size?: number;
}

/** Circular avatar with a warm initials fallback when there's no photo yet. */
export function Avatar({ uri, name, size = 44 }: AvatarProps) {
  const theme = useTheme();
  const initials = getInitials(name);

  if (uri) {
    return (
      <Image
        source={{ uri }}
        style={[styles.image, { width: size, height: size, borderRadius: size / 2 }]}
        contentFit="cover"
        transition={150}
      />
    );
  }

  return (
    <View
      style={[
        styles.fallback,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: theme.colors.accentSoft,
        },
      ]}
    >
      <Text variant="bodyMedium" color="accent" style={{ fontSize: size * 0.38 }}>
        {initials}
      </Text>
    </View>
  );
}

function getInitials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

const styles = StyleSheet.create({
  image: {
    backgroundColor: '#0000000A',
  },
  fallback: {
    alignItems: 'center',
    justifyContent: 'center',
  },
});
