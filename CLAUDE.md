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

## Godot 4.4.1 API Gotchas (learned in Runs 1–4)
- `RandomNumberGenerator` has NO `.shuffle()` method — use Fisher-Yates manually or `Array.shuffle()` (global seed, not deterministic)
- `Array[T].filter(callable)` returns an untyped `Array`, not `Array[T]`
- `Classes.get_class()` conflicts with `Object.get_class()` — renamed to `get_class_data()`
- GDScript lambdas capture local variables **by value** — to read lambda-set state, use an `Array` as a reference container (e.g. `var fired: Array[bool] = [false]`)
- Typed `Array[String]` can't be assigned from an untyped `Array` directly — must iterate and append
- Autoloads are NOT type-checked in `--script` mode; keep tests free of autoload references
- `Combatant.to_dict()` does NOT include a `stats` key — use the new `attack_bonus` field directly
- Signal handlers with `await` become coroutines and return to caller at the first `await` — don't assume they block
- **Architecture rule**: `BattleEngine._calculate_damage()` returns RAW damage (no armor). `Combatant.take_damage(amount, ignore_armor=false)` applies armor. Don't double-apply armor in both places.
- `Combatant.take_damage(amount, ignore_armor)` — the `ignore_armor` parameter bypasses the `armor` field reduction (for backstab, env damage, etc.)

## Current State (Run 4 — Shield Bash, Commentary, Ability Unlocks, HP Regen)
### Implemented ✅
**Run 1 (Bootstrap):**
- `GameRng`, `GameState`, `SystemVoice` autoloads
- `Combatant`, `BattleEngine`, `Ability`, `StatusEffect` pure combat classes
- `HexGrid`, `DungeonMap` pure map classes
- `Classes`, `Abilities`, `EnemyDefs` data classes
- `ClassSelect`, `BattleScene`, `LootScreen`, `Main` scenes
- 45 headless tests

**Run 2 (Movement + Abilities + Polish):**
- Hero movement, hex highlights, ability effects (fireball, frost_nova, taunt, vanish)
- Cave atmosphere (CanvasModulate, stalagmites, lava pulse)
- Death overlay, Level-up screen, Enemy AI variety (golem/goblin/imp/default)
- 69 headless tests

**Run 3 (Charges + Scaling + Tactical Depth):**
- Ability charges/cooldown wired into BattleScene HUD (dots, ↻ countdown, ∞)
- Backstab ignores armor; architecture fix (no double-armor); enemy collision avoidance
- Lava heat damage (armor-ignoring, scales with adjacent lava count)
- Victory screen; floor scaling (+20% HP/floor, +1 armor/2 floors)
- Class and enemy glyphs; `apply_environment_damage` on BattleEngine
- 109 headless tests

**Run 4 (Shield Bash + Commentary + Ability Unlocks + HP Regen):**
- **Shield Bash ability** — Brawler's new signature move (replaces power_strike in starting kit)
  - 2-tile knockback pushing enemy in the direction of impact
  - `HexGrid.push_direction(from, to)` returns the DIRECTIONS entry most aligned with the vector
  - `BattleEngine.push_combatant(pushed, dir, steps, map)` steps through tiles; stops on walls/occupied hexes
  - If pushed into a passable lava tile: 20 armor-ignoring damage — makes lava TACTICALLY LETHAL
  - `combatant_pushed` signal for visual sync; BattleScene handles animation + DCC quip
  - Brawler kit: `basic_attack`, `shield_bash`, `taunt` (power_strike is now an unlock)
- **The System mid-battle commentary** — 6 new SystemVoice pools:
  - `low_hp` — fires once when hero drops below 20% HP (in `_on_action_taken` and `_apply_lava_heat`)
  - `first_blood` — fires on the first enemy kill of the entire run (`GameState.run_total_kills`)
  - `backstab_land` — fires when backstab is used (replaces generic "hit" quip)
  - `surrounded` — fires when 3+ enemies are adjacent at start of hero's turn (5-turn cooldown)
  - `shield_bash_lava` — fires when an enemy is pushed into lava
  - `floor_regen` — fires when hero regenerates HP between floors
- **Ability unlocks on LevelUp screen** — Classes now have `unlockable_abilities` list
  - Brawler unlocks: `power_strike`, `frost_nova`
  - Rogue unlocks: `power_strike`, `fireball`
  - Arcanist unlocks: `vanish`, `backstab`
  - LevelUp pools stat upgrades with ability unlock cards (purple vs. gold styling)
  - On unlock: ability appended to `GameState.hero_abilities`; BattleScene picks it up on next floor
- **HP regen between floors** — `Main._on_floor_cleared()` heals 10% max HP (min 5) before XP/loot
  - `GameState.run_total_kills` added for first-blood tracking; reset in `start_run()`
- **149 headless tests** — all passing: RNG (5), Hex (13), Combat (27), Movement+Abilities (24), Run3 (40), Run4 (40)

### Next Priorities (Run 5)
1. **Sounds** — Even a minimal audio pass: hit, kill, move, ability sounds (use Godot's AudioStreamGenerator or import simple beeps)
2. **Shield Bash visual** — add a short tweened "slide" animation for the pushed enemy node so the knockback is visible, not just teleport
3. **Multi-floor run feel / floor counter** — small HUD indicator showing "Floor X of Y" (generate total floor count at run start); makes the run feel finite
4. **Enemy variety on higher floors** — currently random from pool; have floors 5+ spawn more dangerous enemy types (demon/golem only) and guarantee at least one golem or demon per floor
5. **Minimap or loot preview** — small floor preview on VictoryScreen showing what's ahead (harder enemies, guaranteed lava hazard, etc.)
6. **Status effect visual polish** — when enemy is frozen, dim/blue-tint their node; when on fire, pulse red; currently just icon labels

## File Map
```
autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run-persistent hero state (+run_total_kills for first-blood tracking)
  SystemVoice.gd     — The System commentary pools + signal (+6 new pools in Run 4)

src/combat/
  Combatant.gd       — pure fighter data class (+take_damage ignore_armor param)
  BattleEngine.gd    — pure turn engine (+push_combatant, +combatant_pushed signal)
  Ability.gd         — charges/cooldown data object (now wired into BattleScene HUD)
  StatusEffect.gd    — status dict factories: burning/frozen/vanished/fortified/poisoned

src/map/
  HexGrid.gd         — static hex math utilities (+push_direction static method)
  DungeonMap.gd      — procedural floor generator

src/data/
  Classes.gd         — class definitions (+unlockable_abilities per class; Brawler uses shield_bash)
  Abilities.gd       — all ability definitions (+shield_bash with pushback:2)
  EnemyDefs.gd       — enemy definitions + Combatant factory (+floor_num scaling param)

scenes/
  Main.tscn/.gd      — root, scene orchestration (+HP regen on floor_cleared)
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle visual driver (+shield bash push, +mid-battle commentary triggers)
  VictoryScreen.tscn/.gd — post-battle floor clear screen
  LevelUp.tscn/.gd   — upgrade screen (+ability unlock cards, purple styling)
  LootScreen.tscn/.gd   — post-battle choose-one loot

tests/
  run_tests.gd       — headless test runner (SceneTree)
  test_rng.gd        — RNG reproducibility/bounds tests
  test_hex.gd        — HexGrid geometry tests
  test_combat.gd     — Combatant + BattleEngine tests
  test_movement.gd   — movement, ability effects, AI variants, attack_bonus (Run 2)
  test_run3.gd       — ability charges, backstab armor, collision, floor scaling, env damage (Run 3)
  test_run4.gd       — shield bash, push mechanics, ability unlocks, commentary pools (Run 4)
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
