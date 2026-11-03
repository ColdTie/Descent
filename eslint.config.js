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
    files: ['src/sim/**/*.ts', 'src/content/**/*.ts'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: ['three', 'three/*', 'preact', 'preact/*', 'idb-keyval', '**/render/*', '**/ui/*', '**/input/*', '**/persist/*'],
              message: 'src/sim imports nothing from Three.js, Preact, the DOM or the view layers (CLAUDE.md rule 1).',
            },
          ],
        },
      ],
      'no-restricted-globals': ['error', 'window', 'document', 'navigator', 'requestAnimationFrame', 'localStorage', 'indexedDB', 'performance', 'setTimeout', 'setInterval', 'globalThis', 'self', 'location', 'crypto'],
      'no-restricted-properties': [
        'error',
        { object: 'Math', property: 'random', message: 'Use the seeded RNG in src/sim/rng.ts.' },
        { object: 'Date', property: 'now', message: 'Game time lives in GalaxyState.time.' },
      ],
      'no-restricted-syntax': ['error', { selector: 'NewExpression[callee.name="Date"]', message: 'Game time lives in GalaxyState.time.' }],
    },
  },
  {
    // Tests may time themselves and read the wall clock; they are not the sim. The import bans above still apply.
    files: ['src/**/*.test.ts'],
    rules: {
      'no-restricted-globals': 'off',
      'no-restricted-properties': 'off',
      'no-restricted-syntax': 'off',
    },
  },
]);
