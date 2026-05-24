# CLAUDE.md — DESCENT (working title)

## Concept

A turn-based tactical dungeon crawler in the spirit of *Dungeon Crawler Carl*. The
player controls **Carl** descending through a hostile dungeon. Combat is grid-based
and turn-based, resolved like *Baldur's Gate 3*: initiative order, movement budget,
one action per turn, dice-based to-hit and damage. An in-fiction AI ("The System")
narrates events.

This file is the working spec for Claude Code. Build it **one milestone at a time**,
verifying each before moving on. Do not attempt to generate the whole game in one pass.

---

## Current State (as of v2)

All 8 v1 milestones are complete and committed. Two playable versions exist:

### Godot 4 project — `/home/user/descent/`
- Engine: Godot 4.4, GL Compatibility renderer (required for web export)
- Grid: 12×10, CELL_SIZE=64, 9 hand-authored wall cells
- Units: Carl + 3 Goblins; 5 weapons as `.tres` resources
- Full turn loop, player input, goblin AI, tweens, death-fade, win/lose
- Narrator: `System.gd` autoload with canned lines per event
- RNG: `GameRng.gd` autoload, seeded XOR-shift, deterministic
- Tests: `tests/TestCombatResolver.gd` — dice range, determinism, hit/miss/lethal
- Export preset: `export_presets.cfg` targeting `build/web/index.html`

**Known gotchas (Godot 4.4 specific):**
- `AStarGrid2D`: call `_astar.update()` **before** `set_point_solid()` — calling update
  after solid points clears them.
- `Grid.find_path()` is intentionally NOT named `get_path` — that conflicts with
  `Node.get_path() -> NodePath` and causes a parser error in Godot 4.4.
- `path.assign(_astar.get_id_path(...))` — required for safe typed Array[Vector2i]
  conversion.
- Commit signing must be disabled: `git config commit.gpgsign false`

### Browser version — `/home/user/descent.html`
- Pure HTML5 Canvas 2D, zero dependencies, double-click to open in Chrome
- Canvas: 1400×760, grid 20×13 cells at 55px, two-room dungeon
- Two rooms: Entrance (left, cols 1–8) + Inner Sanctum (right, cols 10–18)
- Dividing wall at col 9, archway doorway at rows 5–7
- 4 enemies: 3 Goblins (5HP) + 1 Goblin Brute (14HP, Heavy Club 1d8, 1.3× scale)
- Bandage consumable: button appears in UI panel when available
- Keyboard: **E** to end turn
- Vignette, room labels, crack-decorated wall tiles, combat log with alpha fade

---

## What v1 was (and is not)

v1 is a single small combat encounter that proves every core system end to end:
one hand-authored room, Carl, three goblins, a few weapons, an HP/death system,
turn order, player and enemy turns, win/lose, and a stubbed narration log.

v1 is **not** the descent loop, item-choice chests, leveling, procedural levels,
isometric art, audio, or the live AI narrator. Those are roadmap items below.

---

## References

- **Theme / tone:** *Dungeon Crawler Carl* — Carl descends floor by floor; "The System"
  makes announcements; loot and trade-off items. Carl's placeholder look: boxers and an
  open bathrobe, barefoot (lore-accurate, fine as a flat sprite for now).
- **Combat model:** *Baldur's Gate 3* — initiative, move + one action, d20 to-hit vs a
  defense value, weapon damage dice.
- **Eventual visual target (NOT v1):** *Halls of Torment* — isometric dark-fantasy
  dungeon, chest-based "Choose One Item" upgrade screens, equipment slots. v1 uses a
  plain top-down square grid with placeholder sprites; the isometric skin comes later.

---

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

---

## Core design (v1 — complete)

### Grid
- Square grid, **12 columns x 10 rows**, hand-authored single room.
- A handful of impassable wall/rock tiles for cover and positioning.
- Use `AStarGrid2D` for pathfinding. One unit per cell; walls and occupied cells block.
- Helpers for world↔cell conversion and "cells reachable within N movement."

### Turn model (BG3-lite)
- At encounter start, each unit rolls **initiative = d20 + 0**; turn order is descending.
  Ties broken by player-first, then spawn order.
- On a unit's turn it has: a **Move** budget (in tiles) and **one Action**.
- Move and Action may be taken in either order; only one Action per turn.
- **Actions:** Attack (target in weapon range), Use Item (e.g., bandage), or End Turn.

### Combat resolution (pure, tested)
`CombatResolver.resolve_attack(to_hit_bonus, damage_dice, defense, current_hp, rng) -> Dictionary`
Returns `{ "hit": bool, "roll": int, "damage": int, "killed": bool }`.
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

### Health
- Every unit has `hp` / `max_hp`. Damage reduces `hp`; at `<= 0` the unit dies and is
  removed from turn order and the grid.
- One consumable, **Bandage**: an Action that heals the user.

### Win / lose
- **Victory:** all goblins dead.
- **Defeat:** Carl dies.

---

## Data definitions

### Weapons (resources)
`Weapon` extends `Resource` with `@export` fields: `weapon_name`, `weapon_range`,
`to_hit`, `damage_dice`, `is_consumable`, `heal_dice`.
(Fields prefixed with `weapon_` to avoid shadowing Godot built-ins `name` and `range`.)

| Name        | Type       | Range | To-hit | Damage / Heal |
|-------------|------------|-------|--------|---------------|
| Rusty Shiv  | melee      | 1     | +2     | 1d4 dmg       |
| Crowbar     | melee      | 1     | +1     | 1d6 dmg       |
| Sling       | ranged     | 4     | +1     | 1d3 dmg       |
| Bandage     | consumable | 0     | —      | 1d6 heal      |
| Goblin Claw | melee      | 1     | +2     | 1d4 dmg       |

### Units
| Unit         | HP | Move | Defense | Loadout                     |
|--------------|----|------|---------|-----------------------------|
| Carl         | 12 | 5    | 12      | Rusty Shiv + Bandage        |
| Goblin       | 5  | 4    | 11      | Goblin Claw                 |
| Goblin Brute | 14 | 3    | 13      | Heavy Club (r=1, +1, 1d8)   |

---

## Architecture

### Autoloads (singletons)
- **GameRng** — wraps one `RandomNumberGenerator`; seeded from a constant in v1.
  Exposes `roll(sides: int) -> int`, `roll_dice(notation: String) -> int`,
  `d20() -> int`, `reset(s: int)` (for test instances).
- **System** — the narrator seam. `func announce(event: StringName, ctx: Dictionary) -> void`
  pushes a line to the combat log. **v1: canned lines.** The signature stays stable so
  the body can later be swapped for a live API call without touching call sites.
  Events: `battle_start`, `hit`, `miss`, `kill`, `carl_hurt`, `victory`, `defeat`.

### Scenes / nodes
- `Main.tscn` → loads `BattleScene.tscn`.
- `BattleScene.tscn`: owns `Grid`, `TurnManager`, `UnitsContainer`, UI (End Turn
  button, combat log panel, result banner).
- `Grid` (script): grid state, `AStarGrid2D`, occupancy, world↔cell, reachable-cells,
  cell highlighting. **Note:** pathfinding method is `find_path()`, NOT `get_path()`.
- `Unit.tscn`: `Node2D` + drawn with `_draw()` + HP bar; `unit.gd` holds stats and
  equipped `Weapon`; emits signals `damaged(amount)` and `died`.
- `TurnManager` (script): initiative order, player input, goblin AI, win/lose, tweens.
  `_animating: bool` flag blocks all input during animation. Uses `call_deferred` +
  `await` for goblin AI coroutine.
- Pure logic scripts: `CombatResolver`, dice parsing inside `GameRng`.

---

## v1 milestone task list (all complete ✓)

1. ✓ **Project setup.** Godot 4 project, folder layout, `GameRng` and `System` autoloads.
2. ✓ **Grid + rendering.** 12×10 grid, walls, `AStarGrid2D`, cell highlight on hover.
3. ✓ **Units + data.** `Weapon` resource, `Unit.tscn`, spawn Carl + 3 goblins with HP bars.
4. ✓ **CombatResolver + tests.** Pure resolver + unit tests for determinism, hit, miss, lethal.
5. ✓ **Player turn.** Initiative, move + attack + End Turn, highlights.
6. ✓ **Enemy turn (goblin AI).** Goblins path to Carl and attack.
7. ✓ **Win/lose + narration log.** Detect victory/defeat; `System.announce` with canned lines.
8. ✓ **Placeholder polish.** Readable sprites, move/attack tweens, death fade.

---

## Economy vision (future roadmap)

The long-term goal is a full DCC-style item, weapon, gear, and potion economy.
The "Choose One Item" chest screen between floors is a core loop pillar.
Do not build any of this until the descent loop (v2) is working.

### Item tiers
Items have a **tier** (Common → Uncommon → Rare → Epic → Cursed):
- **Common:** reliable small bonuses (+1 to-hit, +2 max HP, etc.)
- **Uncommon:** meaningful tradeoffs (Spiked Armor: +2 defense, take 1 dmg per melee hit)
- **Rare:** strong effects with strings attached (Lucky Coin: reroll any die once per floor,
  but reroll your initiative too)
- **Epic:** game-changing (Blood Pact: double all damage dealt AND received)
- **Cursed:** DCC-style extreme tradeoffs (Philosopher's Stone: +100% all stats, −1000 max HP;
  Coward's Blessing: never targeted by enemies, can never attack)

### Equipment slots
Carl has equipment slots for: **Head**, **Body**, **Hands**, **Feet**, **Weapon (main)**,
**Weapon (off-hand or consumable)**. Each slot shows the equipped item icon + stat diff
in the item-choice screen.

### Weapon tiers
Beyond the v1 weapons, the weapon progression:
- **Tier 1** (floor 1–2): Rusty Shiv, Crowbar, Sling, Goblin Fang (looted)
- **Tier 2** (floor 3–5): Iron Sword (+3, 1d8), War Club (+2, 1d10), Short Bow (r=5, +2, 1d6)
- **Tier 3** (floor 6+): Enchanted Blade (+4, 2d6), Thundermace (+2, 1d12, AoE 1-tile),
  Crossbow (r=6, +3, 1d8, ignores 2 defense)
- **Unique / named:** The Protagonist's Crowbar (Carl's signature weapon — starts Tier 2,
  gains +1 after each floor cleared), Vorpal Shiv (crit on 18+), Boxers of Speed (+2 move)

### Potion types
Potions are single-use, take the Action slot:
- **Health Potion:** heal 2d6 HP
- **Greater Health Potion:** heal 4d8 HP + remove one debuff
- **Speed Potion:** +3 move this turn only
- **Rage Potion:** +2 to-hit and damage for 3 turns; -2 defense while active
- **Invisibility Draft:** skip one enemy turn (they cannot target Carl this round)
- **Poison Vial (offensive):** throw at enemy, deals 1d4 per turn for 3 turns
- **Mystery Vial (DCC-style):** roll d6 — 1: poison yourself, 2-4: heal 1d8, 5: gain a
  temporary weapon upgrade, 6: full heal and gain +1 permanent max HP

### Gold economy
- Enemies drop **gold** on death (goblins: 1d4 gold, brutes: 1d8+2, boss: 2d10+5)
- Shops appear every 2–3 floors. Shop inventory: 3 random items + 1 guaranteed potion.
  Item costs scale with tier: Common=5–15g, Uncommon=20–40g, Rare=50–80g, Epic=100+g
- **Bargaining (DCC flavor):** Carl can haggle — roll d20 + Charisma; beat the shopkeeper's
  DC to get a 20% discount. Fail badly and they raise prices 10%.
- Gold can also be bet at a "Risky Chest" (see below).

### Chest mechanics (the core loop)
Between floors Carl finds **one chest**. The chest presents **3 item choices** (rarities
weighted by floor depth). Carl picks exactly one. This is the BG3/Hades-style upgrade
moment — the choice should feel meaningful.

Chest types:
- **Standard Chest:** 3 random items at current floor's rarity weight
- **Risky Chest:** bet gold for better odds — pay 10g to upgrade one item's rarity,
  or take a "Cursed Draw" (all items are Cursed tier but extremely powerful)
- **Boss Chest:** appears after a boss floor — guaranteed 1 Rare + 2 Uncommon choices
- **System Cache (DCC):** The System occasionally offers a "glitch" item that doesn't
  follow normal rules (e.g., "Stack Overflow Amulet: each time you take damage, gain +1
  to-hit permanently, max 10 stacks")

### Status effects (future)
Effects that last N turns, tracked per-unit:
- **Poisoned:** take 1 damage at start of each turn
- **Burning:** take 1d4 at start of turn, spreads to adjacent units on death
- **Stunned:** skip movement (still get action)
- **Enraged:** +2 to-hit, +2 damage, cannot End Turn voluntarily (must attack)
- **Blessed:** +2 to all defense rolls this turn

---

## v2 milestone task list (next, after economy design)

Do these in order. Each ends with a concrete verification step.

### v2.1 — Descent loop (floors)
- After victory, Carl reaches a "floor exit staircase" cell.
- Stepping on it ends the encounter and triggers a new hand-authored room (or a
  procedurally shuffled variant of existing rooms).
- Floor counter increments. Enemy HP and count scale per floor.
- *Verify:* complete floor 1, advance to floor 2 with harder enemies.

### v2.2 — Chest screen ("Choose One Item")
- After clearing a floor, before the staircase opens, show a chest overlay with 3 item
  choices. Carl picks one. Item is added to inventory/equipped.
- Items at this stage: simple stat boosts (max HP +3, to-hit +1, move +1, new weapon).
- *Verify:* chest screen appears, selection is applied to Carl's stats on floor 2.

### v2.3 — Inventory & equipment slots
- Carl has Head / Body / Weapon / Consumable slots shown in a side panel.
- Equipping a new weapon replaces the old one (old goes to "stash" or is lost).
- *Verify:* equipping an item visually changes Carl's stats; the old item is gone.

### v2.4 — Potions & consumables
- Bandage replaced by a real consumable slot. Multiple potion types from the list above.
- Potions appear as chest choices and in shops.
- *Verify:* heal potion restores HP; rage potion correctly applies +2/−2 for 3 turns.

### v2.5 — Gold & shops
- Enemies drop gold (shown in panel). After every 2nd floor a shop screen appears.
- Shop offers 3 items. Carl can buy or skip.
- *Verify:* gold accumulates; shop purchases correctly modify inventory.

### v2.6 — Status effects
- Implement Poisoned, Burning, Stunned. Show active effects as icons on the unit.
- *Verify:* a Poison Vial correctly applies 3-turn DOT; Stunned unit can't move.

### v2.7 — Boss floor
- Every 5th floor is a "boss room": larger room, one boss unit (unique name, 50+ HP,
  multi-attack, special ability), Boss Chest on victory.
- *Verify:* floor 5 spawns boss; boss uses special ability at least once.

### v2.8 — Procedural rooms
- Replace hand-authored rooms 2–N with procedurally generated layouts (BSP or
  room-connector algorithm) using the existing wall/pathfinding system.
- Hand-authored room 1 stays as the tutorial room.
- *Verify:* 5 consecutive runs each produce a different floor 2 layout.

---

## Out of scope for v1
Descent / multiple floors · chest "Choose One Item" upgrades · equipment & inventory UI ·
XP & leveling · procedural generation · isometric or 3D art · audio · live AI narrator.

## Out of scope for v2
Isometric art · audio · live AI narrator · multiplayer · mobile controls.

---

## Full roadmap (rough order, post v2)

1. **v3 — Visual re-skin:** Begin moving toward the *Halls of Torment* isometric
   dark-fantasy look. Sprite sheets for Carl and enemies. Particle effects for hits.
2. **v4 — Companions:** A second player unit (Donut the cat? Another DCC character).
   Party management, shared gold pool.
3. **v5 — Live AI narrator:** Replace `System.announce` body with an async Anthropic API
   call (Godot `HTTPRequest`). The System generates contextual commentary. Call sites
   do not change.
4. **v6 — Audio:** Ambient dungeon sounds, hit/miss SFX, music.
5. **v7 — Full DCC economy:** All potion types, shop bargaining, cursed items, boss chests,
   System Cache glitch items.
6. **v8 — Multiple classes / Descent Loop:** Real floor progression, class selection at
   start (Carl / Donut / Arnold the Barbarian), prestige items.

---

## Working agreement for the agent
- Build strictly one milestone at a time and verify before continuing.
- Keep the rules engine pure and node-free; keep randomness behind `GameRng`.
- Write tests for combat logic; run the project / capture screenshots to confirm behavior.
- Verify every Godot 4 GDScript API against the docs; never assume.
- Prefer composition and small scripts over inheritance.
- Commit after each milestone with a short message naming the milestone.
- When adding new weapon or item fields, always prefix field names that shadow Godot
  built-ins (e.g., `weapon_name` not `name`, `weapon_range` not `range`).
- The `System.announce(event, ctx)` signature must never change — only the body changes
  when upgrading to a live narrator.
