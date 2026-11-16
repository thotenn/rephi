import js from "@eslint/js";
import reactHooks from "eslint-plugin-react-hooks";
import { defineConfig, globalIgnores } from "eslint/config";
import globals from "globals";
import tseslint from "typescript-eslint";

export default defineConfig([
  globalIgnores(["dist"]),
  {
    files: ["**/*.{ts,tsx,mts}"],
    extends: [
      js.configs.recommended,
      tseslint.configs.recommended,
      reactHooks.configs.flat.recommended,
    ],
    languageOptions: {
      ecmaVersion: 2020,
      globals: globals.browser,
      // One ESLint process can lint every workspace (the editor integration
      // does): anchor typescript-eslint to this package's tsconfig.
      parserOptions: { tsconfigRootDir: import.meta.dirname },
    },
  },
  {
    files: ["*.config.{js,mjs,ts,mts}"],
    languageOptions: {
      globals: globals.node,
    },
  },
]);
