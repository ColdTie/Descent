# Status

_Updated: 2026-11-03, end of Phase 2._

## What works
- Phase 0 scaffold (Vite 8, TypeScript 6, Three.js 0.187, Preact 11, Vitest 5, ESLint 10, pinned) and the placeholder scene: seeded star field, primitive Vessel, orbit camera, FPS counter.
- Phase 1 clock and ledger core, all headless in `src/sim/`:
  - `GameClock`: fixed step accumulator, eight warp levels, step length scaling from 1 s to 1 day, 240-step cap per frame.
  - `GalaxyState`: seed, time, warp, pause, named RNG cursors, star map (30 to 60 stars in 50 ly), Vessels with five systems and a stockpile, alerts, per-Vessel log.
  - Vessel 1 starts in transit on a 5 to 15 ly hop at 0.2c; the ledger coasts it and wears its systems per game hour; integrity alerts at 50 / 25 / 10 drop warp to 1x.
  - Commands: `setWarp`, `pause`, `focusVessel`, `dismissAlert` live; the rest typed and refused until their phase.
  - Save and load: JSON with `schemaVersion`, `migrate()` chain, idb-keyval slot, autosave every 2 minutes and on tab hide, export and import buttons, resume paused.
- Phase 2 Vessel view in the Overlay direction (design brief, option B with C's lineage tree):
  - Top strip: clock, pause and warp pills, focused Vessel pill, save / export / import / new galaxy. Hotkeys: Space, `[` `]`, `1` to `8`.
  - Left cards, each foldable and remembered per browser: SYSTEMS (five gauges coloured by the 50 / 25 ladder, worst integrity in the header), STOCKPILE, LINEAGE (tree of all Vessels, click to focus, alert dots), LOG (last 40 entries).
  - Alert banner under the strip with focus and dismiss; fading three-line log bottom left; destination readout bottom right (target, distance left, speed, ETA, progress).
  - Scene: destination marker tinted by the target star's spectral class, slides closer with progress along a dashed track; the departed star recedes behind the camera.
  - Star map now grows as a 5 to 15 ly chain so every Vessel always has a hop in range.
- 56 tests: determinism (same seed and command list gives identical state; `Game.tick` matches `runSteps`), save then load is identity and continues identically, clock bounds at every warp level, star map bounds, ledger wear and alerts, commands, hotkeys.
- `npm run lint`, `npm test`, `npm run build` green. Headless checks confirmed: the clock advances at all eight warp levels; pause holds it; a reload resumes the save paused; at 10M warp the gauges and ETA visibly drop within seconds; an imported save with hull at 49.5 raises the banner and drops warp to 1x; dismiss clears it; the lineage card focuses; fold state survives a reload.

## Deploy
- Live: https://coldtie.github.io/Descent/ (case-sensitive). Deploys on every push to `main` via `.github/workflows/pages.yml`.
- Pages source could not be read from this environment; the Actions deploy works. Please confirm Settings → Pages → Source is "GitHub Actions". Leftover `gh-pages` and `claude/run-*` branches can be deleted.

## What is next
- Phase 3, Transit: accelerate / coast / decelerate with fuel, hull wear and the arrival trigger; four events with two or three choices that drop warp and open a modal; Parts spent on repairs through the Fabricator.

## Known bugs
- None in the game.
- `npm audit`: 11 moderate, dev-only, transitive (`minimatch` under eslint); not fixable without moving pinned majors.
