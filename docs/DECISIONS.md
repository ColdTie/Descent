# Decisions

One line of reasoning each. Newest at the bottom. Design questions that `docs/DESIGN.md` does not answer land here; lore never does.

## Phase 0
- **Exact version pins, no caret ranges.** CLAUDE.md says "pinned"; `package-lock.json` is committed so CI (`npm ci`) builds the same tree.
- **TypeScript pinned at 6.0.3, not the latest 7.0.2.** typescript-eslint 8.72 supports `<6.1`; 7.x would break `npm run lint`. Revisit when typescript-eslint supports 7.
- **`src/sim/rng.ts` exists already (minimal mulberry32).** The star field needs seeded randomness and Vitest needs a real test; Phase 1 adds the named streams on top.
- **FPS counter is a Preact component over a pure `FpsMeter` class.** Proves the dashboard stack end to end while keeping the meter testable without a DOM.
- **Vite `base` comes from `VITE_BASE`, which CI sets to `/${{ github.event.repository.name }}/`.** Renaming the repo later keeps the deploy working with no edit.
- **Pages workflow runs lint and tests before the build.** Cheap, and a red check on `main` is the only CI this project has.
- **`actions/configure-pages` runs without `enablement`.** It only reads the existing Pages site; `enablement: true` needs a PAT or App token, which `GITHUB_TOKEN` is not. Enabling Pages or switching a branch-type site to Actions is a repo setting Steve owns.
- **CI builds on Node 24; `engines` is `^22.13 || ^24 || >=26`, the intersection of the pinned tools' own ranges.** Node 24 is Maintenance LTS until 2028-04 and the local dev box runs 22; both are supported by every pinned tool.
- **`npm run screenshot` is optional and Playwright is not a dependency.** The script resolves `playwright` from the environment and exits 0 with a note when it is missing.
- **One JS chunk; `chunkSizeWarningLimit` raised to 800 kB.** Three.js alone is ~500 kB minified; code splitting buys nothing for a single scene.
- **Placeholder Vessel is cylinder + torus + cone plus a nose cone and an emissive drive glow.** Still primitives, reads better as a ship.
- **Phase 0 step 1 was done in the kickoff order, not PLAN.md's command.** The repo had no `docs/` to keep and `git checkout HEAD -- CLAUDE.md` would have restored the old Godot file; the wipe commit (`Fresh start`) was followed by a second commit adding the four kickoff files verbatim. PLAN.md is left as given.
- **Views may seed their own `createRng(seed)` for cosmetics, never a sim stream.** `StarField` uses a fixed seed so screenshots are stable; drawing from a sim stream would change sim results with the camera.
- **The orbit camera lives in `src/render/SpaceScene.ts` for now.** CLAUDE.md puts cameras under `src/input/`; the RTS and drone cameras go there in Phases 5 and 6 and this one moves with them.
- **`src/main.ts` owns the requestAnimationFrame loop and clamps `dt` to 0.25 s.** A hidden tab does not catch up on return; Phase 1's `GameClock` is fed this clamped value.
- **Vessel axis convention: nose +Z, Y up, about 8 units long.** Placeholder roll of 0.15 rad/s is cosmetic.
- **Preact JSX is wired through tsconfig (`jsx: react-jsx`, `jsxImportSource: preact`), no `@preact/preset-vite`.** Vite 8's transform honours it; prefresh HMR can be added if hot reload of UI ever matters.
- **Tests are colocated as `src/**/*.test.{ts,tsx}` and run in Vitest's `node` environment.** Pure classes get unit tests; Preact components do not, which keeps tests DOM-free.
- **ESLint enforces CLAUDE.md rule 1.** `src/sim/**` cannot import Three.js, Preact or the view layers, nor touch `window`, `document` and friends; lint already gates the deploy.
- **Flat shaded `MeshStandardMaterial` under a directional sun plus a hemisphere fill.** Reads as low poly with no extra work; unlit materials lose the facet look.
- **Pages concurrency does not cancel in-flight deploys** (`cancel-in-progress: false`), matching GitHub's starter workflow; queued runs still collapse to the latest. Permissions are per job: the build job gets read-only scopes, only the deploy job can mint the OIDC token and create a Pages deployment.
- **`shots/` is gitignored, `scripts/*.mjs` is plain JS outside `tsc`, and `README.md` exists for GitHub's landing view.** None of these are in CLAUDE.md's layout; all are small.
