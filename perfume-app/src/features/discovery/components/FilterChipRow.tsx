import { ScrollView, StyleSheet, View } from 'react-native';

import { Tag, Text } from '@/components/ui';

export interface ChipOption {
  key: string;
  label: string;
  color?: string;
}

export interface FilterChipRowProps {
  title: string;
  options: ChipOption[];
  selectedKey: string | null;
  onSelect: (key: string | null) => void;
}

/** Horizontally-scrolling row of selectable filter chips, used for Discover's browse-by-accord/note/brand/occasion sections. */
export function FilterChipRow({ title, options, selectedKey, onSelect }: FilterChipRowProps) {
  if (options.length === 0) return null;

  return (
    <View style={styles.container}>
      <Text variant="label" color="secondary" style={styles.title}>
        {title.toUpperCase()}
      </Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.row}>
        {options.map((opt) => (
          <Tag
            key={opt.key}
            label={opt.label}
            color={opt.color}
            selected={selectedKey === opt.key}
            onPress={() => onSelect(selectedKey === opt.key ? null : opt.key)}
          />
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { marginBottom: 18 },
  title: { marginBottom: 10 },
  row: { gap: 8, paddingRight: 16 },
});
