# Decisions

One line of reasoning each. Newest at the bottom. Design questions that `docs/DESIGN.md` does not answer land here; lore never does.

## Phase 0
- **Exact version pins, no caret ranges.** CLAUDE.md says "pinned"; `package-lock.json` is committed so CI (`npm ci`) builds the same tree.
- **TypeScript pinned at 6.0.3, not the latest 7.0.2.** typescript-eslint 8.72 supports `<6.1`; 7.x would break `npm run lint`. Revisit when typescript-eslint supports 7.
- **`src/sim/rng.ts` exists already (minimal mulberry32).** The star field needs seeded randomness and Vitest needs a real test; Phase 1 adds the named streams on top.
- **FPS counter is a Preact component over a pure `FpsMeter` class.** Proves the dashboard stack end to end while keeping the meter testable without a DOM.
- **Vite `base` comes from `VITE_BASE`, which CI sets to `/${{ github.event.repository.name }}/`.** Renaming the repo later keeps the deploy working with no edit.
- **Pages workflow runs lint and tests before the build.** Cheap, and a red check on `main` is the only CI this project has.
- **`actions/configure-pages` with `enablement: true` stays in the workflow.** No-op while the site exists; creates a workflow-type site if Pages is ever disabled. It does not switch a branch-type site to Actions, that is a repo setting.
- **CI builds on Node 24; `engines` allows `>=22.12`.** Node 24 is the active LTS; the local dev box runs 22 and every pinned tool supports both.
- **`npm run screenshot` is optional and Playwright is not a dependency.** The script resolves `playwright` from the environment and exits 0 with a note when it is missing.
- **One JS chunk; `chunkSizeWarningLimit` raised to 800 kB.** Three.js alone is ~500 kB minified; code splitting buys nothing for a single scene.
- **Placeholder Vessel is cylinder + torus + cone plus a nose cone and an emissive drive glow.** Still primitives, reads better as a ship.
- **Phase 0 step 1 was done in the kickoff order, not PLAN.md's command.** The repo had no `docs/` to keep and `git checkout HEAD -- CLAUDE.md` would have restored the old Godot file; the wipe commit (`Fresh start`) was followed by a second commit adding the four kickoff files verbatim. PLAN.md is left as given.
