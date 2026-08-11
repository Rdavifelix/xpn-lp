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
    },
  },
];
