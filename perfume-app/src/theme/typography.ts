/**
 * Type system: Fraunces (a soft, high-contrast serif) for display/heading
 * moments — names of fragrances, the daily rec card, section titles — paired
 * with Manrope for anything read at length or used in UI chrome. The serif
 * is what gives the app its "perfume house" feel instead of reading as a
 * generic utility app.
 */

export const fontFamily = {
  displayRegular: 'Fraunces_400Regular',
  displayMedium: 'Fraunces_500Medium',
  displaySemiBold: 'Fraunces_600SemiBold',
  displayItalic: 'Fraunces_500Medium_Italic',
  bodyRegular: 'Manrope_400Regular',
  bodyMedium: 'Manrope_500Medium',
  bodySemiBold: 'Manrope_600SemiBold',
  bodyBold: 'Manrope_700Bold',
} as const;

export const fontsToLoad = {
  Fraunces_400Regular: require('@expo-google-fonts/fraunces/400Regular/Fraunces_400Regular.ttf'),
  Fraunces_500Medium: require('@expo-google-fonts/fraunces/500Medium/Fraunces_500Medium.ttf'),
  Fraunces_600SemiBold: require('@expo-google-fonts/fraunces/600SemiBold/Fraunces_600SemiBold.ttf'),
  Fraunces_500Medium_Italic: require('@expo-google-fonts/fraunces/500Medium_Italic/Fraunces_500Medium_Italic.ttf'),
  Manrope_400Regular: require('@expo-google-fonts/manrope/400Regular/Manrope_400Regular.ttf'),
  Manrope_500Medium: require('@expo-google-fonts/manrope/500Medium/Manrope_500Medium.ttf'),
  Manrope_600SemiBold: require('@expo-google-fonts/manrope/600SemiBold/Manrope_600SemiBold.ttf'),
  Manrope_700Bold: require('@expo-google-fonts/manrope/700Bold/Manrope_700Bold.ttf'),
};

export interface TextStyleToken {
  fontFamily: string;
  fontSize: number;
  lineHeight: number;
  letterSpacing?: number;
}

export const typeScale: Record<string, TextStyleToken> = {
  display: { fontFamily: fontFamily.displaySemiBold, fontSize: 34, lineHeight: 40, letterSpacing: -0.3 },
  h1: { fontFamily: fontFamily.displaySemiBold, fontSize: 28, lineHeight: 34, letterSpacing: -0.2 },
  h2: { fontFamily: fontFamily.displayMedium, fontSize: 22, lineHeight: 28 },
  h3: { fontFamily: fontFamily.displayMedium, fontSize: 18, lineHeight: 24 },
  subtitle: { fontFamily: fontFamily.bodySemiBold, fontSize: 15, lineHeight: 20, letterSpacing: 0.1 },
  body: { fontFamily: fontFamily.bodyRegular, fontSize: 15, lineHeight: 22 },
  bodyMedium: { fontFamily: fontFamily.bodyMedium, fontSize: 15, lineHeight: 22 },
  caption: { fontFamily: fontFamily.bodyMedium, fontSize: 13, lineHeight: 18 },
  label: { fontFamily: fontFamily.bodySemiBold, fontSize: 12, lineHeight: 16, letterSpacing: 0.6 },
  quote: { fontFamily: fontFamily.displayItalic, fontSize: 17, lineHeight: 24 },
};

export type TypeScaleKey = keyof typeof typeScale;
