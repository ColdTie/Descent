import { defineConfig } from 'vitest/config';

// VITE_BASE is `/<repo>/` in CI (set by .github/workflows/pages.yml) and unset locally.
// `||` rather than `??` so an empty string from a misconfigured CI variable still falls back to `/`.
export default defineConfig({
  base: process.env.VITE_BASE || '/',
  build: {
    target: 'es2022',
    // Three.js alone is ~500 kB minified; one chunk is fine for now.
    chunkSizeWarningLimit: 800,
  },
  test: {
    include: ['src/**/*.test.{ts,tsx}'],
    environment: 'node',
  },
});
