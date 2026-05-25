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

## Godot 4.4.1 API Gotchas (accumulated across runs)
- `RandomNumberGenerator` has NO `.shuffle()` method — use Fisher-Yates manually or `Array.shuffle()` (global seed, not deterministic)
- `Array[T].filter(callable)` returns an untyped `Array`, not `Array[T]` — use a for-loop instead
- `Classes.get_class()` conflicts with `Object.get_class()` — renamed to `get_class_data()`
- GDScript lambdas capture local variables **by value** — to read lambda-set state, check it on the object, not the captured var
- Typed `Array[String]` can't be assigned from an untyped `Array` directly — must iterate and append
- Autoloads are NOT type-checked in `--script` mode; keep tests free of autoload references
- `Dictionary.get(key, default)` loses type info — `Array[String]` from a dict must be iterated into a typed array
- Array literal `[a] + typed_array` produces untyped Array — build typed arrays manually with `.append()`
- `as Array[T]` cast from untyped Array → unreliable; use loop + append pattern
- `CanvasModulate` added as a Node2D child modulates the 2D world (hex grid, entities) but NOT CanvasLayer UI

## Current State (Run 2 — Tactical Foundation)
### Implemented ✅
- `GameRng` autoload — seeded Fisher-Yates RNG, reproducible runs
- `GameState` autoload — run state (class, HP, XP, floor, stats, signals, total_kills)
- `SystemVoice` autoload — The System's dry commentary with line pools, no-repeat cycling
- `Combatant` — pure data class: HP, armor, speed, attack_bonus, status effects, typed abilities, ability_states (charge/cooldown), vanish_active flag
- `BattleEngine` — pure turn rules engine:
  - Speed-based turn ordering, status ticking
  - `perform_action(attacker, target_hex, ability_id)` handles all ability types
  - AOE: fireball hits all enemies in radius; frost_nova hits all adjacent + freezes
  - Buffs: taunt applies fortified; vanish sets 3× damage multiplier on next attack
  - Backstab ignores armor (via `take_damage(raw, ignore_armor=true)`)
  - **Hero movement**: `move_combatant(c, dest)` + `combatant_moved` signal
  - **Enemy AI movement**: enemies move toward hero when out of attack range; ranged enemies (range≥3) stand and shoot
  - Frozen (skip_turn) status: combatant's turn is skipped while frozen
  - Ability charge/cooldown tracking: per-combatant `ability_states` dict
  - `enemies_defeated` counter for death screen stats
- `Ability` — charges/cooldown data object (exists but ability_states in Combatant is used in practice)
- `StatusEffect` — factory for burning/frozen(skip_turn)/poisoned/fortified dicts
- `HexGrid` — static axial hex math: pixel↔hex, distance, disk, ring, neighbors
- `DungeonMap` — procedural floor: lava tiles (10-15%), enemy spawns (3+floor), seeded
- `Classes` — Brawler (150HP/tank), Rogue (100HP/fast), Arcanist (80HP/mage)
- `Abilities` — 10 abilities: basic_attack, power_strike, backstab, fireball, frost_nova, taunt, vanish + 3 enemy abilities
- `EnemyDefs` — 5 enemy types (imp/goblin/skeleton/demon/golem), floor-gated
- `ClassSelect` scene — dark card UI, The System quips, Brawler/Rogue/Arcanist pick
- `BattleScene` (Run 2 major update):
  - **Hex movement highlights**: green=can move, red=attack range
  - **Cave atmosphere**: CanvasModulate dark-purple tint, stalagmite polygon silhouettes at map edge
  - **Lava pulse**: continuous tween animating lava tiles brightness
  - **Ability charge/cooldown display**: shows `[∞]`, `[1/1]`, `[CD:N]` per ability button
  - **AoE visual effects**: flash hex on fireball/frost nova hits
  - **Buff visual effects**: entity glow on vanish/taunt activation
  - **Hero movement**: click empty adjacent passable hex to move (uses turn)
  - **Enemy AI movement**: enemies animate to new position when moving
  - **Death screen overlay**: CanvasLayer "YOU DIED" with stats, System quip, Try Again button
  - **Hero HP label** in top-right showing current/max HP
- `LootScreen` — 3-choice loot cards: heal/stat/recharge/skip, GameState mutations
- `UpgradeScreen` (Run 2 new) — XP-driven level-up screen: Recharge/Primary/Special tabs, 3 random choices, applies stat upgrades to GameState
- `Main` — scene orchestration: ClassSelect → Battle → (LevelUp?) → Loot → loop; death → ClassSelect
- **67 headless tests** — all passing: RNG (5), HexGrid (13), Combat (49 including new movement/AOE/ability tests)

### Bug Fixes in Run 2
- **Armor double-subtraction**: `_calculate_damage` no longer subtracts armor; `take_damage(raw, ignore_armor)` handles it
- **Attack bonus never applied**: hero's attack stat now stored in `Combatant.attack_bonus` and applied in damage calc
- **Array type assignment**: fixed `hero_abilities` and `_all_combatants` typed array assignments

### Next Priorities (Run 3)
1. **Entity size / visibility** — entities are small (16px hex); increase to 22-26px and brighten colors so hero vs enemy is more legible at a glance
2. **Lava damage** — walking onto a lava tile should deal damage (currently lava tiles block movement via `passable=false`; make "hot but passable" and apply 3 burn DoT)
3. **Ranged enemy behavior polish** — Golem should kite backward if hero gets adjacent
4. **XP bar** — add a small XP progress bar to the HUD alongside the level indicator
5. **Ability upgrade depth** — after level 3+, add per-ability power upgrades (e.g., "Fireball: +10 damage", "Power Strike: 2 charges")
6. **System voice during battle** — speak on status tick (burning), enemy movement, and frozen events
7. **Floor exit hex** — show a visible exit tile the hero can step on to end the floor without killing everything
8. **Visual polish** — color the stalagmites with a slight cave-brown gradient; add particle-style lava sparks at lava tiles; animate lava shimmer with brighter flicker

## File Map
```
autoloads/
  GameRng.gd       — seeded RNG singleton
  GameState.gd     — run-persistent hero state (+ total_kills Run 2)
  SystemVoice.gd   — The System commentary pools + signal

src/combat/
  Combatant.gd     — pure fighter data class (+ ability_states, vanish_active Run 2)
  BattleEngine.gd  — pure turn engine (+ movement, AOE, AI movement Run 2)
  Ability.gd       — charges/cooldown data object (exists, but Combatant.ability_states used in practice)
  StatusEffect.gd  — status dict factories (frozen has skip_turn=true)

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
  BattleScene.tscn/.gd  — hex battle visual driver (Run 2: major update)
  LootScreen.tscn/.gd   — post-battle choose-one loot
  UpgradeScreen.tscn/.gd — XP level-up upgrade picker (Run 2 new)
  HUD.tscn/.gd     — (stub) bottom ability HUD

tests/
  run_tests.gd     — headless test runner (SceneTree)
  test_rng.gd      — RNG reproducibility/bounds tests
  test_hex.gd      — HexGrid geometry tests
  test_combat.gd   — Combatant + BattleEngine tests (Run 2: movement, AOE, charges added)
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
DISPLAY=:99 godot --path /path/to/descent --rendering-driver opengl3 &
sleep 5
DISPLAY=:99 scrot screenshot.png
```

## DCC Tone Guidelines
- The System speaks in second person, addressing "Hero"
- Dry, mocking, never cheerful
- Short sentences. Statistical references. Faint disdain.
- Never breaks the fourth wall explicitly, but is clearly aware it's a game
- Example: "You have died. This is embarrassing for both of us."
