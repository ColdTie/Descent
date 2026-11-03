import js from '@eslint/js';
import { defineConfig, globalIgnores } from 'eslint/config';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default defineConfig([
  globalIgnores(['dist', 'node_modules', 'shots']),
  {
    files: ['**/*.{js,mjs,ts,tsx}'],
    extends: [js.configs.recommended, tseslint.configs.recommended],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: { ...globals.browser, ...globals.node },
    },
  },
  {
    // CLAUDE.md rule 1: src/sim is headless and deterministic. Lint is the CI gate, so enforce it here.
    files: ['src/sim/**/*.ts'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: ['three', 'three/*', 'preact', 'preact/*', '**/render/*', '**/ui/*', '**/input/*'],
              message: 'src/sim imports nothing from Three.js, Preact, the DOM or the view layers (CLAUDE.md rule 1).',
            },
          ],
        },
      ],
      'no-restricted-globals': ['error', 'window', 'document', 'navigator', 'requestAnimationFrame', 'localStorage', 'indexedDB'],
    },
  },
]);
