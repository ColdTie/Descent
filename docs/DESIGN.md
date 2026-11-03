# Vessel (working title): design doc v0

## Pitch
You are the mind of an interstellar probe. Cross to a star over decades, land, direct a robot workforce to turn rock and ice into industry, build a copy of yourself, and launch it. Every copy keeps going. One persistent galaxy, many Vessels alive at once, and you can be any of them.

## Pillars
1. Executive, not micromanager. You set priorities and quotas; robots organize themselves. Step into any drone when you want hands on.
2. Time is the resource you spend. Warp through the quiet decades; events pull you back.
3. The galaxy keeps running. Unfocused Vessels progress on the ledger. Switching Vessels is the Bobiverse feeling.
4. Ugly first. The loop has to be fun with boxes before anything is pretty.

## The loop
| Phase | You do | View | Ends when |
|---|---|---|---|
| Transit | Watch systems, answer events, spend Parts on repairs, accept or refuse detours | Vessel | Arrival at the target star |
| Arrival | Survey bodies (takes game time), pick a world, land | Vessel | Landed |
| Planetside | Set priorities, queue buildings, grow the workforce, pilot a drone when you like | Both | Shipyard completes a Vessel |
| Replicate | Build hull, drive and mind core; the copy wakes as a new Vessel | Vessel | Copy exists in the lineage tree |
| Launch | Choose a target star for the copy (or for yourself) | Vessel | That Vessel enters Transit |

A Vessel that stays behind keeps developing its world on the ledger.

## Time
- One galactic clock in game seconds since epoch, shown as Year / Day / Hour.
- Warp levels: 1, 10, 100, 1k, 10k, 100k, 1M, 10M. Space pauses. Any event drops warp to 1x and raises an alert. Alerts from unfocused Vessels appear in the lineage panel.
- Drone view caps warp at 1x.
- Cruise speed about 0.2c (tunable) and hops of 5 to 15 light years, so a quiet transit is a few real minutes at max warp.
- Fixed step accumulator; step length scales with warp so per frame cost stays bounded. Rates are per game hour and integrate linearly within a step. Events resolve on step boundaries.

## Two fidelities
The ledger simulates every Vessel every step: stockpiles, production rates, build queues, system wear, event rolls. The focused Vessel also gets a 3D scene hydrated from that ledger. Nothing in the scene is authoritative. Refocusing a Vessel rebuilds its scene from the ledger.

## Control
- Executive panel (default): priority sliders for Survey, Mine, Build, Haul and Expand; a build queue; quotas such as "2 miners per ore node". Robots pick jobs by priority, then distance.
- Drone view: Tab into any robot. Third person, WASD and mouse. Manual actions: survey a node, carry, build. Tab out returns to the executive panel and the ledger resumes the job.

## Vessel systems (transit)
Power, Drive, Hull, Fabricator, Sensors. Each has integrity 0 to 100 and a wear rate. Parts repair through the Fabricator. The deceleration burn consumes Fuel; arrive short and the Vessel takes hull damage.

Transit events for v0: micrometeoroid strike, drive fault, reactor flicker, signal detected (detour or log it). Each is one alert with two or three choices.

## Planetside economy (v0, deliberately tiny)
- Resources: Ore, Metal, Volatiles, Fuel, Parts, Power.
- Nodes: ore deposits and ice fields, revealed by survey.
- Buildings: Solar array, Miner (on a node), Refinery (Ore to Metal), Cracker (Volatiles to Fuel), Fabricator (Metal to Parts), Depot, Shipyard.
- Robots: Surveyor, Hauler, Builder. Built at the Fabricator from Parts.
- Replication: the Shipyard consumes Metal, Parts and Fuel over many game hours to produce a Vessel.

## Galaxy and structure
- Procedural star map from the galaxy seed: 30 to 60 stars within about 50 light years. Planets generate lazily on arrival.
- Many Vessels live. Lineage tree panel: root Vessel at the top, copies branching below, each node showing phase, location and alerts. Click to focus.
- Persistent single player save in IndexedDB. Autosave every two minutes and on tab hide. JSON export and import. Shared galaxies through Supabase are a later option, not a v1 goal.
- No win state in v0. A Vessel can be lost (Hull at 0). Slice goal: a second Vessel completes a full cycle.

## Look
Low poly flat shaded. The Vessel is built from primitives: long hull, ring, drive. Robots and buildings come from CC0 packs later; boxes and capsules now. Procedural terrain is a flat shaded heightmap with vertex colors by biome. Small fixed palette. Desktop only.

## Out of scope for the slice
Combat, mannies, alien civilizations and ruins, idle progress while away, multiplayer, audio, physics, navmesh, touch.

## Universe hooks the game needs
See `docs/LORE.md` (Steve owns it): what a Vessel is and why it replicates, how copies are named, what Vessels are looking for, what counts as a find on a world.
