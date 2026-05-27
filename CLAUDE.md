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
- `Array[Dictionary].slice()` returns an untyped Array — use explicit loop to build typed slice: `for i in range(n): arr.append(pool[i])`
- **Push direction**: use cube-coordinate dot product (q, r, -q-r) to find nearest hex direction; plain axial dot product gives wrong results for e.g. (0,-1) direction
- **Headless screenshots** (Xvfb): need `openbox` WM running first and ~15s for Godot to fully render before `scrot` captures correctly

## Current State (Run 4 — Shield Bash, Commentary, Ability Unlock, HP Regen)
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
- **Backstab correctly ignores armor** — `ignore_armor` flag in `Abilities.DATA` + `Combatant.take_damage(amount, ignore_armor=false)` param
- **Architecture fix**: `_calculate_damage` returns raw damage; `take_damage` is the single armor-application point.
- **Enemy collision avoidance** — enemies can't stack on living combatants
- **Lava heat damage** — Any entity starting their turn adjacent to lava takes heat damage (3 + 3*(adjacent_count-1)), bypassing armor
- **Victory screen** (`VictoryScreen.tscn/.gd`) — "FLOOR N CLEARED!" with gold title, System quip, stats
- **Floor scaling** — `EnemyDefs.make_combatant`: +20% HP per floor above 1; +1 armor every 2 floors
- **Class glyph on hero** — ⚔ Brawler, 🗡 Rogue, ✦ Arcanist; class-colored hex body
- **109 headless tests**

**Run 4 (Shield Bash, Commentary, Ability Unlock, HP Regen):**
- **Shield Bash ability** — Brawler's new signature move:
  - `shield_bash` in `Abilities.DATA`: 18 base damage, 2 charges, 2-turn cooldown, push_distance=2
  - Added to Brawler starting kit (now has 4 abilities: basic_attack, power_strike, taunt, shield_bash)
  - `BattleEngine.perform_push(attacker, target, distance, map=null)`: pushes target `distance` hexes away from attacker using cube-coordinate dot product to find correct direction; stops at impassable tiles or living combatants
  - New `combatant_pushed` signal on BattleEngine
  - BattleScene: after `perform_attack` with shield_bash, calls `perform_push`; animates enemy sliding with TRANS_BACK tween; bonus quip if pushed adjacent to lava
- **Mid-battle The System commentary** — DCC tone now fires during combat:
  - `low_hp` pool: fires once when hero HP drops below 20% (tracked with `_low_hp_warned` flag)
  - `surrounded` pool: fires when 3+ enemies are adjacent; resets when hero escapes; tracked with `_surrounded_warned`
  - `backstab_hit` pool: fires when hero uses backstab ability
  - `first_kill` pool: fires on the very first enemy kill of the entire run (tracked via `GameState.total_kills`)
  - `push_hit` pool: fires on each successful push; bonus "adjacent to lava" quip if target lands near lava
  - `between_floors` pool: fires during floor transition regen
- **Ability unlocking at level-up** — LevelUp screen now offers cross-class ability unlocks:
  - Dynamically adds unlock entries for abilities the hero doesn't have yet to the upgrade pool
  - Each unlock card shows ability name, description, and "[New ability added to your bar]"
  - Applying unlock appends ability_id to `GameState.hero_abilities`; BattleScene picks it up on next floor
  - Pool: power_strike, backstab, fireball, frost_nova, taunt, vanish, shield_bash
- **HP regeneration between floors** — `GameState.heal_between_floors()`: ~8% of max HP (min 5); called in `Main._on_loot_chosen()` with `between_floors` System commentary
- **Kill tracking** — `GameState.total_kills` persists across floors; used for first-kill commentary; reset on new run
- **135 headless tests** — all passing: RNG (5), Hex (13), Combat (27), Movement+Abilities (24), Run3 (40), Run4 (26)

### Next Priorities (Run 5)
1. **Sounds** — Minimal audio pass: hit/kill/move/ability sounds using AudioStreamGenerator or simple procedural beeps; current audio falls back to dummy driver (no audio hardware in CI)
2. **Enemy "push into lava" death** — when push lands an enemy ON a lava-adjacent tile, they take heat damage next turn; future: make lava _fully_ impassable and kill enemies at edge? Or add "lava push kill" instant mechanic?
3. **Visual polish: push animation** — add a visual "whoosh" effect when enemy is pushed (brief flash/trail) to make Shield Bash feel more impactful
4. **Minimap / floor progress indicator** — small top-right indicator: "Floor N of M" with a simple progress bar; generate run length at run start (e.g. 5-10 floors)
5. **Enemy with push** — give the Golem a "Shove" ability that can push the hero toward lava — creates symmetric tactical back-and-forth
6. **Loot screen improvements** — currently loot choices are generic; tie them to class identity (Rogue gets stealth items, Arcanist gets mana crystals, etc.)
7. **Roguelike meta-goal** — generate a "boss floor" every 5 floors with a named, scaled enemy using a boss-specific ability set
8. **Run 4 ability unlock UX improvement** — currently unlock cards mix with stat upgrade cards randomly; consider making a dedicated "CHOOSE ABILITY" tab in the LevelUp screen for clearer player choice

## File Map
```
autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run-persistent hero state (+total_kills, +heal_between_floors)
  SystemVoice.gd     — The System commentary pools + signal (+8 new pools in Run 4)

src/combat/
  Combatant.gd       — pure fighter data class
  BattleEngine.gd    — pure turn engine (+perform_push, +combatant_pushed signal)
  Ability.gd         — charges/cooldown data object
  StatusEffect.gd    — status dict factories

src/map/
  HexGrid.gd         — static hex math utilities
  DungeonMap.gd      — procedural floor generator

src/data/
  Classes.gd         — class definitions (+shield_bash for Brawler)
  Abilities.gd       — all ability definitions (+shield_bash with push_distance)
  EnemyDefs.gd       — enemy definitions + Combatant factory

scenes/
  Main.tscn/.gd      — root, scene orchestration (+floor regen in _on_loot_chosen)
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle visual driver (+push wiring, +commentary triggers)
  VictoryScreen.tscn/.gd — post-battle floor clear screen
  LevelUp.tscn/.gd   — upgrade screen (+dynamic ability unlock options in pool)
  LootScreen.tscn/.gd   — post-battle choose-one loot

tests/
  run_tests.gd       — headless test runner (SceneTree)
  test_rng.gd        — RNG reproducibility/bounds tests
  test_hex.gd        — HexGrid geometry tests
  test_combat.gd     — Combatant + BattleEngine tests
  test_movement.gd   — movement, ability effects, AI variants, attack_bonus
  test_run3.gd       — ability charges, backstab armor, collision, floor scaling, env damage
  test_run4.gd       — NEW: push direction, push collision, push signal, regen math, unlock pool
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
