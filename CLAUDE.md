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
- Dictionary keys with `Vector2i` work by value in GDScript 4. You can manually override generated map tiles: `map.tile_types[Vector2i(x,y)] = "floor"` / `map.passable[Vector2i(x,y)] = true`. This is the correct pattern for deterministic push-path tests.
- Signal handlers with `await` are coroutines — control returns to the emitter at the first `await`. Safe to use for brief async commentary (e.g., backstab quip after a 0.15s delay) but don't assume they block the caller.
- `_` prefix on function parameters is a GDScript convention for "unused" — remove the prefix when you need to reference the parameter in Run 4+ signal handlers (`_on_action_taken(attacker, ..., ability_id)`).

## Current State (Run 4 — Pushback, Mid-Battle Commentary, Ability Unlocks, HP Regen)
### Implemented ✅

**Run 4 (Pushback + Commentary + Unlocks):**
- Shield Bash (Brawler) + BattleEngine.push_combatant() with lava-landing damage
- Whirlwind ability (AOE melee, unlockable)
- Mid-battle System commentary: first_kill, low_hp, backstab_success, surrounded, pushback
- Dynamic ability unlock cards on level-up screen
- HP regen (10% max HP, min 5) between floors, shown on VictoryScreen
- 146 headless tests passing

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

**Run 4 (Pushback + Commentary + Ability Unlocks + HP Regen):**
- **Shield Bash** — Brawler melee ability that deals 15 damage and hurls the enemy 2 hexes backward. If they land on lava, they take 15 extra env damage. Makes lava tiles tactically decisive. Brawler now starts with: basic_attack, power_strike, shield_bash, taunt.
- **Whirlwind** — AOE melee ability (all_enemies, range 1, 16 damage). Available as an unlock from LevelUp.
- **BattleEngine.push_combatant()** — new pure-logic pushback mechanic. Takes pusher, target, distance, map; walks target along the push direction, stops at walls/occupants, deals lava env damage on landing. `_closest_hex_direction()` helper converts arbitrary delta to unit hex direction.
- **combatant_pushed signal** — BattleScene listens and animates the slide/bounce.
- **Mid-battle System commentary** — five new categories, triggered live in BattleScene:
  - `first_kill`: on the very first enemy death of a battle
  - `low_hp`: once when hero falls below 20% HP
  - `backstab_success`: after hero uses backstab (via `_on_action_taken`)
  - `surrounded`: when 3+ enemies are adjacent to the hero (resets when cleared)
  - `pushback`: whenever a push animation fires
- **SystemVoice new categories**: first_kill, low_hp, backstab_success, surrounded, pushback, ability_unlock, floor_regen
- **Ability unlocks on level-up** — LevelUp.gd now builds a DYNAMIC pool: stat upgrades + any unlockable ability the hero doesn't already have. Unlock cards are visually distinct (cyan name, "✦ NEW ABILITY ✦" tag, charges/cooldown metadata). Unlockable abilities: fireball, frost_nova, backstab, power_strike, taunt, vanish, shield_bash, whirlwind.
- **HP regen between floors** — After clearing a floor, hero heals 10% of max HP (min 5). Regen is shown as a "💚 RECOVERED" stat card on VictoryScreen.
- **146 headless tests** — all passing (5 suites + new test_run4.gd: 37 tests covering pushback, hex direction, ability data, unlock pool filtering, HP regen calculation, SystemVoice categories)

### Next Priorities (Run 5)
1. **Sounds** — Even a minimal audio pass: hit, kill, move, ability sounds (Godot AudioStreamGenerator beeps, or import OGG files)
2. **Enemy variety and new enemy types** — add a "Witch" or "Necromancer" ranged enemy that casts status effects; a "Brute" that also does pushback; elevate combat from "rush the hero" to "manage positioning" for the player
3. **Run length and floor preview** — generate a fixed run (e.g., 10 floors) at start, show "Floor N / 10" in battle HUD and VictoryScreen so players see progress toward a win condition
4. **Boss floor** — at floor 5 and floor 10 (or configurable), spawn a single boss enemy with much higher HP, special multi-phase abilities, and a big XP/loot reward
5. **Status effect improvements** — poison from enemies (Witch's curse), burning from lava adjacency applying the `burning` status, so status icons on HUD are actually used in gameplay
6. **Class Select polish** — show each class's full ability list with actual ability icons/colors; add flavor text ("The Brawler favors a direct approach. The dungeon respects this."); animate selection

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
  test_run4.gd       — pushback mechanic, hex direction, shield_bash/whirlwind data, unlock pool, regen (Run 4)
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
