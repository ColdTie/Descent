# Status

_Updated: Phase 0, 2026-11-03._

## What works
- Phase 0 scaffold: Vite 8 + TypeScript 6 + Three.js 0.187 + Preact 11 + Vitest 5 + ESLint 10, all pinned in `package.json`.
- Placeholder scene: seeded star field, primitive Vessel (hull cylinder, ring torus, drive cone, nose cone, drive glow), orbit camera (drag to orbit, wheel to zoom), FPS counter in a Preact HUD.
- `npm run lint`, `npm test` (7 tests: seeded RNG, FPS meter, palette) and `npm run build` are green.
- `npm run screenshot` renders the scene headlessly with Playwright when it is available and writes `shots/latest.png`.
- GitHub Pages workflow (`.github/workflows/pages.yml`): lint, test, build with `VITE_BASE=/<repo>/`, upload `dist/`, deploy with `actions/deploy-pages`.

## Deploy
- TBD (filled in after the first run).

## What is next
- Phase 1: `GameClock`, `GalaxyState` types, named RNG streams, save and load with `schemaVersion`, determinism tests.

## Known bugs
- None yet.
