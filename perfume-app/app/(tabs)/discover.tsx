import { useMemo, useState } from 'react';
import { FlatList, StyleSheet, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

import { FilterChipRow, useAccordOptions, useBrandOptions, useNoteOptions } from '@/features/discovery';
import { FragranceCard, useFragranceList, useOccasions, type ListFragrancesFilters } from '@/features/fragrances';
import { EmptyState, LoadingState, ScreenContainer, Text, TextField } from '@/components/ui';
import { useTheme } from '@/theme';

type FilterType = 'accord' | 'note' | 'brand' | 'occasion';
interface ActiveFilter {
  type: FilterType;
  key: string;
}

export default function DiscoverScreen() {
  const theme = useTheme();
  const router = useRouter();

  const [query, setQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState<ActiveFilter | null>(null);

  const { data: accords } = useAccordOptions();
  const { data: notes } = useNoteOptions();
  const { data: brands } = useBrandOptions();
  const { data: occasions } = useOccasions();

  const filters: ListFragrancesFilters = useMemo(() => {
    if (query.trim().length > 0) return { query, limit: 40 };
    if (activeFilter && activeFilter.type === 'accord') return { accordSlug: activeFilter.key, limit: 40 };
    if (activeFilter && activeFilter.type === 'note') return { noteId: activeFilter.key, limit: 40 };
    if (activeFilter && activeFilter.type === 'brand') return { brandId: activeFilter.key, limit: 40 };
    if (activeFilter && activeFilter.type === 'occasion') return { occasionSlug: activeFilter.key, limit: 40 };
    return { limit: 40 };
  }, [query, activeFilter]);

  const { data: results, isLoading } = useFragranceList(filters);

  const selectFilter = (type: FilterType, key: string | null) => {
    setQuery('');
    setActiveFilter(key ? { type, key } : null);
  };

  // Deliberately depends only on `query`, not `activeFilter` — the chip rows
  // stay visible after selecting one (so you can see its selected state and
  // switch to another), only hiding when there's a text search instead.
  const isBrowsing = query.trim().length === 0;

  return (
    <ScreenContainer edges={['top', 'left', 'right']}>
      <View style={styles.header}>
        <Text variant="h1">Discover</Text>
        <TextField
          value={query}
          onChangeText={(v) => {
            setQuery(v);
            if (v.trim()) setActiveFilter(null);
          }}
          placeholder="Search fragrances or houses…"
          autoCapitalize="none"
          style={styles.search}
        />
      </View>

      <FlatList
        data={results ?? []}
        keyExtractor={(item) => item.id}
        numColumns={2}
        columnWrapperStyle={styles.row}
        contentContainerStyle={styles.list}
        ListHeaderComponent={
          isBrowsing ? (
            <View style={styles.filters}>
              <FilterChipRow
                title="Browse by Accord"
                options={(accords ?? []).map((a) => ({ key: a.slug, label: a.label, color: a.hexColor }))}
                selectedKey={activeFilter && activeFilter.type === 'accord' ? activeFilter.key : null}
                onSelect={(key) => selectFilter('accord', key)}
              />
              <FilterChipRow
                title="Browse by Occasion"
                options={(occasions ?? []).map((o) => ({ key: o.slug, label: o.label, color: theme.colors.secondary }))}
                selectedKey={activeFilter && activeFilter.type === 'occasion' ? activeFilter.key : null}
                onSelect={(key) => selectFilter('occasion', key)}
              />
              <FilterChipRow
                title="Browse by Note"
                options={(notes ?? []).map((n) => ({ key: n.id, label: n.name }))}
                selectedKey={activeFilter && activeFilter.type === 'note' ? activeFilter.key : null}
                onSelect={(key) => selectFilter('note', key)}
              />
              <FilterChipRow
                title="Browse by House"
                options={(brands ?? []).map((b) => ({ key: b.id, label: b.name }))}
                selectedKey={activeFilter && activeFilter.type === 'brand' ? activeFilter.key : null}
                onSelect={(key) => selectFilter('brand', key)}
              />
              <Text variant="label" color="secondary" style={styles.resultsLabel}>
                {activeFilter ? `RESULTS · ${results?.length ?? 0}` : 'TRENDING'}
              </Text>
            </View>
          ) : (
            <View style={styles.activeFilterHeader}>
              <Ionicons name="search-outline" size={14} color={theme.colors.textMuted} />
              <Text variant="caption" color="muted">
                {results?.length ?? 0} result{results?.length === 1 ? '' : 's'} for &quot;{query.trim()}&quot;
              </Text>
            </View>
          )
        }
        renderItem={({ item }) => (
          <FragranceCard fragrance={item} onPress={() => router.push({ pathname: '/fragrance/[id]', params: { id: item.id } })} />
        )}
        ListEmptyComponent={
          isLoading ? (
            <LoadingState message="Searching…" />
          ) : (
            <EmptyState icon="search-outline" title="No fragrances found" message="Try another search or a different filter." />
          )
        }
      />
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { paddingTop: 8, paddingBottom: 12, gap: 12 },
  search: { marginBottom: 0 },
  filters: { paddingTop: 4 },
  resultsLabel: { marginBottom: 10 },
  activeFilterHeader: { flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 12 },
  list: { paddingBottom: 24, flexGrow: 1 },
  row: { gap: 12, marginBottom: 12 },
});
