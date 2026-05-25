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

## Godot 4.4.1 API Gotchas (learned in Run 1)
- `RandomNumberGenerator` has NO `.shuffle()` method — use Fisher-Yates manually or `Array.shuffle()` (global seed, not deterministic)
- `Array[T].filter(callable)` returns an untyped `Array`, not `Array[T]`
- `Classes.get_class()` conflicts with `Object.get_class()` — renamed to `get_class_data()`
- GDScript lambdas capture local variables **by value** — to read lambda-set state, check it on the object, not the captured var
- Typed `Array[String]` can't be assigned from an untyped `Array` directly — must iterate and append
- Autoloads are NOT type-checked in `--script` mode; keep tests free of autoload references

## Current State (Run 1 — Bootstrap)
### Implemented ✅
- `GameRng` autoload — seeded Fisher-Yates RNG, reproducible runs
- `GameState` autoload — run state (class, HP, XP, floor, stats, signals)
- `SystemVoice` autoload — The System's dry commentary with line pools, no-repeat cycling
- `Combatant` — pure data class: HP, armor, speed, status effects, typed abilities
- `BattleEngine` — pure turn rules engine: speed-based ordering, enemy AI, status ticking
- `Ability` — charges, cooldown, tick logic data object
- `StatusEffect` — factory for burning/frozen/poisoned/fortified dicts
- `HexGrid` — static axial hex math: pixel↔hex, distance, disk, ring, neighbors
- `DungeonMap` — procedural floor: lava tiles (10-15%), enemy spawns (3+floor), seeded
- `Classes` — Brawler (150HP/tank), Rogue (100HP/fast), Arcanist (80HP/mage)
- `Abilities` — 10 abilities: basic_attack, power_strike, backstab, fireball, frost_nova, taunt, vanish + 3 enemy abilities
- `EnemyDefs` — 5 enemy types (imp/goblin/skeleton/demon/golem), floor-gated, Combatant factory
- `ClassSelect` scene — dark card UI, The System quips, Brawler/Rogue/Arcanist pick
- `BattleScene` — hex grid rendered with Polygon2D, entities with HP bars, ability bar HUD, click-to-attack, damage floaters
- `LootScreen` — 3-choice loot cards: heal/stat/recharge/skip, GameState mutations
- `Main` — scene orchestration: ClassSelect → Battle → Loot → loop; death → ClassSelect
- **45 headless tests** — all passing: RNG (5), HexGrid (13), Combat/Map/Enemies (27)

### Next Priorities (Run 2)
1. **Hero movement** — let the hero spend a turn to move to an adjacent hex; this unlocks tactical positioning
2. **Cave atmosphere** — dark background with stalagmite silhouettes, glowing lava pulse, use CanvasModulate for dungeon ambiance
3. **Ability effects in scene** — fireball (AOE hit all enemies in radius), frost_nova (frozen status + skip_turn), taunt (fortified buff), vanish (3× next attack)
4. **Death/defeat screen** — proper "YOU DIED" overlay with System quip, run summary (floors cleared, enemies killed), restart button
5. **Level-up/upgrade screen** — after XP threshold: Recharge/Primary/Special tabs, icon+name+cost+desc, pick one upgrade, Continue
6. **Enemy variety in AI** — Golem stays put and uses ranged; Goblin flanks; Imp rushes
7. **Stalagmite silhouette art** — draw polygon silhouettes at map edges using dark triangles

## File Map
```
autoloads/
  GameRng.gd       — seeded RNG singleton
  GameState.gd     — run-persistent hero state
  SystemVoice.gd   — The System commentary pools + signal

src/combat/
  Combatant.gd     — pure fighter data class
  BattleEngine.gd  — pure turn engine
  Ability.gd       — charges/cooldown data
  StatusEffect.gd  — status dict factories

src/map/
  HexGrid.gd       — static hex math utilities
  DungeonMap.gd    — procedural floor generator

src/data/
  Classes.gd       — class definitions (Brawler/Rogue/Arcanist)
  Abilities.gd     — all ability definitions
  EnemyDefs.gd     — enemy definitions + Combatant factory

scenes/
  Main.tscn/.gd    — root, scene orchestration
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle visual driver
  LootScreen.tscn/.gd   — post-battle choose-one loot
  HUD.tscn/.gd     — (stub) bottom ability HUD

tests/
  run_tests.gd     — headless test runner (SceneTree)
  test_rng.gd      — RNG reproducibility/bounds tests
  test_hex.gd      — HexGrid geometry tests
  test_combat.gd   — Combatant + BattleEngine tests
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

## Screenshot (headless CI)
```bash
Xvfb :99 -screen 0 1280x720x24 &
DISPLAY=:99 godot --path /path/to/descent &
sleep 3
DISPLAY=:99 scrot screenshot.png
```

## DCC Tone Guidelines
- The System speaks in second person, addressing "Hero"
- Dry, mocking, never cheerful
- Short sentences. Statistical references. Faint disdain.
- Never breaks the fourth wall explicitly, but is clearly aware it's a game
- Example: "You have died. This is embarrassing for both of us."
