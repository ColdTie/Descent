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

## Phase 1
- **Game time is integer seconds since the galaxy epoch; the clock shows Y · D · HH:MM.** DESIGN.md says Year / Day / Hour; minutes make 1x and 10x visibly move.
- **Step length is `clamp(warp / 100, 1 s, 1 day)`.** One second at 1x, one day at 10M, never more than ~116 steps per real second, so per-frame cost is bounded at every level.
- **At most 240 steps per frame; the rest of the accumulated time is dropped, not caught up.** A stalled tab resumes smoothly instead of spiralling; the dropped amount is reported by the clock.
- **Warp and pause live in `GalaxyState`; `GameClock` holds only the accumulator.** The ledger is the truth, so the clock has nothing to save.
- **Commands apply at step boundaries; while paused they apply on the next frame.** Keeps determinism (same seed + same commands by step = same state) without making a paused UI unresponsive.
- **Integrity alerts at 50 / 25 / 10 are the Phase 2 stand-in for events.** They drop warp to 1x like events will; `dismissAlert` is added to the command list to clear them.
- **RNG streams keep their cursor in `state.rng`.** `streamRng` writes back on every draw, so a save resumes the exact sequence; the galaxy stream is only used at creation, worlds and events are reserved.
- **Placeholder names: Vessel 1, Home, Star N.** LORE.md says names are TBD and placeholders are fine.
- **Persistence lives in `src/persist/`, outside `src/sim`.** idb-keyval touches IndexedDB, which is DOM; sim stays headless and only knows JSON.
- **Autosave every two minutes and on tab hide; export is a JSON download; import replaces the galaxy and saves at once.** Straight from DESIGN.md; one save slot until Phase 8 adds slots.
- **A resumed galaxy starts paused.** The player sees where things stand before decades run; Space resumes.
- **New galaxy needs a second click within three seconds.** No `confirm()` dialogs; the notice line explains.
- **Later-phase commands exist as types and are refused at runtime.** Callers can be written against the full command list now; the refusal reason reaches the notice line.

## Phase 2
- **UI direction is B (Overlay) with C's lineage tree as a drawer** (chosen by Steve from the design brief). Full-bleed scene, pill strip on top, foldable cards on the left, fading log bottom left, destination readout bottom right.
- **The star map grows as a chain: each new star is placed 5 to 15 ly from one already placed, never closer than 2 ly to another.** A uniform 30 to 60 stars in 50 ly often had no star within hop range of home; the chain guarantees a hop from every star and a connected map.
- **Card fold state is remembered in `localStorage`, not in the save.** It is a per-browser convenience, so it stays out of `GalaxyState` and out of determinism.
- **The alert banner shows the newest alert and a count of the rest; integrity alerts are `warn` below 50 and `critical` below 25 and 10**, the same ladder the gauge colours use.
- **Destination marker sits 60 scene units ahead at departure and 10 on arrival; the departed star sits behind the camera.** The scene reads `transitSummary()` from the ledger each frame and writes nothing back.
- **The camera orbits a point 7 units ahead of the Vessel.** Keeps the drive plume and the destination in one default framing.
- **Systems card shows the worst integrity in its header badge; the log card shows the last 40 entries; the fading log the last 3.** Enough to read the ship at 10M warp without opening anything.

## Phase 3
- **Transit is three burns: a one-year launch burn to 0.2c (0.1 ly), a coast, and a braking burn over the last 0.1 ly.** Constant 0.2c per year in both burns; braking starts when the remaining distance equals the stopping distance.
- **Both burns cost Fuel, 30 per year of burn; a Vessel starts with 100.** DESIGN.md only names the braking burn; charging the launch too makes Fuel a resource across the whole hop and leaves a 40 margin for events.
- **Braking without Fuel or Drive still slows the Vessel but costs Hull, 60 per dry year.** "Arrive short and take hull damage" without a stranded Vessel; a long dry brake on a weak hull loses it.
- **A Vessel is lost when Hull reaches 0; it becomes phase `lost` and the ledger stops moving it.** Slice rule from DESIGN.md.
- **System couplings: Drive below 25 doubles burn Fuel; Power at 0 doubles wear on the others; Sensors below 25 make debris strikes 1.5× worse; Fabricator integrity scales repairs.** Each system matters without new mechanics.
- **Events roll at 0.15 per game year per Vessel in transit, at most one open per Vessel.** A 25 to 75 year hop sees about 4 to 11; the exit criterion needs two.
- **An open event holds the whole galaxy: no steps run until it is answered.** Simplest reading of "events pull you back"; it also keeps unfocused Vessels from racing ahead while the player decides.
- **The frame stops at the first step that raises an alert or opens an event, and the warp drop happens inside the sim step.** Fixes the Phase 1 review finding that 28+ day-steps ran past an alert at 10M, and keeps `Game.tick` and `runSteps` identical.
- **The clock keeps its leftover in real seconds, and resets when an event stops the frame.** A 10M remainder no longer becomes a 240-step burst after dropping to 1x.
- **Integrity thresholds re-arm once a system is repaired back above them.** Repairs exist now, so a second crossing must alert again.
- **The signal event's detour salvages 6 Parts from nearby debris; what the signal is stays TBD.** A mechanical reward that claims nothing about lore. Steve may want to change this once LORE.md says what a find is.
- **Repairs are a `repair` command: 2 Parts for up to +10 integrity, scaled by Fabricator integrity, instant.** Added to the command list alongside `dismissAlert`; DESIGN.md says "Parts repair through the Fabricator" and nothing about time.
- **Schema 2.** Transits gain `cruiseC`, `burn` and `dryBurn`; the galaxy gains `events` and `nextEventId`; phase `lost` is new. The 1→2 migration puts a v1 Vessel in the coast at its old speed.
- **Every load is validated field by field; a save that fails is refused with the field named and kept aside under `vessel.galaxy.unreadable` before the autosave can overwrite it.** From the Phase 1 and 2 reviews: a malformed import could brick the page.
- **Resumed and imported galaxies start paused through the `pause` command**, not by writing state from `main.ts` (CLAUDE.md rule 3).
- **Space and Enter on a keyboard-focused button activate the button; a mouse click drops focus so the next Space pauses.** Fixes keyboard access to cards without breaking click-then-Space.
- **ESLint now guards `src/content` too, and also bans `Math.random`, `Date.now`, `new Date`, timers, `performance` and `idb-keyval`/`persist` imports in the sim.** From the Phase 1 review.
- **A coasting step that reaches the stopping point is split there.** Braking starts at the same place at any warp; before, a day step at 10M could start it late and save a borderline Vessel that dies at 1x (Phase 3 review).
- **Autosave stays off when the stored save could not be read or set aside**, until the player saves, imports or starts a new galaxy by hand. A storage hiccup must never cost the only copy.
- **An error boundary keeps export and new galaxy on screen if the dashboard ever fails to draw.** Validation is the first line; this is the last.
- **While an event is open, the dashboard behind it is `inert` and focus moves into the dialog and stays there.** Keys and clicks can only answer the event.
