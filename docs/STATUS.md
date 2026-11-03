# Status

_Updated: 2026-11-03, end of Phase 0._

## What works
- Phase 0 scaffold: Vite 8.3.5, TypeScript 6.0.3, Three.js 0.187.0, Preact 11.1.1, Vitest 5.1.0, ESLint 10.14.0, all pinned exactly in `package.json`, `package-lock.json` committed.
- Placeholder scene: seeded star field, primitive Vessel (hull cylinder, ring torus, drive cone, nose cone, drive glow), orbit camera (drag to orbit, wheel to zoom), FPS counter in a Preact HUD.
- `npm run lint`, `npm test` (7 tests: seeded RNG, FPS meter, palette) and `npm run build` are green locally and in CI.
- `npm run screenshot` (optional) builds, serves and screenshots the scene with Playwright. Verified here; writes `shots/latest.png` (gitignored).
- Lint enforces CLAUDE.md rule 1 for `src/sim/**`: no Three.js, Preact, DOM globals or view-layer imports.

## Deploy
- Live: https://coldtie.github.io/Descent/ (case-sensitive, `/descent/` is a 404). Verified after workflow runs 41575834511 and 41577453826: the page serves `<title>Vessel</title>`, the bundle under `/Descent/assets/` matches the local build, and a headless browser renders the Vessel and drive plume with the HUD at 60 fps.
- Workflow `.github/workflows/pages.yml` runs on every push to `main` and on manual dispatch: `npm ci`, lint, test, build with `VITE_BASE=/<repo name>/`, upload `dist/`, deploy with `actions/deploy-pages`.
- Pages source: this session could not read or change the repository's Pages settings (that API path is blocked through the session's proxy). The deploy from `main` succeeded and the live site serves the new build, so the Actions route works. Steve, please confirm Settings → Pages → Build and deployment → Source reads "GitHub Actions"; if it still says "Deploy from a branch", switch it.
- Leftovers from the Godot project that can be deleted: the `gh-pages` branch and the 18 `claude/run-*` branches on origin.
- The repo is still named `Descent`. Renaming it to Vessel changes the Pages URL and nothing else; the workflow derives the base path from the repo name.

## What is next
- Phase 1: `GameClock` with warp levels and a fixed step accumulator, `GalaxyState` types, named RNG streams on top of `src/sim/rng.ts`, save and load with `schemaVersion` via idb-keyval, determinism tests, a dashboard clock running at every warp level.

## Known bugs
- None in the game.
- `npm audit` reports 11 moderate advisories, all dev-only and transitive (`minimatch` under eslint and typescript-eslint). Not fixable without `npm audit fix --force`, which would move pinned majors; revisit when upstream updates.
