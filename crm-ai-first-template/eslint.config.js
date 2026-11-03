import js from "@eslint/js";
import globals from "globals";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["dist"] },
  {
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    files: ["**/*.{ts,tsx}"],
    languageOptions: {
      ecmaVersion: 2020,
      globals: globals.browser,
    },
    plugins: {
      "react-hooks": reactHooks,
      "react-refresh": reactRefresh,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      "react-hooks/exhaustive-deps": "warn",
      "react-refresh/only-export-components": ["warn", {
        allowConstantExport: true,
        // These stable helpers and hooks intentionally live beside their provider/component.
        // Any future unlisted non-component export still triggers the rule.
        allowExportNames: [
          "AVATAR_COLORS", "getSelectedPlaybook", "clearSelectedPlaybook",
          "parseCarouselBlock", "generateMeetingPDF", "downloadMeetingPDF",
          "formatCurrency", "formatCurrencyFull", "formatPercent", "DATE_PRESETS",
          "useSessionState", "useDemoMultiplier", "dv", "useEnabledModules",
          "badgeVariants", "buttonVariants", "toCents", "toFloat", "useFormField",
          "navigationMenuTriggerStyle", "useSidebar", "toast", "toggleVariants",
          "useAuth", "useCall", "formatCallDuration", "useDemoMode",
          "useEventAppAuth", "callActionsFunction", "useFocusMode", "useMeeting",
          "useTheme", "setCallMode", "isCallModeActive", "useNotifications",
          "useNotificationContext",
        ],
      }],
      "@typescript-eslint/no-unused-vars": "off",
      // The legacy CRM is not strict-TypeScript yet. Track `any` reduction via
      // typecheck migrations instead of making every existing file fail lint.
      "@typescript-eslint/no-explicit-any": "off",
      "no-empty": ["error", { allowEmptyCatch: true }],
      "@typescript-eslint/no-empty-object-type": "off",
      "@typescript-eslint/ban-ts-comment": "warn",
      "no-control-regex": "off",
      "no-misleading-character-class": "off",
      // Legacy integrations contain intentionally escaped regex characters.
      // Typechecking and focused tests cover behavior while these patterns are migrated.
      "no-useless-escape": "off",
      "no-irregular-whitespace": ["error", { skipRegExps: true }],
      "no-constant-condition": "off",
    },
  },
);
