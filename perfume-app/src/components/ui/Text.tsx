import { Text as RNText, type TextProps as RNTextProps } from 'react-native';

import { useTheme } from '@/theme';
import type { TypeScaleKey } from '@/theme/typography';

export interface TextProps extends RNTextProps {
  /** Typography token from the scale — defaults to `body`. */
  variant?: TypeScaleKey;
  /** Semantic color token — defaults to `textPrimary`. */
  color?: 'primary' | 'secondary' | 'muted' | 'onAccent' | 'accent' | 'secondaryAccent' | 'danger' | 'success';
}

const colorTokenMap: Record<NonNullable<TextProps['color']>, keyof ReturnType<typeof useTheme>['colors']> = {
  primary: 'textPrimary',
  secondary: 'textSecondary',
  muted: 'textMuted',
  onAccent: 'textOnAccent',
  accent: 'accent',
  secondaryAccent: 'secondary',
  danger: 'danger',
  success: 'success',
};

/**
 * Themed text primitive. All copy in the app should go through this (rather
 * than raw RN `Text`) so typography and color stay centralized in
 * src/theme.
 */
export function Text({ variant = 'body', color = 'primary', style, ...props }: TextProps) {
  const theme = useTheme();
  const typeToken = theme.type[variant];
  const resolvedColor = theme.colors[colorTokenMap[color]];

  return (
    <RNText
      style={[
        {
          fontFamily: typeToken.fontFamily,
          fontSize: typeToken.fontSize,
          lineHeight: typeToken.lineHeight,
          letterSpacing: typeToken.letterSpacing,
          color: resolvedColor,
        },
        style,
      ]}
      {...props}
    />
  );
}
