# Status

_Updated: 2026-11-03, end of Phase 1._

## What works
- Phase 0 scaffold (Vite 8, TypeScript 6, Three.js 0.187, Preact 11, Vitest 5, ESLint 10, pinned) and the placeholder scene: seeded star field, primitive Vessel, orbit camera, FPS counter.
- Phase 1 clock and ledger core, all headless in `src/sim/`:
  - `GameClock`: fixed step accumulator, eight warp levels, step length scaling from 1 s to 1 day, 240-step cap per frame.
  - `GalaxyState`: seed, time, warp, pause, named RNG cursors, star map (30 to 60 stars in 50 ly), Vessels with five systems and a stockpile, alerts, per-Vessel log.
  - Vessel 1 starts in transit on a 5 to 15 ly hop at 0.2c; the ledger coasts it and wears its systems per game hour; integrity alerts at 50 / 25 / 10 drop warp to 1x.
  - Commands: `setWarp`, `pause`, `focusVessel`, `dismissAlert` live; the rest typed and refused until their phase.
  - Save and load: JSON with `schemaVersion`, `migrate()` chain, idb-keyval slot, autosave every 2 minutes and on tab hide, export and import buttons, resume paused.
- Dashboard top strip (Overlay direction): clock pill, pause and warp pills, save / export / import / new galaxy. Hotkeys: Space, `[` `]`, `1` to `8`.
- 49 tests: determinism (same seed and command list gives identical state; `Game.tick` matches `runSteps`), save then load is identity and continues identically, clock bounds at every warp level, star map bounds, ledger wear and alerts, commands, hotkeys.
- `npm run lint`, `npm test`, `npm run build` green; headless check confirmed the clock advancing at all eight warp levels, pause holding it, and a reload resuming the save.

## Deploy
- Live: https://coldtie.github.io/Descent/ (case-sensitive). Deploys on every push to `main` via `.github/workflows/pages.yml`.
- Pages source could not be read from this environment; the Actions deploy works. Please confirm Settings → Pages → Source is "GitHub Actions". Leftover `gh-pages` and `claude/run-*` branches can be deleted.

## What is next
- Phase 2, Vessel view v0 in the chosen Overlay direction: systems card with five gauges, stockpile and lineage drawers, fading event log, alert banner, destination marker with distance and ETA in the scene.

## Known bugs
- None in the game.
- `npm audit`: 11 moderate, dev-only, transitive (`minimatch` under eslint); not fixable without moving pinned majors.
