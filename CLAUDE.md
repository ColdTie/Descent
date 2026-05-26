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
- Array literal `[a] + array_b` creates an **untyped** Array — always build typed arrays with `append`/`append_array`
- `Array.filter()` / `Array + Array` always return untyped — iterate to append into a typed `Array[T]`
- `GameState.hero_abilities` is `Array[String]` — must iterate to append from Dictionary-sourced arrays, same for `_all_combatants: Array[Combatant]`

## Current State (Run 3 — Ability Charges, Enemy Scaling, Lava Hazard, Victory)
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
- **Ability effects fully implemented:**
  - `fireball` — AOE damage (radius 2) centered on clicked hex; orange flash visual
  - `frost_nova` — freezes all adjacent enemies for 2 turns (frozen enemies skip AI action)
  - `taunt` — applies `fortified` status (+5 armor, 3 turns) to hero
  - `vanish` — applies `vanished` status; next attack deals 3× damage (consumed on use)
- **Self-target UX** — pressing an already-selected self-target ability button uses it immediately
- **Cave atmosphere** — `CanvasModulate` blue-purple tint; dark stalagmite polygons in outer rings (6–7); lava tiles pulse orange↔dim with staggered tweens
- **Status icon labels** on entity nodes (🔥❄☠🛡👁)
- **Death overlay** — "YOU DIED" with System quip, floor/kill/level stats, animated fade, "TRY AGAIN" button → back to class select
- **Level-up screen** (`LevelUp.tscn/.gd`) — 6-upgrade pool shuffled to 3 choices; atk/spd/hp/def/xp/heal variants; DCC quip on each
- **Enemy AI variety:** Golem (ranged wait), Goblin (flank), Imp (rush), Default (random)
- **`attack_bonus` on Combatant** — hero stat bonuses correctly apply to damage
- **69 headless tests**

**Run 3 (Charges/Cooldown, Scaling, Lava, Victory, Portraits):**
- **Ability charges/cooldown HUD** — Each hero ability is now backed by an `Ability` object tracking `current_charges`, `cooldown_remaining`. HUD buttons show `∞` (unlimited), `●●` (charged dots), `○●` (partial), or `⏳N` (cooldown) and gray out when depleted. `can_use()` is checked before executing; abilities that miss cooldown window show a banner.
- **Ability cooldown ticking** — `_tick_hero_ability_cooldowns()` runs at the start of each hero turn; charges refill when cooldown hits 0.
- **Enemy collision avoidance** — `BattleEngine._move_toward()` now skips hexes occupied by other living combatants; enemies cannot stack.
- **Floor-based enemy scaling** — `EnemyDefs.make_combatant(…, floor_num)` now adds HP (+10/floor above min_floor), armor (+1 per 2 floors), attack_bonus (+2/floor), and XP reward (+5/floor) — later floors are meaningfully harder.
- **Lava hazard** — At the start of each hero turn, adjacent lava tiles deal 2 HP damage per tile; System banner quip shown. Hero start and its 6 neighbors are now lava-free so floor 1 start isn't immediately punishing.
- **Victory overlay** — When battle_ended fires with hero_won=true, a "FLOOR N CLEARED!" overlay appears with System quip, kill count, XP, HP remaining, and animated CONTINUE button before transitioning to loot/level-up.
- **Hero class portraits** — Replaced letter initial with distinct polygon shapes: Brawler=gold shield (pentagon), Rogue=green dagger (elongated diamond), Arcanist=bright cyan 4-pointed star.
- **Typed array bug fix** — Fixed `GameState.hero_abilities` and `BattleScene._all_combatants` assignments that were failing with "Trying to assign an array of type Array to Array[T]".
- **95 headless tests** — all passing: RNG (5), Hex (13), Combat (27), Movement+Abilities (24), Run3 (26)

### Next Priorities (Run 4)
1. **Rogue class — Backstab ignores armor** — `Abilities.DATA["backstab"]` has `"ignore_armor": true` but `BattleEngine._calculate_damage()` doesn't check it; wire it in
2. **Enemy-type based health bars** — Show enemy HP numbers on hover; current thin bar is hard to read at a glance
3. **Sounds** — minimal audio pass (synthesized using AudioStreamGenerator): hit, kill, move, ability sounds; no audio assets needed
4. **Multi-floor progression visuals** — floor depth should visually change (more lava density, darker modulate, different stalagmite density on deeper floors)
5. **Ranged attack visual** — show a projectile Line2D for golem fireball and enemy ranged attacks, not just instant damage
6. **Turn queue preview** — Show upcoming turn order as small icons in a strip so players can plan around it
7. **Loot: ability unlock items** — Add "unlock new ability" loot type (e.g., Poison Dart, Shield Slam) so the player's kit grows across floors

## File Map
```
autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run-persistent hero state
  SystemVoice.gd     — The System commentary pools + signal

src/combat/
  Combatant.gd       — pure fighter data class (+ attack_bonus field)
  BattleEngine.gd    — pure turn engine (+ move_combatant, perform_aoe_attack, enemy AI variants)
  Ability.gd         — charges/cooldown data object (not yet wired into BattleScene HUD)
  StatusEffect.gd    — status dict factories: burning/frozen/vanished/fortified/poisoned

src/map/
  HexGrid.gd         — static hex math utilities
  DungeonMap.gd      — procedural floor generator

src/data/
  Classes.gd         — class definitions (Brawler/Rogue/Arcanist)
  Abilities.gd       — all ability definitions
  EnemyDefs.gd       — enemy definitions + Combatant factory

scenes/
  Main.tscn/.gd      — root, scene orchestration; handles death→class select
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle visual driver (Run 2: movement, highlights, AOE, atmosphere, death overlay)
  LevelUp.tscn/.gd   — upgrade screen (new in Run 2); 3 of 6 upgrades per level
  LootScreen.tscn/.gd   — post-battle choose-one loot

tests/
  run_tests.gd       — headless test runner (SceneTree)
  test_rng.gd        — RNG reproducibility/bounds tests
  test_hex.gd        — HexGrid geometry tests
  test_combat.gd     — Combatant + BattleEngine tests
  test_movement.gd   — movement, ability effects, AI variants, attack_bonus (Run 2)
  test_run3.gd       — Run3: Ability charges/cooldown, collision avoidance, floor scaling (Run 3)
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
