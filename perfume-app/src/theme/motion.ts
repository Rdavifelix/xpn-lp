import { Easing } from 'react-native-reanimated';

/**
 * Shared animation timing so every screen feels like part of the same
 * "tactile" interaction language instead of a grab-bag of durations.
 */
export const motion = {
  duration: {
    quick: 150,
    base: 250,
    slow: 400,
    lazy: 600,
  },
  easing: {
    standard: Easing.bezier(0.2, 0.0, 0, 1),
    decelerate: Easing.out(Easing.cubic),
    accelerate: Easing.in(Easing.cubic),
    spring: { damping: 16, stiffness: 180, mass: 0.9 },
    gentleSpring: { damping: 20, stiffness: 120, mass: 1 },
  },
} as const;
