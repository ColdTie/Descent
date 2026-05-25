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

## Godot 4.4.1 API Gotchas (accumulated)
- `RandomNumberGenerator` has NO `.shuffle()` method — use Fisher-Yates manually or `Array.shuffle()` (global seed, not deterministic)
- `Array[T].filter(callable)` returns an untyped `Array`, not `Array[T]`
- `Classes.get_class()` conflicts with `Object.get_class()` — renamed to `get_class_data()`
- GDScript lambdas capture local variables **by value** — to read lambda-set state, check it on the object, not the captured var
- Typed `Array[String]` can't be assigned from an untyped `Array` directly — must iterate and append
- Typed `Array[Combatant]` likewise — can't do `= [a] + b_array`; must `.clear()` + `.append()` each element
- Autoloads are NOT type-checked in `--script` mode; keep tests free of autoload references
- `_ = variable` is NOT valid GDScript syntax to suppress unused warnings — just remove the unused variable
- Class-scoped `const SELECTED_ABILITY` vs methods using it must match name exactly — don't rename in one place

## Current State (Run 2 — Movement & Abilities)
### Implemented ✅
**Run 1 foundation:**
- `GameRng` autoload — seeded Fisher-Yates RNG, reproducible runs
- `GameState` autoload — run state (class, HP, XP, floor, stats, signals, `enemies_killed`)
- `SystemVoice` autoload — The System's dry commentary with line pools, no-repeat cycling
- `Combatant` — pure data class: HP, armor, speed, `stats` dict, status effects, typed abilities
  - New: `has_status()`, `remove_status()`, `take_damage(ignore_armor=false)`
- `BattleEngine` — pure turn rules engine
  - New: `active_turn_skipped` flag for frozen detection
  - New: `perform_ability()` dispatcher (fireball AOE, frost_nova, taunt, vanish)
  - New: enemy `_move_toward()` — enemies pathfind toward hero before attacking
  - New: `entity_moved` signal for visual animation
  - Fixed: armor applied once (in `take_damage`), not twice
  - Fixed: hero's `stats.attack` bonus applied in damage calculation
- `StatusEffect` — factories for burning/frozen/poisoned/fortified/**vanished**
- `HexGrid`, `DungeonMap`, `Classes`, `Abilities`, `EnemyDefs` — unchanged

**Run 2 additions:**
- **Hero movement** — player can click adjacent passable hex to move (green highlights), then click enemy to attack
- **Ability effects** — fireball (AOE radius 2), frost_nova (freeze all adjacent), taunt (fortified armor), vanish (3× next hit) all work
- **Frozen turns** — frozen enemies/hero skip their turn for N duration; shown in UI
- **Enemy movement** — enemies step toward hero before attacking
- **Cave atmosphere** — stalagmite polygon silhouettes at map edges, lava tile pulse animation
- **Death Screen** — "YOU DIED" overlay with System quip, run stats (floor, kills, level, class), Restart button
- **Level-Up Screen** — 3-card upgrade picker: Recharge/Stat/Ability tabs, filters out known abilities
- **END TURN button** — player can skip their turn entirely
- **Visual FX** — AOE flash rings (fireball/frost_nova), hit burst (backstab/power_strike), buff float text (fortified/vanished)
- **76 headless tests** — all passing: RNG (5), Hex (13), Combat (27), Abilities (31)

## Next Priorities (Run 3)
1. **Sprite/art pass** — replace placeholder letter-initials with simple sprite sheets or procedural silhouettes; improve enemy visual identity
2. **Ability charge system** — track per-ability charges/cooldowns visually in the ability bar (greyed out when on cooldown, show charge count)
3. **Loot screen improvements** — show ability loot cards with proper icons; make recharge actually restore charges
4. **Hex path indicators** — show the actual path an enemy took when it moves (brief trail of dimming hexes)
5. **Floor progression** — improve DungeonMap variety: wall clusters, chokepoints; fix enemy count scaling to feel meaningful by floor 5+
6. **Polish** — System Voice lines for movement, freeze, taunt, vanish; level-up fanfare; death screen stats count up

## File Map
```
autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run state (class, HP, XP, floor, stats, enemies_killed, signals)
  SystemVoice.gd     — The System commentary pools + signal

src/combat/
  Combatant.gd       — pure fighter data (stats dict, has_status/remove_status, ignore_armor)
  BattleEngine.gd    — pure turn engine (perform_ability, enemy_move, frozen skip)
  Ability.gd         — charges/cooldown data
  StatusEffect.gd    — factories: burning/frozen/fortified/poisoned/vanished

src/map/
  HexGrid.gd         — static hex math utilities
  DungeonMap.gd      — procedural floor generator

src/data/
  Classes.gd         — class definitions (Brawler/Rogue/Arcanist)
  Abilities.gd       — all ability definitions (fireball, frost_nova, vanish, taunt, etc.)
  EnemyDefs.gd       — enemy definitions + Combatant factory

scenes/
  Main.tscn/.gd      — root, scene orchestration: ClassSelect→Battle→(LevelUp?)→Loot→loop
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle visual driver (movement, highlights, VFX, atmosphere)
  LootScreen.tscn/.gd   — post-battle choose-one loot
  DeathScreen.tscn/.gd  — YOU DIED overlay + run summary + restart
  LevelUpScreen.tscn/.gd — level-up 3-card upgrade picker

tests/
  run_tests.gd       — headless test runner (SceneTree)
  test_rng.gd        — RNG reproducibility/bounds tests
  test_hex.gd        — HexGrid geometry tests
  test_combat.gd     — Combatant + BattleEngine tests
  test_abilities.gd  — ability effects, frozen, vanish, fireball AOE, enemy movement
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

## Screenshot (CI / headless)
```bash
Xvfb :99 -screen 0 1280x720x24 &
nohup env DISPLAY=:99 godot --path /path/to/descent > /tmp/godot.log 2>&1 &
disown
sleep 5
DISPLAY=:99 scrot screenshot.png
# Navigate using xdotool in separate shell invocations (not chained with background godot)
# GOTCHA: sleep calls in same bash invocation as backgrounded godot get SIGUSR1 killed
```

## DCC Tone Guidelines
- The System speaks in second person, addressing "Hero"
- Dry, mocking, never cheerful
- Short sentences. Statistical references. Faint disdain.
- Never breaks the fourth wall explicitly, but is clearly aware it's a game
- Example: "You have died. This is embarrassing for both of us."
