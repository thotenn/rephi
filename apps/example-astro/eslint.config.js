import eslintReact from "@eslint-react/eslint-plugin";
import js from "@eslint/js";
import { createTypeScriptImportResolver } from "eslint-import-resolver-typescript";
import astro from "eslint-plugin-astro";
import { importX } from "eslint-plugin-import-x";
import jsxA11y from "eslint-plugin-jsx-a11y-x";
import reactHooks from "eslint-plugin-react-hooks";
import { defineConfig, globalIgnores } from "eslint/config";
import globals from "globals";
import tseslint from "typescript-eslint";

export default defineConfig([
  globalIgnores(["dist", ".astro", ".wrangler", "e2e/.results", "e2e/.report"]),
  {
    // React islands and plain TypeScript modules: same rule set as apps/example.
    files: ["**/*.{ts,tsx}"],
    extends: [
      js.configs.recommended,
      tseslint.configs.recommended,
      eslintReact.configs["recommended-typescript"],
      reactHooks.configs.flat.recommended,
      jsxA11y.configs.recommended,
      importX.flatConfigs.recommended,
      importX.flatConfigs.typescript,
    ],
    languageOptions: {
      ecmaVersion: 2022,
      globals: globals.browser,
    },
    settings: {
      // Resolves the `~/*` alias and workspace packages through tsconfig.json.
      "import-x/resolver-next": [
        createTypeScriptImportResolver({ project: `${import.meta.dirname}/tsconfig.json` }),
      ],
    },
    rules: {
      // eslint-plugin-react-hooks (maintained by the React team) owns the hooks
      // rules, so the @eslint-react copies of the same checks are switched off.
      "@eslint-react/error-boundaries": "off",
      "@eslint-react/exhaustive-deps": "off",
      "@eslint-react/purity": "off",
      "@eslint-react/rules-of-hooks": "off",
      "@eslint-react/set-state-in-effect": "off",
      "@eslint-react/set-state-in-render": "off",
      "@eslint-react/static-components": "off",
      "@eslint-react/unsupported-syntax": "off",
      "@eslint-react/use-memo": "off",

      // `astro:*` modules are virtual: they only exist inside Astro's bundler.
      "import-x/no-unresolved": ["error", { ignore: ["^astro:"] }],

      // The shared library must be imported through `~/lib/rephi`, which applies
      // the runtime configuration first. Types are erased, so they are allowed.
      "@typescript-eslint/no-restricted-imports": [
        "error",
        {
          paths: [
            {
              name: "@rephi/shared-components",
              message: "Import from '~/lib/rephi' so the runtime configuration is applied.",
              allowTypeImports: true,
            },
          ],
        },
      ],
    },
  },
  // `.astro` files: the frontmatter is linted as TypeScript, the template with
  // Astro's recommended rules plus accessibility checks for the static markup.
  // Astro's configs come last so that its parser handles the files.
  {
    files: ["**/*.astro"],
    extends: [js.configs.recommended, tseslint.configs.recommended],
    rules: {
      // Covered by TypeScript itself and by the @typescript-eslint variants.
      "no-undef": "off",
      "no-unused-vars": "off",
    },
  },
  astro.configs["flat/recommended"],
  astro.configs["flat/jsx-a11y-recommended"],
  {
    files: ["*.config.{js,ts}"],
    extends: [js.configs.recommended, tseslint.configs.recommended],
    languageOptions: {
      globals: globals.node,
    },
  },
  {
    files: ["e2e/**/*.ts"],
    languageOptions: {
      globals: globals.node,
    },
  },
  {
    languageOptions: {
      parserOptions: {
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
]);
