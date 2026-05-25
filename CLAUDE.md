# DESCENT — Developer Guide

## Vision
DESCENT is a turn-based tactical dungeon crawler in the spirit of **Dungeon Crawler Carl**.
- Carl is a lone hero descending floor by floor through a hostile dungeon
- An in-fiction AI called **"The System"** narrates everything with dry, mocking commentary
- Loot comes as trade-off **"Choose One"** items after each floor
- **Hex-grid battlefield** set in a dark cavern — stalagmites, glowing orange lava tiles

## Engine & Language
- **Godot 4.4.1** — always verify API exists before using it
- **Typed GDScript** throughout — no untyped variables
- **GL Compatibility** renderer (headless-friendly)

## Architecture Rules
1. **Pure rules engine**: `BattleEngine`, `Combatant`, `HexGrid`, `DungeonMap`, `Abilities`, `Classes`, `EnemyDefs` — **zero Node dependency**, fully testable headlessly
2. **Randomness**: All gameplay RNG routes through `GameRng` autoload. Pure logic functions accept explicit `rng: RandomNumberGenerator` parameter
3. **Autoloads**: `GameRng`, `GameState`, `SystemVoice` — always available
4. **Signals over direct calls** for cross-system communication

## Godot 4.4.1 API Gotchas (accumulated)
- `RandomNumberGenerator` has NO `.shuffle()` method — use Fisher-Yates manually or `Array.shuffle()` (global seed, not deterministic)
- `Array[T].filter(callable)` returns an untyped `Array`, not `Array[T]`
- `Classes.get_class()` conflicts with `Object.get_class()` — renamed to `get_class_data()`
- GDScript lambdas capture local variables **by value** — to read lambda-set state, check it on the object, not the captured var
- Typed `Array[String]` can't be assigned from an untyped `Array` directly — must iterate and append
- Autoloads are NOT type-checked in `--script` mode; keep tests free of autoload references
- `[a] + typed_array` produces an untyped Array — must `clear()` then `append()` individually
- `("string1\n" "string2") % [...]` is invalid GDScript — build multi-line format strings by appending separately
- `get_viewport().get_texture().get_image()` works for in-game screenshots
- `move_child(node, idx)` reorders children in scene tree (use for z-layer control)

## Current State (Run 2 — Movement, Atmosphere & Abilities)
### Implemented ✅
**Run 1 (Bootstrap)**
- `GameRng` autoload — seeded Fisher-Yates RNG, reproducible runs
- `GameState` autoload — run state (class, HP, XP, floor, stats, signals)
- `SystemVoice` autoload — The System's dry commentary with line pools, no-repeat cycling
- `Combatant` — pure data class: HP, armor, speed, attack_bonus, status effects, typed abilities
- `BattleEngine` — pure turn rules engine: speed-based ordering, enemy AI, status ticking
- `Ability` — charges, cooldown, tick logic data object
- `StatusEffect` — factory for burning/frozen/poisoned/fortified/vanish dicts
- `HexGrid` — static axial hex math: pixel↔hex, distance, disk, ring, neighbors
- `DungeonMap` — procedural floor: lava tiles (10-15%), enemy spawns (3+floor), seeded
- `Classes` — Brawler (150HP/tank), Rogue (100HP/fast), Arcanist (80HP/mage)
- `Abilities` — 10 abilities: basic_attack, power_strike, backstab, fireball, frost_nova, taunt, vanish + 3 enemy abilities
- `EnemyDefs` — 5 enemy types (imp/goblin/skeleton/demon/golem), floor-gated, Combatant factory
- `ClassSelect` scene — dark card UI, The System quips, Brawler/Rogue/Arcanist pick
- `BattleScene` — hex grid rendered with Polygon2D, entities with HP bars, ability bar HUD, click-to-attack, damage floaters
- `LootScreen` — 3-choice loot cards: heal/stat/recharge/skip, GameState mutations
- `Main` — scene orchestration: ClassSelect → Battle → Loot → loop; death → ClassSelect

**Run 2 (Movement, Atmosphere, Abilities)**
- **Hero movement** — click adjacent empty hex to move (spends turn); lava tile entry deals 5 damage
- **Hex highlights** — blue = valid move hexes, red = attackable enemies, green = self-ability target
- **Ability effects fully wired**:
  - `fireball` — AOE damages all enemies within range 3 of hero
  - `frost_nova` — freezes all adjacent enemies (duration=2, skip_turn=true)
  - `taunt` — applies fortified (+5 armor, 3 turns) to hero
  - `vanish` — applies no-tick status; next attack deals 3× damage, then consumed
  - `backstab` — correctly ignores armor (ignore_armor flag checked in damage calc)
- **USE button** — appears for self/AOE abilities (taunt, vanish, fireball, frost_nova)
- **Frozen enemies skip turns** — BattleEngine.begin_turn() checks has_skip_turn() before tick; max_tries guard prevents infinite loop
- **Enemy AI variety**:
  - Imp (rush) — charges toward hero, attacks when adjacent
  - Goblin (flank) — approaches from unexpected angle
  - Skeleton (cautious) — only closes if hero is far (>3 hexes)
  - Demon Grunt (rush) — aggressive rush
  - Lava Golem (ranged) — stays at distance, retreats if hero is adjacent
- **Enemy movement** — enemies move toward/away from hero when out of attack range
- **Cave atmosphere** — procedural stalagmites+stalactites (14 bottom, 11 top, side rocks) drawn around battle area; seeded per run_seed
- **Lava animation** — inner glow polygon on lava tiles pulses orange→amber via looping Tween
- **Mode label** — top-right UI shows context hint: "Click enemy to attack" / "Press USE for AOE"
- **Death screen** — YOU DIED overlay with System quip, run stats (floor/enemies/level/class), TRY AGAIN button; Enter/Space also restarts
- **GameState tracking** — `enemies_killed`, `floors_cleared` tracked through run; HP synced back to GameState at battle end
- **Ability cooldowns** — tracked in BattleScene dictionary; shown as [CD:N] on ability buttons
- **attack_bonus** wired — hero's class attack stat now applies to damage calculations
- **67 headless tests** — all passing: RNG(5), Hex(13), Combat(27), Movement(22)

### Next Priorities (Run 3)
1. **Level-up / Upgrade screen** — after XP threshold: Recharge/Primary/Special tabs, icon+name+XP cost+desc, pick one upgrade, Continue button; ability improvements (e.g., fireball +damage, vanish +turns)
2. **Visual entity sprites** — replace letter-initial hexagons with small SVG-style sprites: hero gets a sword silhouette, enemies get distinct shapes by type (imp=wings, golem=boulder)
3. **Loot improvements** — the 3 loot options should be more distinct: "Ability Upgrade" option that grants a new ability from a pool; "Recharge All" as a guaranteed option; loot pool depth
4. **Floor exit tile** — visible exit hex (ladder symbol); after clearing all enemies the exit glows and clicking it descends
5. **Multi-floor persistence** — hero damage carries between floors (already wired via GameState.hero_hp sync); stat-up loot actually matters
6. **More system voice** — battle events (first kill, low HP, win), unique voice for different enemy types
7. **Sound design** — when audio becomes available: procedural hit/move sounds via AudioStreamPlayer

## File Map
```
autoloads/
  GameRng.gd       — seeded RNG singleton
  GameState.gd     — run-persistent hero state (HP, XP, abilities, kills, floors)
  SystemVoice.gd   — The System commentary pools + signal (expanded in Run 2)

src/combat/
  Combatant.gd     — pure fighter: HP, armor, attack_bonus, status effects, has_status/consume_status
  BattleEngine.gd  — pure turn engine: movement, skip_turn, AI behaviors, vanish multiplier
  Ability.gd       — charges/cooldown data (future upgrade system)
  StatusEffect.gd  — status dict factories (burning/frozen/fortified/poisoned/vanish)

src/map/
  HexGrid.gd       — static hex math utilities
  DungeonMap.gd    — procedural floor generator

src/data/
  Classes.gd       — class definitions (Brawler/Rogue/Arcanist)
  Abilities.gd     — all ability definitions (ignore_armor, applies_frozen, target types)
  EnemyDefs.gd     — enemy definitions + Combatant factory (ai_behavior: rush/flank/cautious/ranged)

scenes/
  Main.tscn/.gd    — root orchestration: ClassSelect → Battle → Loot → loop; death → DeathScreen
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle: movement, ability effects, cave atmosphere, lava anim
  LootScreen.tscn/.gd   — post-battle choose-one loot
  DeathScreen.tscn/.gd  — YOU DIED: stats, quip, restart button
  HUD.tscn/.gd     — (stub)

tests/
  run_tests.gd      — headless test runner (SceneTree)
  test_rng.gd       — RNG reproducibility/bounds (5 tests)
  test_hex.gd       — HexGrid geometry (13 tests)
  test_combat.gd    — Combatant + BattleEngine (27 tests)
  test_movement.gd  — movement, freeze, vanish, AI (22 tests)
```

## Running Tests
```bash
godot --headless --script tests/run_tests.gd
```
Exit code 0 = all pass.

## Running the Game (with display)
```bash
godot --path /path/to/descent
```

## Screenshot (headless CI — viewport capture method)
```gdscript
# In-game, from a Node:
var img: Image = get_viewport().get_texture().get_image()
img.save_png("/tmp/screenshot.png")
```

Or via Xvfb + scrot:
```bash
Xvfb :99 -screen 0 1280x720x24 &
DISPLAY=:99 godot --path /path/to/descent &
sleep 5
DISPLAY=:99 scrot screenshot.png
```

## DCC Tone Guidelines
- The System speaks in second person, addressing "Hero"
- Dry, mocking, never cheerful
- Short sentences. Statistical references. Faint disdain.
- Never breaks the fourth wall explicitly, but is clearly aware it's a game
- Example: "You have died. This is embarrassing for both of us."
