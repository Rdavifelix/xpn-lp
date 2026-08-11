import { Pressable, StyleSheet, View } from 'react-native';

import { Text } from '@/components/ui';
import { useTheme } from '@/theme';
import type { CollectionStatus } from '@/lib/supabase';

const OPTIONS: { value: CollectionStatus; label: string }[] = [
  { value: 'owned', label: 'Owned' },
  { value: 'wishlist', label: 'Wishlist' },
  { value: 'tried', label: 'Tried' },
];

export function StatusSegmentedControl({ value, onChange }: { value: CollectionStatus; onChange: (v: CollectionStatus) => void }) {
  const theme = useTheme();

  return (
    <View style={[styles.track, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border, borderRadius: theme.radius.pill }]}>
      {OPTIONS.map((opt) => {
        const active = opt.value === value;
        return (
          <Pressable
            key={opt.value}
            onPress={() => onChange(opt.value)}
            style={[styles.segment, { borderRadius: theme.radius.pill, backgroundColor: active ? theme.colors.accent : 'transparent' }]}
          >
            <Text variant="bodyMedium" style={{ color: active ? theme.colors.textOnAccent : theme.colors.textSecondary }}>
              {opt.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  track: { flexDirection: 'row', borderWidth: StyleSheet.hairlineWidth, padding: 3, gap: 3 },
  segment: { flex: 1, paddingVertical: 8, alignItems: 'center' },
});
