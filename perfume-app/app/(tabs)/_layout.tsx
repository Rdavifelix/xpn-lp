import { Redirect, Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { BlurView } from 'expo-blur';
import { Platform, StyleSheet } from 'react-native';

import { useAuth } from '@/features/auth';
import { useTheme } from '@/theme';

const TAB_ICONS: Record<string, { active: keyof typeof Ionicons.glyphMap; inactive: keyof typeof Ionicons.glyphMap }> = {
  index: { active: 'home', inactive: 'home-outline' },
  discover: { active: 'compass', inactive: 'compass-outline' },
  feed: { active: 'people', inactive: 'people-outline' },
  collection: { active: 'flask', inactive: 'flask-outline' },
  profile: { active: 'person-circle', inactive: 'person-circle-outline' },
};

export default function TabsLayout() {
  const theme = useTheme();
  const { session, initializing } = useAuth();

  // Defense in depth: app/index.tsx already gates the initial redirect, but
  // this protects the (tabs) group even if it's reached directly (e.g. a
  // deep link) while signed out.
  if (!initializing && !session) {
    return <Redirect href="/(auth)/sign-in" />;
  }

  return (
    <Tabs
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarActiveTintColor: theme.colors.accent,
        tabBarInactiveTintColor: theme.colors.textMuted,
        tabBarStyle: [
          styles.tabBar,
          {
            backgroundColor: Platform.OS === 'ios' ? 'transparent' : theme.colors.surfaceElevated,
            borderTopColor: theme.colors.border,
          },
        ],
        tabBarBackground: Platform.OS === 'ios' ? () => <BlurView intensity={80} tint={theme.scheme} style={StyleSheet.absoluteFill} /> : undefined,
        tabBarLabelStyle: { fontFamily: theme.font.bodyMedium, fontSize: 11 },
        tabBarIcon: ({ focused, color, size }) => {
          const icons = TAB_ICONS[route.name] ?? TAB_ICONS.index;
          return <Ionicons name={focused ? icons.active : icons.inactive} size={size} color={color} />;
        },
      })}
    >
      <Tabs.Screen name="index" options={{ title: 'Home' }} />
      <Tabs.Screen name="discover" options={{ title: 'Discover' }} />
      <Tabs.Screen name="feed" options={{ title: 'Feed' }} />
      <Tabs.Screen name="collection" options={{ title: 'Collection' }} />
      <Tabs.Screen name="profile" options={{ title: 'Profile' }} />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  tabBar: {
    borderTopWidth: StyleSheet.hairlineWidth,
    height: 88,
    paddingTop: 8,
  },
});
