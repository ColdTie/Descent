# Build plan

Each phase ends with its exit criteria met, `npm test` and `npm run build` green, a commit pushed, and `docs/STATUS.md` updated. Session counts are rough Claude Code sessions.

## Phase 0: Fresh start and scaffold (1 session)
1. Remove every tracked file except `CLAUDE.md` and `docs/`, keeping history: `git rm -r -q . && git checkout HEAD -- CLAUDE.md docs && git commit -m "Fresh start"`.
2. Scaffold Vite + TypeScript + Three.js + Preact + Vitest + ESLint. Add `CLAUDE.md`, `docs/`, `CREDITS.md`, `docs/STATUS.md`, `docs/DECISIONS.md`.
3. Pages workflow: build on push to main with `VITE_BASE=/<repo name>/`, upload `dist/` with `actions/upload-pages-artifact`, deploy with `actions/deploy-pages`. The repo's Pages source must be set to GitHub Actions; if it is set to a branch, switch it.
4. Placeholder scene: star field, a primitive Vessel (cylinder, torus, cone), orbit camera, FPS counter.

Exit: the Pages URL shows the placeholder Vessel.

## Phase 1: Clock and ledger core (1 to 2 sessions)
- `GameClock`: warp levels, pause, fixed step accumulator with warp scaled step length.
- `GalaxyState` types: galaxy seed, star map, Vessels, worlds, lineage.
- Seeded RNG with named streams (galaxy, worlds, events).
- Save and load: JSON with `schemaVersion`, idb-keyval, export and import buttons, autosave.
- Tests: the same seed and the same command list produce identical state after N steps; save then load is identity.

Exit: tests green; the dashboard shows the clock running at every warp level.

## Phase 2: Vessel view v0 (1 to 2 sessions)
- Preact dashboard over the canvas: clock and warp controls, five system gauges, stockpile, event log, alert banner.
- SpaceScene: Vessel, star field, destination marker, distance and ETA readout.

Exit: warp to 10M and watch the systems wear down in the panel.

## Phase 3: Transit (1 to 2 sessions)
- Transit ledger: accelerate, coast, decelerate; fuel; hull wear; arrival trigger.
- Four events with two or three choices each; an event drops warp and opens a modal.
- Parts spent on repairs through the Fabricator.

Exit: one full transit from launch to arrival with at least two events, surviving or losing the Vessel.

## Phase 4: Arrival and survey (1 session)
- Procedural star system from the seed: 2 to 6 bodies with resource profiles and hazards.
- Survey costs game time per body and reveals its profile. Pick a world. Land.

Exit: land on a chosen world and enter Planetside.

## Phase 5: Planetside, executive (2 to 3 sessions)
- WorldScene: procedural flat shaded terrain, ore and ice nodes, RTS camera (orbit, pan, zoom).
- Buildings as boxes, robots as capsules, grid A* pathing.
- Economy ledger: the production chains in DESIGN.md; a job system driven by priorities and quotas; haulers move stock; builders work the queue.
- Executive panel: priority sliders, build queue, quotas, stockpile.

Exit: from landing, the world reaches a working Fabricator with no manual robot control.

## Phase 6: Drone view (1 to 2 sessions)
- Tab into any robot: third person camera, WASD and mouse, warp capped at 1x.
- Manual survey, carry and build actions; the ledger treats the piloted robot as the job holder.
- Camera transitions between executive and drone view.

Exit: pilot a builder to finish a building by hand, Tab out, and the ledger carries on.

## Phase 7: Replicate, lineage, launch (2 sessions)
- Shipyard building and its multi resource, multi hour build.
- New Vessel entity on completion; lineage tree panel; focus switching; unfocused worlds continue on the ledger; hydrate on refocus.
- Launch: pick a target star on a 2D star map panel; the Vessel enters Transit.
- Alerts from unfocused Vessels surface in the lineage panel and drop warp.

Exit: a second Vessel launches while the first keeps mining.

## Phase 8: Close the loop and tune (1 to 2 sessions)
- The second Vessel completes transit, arrival, planetside and replication.
- First hour tuning: starting stock, rates, event frequency, warp feel.
- Settings panel, keybind reference, save slots.

Exit: the slice goal from DESIGN.md, a second Vessel completing a full cycle.

## After the slice (backlog, rough order)
Art pass with CC0 packs and the palette. More transit and planetside events. Navmesh pathing. Idle catch up toggle. Audio. Mannies and ruins (needs lore). Supabase shared galaxy. Physics only if something needs it.

## Kickoff prompt for the first Claude Code session
Read CLAUDE.md, docs/DESIGN.md and docs/PLAN.md. Do Phase 0 exactly as written, confirm the Pages deploy works, update docs/STATUS.md, then stop and report.
