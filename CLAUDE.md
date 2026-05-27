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
- `BattleEngine.perform_knockback_attack(attacker, target, ability_id, map)` — returns `Array[int, Vector2i]` = [damage, push_to_hex]. Target stays at original position if no valid push direction. Knockback CAN push into lava tiles (that's the point).
- `BattleEngine.get_push_hex(attacker_pos, target_pos, map)` — finds the neighbor of `target_pos` farthest from `attacker_pos` that is in the map's tile_types dict and unoccupied. "Wall" tiles (not in dict) are excluded; lava is allowed (tactical).
- LevelUp ability unlocks: check `item.get("is_unlock", false)` before matching `item["id"]` — unlock entries have `"ability_id"` field and use `"unlock_" + ability_id` as their id key.

## Current State (Run 4 — Shield Bash, Mid-Battle Commentary, Ability Unlocks)
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

**Run 4 (Shield Bash + Mid-Battle Commentary + Ability Unlocks):**
- **Shield Bash (Brawler)** — Brawler now starts with `shield_bash` instead of `taunt`:
  - 18 base damage + knocks enemy 1 hex away from attacker
  - Tactically push enemies into lava tiles for extra burn damage
  - Engine-level: `BattleEngine.perform_knockback_attack()` + `get_push_hex()` pure methods
  - Signal: `combatant_pushed(target, from_hex, to_hex)` → BattleScene animates with `Tween.TRANS_BACK`
  - Special System quip when pushed onto lava: "Into the lava! Poetic."
- **Mid-battle System commentary** — 5 new contextual trigger categories:
  - `hero_low_hp` — triggers once when hero HP < 20%, resets at 30% (debounce)
  - `first_kill` — first enemy kill each battle uses "first_kill" pool, rest use "kill"
  - `backstab_hit` — fires whenever backstab is used successfully
  - `hero_near_lava` — 25% chance per hero turn if adjacent to lava (avoids spam)
  - `hero_surrounded` — fires once when 3+ enemies are adjacent (debounce)
  - `shield_bash` + `ability_unlock` + `between_floors` commentary pools added
- **Ability unlocks on Level-Up** — `LevelUp.gd` now mixes ability unlock cards with stat upgrades:
  - Any hero-unlockable ability the hero doesn't already own can appear as a choice
  - Unlock cards tinted cyan/teal to stand out from gold stat upgrade cards
  - On selection: ability appended to `GameState.hero_abilities` (active next battle)
  - 7 unlockable abilities: power_strike, backstab, fireball, frost_nova, taunt, vanish, shield_bash
  - Brawler/Rogue/Arcanist can now cross-class unlock any ability via level-up
- **Between-floor HP regeneration** — `Main._on_floor_cleared()` heals 10% max HP (min 5) before routing to LevelUp/LootScreen
- **136 headless tests** — all passing: +27 new Run4 tests covering knockback, push direction, signal, walls, SystemVoice categories, regen formula, unlock pool logic

### Next Priorities (Run 5)
1. **Sounds** — Even a minimal audio pass: hit, kill, move, ability sounds (use Godot's AudioStreamGenerator or import simple beeps)
2. **Enemy knockback awareness** — Enemies near lava should prioritize getting away from lava on their turn (currently they ignore it). Makes lava a real two-way hazard.
3. **Multi-floor run feel** — hero upgrades should compound visibly. Consider showing a "Run summary so far" overlay at floor 3, 6, 10. Also add more interesting stat synergies in the upgrade pool.
4. **Minimap / floor counter** — small "Floor N / 10" indicator (generate run length at start). Show a progress bar toward the boss floor.
5. **Boss floor** — every 5 floors, spawn a boss enemy with a custom sprite key and unique abilities. Victory over the boss should give a special loot drop.
6. **Loot screen polish** — currently loot choices are plain text. Show an icon, stat change preview, and The System commentary for each option.
7. **XP-driven ability upgrade screen** (Run 4 LevelUp is stat-only or unlock; next: add PER-ABILITY upgrades within the LevelUp flow, e.g. "Power Strike: +5 damage" or "Backstab: +1 charge")

## File Map
```
autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run-persistent hero state
  SystemVoice.gd     — The System commentary pools + signal

src/combat/
  Combatant.gd       — pure fighter data class (+take_damage ignore_armor param)
  BattleEngine.gd    — pure turn engine (+knockback: perform_knockback_attack, get_push_hex, combatant_pushed signal)
  Ability.gd         — charges/cooldown data object (now wired into BattleScene HUD)
  StatusEffect.gd    — status dict factories: burning/frozen/vanished/fortified/poisoned

src/map/
  HexGrid.gd         — static hex math utilities
  DungeonMap.gd      — procedural floor generator

src/data/
  Classes.gd         — class definitions (Brawler now starts with shield_bash instead of taunt)
  Abilities.gd       — all ability definitions (+shield_bash with knockback:1 flag)
  EnemyDefs.gd       — enemy definitions + Combatant factory (+floor_num scaling param)

scenes/
  Main.tscn/.gd      — root, scene orchestration; +between-floor HP regen
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle (Run 4: shield_bash knockback, mid-battle commentary, combatant_pushed)
  VictoryScreen.tscn/.gd — post-battle floor clear screen
  LevelUp.tscn/.gd   — upgrade screen; now mixes stat upgrades AND ability unlock cards
  LootScreen.tscn/.gd   — post-battle choose-one loot

tests/
  run_tests.gd       — headless test runner (SceneTree)
  test_rng.gd        — RNG reproducibility/bounds tests
  test_hex.gd        — HexGrid geometry tests
  test_combat.gd     — Combatant + BattleEngine tests
  test_movement.gd   — movement, ability effects, AI variants, attack_bonus (Run 2)
  test_run3.gd       — ability charges, backstab armor, collision, floor scaling, env damage (Run 3)
  test_run4.gd       — shield_bash, knockback logic, SystemVoice categories, regen, unlock pool (Run 4)
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
