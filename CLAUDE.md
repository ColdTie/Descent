# CLAUDE.md — DESCENT (working title)

## Concept

A turn-based tactical dungeon crawler in the spirit of *Dungeon Crawler Carl*. The
player controls **Carl** descending through a hostile dungeon. Combat is grid-based
and turn-based, resolved like *Baldur's Gate 3*: initiative order, movement budget,
one action per turn, dice-based to-hit and damage. An in-fiction AI ("The System")
narrates events.

This file is the working spec for Claude Code. Build it **one milestone at a time**,
verifying each before moving on. Do not attempt to generate the whole game in one pass.

## What v1 is (and is not)

v1 is a single small combat encounter that proves every core system end to end:
one hand-authored room, Carl, three goblins, a few weapons, an HP/death system,
turn order, player and enemy turns, win/lose, and a stubbed narration log.

v1 is **not** the descent loop, item-choice chests, leveling, procedural levels,
isometric art, audio, or the live AI narrator. Those are roadmap items below. Do not
build them yet, and do not add systems that aren't listed in the v1 task list.

## References

- **Theme / tone:** *Dungeon Crawler Carl* — Carl descends floor by floor; "The System"
  makes announcements; loot and trade-off items. Carl's placeholder look: boxers and an
  open bathrobe, barefoot (lore-accurate, fine as a flat sprite for now).
- **Combat model:** *Baldur's Gate 3* — initiative, move + one action, d20 to-hit vs a
  defense value, weapon damage dice.
- **Eventual visual target (NOT v1):** *Halls of Torment* — isometric dark-fantasy
  dungeon, chest-based "Choose One Item" upgrade screens, equipment slots. v1 uses a
  plain top-down square grid with placeholder sprites; the isometric skin comes later.

## Tech stack & conventions

- **Engine:** Godot 4.x (latest stable). **Language:** GDScript (typed).
- **Verify APIs against the Godot 4 docs before using them.** GDScript is thinly
  represented in training data; do not assume a class or method exists, and do not write
  Python idioms. If unsure, check the docs or test in isolation.
- **Composition over inheritance.** Build behavior from small nodes/scripts and data
  resources, not deep class hierarchies.
- **Separate rules from presentation.** All combat math lives in pure, node-free static
  functions so it can be unit-tested without the scene tree.
- **Determinism.** All randomness goes through one seeded RNG autoload so runs and tests
  are reproducible.
- **Typed GDScript** everywhere (`func f(x: int) -> bool:`), `class_name` where useful.
- **Folders:**
  ```
  /scenes        .tscn files
  /scripts       .gd files (logic)
  /resources     .tres data (weapons, unit defs)
  /tests         unit tests
  /assets        placeholder art
  ```
- Commit after each completed milestone.

## Core design (v1)

### Grid
- Square grid, **12 columns x 10 rows**, hand-authored single room.
- A handful of impassable wall/rock tiles for cover and positioning.
- Use `AStarGrid2D` for pathfinding. One unit per cell; walls and occupied cells block.
- Helpers for world<->cell conversion and "cells reachable within N movement."

### Turn model (BG3-lite)
- At encounter start, each unit rolls **initiative = d20 + 0**; turn order is descending.
  Ties broken by player-first, then spawn order.
- On a unit's turn it has: a **Move** budget (in tiles) and **one Action**.
- Move and Action may be taken in either order; only one Action per turn. (No bonus
  action in v1.)
- **Actions:** Attack (target in weapon range), Use Item (e.g., bandage), or End Turn.

### Combat resolution (pure, tested)
A static resolver, e.g. `CombatResolver.resolve_attack(attacker, defender, weapon, rng) -> Dictionary`
returning `{ "hit": bool, "roll": int, "damage": int, "killed": bool }`.
- To-hit: `d20 + weapon.to_hit` ; hits if `>= defender.defense`.
- Damage on hit: roll `weapon.damage_dice` (e.g. `1d6`).
- Apply damage; `killed = defender.hp <= 0`.
- Must be deterministic given the same RNG seed.

### Enemy AI (goblins)
On its turn, each goblin:
1. Finds the nearest player unit by path distance.
2. If a player is within weapon range, attacks.
3. Otherwise moves up to its Move budget along the shortest path toward that player,
   then attacks if it ends in range.
Deterministic given the seed. No fancy tactics in v1.

### Health
- Every unit has `hp` / `max_hp`. Damage reduces `hp`; at `<= 0` the unit dies and is
  removed from turn order and the grid.
- One consumable, **Bandage**: an Action that heals the user.

### Win / lose
- **Victory:** all goblins dead.
- **Defeat:** Carl dies.
- Either state ends the encounter and shows a result line.

## Data definitions (v1)

### Weapons (resources)
`Weapon` extends `Resource` with `@export` fields: `name`, `range` (tiles),
`to_hit` (int), `damage_dice` (string like `"1d6"`), `is_consumable` (bool),
`heal_dice` (string, for consumables).

| Name        | Type      | Range | To-hit | Damage / Heal |
|-------------|-----------|-------|--------|---------------|
| Rusty Shiv  | melee     | 1     | +2     | 1d4 dmg       |
| Crowbar     | melee     | 1     | +1     | 1d6 dmg       |
| Sling       | ranged    | 4     | +1     | 1d3 dmg       |
| Bandage     | consumable| 0     | —      | 1d6 heal      |

### Units (resources / scenes)
| Unit   | HP | Move | Defense | Loadout              |
|--------|----|------|---------|----------------------|
| Carl   | 12 | 5    | 12      | Rusty Shiv + Bandage |
| Goblin | 5  | 4    | 11      | Goblin Claw (range 1, +2, 1d4) |

Spawn Carl plus **3 goblins** at hand-placed cells.

## Architecture

### Autoloads (singletons)
- **GameRng** — wraps one `RandomNumberGenerator`; seeded from a constant in v1.
  Exposes `roll(sides: int) -> int`, `roll_dice(notation: String) -> int` (e.g. `"2d4"`),
  `d20() -> int`.
- **System** — the narrator seam. `func announce(event: StringName, ctx: Dictionary) -> void`
  pushes a line to the combat log. **v1: pick a canned line from a per-event dictionary.**
  (Events: `battle_start`, `hit`, `miss`, `kill`, `carl_hurt`, `victory`, `defeat`.)
  The signature must stay stable so the body can later be swapped for a live API call
  without touching call sites.

### Scenes / nodes
- `Main.tscn` → loads `BattleScene.tscn`.
- `BattleScene.tscn`: owns `Grid`, `TurnManager`, a `UnitsContainer`, the UI (End Turn
  button, combat log panel, result banner).
- `Grid` (script): grid state, `AStarGrid2D`, occupancy, world<->cell, reachable-cells,
  cell highlighting.
- `Unit.tscn`: `Node2D` + `Sprite2D` + small HP bar; `unit.gd` holds stats and equipped
  `Weapon`; emits signals on damage/death.
- `TurnManager` (script): builds initiative order, tracks current unit and phase, drives
  player input vs. enemy AI, checks win/lose.
- Pure logic scripts (no nodes): `CombatResolver`, dice parsing.

### Input (turn-based, point-and-click)
- Click a highlighted cell to move; click an enemy in range to attack; button to end turn.
- No real-time input. Discrete clicks only.

## v1 milestone task list

Do these in order. Each ends with a concrete verification step; do not proceed until it passes.

1. **Project setup.** Create the Godot 4 project, folder layout, empty `GameRng` and
   `System` autoloads, git init. *Verify:* project opens and runs an empty `Main` scene.
2. **Grid + rendering.** 12x10 grid, walls, `AStarGrid2D`, world<->cell conversion, mouse
   cell highlight. *Verify:* hovering highlights the correct cell; walls are not pathable.
3. **Units + data.** `Weapon` resource, `Unit.tscn`/`unit.gd`, the four weapons and two
   unit types as data; spawn Carl + 3 goblins on hand-placed cells with HP bars.
   *Verify:* all units render on the right cells with correct HP shown.
4. **CombatResolver + tests.** Pure resolver and dice parser; unit tests for determinism
   (same seed → same result), a guaranteed hit, a guaranteed miss, and lethal damage
   setting `killed = true`. *Verify:* all tests pass.
5. **Player turn.** Initiative order, current-unit highlight, move within Move budget via
   pathing, attack an in-range enemy through the resolver, End Turn. *Verify:* you can
   move Carl, attack a goblin, see damage applied, and pass the turn.
6. **Enemy turn (goblin AI).** Goblins path to Carl and attack per the AI rules.
   *Verify:* goblins act on their turns and can damage Carl.
7. **Win/lose + narration log.** Detect victory/defeat; `System.announce` pushes canned
   lines to a log panel for each event. *Verify:* a full playthrough can reach both a win
   and a loss, with matching log lines.
8. **Placeholder polish.** Readable placeholder sprites (Carl in boxers/bathrobe, goblins
   as green figures), simple move/attack tweens. Capture a screenshot and self-check for
   visible defects. *Verify:* a clean screenshot of a running encounter.

## Out of scope for v1
Descent / multiple floors · chest "Choose One Item" upgrades · equipment & inventory UI ·
XP & leveling · procedural generation · isometric or 3D art · audio · live AI narrator.

## Roadmap (later, in rough order)
1. **Descent loop:** chain encounters into floors that go deeper, DCC-style.
2. **Chests & items:** the "Choose One Item" screen with trade-off items (e.g.,
   Philosopher's Stone: +100% all stats, −1000 max HP), equipment slots.
3. **Progression:** XP, levels, more weapons and enemy types.
4. **Live AI narrator:** replace the body of `System.announce` with an async call to the
   Anthropic API (Godot `HTTPRequest`) so The System generates contextual commentary.
   The call sites do not change.
5. **Visual re-skin:** move toward the *Halls of Torment* isometric dark-fantasy look.
6. **Companions & audio.**

## Working agreement for the agent
- Build strictly one milestone at a time and verify before continuing.
- Keep the rules engine pure and node-free; keep randomness behind `GameRng`.
- Write tests for combat logic; run the project / capture screenshots to confirm behavior.
- Verify every Godot 4 GDScript API against the docs; never assume.
- Prefer composition and small scripts over inheritance.
- Commit after each milestone with a short message naming the milestone.
