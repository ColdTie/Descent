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

## Godot 4.4.1 API Gotchas (learned in Runs 1–5)
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
- `Array[Dictionary].slice()` returns an untyped Array — use explicit loop to build typed slice: `for i in range(n): arr.append(pool[i])`
- **Push direction**: use cube-coordinate dot product (q, r, -q-r) to find nearest hex direction; plain axial dot product gives wrong results for e.g. (0,-1) direction
- **Headless screenshots** (Xvfb): need `openbox` WM running first and ~15s for Godot to fully render before `scrot` captures correctly
- **Enemy ability cooldowns in BattleEngine**: use `_enemy_ability_cooldowns: Dictionary` (combatant_id → {ability_id → turns_remaining}); call `_tick_enemy_cooldowns(enemy)` at the start of each enemy's AI turn; `_enemy_ability_ready()` / `_enemy_use_ability()` helpers
- **Boss entity spawning**: `BossDefs.make_boss()` always sets `sprite_key = "boss"` for all bosses; BattleScene `match enemy.sprite_key` dispatch uses `"boss"` case for boss AI

## Current State (Run 5 — Boss Floors, Golem Shove, Floor Progress)
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
- Ability charges/cooldown HUD (●●○ dots, ↻3 countdown, ∞ unlimited)
- Backstab ignores armor; architecture fix (no double-armor)
- Enemy collision avoidance, lava heat damage, Victory screen, floor scaling
- Class/enemy glyphs
- **109 headless tests**

**Run 4 (Shield Bash, Commentary, Ability Unlock, HP Regen):**
- Shield Bash: 18 dmg, 2 charges, push_distance=2 for Brawler
- `BattleEngine.perform_push()` using cube-coord dot product for correct direction
- Mid-battle commentary: low_hp, surrounded, backstab_hit, first_kill, push_hit, between_floors
- Ability unlocking at level-up: cross-class builds
- HP regeneration ~8% between floors
- **135 headless tests**

**Run 5 (Boss Floors, Golem Shove, Floor Progress):**
- **Boss Floors every 5 floors** — `BossDefs.gd` new pure data class:
  - 3 bosses cycling: Stone Herald (floor 5), Wrathful Champion (floor 10), Demon Overlord (floor 15)
  - `BossDefs.is_boss_floor(floor_num)`: `floor_num > 0 and floor_num % 5 == 0`
  - `BossDefs.get_boss_for_floor(floor_num)`: cycles via `(tier) % BOSSES.size()`
  - `BossDefs.make_boss(floor_num, pos, rng)`: creates Combatant with HP scaling (+50%/tier), armor scaling (+2/tier), XP scaling (+50/tier), sprite_key="boss"
  - Boss abilities: `boss_slam` (32 dmg, 4t cd), `boss_cleave` (26 dmg, 3t cd), `boss_inferno` (28 dmg, range 2, 3t cd)
  - `GameState.is_boss_floor()` wrapper — returns `BossDefs.is_boss_floor(floor_num)`
- **Boss floor BattleScene** — when `is_boss_floor`:
  - Spawns single boss (no normal enemies)
  - Floor label shows "⚠ BOSS  Floor N / M" in red
  - Boss entity: larger hex body (55% vs 42%), deep crimson color, pulsing aura tween, gold glyph, name label above
  - `boss_encounter` System commentary on enter; boss flavor text shown
  - `boss_defeated` commentary in Main when boss floor battle won
- **Boss AI** — `"boss"` sprite_key case in `enemy_ai_action`:
  - Moves toward hero, uses `_pick_boss_ability()` to select highest-damage in-range, non-cooldown ability
  - `_enemy_ability_cooldowns` dict tracks per-combatant ability cooldowns for enemy AI
  - `_tick_enemy_cooldowns()`, `_enemy_ability_ready()`, `_enemy_use_ability()` engine helpers
- **VictoryScreen boss variant** — when `was_boss_floor`:
  - Shows "BOSS DEFEATED!" in red-orange instead of "CLEARED!" in gold
  - Uses `BOSS_QUIPS` pool (dungeon's HR filing a complaint, etc.)
  - Floor progress bar now present on ALL victory screens: orange fill for boss floors, blue for normal
  - Red tick-marks at every 5th floor position on the progress bar
- **Floor Progress Indicator** — "Floor N / M" everywhere:
  - `GameState.run_length = 10` (set at `start_run`)
  - BattleScene floor label: "Floor N / M" (or "⚠ BOSS  Floor N / M" for boss floors)
  - VictoryScreen: `FLOOR N / M` text + colored progress bar with boss markers
  - Main passes `was_boss_floor` in the `prepare()` data dict to VictoryScreen
- **Golem Shove (enemy push mechanic)** — symmetric tactical mechanic:
  - `enemy_shove` ability: 10 base damage, push_distance=2, unlimited, range=1
  - Added to Lava Golem's abilities list in EnemyDefs
  - Golem AI updated: when hero is ADJACENT (dist≤1), use shove (attack + push); else fire breath at range 3
  - `_on_combatant_pushed` in BattleScene now differentiates hero vs enemy pushes:
    - Hero push: `hero_pushed` System commentary; bonus quip if adjacent to lava
    - Enemy push: existing `push_hit` commentary + lava quip
- **System Voice new pools**: `boss_encounter` (5 lines), `boss_defeated` (5 lines), `hero_pushed` (5 lines)
- **174 headless tests** — all passing: RNG (5), Hex (13), Combat (27), Movement+Abilities (24), Run3 (40), Run4 (26), Run5 (39)

### Next Priorities (Run 6)
1. **Sounds** — AudioStreamGenerator or procedural beeps; structure audio stubs so sounds can be wired in
2. **Loot screen class-identity** — tie loot choices to hero class (Rogue gets stealth/crit items, Arcanist gets spell crystals, Brawler gets armor/regen items)
3. **Push-into-lava instant kill** — when boss/golem push lands enemy/hero ON a lava tile, deal bonus damage or instakill; makes lava truly deadly as a tactical weapon
4. **Boss title card** — full-screen boss introduction: black background, boss name, flavor text, then fade into battle; currently just System banner
5. **Ability unlock UX improvement** — dedicated "CHOOSE ABILITY" tab on LevelUp screen, separate from stat upgrades; currently ability unlocks mix randomly with stat cards
6. **Visual push trail** — brief flash/trail on pushed entities to make Shield Bash feel punchy
7. **Post-run summary screen** — after floor 10 (run end), show full-run stats; currently only per-floor victory

## File Map
```
autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run-persistent hero state (+run_length, +is_boss_floor())
  SystemVoice.gd     — The System commentary (+boss_encounter, +boss_defeated, +hero_pushed)

src/combat/
  Combatant.gd       — pure fighter data class
  BattleEngine.gd    — pure turn engine (+boss AI, +golem shove, +enemy cooldown tracking)
  Ability.gd         — charges/cooldown data object
  StatusEffect.gd    — status dict factories

src/map/
  HexGrid.gd         — static hex math utilities
  DungeonMap.gd      — procedural floor generator

src/data/
  Classes.gd         — class definitions
  Abilities.gd       — all ability definitions (+enemy_shove, +boss_slam/cleave/inferno)
  EnemyDefs.gd       — enemy definitions + Combatant factory (+enemy_shove for golem)
  BossDefs.gd        — NEW: boss definitions + make_boss factory + is_boss_floor static

scenes/
  Main.tscn/.gd      — root, scene orchestration (+was_boss_floor in prepare data, +boss_defeated commentary)
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle visual driver (+boss spawn, +boss entity style, +hero push commentary)
  VictoryScreen.tscn/.gd — post-battle floor clear (+boss variant, +floor progress bar)
  LevelUp.tscn/.gd   — upgrade screen
  LootScreen.tscn/.gd   — post-battle choose-one loot

tests/
  run_tests.gd       — headless test runner
  test_rng.gd        — RNG reproducibility/bounds tests
  test_hex.gd        — HexGrid geometry tests
  test_combat.gd     — Combatant + BattleEngine tests
  test_movement.gd   — movement, ability effects, AI variants, attack_bonus
  test_run3.gd       — ability charges, backstab armor, collision, floor scaling, env damage
  test_run4.gd       — push direction/collision/signal, regen math, unlock pool
  test_run5.gd       — NEW: BossDefs, boss floor detection, boss HP/armor/XP scaling,
                         golem shove (damage+push+signal), boss AI (ability pick, cooldown, range filter)
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
# Install deps: apt-get install xvfb openbox scrot
rm -f /tmp/.X99-lock 2>/dev/null
Xvfb :99 -screen 0 1280x720x24 &
sleep 1
DISPLAY=:99 openbox &
sleep 2
DISPLAY=:99 godot --path /path/to/descent &
sleep 15  # wait for full render
DISPLAY=:99 scrot screenshot.png
# Navigate: xdotool mousemove 440 410 click 1  (Brawler SELECT)
#           xdotool mousemove 640 490 click 1  (DESCEND INTO HELL)
```

## DCC Tone Guidelines
- The System speaks in second person, addressing "Hero"
- Dry, mocking, never cheerful
- Short sentences. Statistical references. Faint disdain.
- Never breaks the fourth wall explicitly, but is clearly aware it's a game
- Example: "You have died. This is embarrassing for both of us."
