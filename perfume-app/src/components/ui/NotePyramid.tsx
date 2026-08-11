import { StyleSheet, View } from 'react-native';

import { useTheme } from '@/theme';
import { ACCORD_FAMILY_COLORS } from '@/theme/colors';

import { Text } from './Text';
import { Tag } from './Tag';

export interface PyramidNote {
  id: string;
  name: string;
  /** Note family slug (e.g. "citrus", "woody") — used to tint the chip. */
  noteFamily?: string | null;
}

export interface NotePyramidProps {
  top: PyramidNote[];
  middle: PyramidNote[];
  base: PyramidNote[];
}

/**
 * Classic fragrance pyramid: top notes (first impression, most volatile) at
 * the narrow peak, down through heart/middle notes, to the base notes
 * (the longest-lasting, "dry down") at the widest tier.
 */
export function NotePyramid({ top, middle, base }: NotePyramidProps) {
  return (
    <View style={styles.container}>
      <PyramidTier label="Top Notes" sublabel="First impression" notes={top} />
      <PyramidTier label="Heart Notes" sublabel="The main character" notes={middle} />
      <PyramidTier label="Base Notes" sublabel="The dry-down" notes={base} />
    </View>
  );
}

function PyramidTier({ label, sublabel, notes }: { label: string; sublabel: string; notes: PyramidNote[] }) {
  const theme = useTheme();

  if (notes.length === 0) return null;

  return (
    <View style={[styles.tier, { borderTopColor: theme.colors.border }]}>
      <View style={styles.tierHeader}>
        <Text variant="label" color="muted">
          {label.toUpperCase()}
        </Text>
        <Text variant="caption" color="muted">
          {sublabel}
        </Text>
      </View>
      <View style={styles.chipRow}>
        {notes.map((note) => (
          <Tag key={note.id} label={note.name} color={note.noteFamily ? ACCORD_FAMILY_COLORS[note.noteFamily] : undefined} size="sm" />
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 16,
  },
  tier: {
    paddingTop: 14,
    borderTopWidth: StyleSheet.hairlineWidth,
    gap: 8,
  },
  tierHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'baseline',
  },
  chipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
});
