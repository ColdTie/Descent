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
- `_check_battle_end()` must guard `if battle_over: return true` to prevent double emission when lava kills trigger it AND `end_turn()` also calls it

## Current State (Run 3 — Charges, Scaling, Lava, Victory)

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
- **Ability effects fully implemented:** fireball (AOE), frost_nova (freeze), taunt (fortify), vanish (3× damage)
- **Self-target UX** — pressing an already-selected self-target ability button uses it immediately
- **Cave atmosphere** — `CanvasModulate` blue-purple tint; dark stalagmite polygons in outer rings (6–7); lava tiles pulse orange↔dim with staggered tweens
- **Status icon labels** on entity nodes (🔥❄☠🛡👁)
- **Death overlay** — "YOU DIED" with System quip, floor/kill/level stats, animated fade, "TRY AGAIN" button → back to class select
- **Level-up screen** (`LevelUp.tscn/.gd`) — 6-upgrade pool shuffled to 3 choices; atk/spd/hp/def/xp/heal variants; DCC quip on each
- **Enemy AI variety:** Golem (ranged), Goblin (flanks), Imp (rushes), Default (random)
- **69 headless tests** — all passing

**Run 3 (Charges, Scaling, Lava, Victory):**
- **Ability charges/cooldown tracking** — `Ability` objects now wired into BattleScene; HUD shows `∞` for unlimited, `N/N` for charges, `⏳N` for cooldown; depleted abilities grayed out and blocked; charges tick down after each hero turn
- **Victory screen** (`VictoryScreen.tscn/.gd`) — "FLOOR N CLEARED" + System quip + stats (kills, XP, level, HP) + "DESCEND" button; shown after every battle win before LootScreen; XP applied only when player clicks Descend
- **Enemy collision avoidance** — `_move_toward()` now checks for other living combatants before committing a step; enemies spread out naturally
- **Floor progression scaling** — `EnemyDefs.make_combatant()` accepts `floor_num`; HP scales +15% per floor above 1; attack_bonus scales +2 per floor above 1
- **Lava hazard** — `BattleEngine.apply_lava_damage()` checks all neighbors; 3 unmitigated fire damage per turn if adjacent to lava; triggers `lava_damaged` signal for visuals; can kill enemies (ends battle) or hero (death overlay)
- **Hero class icons** — Brawler: pentagon shield, Rogue: narrow dagger diamond, Arcanist: 6-pointed star; white polygon replaces letter initial on hero entity
- **Battle end guard** — `_check_battle_end()` now guards against double emission with `if battle_over: return true`
- **GameState tracking** — `last_battle_kills` and `last_battle_xp` stored on GameState for VictoryScreen
- **94 headless tests** — all passing: RNG (5), HexGrid (13), Combat (27), Movement+Abilities (24), Run3 (25)

### Next Priorities (Run 4)
1. **Sounds** — even minimal audio pass: hit, kill, move, ability sounds; game currently uses dummy audio driver (no hardware needed in container, but file-based synthesized sounds should work with `AudioStreamGenerator`)
2. **Enemy icons** — enemies currently show a letter initial; add polygon icons per enemy type (imp=horns, goblin=spike, skeleton=skull outline, golem=hexagon)
3. **Floor exit mechanic** — the `exit_pos` from DungeonMap is never shown or used; add a staircase icon and let hero walk to it to descend without killing all enemies
4. **Status effect visuals** — show status icon overlays directly on the hex polygon (not just a label); make frozen enemies have a blue tint
5. **Loot variety** — LootScreen pool has 8 items but could use more interesting trade-offs; "upgrade an ability" loot that permanently boosts one ability's damage/charges
6. **Ability upgrade screen polish** — the `LevelUp` screen shows generic upgrade names; wire each upgrade to the hero's actual class abilities
7. **HUD XP bar** — show XP progress toward next level; currently invisible until level-up fires

## File Map
```
autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run-persistent hero state (+ last_battle_kills, last_battle_xp)
  SystemVoice.gd     — The System commentary pools + signal

src/combat/
  Combatant.gd       — pure fighter data class (+ attack_bonus field)
  BattleEngine.gd    — pure turn engine (+ collision avoidance, apply_lava_damage, lava_damaged signal, battle_end guard)
  Ability.gd         — charges/cooldown data object (wired into BattleScene Run 3)
  StatusEffect.gd    — status dict factories: burning/frozen/vanished/fortified/poisoned

src/map/
  HexGrid.gd         — static hex math utilities
  DungeonMap.gd      — procedural floor generator

src/data/
  Classes.gd         — class definitions (Brawler/Rogue/Arcanist)
  Abilities.gd       — all ability definitions
  EnemyDefs.gd       — enemy definitions + Combatant factory (+ floor_num scaling)

scenes/
  Main.tscn/.gd      — root, scene orchestration; Run 3: routes through VictoryScreen
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle visual driver (Run 3: ability charges, lava, class icons, victory flow)
  VictoryScreen.tscn/.gd — NEW Run 3: post-floor "FLOOR N CLEARED" screen
  LevelUp.tscn/.gd   — upgrade screen; 3 of 6 upgrades per level
  LootScreen.tscn/.gd   — post-battle choose-one loot

tests/
  run_tests.gd       — headless test runner (SceneTree)
  test_rng.gd        — RNG reproducibility/bounds tests
  test_hex.gd        — HexGrid geometry tests
  test_combat.gd     — Combatant + BattleEngine tests
  test_movement.gd   — movement, ability effects, AI variants, attack_bonus (Run 2)
  test_run3.gd       — NEW Run 3: ability charges, floor scaling, collision, lava damage (25 tests)
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
