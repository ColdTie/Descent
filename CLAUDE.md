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
- `[a] + typed_array` creates an **untyped** Array, NOT `Array[T]` — always build typed arrays by declaring `var arr: Array[T] = []` then appending
- `Dictionary.get(key, default_array)` always returns untyped `Array`, never `Array[T]` — must iterate and append when assigning to a typed variable
- `DungeonMap.is_passable()` returns false for lava tiles — for push-into-lava mechanic, check `tile_types.has(hex)` (in dungeon area?) instead of passability

## Current State (Run 4 — Push Mechanic, Reactive Commentary, Ability Unlocks, HP Regen)
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
- **Ability charges/cooldown wired into BattleScene HUD:**
  - Each hero ability tracked with an `Ability` object (`_hero_ability_objs` dict)
  - Buttons show charge dots (●●○), cooldown countdown (↻3), or ∞ for unlimited
  - Depleted abilities are greyed out and disabled; can't be clicked
  - Cooldowns tick at the START of each hero turn (so cooldown 4 = 4 of YOUR turns)
  - Message shown when trying to use an ability on cooldown
- **Backstab correctly ignores armor** — `ignore_armor` flag in `Abilities.DATA` + `Combatant.take_damage(amount, ignore_armor=false)` param
- **Architecture fix**: `_calculate_damage` returns raw damage; `take_damage` is the single armor-application point. Eliminated double-armor bug from Run 1/2.
- **Enemy collision avoidance** — `BattleEngine._move_toward` checks for living combatants at target hex; enemies can't stack
- **Lava heat damage** — Any entity starting their turn adjacent to lava takes heat damage (3 + 3*(adjacent_count-1)), bypassing armor. Makes lava tiles tactically significant.
- **Victory screen** (`VictoryScreen.tscn/.gd`) — "FLOOR N CLEARED!" with gold title, System quip, stats (kills / XP / level / HP), "DESCEND DEEPER" button
  - Flow: BattleScene → VictoryScreen → (level check) → LevelUp or LootScreen → next floor
- **Floor scaling** — `EnemyDefs.make_combatant(def, pos, rng, floor_num)`: +20% HP per floor above 1; +1 armor every 2 floors
- **Class glyph on hero** — entity node shows ⚔ for Brawler, 🗡 for Rogue, ✦ for Arcanist; class-colored hex body
- **Enemy glyphs** — 👿 Imp, G Goblin, 💀 Skeleton, D Demon, ⬡ Golem
- **`apply_environment_damage`** on BattleEngine — deals armor-ignoring damage for lava/env hazards
- **109 headless tests** — all passing: RNG (5), Hex (13), Combat (27), Movement+Abilities (24), Run3 (40)

**Run 4 (Push Mechanic + Reactive Commentary + Ability Unlocks + HP Regen):**
- **Shield Bash ability** — New Brawler ability (`shield_bash`): 18 dmg, 1 charge, 3-turn CD, pushes target 1 hex away
  - Push into lava = 30 env damage immediately (armor-ignored) + "push_into_lava" commentary
  - Push blocked by walls/off-map or another entity = "push_blocked" commentary
  - `BattleEngine.push_combatant(attacker, target, map)` → pure logic, returns push result dict
  - `combatant_pushed` signal on BattleEngine for visual animation
  - Highlights show enemy + push destination (lava-colored if lava) when Shield Bash selected
- **Poison Strike ability** — New unlockable ability: 12 dmg + applies poisoned (5 dmg/turn, 3 turns), 2 charges, 3-turn CD
- **Reactive System commentary** — Mid-battle quips triggered by:
  - Hero HP < 20% for first time (`low_hp` pool, announced once)
  - 3+ adjacent enemies at turn start (`surrounded` pool)
  - Standing next to lava for first time (`lava_adjacent` pool)
  - Backstab hit (`backstab_hit` pool)
  - First enemy kill of the run (`first_kill` pool, all subsequent → `kill` pool)
  - Push into lava / push blocked (`push_into_lava` / `push_blocked` pools)
- **Ability unlocking at Level-Up** — LevelUp screen now combines stat upgrades with ability unlock options
  - Each class has `unlockable_abilities`: Brawler → [fireball, frost_nova, poison_strike]; Rogue → [power_strike, poison_strike, frost_nova]; Arcanist → [backstab, taunt, poison_strike]
  - Only abilities the hero doesn't already own are offered
  - Unlock cards shown in cyan (vs gold for stat upgrades), "UNLOCK IT" button
  - Appends ability to `GameState.hero_abilities`; BattleScene rebuilds objects each floor
- **HP regen between floors** — `GameState.descend()` heals `max(1, hero_max_hp / 10)` HP passively
- **Bug fix**: `GameState.start_run()` typed array assignment (untyped Array → Array[String]) — now iterates to append
- **Bug fix**: `BattleScene._build_encounter()` `_all_combatants` typed array — now appends individually
- **156 headless tests** — all passing: RNG (5), Hex (13), Combat (27), Movement+Abilities (24), Run3 (40), Run4 (47)

### Next Priorities (Run 5)
1. **Sounds** — Even a minimal audio pass: hit, kill, move, ability sounds (AudioStreamGenerator or procedural beeps)
2. **Minimap / floor indicator** — top-left shows "Floor N / 10" run length; generate run_length at start of run
3. **Poison strike visual** — show ☠ poison icon on poisoned enemies in HUD + periodic damage floaters
4. **Enemy variety on later floors** — floor 5+ should spawn Skeletons and Demons (stronger types); currently imps/goblins dominate
5. **LootScreen upgrades** — currently loot is stat-based; add "ability tome" loot that unlocks an ability immediately
6. **Healing items** — "Blessed Bandage" / "Demon Blood Flask" as loot options; more HP recovery choices
7. **Combo kill** — the Rogue vanish+backstab combo should get special commentary; currently it's just "backstab_hit"
8. **Golem sentry AI** — golems with ranged fire should also not stack; currently broken (they sit at spawn but enemy_fireball fires from range 3)

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
