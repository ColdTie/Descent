# Status

_Updated: 2026-11-03, end of Phase 4._

## What works
- **Phases 0 to 4.** Scaffold and deploy; the headless clock and ledger; the Vessel view in the Overlay direction; a full transit you can win or lose; and now arrival, survey and landing.
- **Arrival and survey.** Arriving at a star generates its system: 2 to 6 bodies (molten, rocky, ice world, gas giant) with ore, ice, gravity and a hazard. The SYSTEM card lists them. Surveying a body takes 30 game days (60 with weak sensors) and reveals its profile. Land on any surveyed body with a surface for 10 Fuel; short of Fuel or with a dead drive, the landing costs Hull, and the button warns when it would be fatal. Landing enters Planetside. The scene draws the star and its bodies, and rings the one you landed on.
- **Transit.** Vessel 1 makes a one-year launch burn to 0.2c, coasts, then brakes over the last 0.1 ly. Both burns cost Fuel. Braking dry costs Hull. Hull at 0 loses the Vessel. Arrival raises an alert and parks the Vessel at the target star.
- **Events.** Four events: micrometeoroid strike, drive fault, reactor flicker, signal detected. Each has two or three choices with their costs shown, and choices you cannot afford are greyed out. An event drops warp to 1x and opens a modal. The galaxy holds still until you answer, by click or with the keys 1 to 3.
- **Repairs.** A `+` beside each gauge repairs that system through the Fabricator: 2 Parts for up to +10, scaled by Fabricator health.
- **Readout.** Shows the burn (launch burn, coasting, braking), fuel, ETA for the whole burn plan, arrival, or loss. The drive plume glows only while burning.
- **Saves.** Schema 3, with migrations from schemas 1 and 2. Every load is validated field by field. A save this build cannot read is kept aside under `vessel.galaxy.unreadable` instead of being overwritten. Resumed and imported galaxies start paused.
- **Review fixes.** Braking starts at the same point at any warp. Logs and alerts are validated on load. A storage read error keeps autosave off so it cannot overwrite the save. Lost Vessels read as lost in the readout and the scene. The event dialog takes and holds keyboard focus. An import no longer leaves hotkeys dead.
- **Tests.** 100, including the Phase 4 exit test (fly, survey every body, land on the most ore-rich landable one, for 10 seeds) and the Phase 3 exit test: across 12 seeds every transit ends in arrival or loss, and at least 10 of them see two or more events. Plus determinism through `Game.tick` with warp, pause and event answers, burn kinematics and fuel, dry braking, loss, alert re-arming, the 10M-to-1x clock, save validation, and star-map connectivity.
- **Browser check, Phase 4.** From a save just short of arrival: arrived at Star 2, surveyed both bodies through the SYSTEM card at 1M warp, landed on the molten world, and the readout switched to Planetside.
- **Browser check, Phase 3.** A headless run played a full transit at 10M warp. Four events were answered through the modal and two repairs made. The Vessel arrived at Star 22 in game year 27, about 85 real seconds.

## Deploy
- Live: https://coldtie.github.io/Descent/ (case-sensitive). Deploys on every push to `main`.
- Please confirm Settings → Pages → Source reads "GitHub Actions". The leftover `gh-pages` and `claude/run-*` branches can be deleted.

## Needs Steve
- **The signal event's detour.** It currently salvages 6 Parts from debris, and what the signal is stays TBD. Change this once LORE.md says what a find is.

## What is next
- **Phase 5, Planetside executive.** A procedural flat-shaded terrain for the landed world with ore and ice nodes, an RTS camera, buildings as boxes and robots as capsules on grid A*, the production chains, a job system driven by priorities and quotas, and the executive panel. Hazards and gravity start to matter here.

## Known bugs
- None known in the game.
- `npm audit` shows 11 moderate advisories, all dev-only and transitive (`minimatch` under eslint). They cannot be fixed without moving pinned majors.
