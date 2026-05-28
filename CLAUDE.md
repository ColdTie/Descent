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
- **Architecture rule**: `BattleEngine._calculate_damage()` returns RAW damage (no armor). `Combatant.take_damage(amount, ignore_armor=false)` applies armor. Don't double-apply armor in both places.
- `Combatant.take_damage(amount, ignore_armor)` — the `ignore_armor` parameter bypasses the `armor` field reduction (for backstab, env damage, etc.)

## Current State (Run 4 — Shield Bash, Ability Unlocks, Commentary)
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
- Ability charges/cooldown wired into BattleScene HUD (dots, cooldown countdown, disabled state)
- Backstab ignores armor, architecture fix for double-armor bug
- Enemy collision avoidance, lava heat damage, victory screen, floor scaling
- Class + enemy glyphs, `apply_environment_damage`
- 109 headless tests

**Run 4 (Shield Bash + Ability Unlocks + Commentary):**
- **Shield Bash** (Brawler starting ability) — pushes enemy one hex away; if blocked by wall/lava or another unit → SLAM (15 armor-ignoring bonus damage). Makes lava edges lethal for Brawler.
  - `BattleEngine.apply_push(attacker, target, map)` — pure, testable, emits `combatant_pushed(c, from, to, slammed)` signal
- **New abilities per class (unlockable at level-up):**
  - Brawler → **Whirlwind**: hits all adjacent enemies, 12 dmg each, range 1, 3 cooldown
  - Rogue → **Smoke Bomb**: freezes all enemies within radius 2 for 2 turns, 4 cooldown
  - Arcanist → **Lightning Bolt**: 45 dmg single target, range 4, 3 cooldown
- **Ability unlocks on LevelUp screen** — when a class has an ability in `unlockable_abilities` that the hero hasn't learned, one guaranteed ability-unlock card appears (cyan) alongside 2 stat upgrades. Ability icon + `[NEW ABILITY]` tag distinguishes them visually.
- **`_do_hero_aoe_ability` refactored** — match statement handles frost_nova / smoke_bomb (hero-centered freeze), whirlwind (hero-centered damage AoE), fireball (targeted AoE). Uses `aoe_radius` from ability data.
- **The System mid-battle commentary** — 5 new trigger pools:
  - `low_hp`: fires once per battle when hero falls below 20% HP
  - `first_kill`: fires on the very first enemy kill of a run (`GameState.first_kill_done` flag)
  - `backstab_hit`: fires after hero uses backstab
  - `surrounded`: fires at start of hero turn when 3+ enemies are adjacent
  - `push_slam`: fires when Shield Bash slams an enemy into a wall
- **HP regen between floors** — `Main._on_floor_cleared` heals hero 10 HP before processing XP/loot
- **144 headless tests** — all passing: RNG (5), Hex (13), Combat (27), Movement+Abilities (24), Run3 (40), Run4 (35)

### Godot 4.4.1 API Gotchas (learned in Runs 1–4)
- `aoe_radius` must be stored in ability DATA and read with `abl.get("aoe_radius", 1)` — don't hardcode AOE radii in scene code
- `GameRng.shuffle(typed_array)` works because typed `Array[T]` coerces to untyped `Array` in GDScript method calls
- Tests that access autoload constants (e.g. `SystemVoice.LINES`) produce compile warnings in `--script` mode but still pass; keep test assertions autoload-free where possible

### Next Priorities (Run 5)
1. **Sounds** — Minimal audio pass: hit, kill, move, ability sounds (AudioStreamGenerator or simple WAVs)
2. **Multi-floor run feel** — Hero stat upgrades should visibly compound; add a "Run Stats" panel to VictoryScreen showing cumulative bonuses
3. **Enemy variety on deep floors** — New enemy types for floors 5+: Demon Archer (ranged 3, high damage), Elite Goblin (moves twice per turn), Boss on floor 10
4. **Minimap / floor depth indicator** — small progress indicator (Floor N of 10) shown during battle and on VictoryScreen
5. **Ability highlight improvements** — show Whirlwind/Smoke Bomb range overlay when hovering button; show Lightning Bolt targeting arc
5. **The System mid-battle commentary** — trigger quips on: hero surviving below 20% HP, first kill of run, using backstab successfully, hero standing adjacent to lava, enemies surrounding hero
6. **HP regeneration between floors** — currently hero HP is frozen between floors unless they take healing loot; add small passive regen (5-10 HP) between floors as a quality-of-life change
7. **Minimap / floor preview** — small indicator showing which floor you're on out of N (generate run length at run start)

## File Map
```
autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run-persistent hero state
  SystemVoice.gd     — The System commentary pools + signal

src/combat/
  Combatant.gd       — pure fighter data class (+take_damage ignore_armor param)
  BattleEngine.gd    — pure turn engine (+apply_environment_damage, +enemy collision fix, +armor fix)
  Ability.gd         — charges/cooldown data object (now wired into BattleScene HUD)
  StatusEffect.gd    — status dict factories: burning/frozen/vanished/fortified/poisoned

src/map/
  HexGrid.gd         — static hex math utilities
  DungeonMap.gd      — procedural floor generator

src/data/
  Classes.gd         — class definitions (Brawler/Rogue/Arcanist)
  Abilities.gd       — all ability definitions (+ignore_armor flag on backstab)
  EnemyDefs.gd       — enemy definitions + Combatant factory (+floor_num scaling param)

scenes/
  Main.tscn/.gd      — root, scene orchestration; now routes through VictoryScreen
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle visual driver (Run 3: charges HUD, lava heat, class glyphs)
  VictoryScreen.tscn/.gd — NEW: post-battle floor clear screen (Run 3)
  LevelUp.tscn/.gd   — upgrade screen; 3 of 6 upgrades per level
  LootScreen.tscn/.gd   — post-battle choose-one loot

tests/
  run_tests.gd       — headless test runner (SceneTree)
  test_rng.gd        — RNG reproducibility/bounds tests
  test_hex.gd        — HexGrid geometry tests
  test_combat.gd     — Combatant + BattleEngine tests
  test_movement.gd   — movement, ability effects, AI variants, attack_bonus (Run 2)
  test_run3.gd       — ability charges, backstab armor, collision, floor scaling, env damage (Run 3)
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
