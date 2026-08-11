/**
 * Warm, tactile palette for Sillage.
 *
 * The app leans on paper/ivory surfaces, aged-gold accents and a deep wine
 * secondary — evocative of perfume packaging rather than a generic "app
 * blue" look. Every token below has a light and dark counterpart so the
 * whole app follows the system color scheme (see ThemeProvider).
 */

export type ColorScheme = 'light' | 'dark';

export interface ThemeColors {
  /** Screen background. */
  background: string;
  /** Cards, sheets, inputs. */
  surface: string;
  /** Raised surfaces (modals, the daily rec card). */
  surfaceElevated: string;
  /** Hairline borders / dividers. */
  border: string;
  /** Soft borders on interactive elements. */
  borderStrong: string;

  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  /** Text drawn on top of `accent`. */
  textOnAccent: string;

  /** Primary brand accent — aged gold. Buttons, active tab, links. */
  accent: string;
  accentStrong: string;
  accentSoft: string;

  /** Secondary brand accent — deep wine. Used sparingly for emphasis. */
  secondary: string;
  secondarySoft: string;

  success: string;
  danger: string;
  warning: string;

  /** Heart / like color. */
  like: string;

  overlay: string;
  shadow: string;
}

const light: ThemeColors = {
  background: '#FBF4EC',
  surface: '#FFFDF9',
  surfaceElevated: '#FFFFFF',
  border: '#E8DCC8',
  borderStrong: '#D8C6A6',

  textPrimary: '#2B2420',
  textSecondary: '#6B5D4F',
  textMuted: '#9C8D7B',
  textOnAccent: '#2B1D0E',

  accent: '#C08A3E',
  accentStrong: '#A66C22',
  accentSoft: '#F1DFC0',

  secondary: '#7B2D43',
  secondarySoft: '#F0D9DF',

  success: '#4C7A5A',
  danger: '#B23B3B',
  warning: '#B8863A',

  like: '#C0435B',

  overlay: 'rgba(43, 36, 32, 0.45)',
  shadow: 'rgba(87, 66, 39, 0.18)',
};

const dark: ThemeColors = {
  background: '#171310',
  surface: '#211C17',
  surfaceElevated: '#2B241D',
  border: '#3A3128',
  borderStrong: '#4A3E30',

  textPrimary: '#F3EAD9',
  textSecondary: '#C9B8A0',
  textMuted: '#8E7F6C',
  textOnAccent: '#2B1D0E',

  accent: '#D9A44F',
  accentStrong: '#E9BC72',
  accentSoft: '#3D2F1C',

  secondary: '#D98298',
  secondarySoft: '#3D2530',

  success: '#7FB88F',
  danger: '#E27676',
  warning: '#E0B36B',

  like: '#E27E93',

  overlay: 'rgba(0, 0, 0, 0.55)',
  shadow: 'rgba(0, 0, 0, 0.4)',
};

export const palettes: Record<ColorScheme, ThemeColors> = { light, dark };

/**
 * Reference colors for the 12 scent/note families used throughout the
 * catalog (accord tags, the pyramid, the accord chart on fragrance detail
 * pages). Seeded into `accords.hex_color` too, so the same value drives
 * both the SQL seed data and any client-side fallback rendering.
 */
export const ACCORD_FAMILY_COLORS: Record<string, string> = {
  citrus: '#E8A33D',
  floral: '#D998B5',
  woody: '#8A6240',
  oriental: '#9A5B3C',
  fresh: '#6FB8A8',
  gourmand: '#C97B4A',
  spicy: '#B5482F',
  green: '#7A9B5C',
  aquatic: '#4E8FB0',
  musk: '#B8A48C',
  leather: '#6B4A3A',
  resin: '#8C5A2B',
};
