# CLAUDE.md

Working title: Vessel (rename later). A 3D management game set in Steve's Vessel Metanoia universe. You are the mind of an interstellar probe: cross to a star over decades, land, direct a robot workforce, build a copy of yourself, launch it. Many Vessels live at once in one persistent galaxy, and the player can be any of them.

Read `docs/DESIGN.md` (what the game is) and `docs/PLAN.md` (what to build, in order) before writing code. `docs/LORE.md` is owned by Steve: read it, never edit it, never invent lore beyond it. Anything marked TBD stays TBD in the game.

## Stack
- Vite + TypeScript + Three.js (current stable, pinned in package.json). Preact for the HTML dashboard. Vitest for sim tests. idb-keyval for saves.
- No physics engine and no navmesh library in the slice. Kinematic robots on a terrain heightmap with grid A*. Add Rapier or a navmesh only when a phase in `docs/PLAN.md` calls for it.
- Deploy: a GitHub Actions workflow builds `dist/` and deploys to GitHub Pages on every push to main. Vite `base` comes from `VITE_BASE` (`/<repo>/` in CI, `/` locally).

## Architecture rules
1. `src/sim/` is the game. It is headless and deterministic and imports nothing from Three.js or the DOM. All randomness comes from the seeded RNG in `src/sim/rng.ts`.
2. The ledger is the truth. Every Vessel and every world is advanced by the ledger every step, on screen or not. 3D scenes (`src/render/`) and UI (`src/ui/`) are views that read sim state. They never mutate it.
3. All player intent is a command (`src/sim/commands.ts`): setWarp, pause, focusVessel, setPriority, queueBuild, setQuota, pilotRobot, resolveEvent, launch. UI, hotkeys and the drone view all dispatch commands. Nothing else writes state.
4. One galactic clock. Fixed step accumulator; step length scales with warp (one game second at 1x, up to one game day at max warp). Rates are per game hour and integrate linearly inside a step. Events resolve on step boundaries and drop warp to 1x.
5. A save is JSON of `GalaxyState` with a `schemaVersion`. Migrations live in `src/sim/migrations.ts`. Never break an old save silently.
6. Only the focused Vessel gets a 3D world scene. It is hydrated from ledger state on focus and torn down on unfocus. Robot positions in unfocused worlds are not tracked; on hydrate, robots are placed at their job sites.

## Working agreement
- Build in the order of `docs/PLAN.md`. Meet a phase's exit criteria, run `npm test` and `npm run build`, commit, push. Small commits.
- Ugly is fine. Placeholders are colored primitives. Never block a phase on art, audio or lore.
- When art arrives, the rule is low poly flat shaded: `flatShading: true`, a small palette in `src/render/palette.ts`, CC0 GLTF only, credits in `CREDITS.md`.
- Desktop, mouse and keyboard only. No touch, no gamepad.
- When `docs/DESIGN.md` does not answer a design question, pick the simplest option, implement it, and log it in `docs/DECISIONS.md` with one line of reasoning. Stop and ask only if the choice touches lore or changes the loop.
- Keep `docs/STATUS.md` current: what works, what is next, known bugs. Steve reads this, not the commit log.

## Commands
- `npm run dev`, `npm run build`, `npm test`, `npm run lint`
- `npm run screenshot` (optional, Playwright): saves `shots/latest.png` of the current scene when Chromium is available in the environment.

## Layout
```
src/main.ts
src/sim/        clock, state, rng, commands, ledger, economy, events, migrations
src/render/     SpaceScene, WorldScene, palette, primitives
src/ui/         Preact dashboard, panels, lineage tree, alerts
src/input/      hotkeys, RTS camera, drone controls
src/content/    data tables: resources, buildings, robots, events, star classes
public/models/  CC0 GLTF (later)
docs/           DESIGN.md, PLAN.md, LORE.md, DECISIONS.md, STATUS.md
.github/workflows/pages.yml
```
