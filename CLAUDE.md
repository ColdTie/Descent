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

## Godot 4.4.1 API Gotchas (learned in Runs 1–2)
- `RandomNumberGenerator` has NO `.shuffle()` method — use Fisher-Yates manually or `Array.shuffle()` (global seed, not deterministic)
- `Array[T].filter(callable)` returns an untyped `Array`, not `Array[T]`
- `Classes.get_class()` conflicts with `Object.get_class()` — renamed to `get_class_data()`
- GDScript lambdas capture local variables **by value** — to read lambda-set state, use an `Array` as a reference container (e.g. `var fired: Array[bool] = [false]`)
- Typed `Array[String]` can't be assigned from an untyped `Array` directly — must iterate and append
- Autoloads are NOT type-checked in `--script` mode; keep tests free of autoload references
- `Combatant.to_dict()` does NOT include a `stats` key — use the new `attack_bonus` field directly
- Signal handlers with `await` become coroutines and return to caller at the first `await` — don't assume they block

## Current State (Run 2 — Movement, Abilities, Atmosphere)
### Implemented ✅
**Run 1 (Bootstrap):**
- `GameRng`, `GameState`, `SystemVoice` autoloads
- `Combatant`, `BattleEngine`, `Ability`, `StatusEffect` pure combat classes
- `HexGrid`, `DungeonMap` pure map classes
- `Classes`, `Abilities`, `EnemyDefs` data classes
- `ClassSelect`, `BattleScene`, `LootScreen`, `Main` scenes
- 45 headless tests

**Run 2 (Movement + Abilities + Polish):**
- **Hero movement** — click adjacent passable empty hex to move (costs a turn); animated with Tween
- **Hex highlights** — green for valid moves, red for attack targets, orange for AOE zones, blue for frost, purple for self-buffs; clears on turn end
- **Ability effects fully implemented:**
  - `fireball` — AOE damage (radius 2) centered on clicked hex; orange flash visual
  - `frost_nova` — freezes all adjacent enemies for 2 turns (frozen enemies skip AI action)
  - `taunt` — applies `fortified` status (+5 armor, 3 turns) to hero
  - `vanish` — applies `vanished` status; next attack deals 3× damage (consumed on use)
- **Self-target UX** — pressing an already-selected self-target ability button uses it immediately
- **Cave atmosphere** — `CanvasModulate` blue-purple tint; dark stalagmite polygons in outer rings (6–7); lava tiles pulse orange↔dim with staggered tweens
- **Status icon labels** on entity nodes (🔥❄☠🛡👁)
- **Death overlay** — "YOU DIED" with System quip, floor/kill/level stats, animated fade, "TRY AGAIN" button → back to class select
- **Level-up screen** (`LevelUp.tscn/.gd`) — 6-upgrade pool shuffled to 3 choices; atk/spd/hp/def/xp/heal variants; DCC quip on each
- **Enemy AI variety:**
  - Golem: stays put, ranged attack only when in range 3
  - Goblin: moves one step toward hero, then attacks if adjacent
  - Imp: always rushes toward hero, attacks on contact
  - Default: random ability, no movement
- **`attack_bonus` on Combatant** — hero stat bonuses (from loot/level-up) now correctly apply to damage
- **`perform_aoe_attack`** on BattleEngine — hits multiple targets, returns Array[int] of damage dealt
- **`is_combatant_frozen`** on BattleEngine — checks status_effects for frozen id
- **69 headless tests** — all passing: RNG (5), HexGrid (13), Combat (27), Movement+Abilities (24)

### Next Priorities (Run 3)
1. **Ability charges/cooldown tracking** — wire the existing `Ability` class into BattleScene; show charges remaining in HUD; prevent using depleted abilities
2. **Enemy collision avoidance** — prevent two enemies from occupying the same hex when moving
3. **Lava damage on movement** — if hero moves into lava (should be blocked, but) if hero is adjacent to lava, fire damage ticks; make lava a tactical hazard
4. **Victory screen** — a proper post-floor "CLEARED!" screen showing XP, level, kills before Loot screen
5. **Hero portrait / class icon** — replace letter initial with a distinct polygon silhouette per class (Brawler=shield, Rogue=dagger shape, Arcanist=star)
6. **Sounds** — even a minimal audio pass: hit, kill, move, ability sounds (synthesized or imported)
7. **Floor progression** — enemies should scale in count and HP by floor; currently capped at floor_num+3 but HP/stats don't scale

## File Map
```
autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run-persistent hero state
  SystemVoice.gd     — The System commentary pools + signal

src/combat/
  Combatant.gd       — pure fighter data class (+ attack_bonus field)
  BattleEngine.gd    — pure turn engine (+ move_combatant, perform_aoe_attack, enemy AI variants)
  Ability.gd         — charges/cooldown data object (not yet wired into BattleScene HUD)
  StatusEffect.gd    — status dict factories: burning/frozen/vanished/fortified/poisoned

src/map/
  HexGrid.gd         — static hex math utilities
  DungeonMap.gd      — procedural floor generator

src/data/
  Classes.gd         — class definitions (Brawler/Rogue/Arcanist)
  Abilities.gd       — all ability definitions
  EnemyDefs.gd       — enemy definitions + Combatant factory

scenes/
  Main.tscn/.gd      — root, scene orchestration; handles death→class select
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle visual driver (Run 2: movement, highlights, AOE, atmosphere, death overlay)
  LevelUp.tscn/.gd   — upgrade screen (new in Run 2); 3 of 6 upgrades per level
  LootScreen.tscn/.gd   — post-battle choose-one loot

tests/
  run_tests.gd       — headless test runner (SceneTree)
  test_rng.gd        — RNG reproducibility/bounds tests
  test_hex.gd        — HexGrid geometry tests
  test_combat.gd     — Combatant + BattleEngine tests
  test_movement.gd   — movement, ability effects, AI variants, attack_bonus (Run 2)
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
