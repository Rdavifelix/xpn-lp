import { createContext, useContext, useMemo, type PropsWithChildren } from 'react';
import { useColorScheme } from 'react-native';

import { palettes, type ColorScheme, type ThemeColors } from './colors';
import { motion } from './motion';
import { radius, spacing } from './spacing';
import { fontFamily, typeScale } from './typography';

export interface Theme {
  scheme: ColorScheme;
  colors: ThemeColors;
  spacing: typeof spacing;
  radius: typeof radius;
  motion: typeof motion;
  font: typeof fontFamily;
  type: typeof typeScale;
}

function buildTheme(scheme: ColorScheme): Theme {
  return {
    scheme,
    colors: palettes[scheme],
    spacing,
    radius,
    motion,
    font: fontFamily,
    type: typeScale,
  };
}

const ThemeContext = createContext<Theme>(buildTheme('light'));

/**
 * Wraps the app and derives the active theme from the OS color scheme.
 * Kept intentionally simple (no manual light/dark toggle) — can be extended
 * with a stored user preference later without touching consumers, since
 * everything reads through `useTheme()`.
 */
export function ThemeProvider({ children }: PropsWithChildren) {
  const scheme = useColorScheme();
  const theme = useMemo(() => buildTheme(scheme === 'dark' ? 'dark' : 'light'), [scheme]);

  return <ThemeContext.Provider value={theme}>{children}</ThemeContext.Provider>;
}

export function useTheme(): Theme {
  return useContext(ThemeContext);
}
