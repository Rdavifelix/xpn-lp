// https://docs.expo.dev/guides/using-eslint/
const expoConfig = require('eslint-config-expo/flat');

module.exports = [
  ...expoConfig,
  {
    ignores: ['dist/*', 'node_modules/*', '.expo/*'],
  },
  {
    rules: {
      // Feature folders intentionally re-export their public surface via index.ts barrels.
      'import/no-unresolved': 'off',
      // react-hooks v7 ships React Compiler-derived rules that assume all
      // render-scope values are immutable. That's incompatible with
      // react-native-reanimated's core pattern of mutating `.value` on a
      // useSharedValue() ref from event handlers to drive UI-thread
      // animations — Reanimated isn't in the compiler's known-mutable-hook
      // allowlist, so every shared-value assignment false-positives here.
      'react-hooks/immutability': 'off',
    },
  },
];
