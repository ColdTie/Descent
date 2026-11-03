# Status

_Updated: 2026-11-03, end of Phase 5._

## What works
- **Phases 0 to 5.** Scaffold and deploy; the headless clock and ledger; the Vessel view in the Overlay direction; a full transit you can win or lose; arrival, survey and landing; and now a colony that runs itself.
- **Planetside.** Landing opens a 3D world: a flat-shaded heightmap with ore and ice nodes, the landed Vessel at the centre, unsurveyed ground drawn dark. RTS camera: left drag orbits, right drag pans, wheel zooms. Buildings are boxes that rise as they are built; robots are capsules that walk the grid on A*.
- **Colony.** The Vessel lands with a surveyor, two builders and two haulers. The surveyor reveals the map and its nodes. Builders build what is queued. Haulers carry miner output home and feed the Refinery, Cracker and Fabricator. Power comes from the Vessel and solar arrays and is shared out when short. Expand adds miners on surveyed nodes and solar when power runs short, without touching what your own queue needs. A Fabricator turns Metal into Parts and builds robots up to your quotas. Gravity and hazards now slow the parts of the chain they touch.
- **Executive panel (right).** PRIORITIES has five sliders (Survey, Mine, Build, Haul, Expand; 0 switches one off). WORKFORCE has robot quotas with + and −. BUILD has a button per building with its cost, and the queue says what each item waits on (a node, Metal, a builder) and lets you cancel it. STOCKPILE shows rates per game hour.
- **Arrival and survey.** Arriving at a star generates its system: 2 to 6 bodies (molten, rocky, ice world, gas giant) with ore, ice, gravity and a hazard. The SYSTEM card lists them. Surveying a body takes 30 game days (60 with weak sensors) and reveals its profile. Land on any surveyed body with a surface for 10 Fuel; short of Fuel or with a dead drive, the landing costs Hull, and the button warns when it would be fatal. Landing enters Planetside. The scene draws the star and its bodies, and rings the one you landed on.
- **Transit.** Vessel 1 makes a one-year launch burn to 0.2c, coasts, then brakes over the last 0.1 ly. Both burns cost Fuel. Braking dry costs Hull. Hull at 0 loses the Vessel. Arrival raises an alert and parks the Vessel at the target star.
- **Events.** Four events: micrometeoroid strike, drive fault, reactor flicker, signal detected. Each has two or three choices with their costs shown, and choices you cannot afford are greyed out. An event drops warp to 1x and opens a modal. The galaxy holds still until you answer, by click or with the keys 1 to 3.
- **Repairs.** A `+` beside each gauge repairs that system through the Fabricator: 2 Parts for up to +10, scaled by Fabricator health.
- **Readout.** Shows the burn (launch burn, coasting, braking), fuel, ETA for the whole burn plan, arrival, or loss. The drive plume glows only while burning.
- **Saves.** Schema 4, with migrations from schemas 1 to 3. Every load is validated field by field. A save this build cannot read is kept aside under `vessel.galaxy.unreadable` instead of being overwritten. Resumed and imported galaxies start paused.
- **Review fixes.** Braking starts at the same point at any warp. Logs and alerts are validated on load. A storage read error keeps autosave off so it cannot overwrite the save. Lost Vessels read as lost in the readout and the scene. The event dialog takes and holds keyboard focus. An import no longer leaves hotkeys dead.
- **Tests.** 121, including the Phase 5 exit test (land, queue Solar, Ore miner, Refinery, Fabricator, and the robots reach a working Fabricator unaided for at least 4 of 6 seeds), warp independence of the colony within 15%, and the Phase 4 exit test (fly, survey every body, land on the most ore-rich landable one, for 10 seeds) and the Phase 3 exit test: across 12 seeds every transit ends in arrival or loss, and at least 10 of them see two or more events. Plus determinism through `Game.tick` with warp, pause and event answers, burn kinematics and fuel, dry braking, loss, alert re-arming, the 10M-to-1x clock, save validation, and star-map connectivity.
- **Browser check, Phase 5.** Imported a freshly landed save, queued the four buildings from the BUILD card, ran at 10k and 1M warp: the robots built them, the Fabricator came online and made Parts, Expand added miners and solar. Software rendering runs the world scene at about 26 fps; a real GPU will be well above that.
- **Browser check, Phase 4.** From a save just short of arrival: arrived at Star 2, surveyed both bodies through the SYSTEM card at 1M warp, landed on the molten world, and the readout switched to Planetside.
- **Browser check, Phase 3.** A headless run played a full transit at 10M warp. Four events were answered through the modal and two repairs made. The Vessel arrived at Star 22 in game year 27, about 85 real seconds.

## Deploy
- Live: https://coldtie.github.io/Descent/ (case-sensitive). Deploys on every push to `main`.
- Please confirm Settings → Pages → Source reads "GitHub Actions". The leftover `gh-pages` and `claude/run-*` branches can be deleted.

## Needs Steve
- **The signal event's detour.** It currently salvages 6 Parts from debris, and what the signal is stays TBD. Change this once LORE.md says what a find is.

## What is next
- **Phase 6, Drone view.** Tab into any robot: third-person camera, WASD and mouse, warp capped at 1x. Manual survey, carry and build; the ledger treats the piloted robot as the job holder.

## Known bugs
- None known in the game.
- `npm audit` shows 11 moderate advisories, all dev-only and transitive (`minimatch` under eslint). They cannot be fixed without moving pinned majors.
