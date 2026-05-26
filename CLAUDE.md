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

## Godot 4.4.1 API Gotchas (learned in Runs 1–3)
- `RandomNumberGenerator` has NO `.shuffle()` method — use Fisher-Yates manually or `Array.shuffle()` (global seed, not deterministic)
- `Array[T].filter(callable)` returns an untyped `Array`, not `Array[T]`
- `Classes.get_class()` conflicts with `Object.get_class()` — renamed to `get_class_data()`
- GDScript lambdas capture local variables **by value** — to read lambda-set state, use an `Array` as a reference container (e.g. `var fired: Array[bool] = [false]`)
- Typed `Array[String]` can't be assigned from an untyped `Array` directly — must iterate and append
- Autoloads are NOT type-checked in `--script` mode; keep tests free of autoload references
- `Combatant.to_dict()` does NOT include a `stats` key — use the new `attack_bonus` field directly
- Signal handlers with `await` become coroutines and return to caller at the first `await` — don't assume they block
- Lambda captures in `btn.pressed.connect(func() -> void: ...)` — to pass a value from outer scope into a button callback safely, wrap in an `Array[T]` container (e.g. `var xp_ref: Array[int] = [xp_earned]`)

## Current State (Run 3 — Charges, Victory, Scaling, Silhouettes)
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
- **Ability effects fully implemented:** fireball (AOE), frost_nova (freeze), taunt (fortified), vanish (3× next hit)
- **Self-target UX** — pressing an already-selected self-target ability button uses it immediately
- **Cave atmosphere** — `CanvasModulate` blue-purple tint; dark stalagmite polygons; lava tiles pulse orange↔dim
- **Status icon labels** on entity nodes (🔥❄☠🛡👁)
- **Death overlay** — "YOU DIED" with System quip, floor/kill/level stats, animated fade, "TRY AGAIN" button
- **Level-up screen** (`LevelUp.tscn/.gd`) — 6-upgrade pool shuffled to 3 choices; DCC quip per choice
- **Enemy AI variety:** Golem (ranged wait), Goblin (flank+attack), Imp (rush), Default (random)
- **`attack_bonus` on Combatant** — hero stat bonuses apply to damage
- **`perform_aoe_attack`** on BattleEngine — hits multiple targets
- **`is_combatant_frozen`** on BattleEngine — checks status_effects for frozen id
- **69 headless tests** — all passing

**Run 3 (Charges + Victory + Scaling + Silhouettes):**
- **Ability charges/cooldown tracking** — `Abilities.make_ability()` factory creates `Ability` objects; BattleScene maintains `_ability_objects: Dictionary`; ability buttons show charge pips (●●○) or cooldown (CD:3); depleted abilities are greyed/disabled; each hero action calls `ability.use()` then `_tick_hero_ability_cooldowns()` after turn end
- **Enemy collision avoidance** — `BattleEngine._move_toward()` now checks all living combatant positions and skips occupied hexes; enemies never stack
- **Victory overlay** — `_show_victory_overlay(xp)` drawn as CanvasLayer (layer 10); animated fade-in; shows "FLOOR N CLEARED!" in gold, System quip, kill/XP/level stats, HP remaining, "DESCEND DEEPER ▼" button to proceed
- **Floor scaling** — enemies gain `+18% HP per floor` and `+3 attack_bonus per floor-1` in `_build_encounter()`; floor 1 = baseline, floor 5 ≈ +72% HP
- **Hero class silhouettes** — class-specific polygon replaces letter initial for hero node: Brawler=kite shield, Rogue=dagger+crossguard, Arcanist=4-point star
- **112 headless tests** — all passing (43 new in Run 3)

### Next Priorities (Run 4)
1. **Lava as tactical hazard** — hero/enemies take burn damage if they end their turn on or adjacent to lava; display lava damage numbers; encourage tactical hex-grid positioning
2. **Enemy collision → push/stagger** — when an enemy can't advance, they use a ranged ability if available (Golem already does this; generalize)
3. **Sounds** — synthesized hits, kills, ability fires; even 2–3 audio clips would dramatically improve feel (Godot's AudioStreamGenerator or imported WAV)
4. **Boss floor every 5 floors** — floor 5, 10, etc. spawn a single high-HP boss enemy with a scripted ability set; banner "FLOOR 5 — BOSS ENCOUNTER"
5. **Loot: new ability unlock items** — loot pool entries that add a new ability to the hero (from a separate "unlockable" pool); currently loot only gives stat boosts
6. **Persistent run stats** — track total kills, floors cleared, best run; display on death screen; store in a JSON file
7. **Minimap / floor progress indicator** — small HUD element showing current floor number in a visual column (floors 1–10 or whatever is the run length)

## File Map
```
autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run-persistent hero state
  SystemVoice.gd     — The System commentary pools + signal

src/combat/
  Combatant.gd       — pure fighter data class (+ attack_bonus field)
  BattleEngine.gd    — pure turn engine (+ collision-aware _move_toward, Run 3)
  Ability.gd         — charges/cooldown data object (fully wired in Run 3)
  StatusEffect.gd    — status dict factories: burning/frozen/vanished/fortified/poisoned

src/map/
  HexGrid.gd         — static hex math utilities
  DungeonMap.gd      — procedural floor generator

src/data/
  Classes.gd         — class definitions (Brawler/Rogue/Arcanist)
  Abilities.gd       — all ability definitions + make_ability() factory (Run 3)
  EnemyDefs.gd       — enemy definitions + Combatant factory

scenes/
  Main.tscn/.gd      — root, scene orchestration; handles death→class select
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle visual driver (Run 3: charges HUD, victory overlay,
                           floor scaling, class silhouettes, enemy collision fix)
  LevelUp.tscn/.gd   — upgrade screen; 3 of 6 upgrades per level
  LootScreen.tscn/.gd   — post-battle choose-one loot

tests/
  run_tests.gd       — headless test runner (SceneTree)
  test_rng.gd        — RNG reproducibility/bounds tests
  test_hex.gd        — HexGrid geometry tests
  test_combat.gd     — Combatant + BattleEngine tests
  test_movement.gd   — movement, ability effects, AI variants, attack_bonus
  test_abilities.gd  — Ability charges/cooldown, make_ability factory,
                       enemy collision, floor scaling (Run 3)
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
