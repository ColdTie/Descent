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

## Godot 4.4.1 API Gotchas (learned in Runs 1–2)
- `RandomNumberGenerator` has NO `.shuffle()` method — use Fisher-Yates manually or `Array.shuffle()` (global seed, not deterministic)
- `Array[T].filter(callable)` returns an untyped `Array`, not `Array[T]`
- `Classes.get_class()` conflicts with `Object.get_class()` — renamed to `get_class_data()`
- GDScript lambdas capture local variables **by value** — to read lambda-set state, use an `Array` as a reference container (e.g. `var fired: Array[bool] = [false]`)
- Typed `Array[String]` can't be assigned from an untyped `Array` directly — must iterate and append
- Autoloads are NOT type-checked in `--script` mode; keep tests free of autoload references
- `Combatant.to_dict()` does NOT include a `stats` key — use the new `attack_bonus` field directly
- Signal handlers with `await` become coroutines and return to caller at the first `await` — don't assume they block
- `Button.disabled = true` suppresses the `pressed` signal entirely — good for greyed-out abilities
- `match` arm variables are scoped to their arm — safe to reuse `var pts` across arms

## Current State (Run 3 — Charges, Lava, Victory, Scaling, Icons)
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
- **Ability effects fully implemented** (fireball AOE, frost_nova freeze, taunt fortified, vanish 3× damage)
- **Cave atmosphere** — `CanvasModulate` blue-purple tint; stalagmite polygons; lava tiles pulse
- **Status icon labels** on entity nodes (🔥❄☠🛡👁)
- **Death overlay** — "YOU DIED" with quip, stats, TRY AGAIN → class select
- **Level-up screen** — 3-of-6 upgrade choices per level
- **Enemy AI variety** — Golem/Goblin/Imp/Default behaviours
- **69 headless tests**

**Run 3 (Charges + Lava + Victory + Scaling + Icons):**
- **Ability charges/cooldown HUD** — `Ability` instances wired into BattleScene for every hero ability:
  - Buttons show `[N/Max]` charges, `CD:N` when on cooldown, `[∞]` for infinite abilities
  - Depleted buttons are disabled (grey); re-enable when cooldown expires
  - Cooldowns tick at the START of the hero's turn (so feedback is immediate)
  - All action handlers (`_do_hero_attack`, `_do_hero_aoe_ability`, `_do_hero_self_ability`) call `ability.use()` and refresh the bar
- **Enemy collision avoidance** — `BattleEngine._move_toward()` now builds an occupied-positions list and skips occupied hexes; enemies never stack
- **Lava adjacency damage** — at the start of the hero's turn, 4 fire damage is dealt per adjacent lava tile; displayed as orange floating number; if fatal, shows death overlay
- **Victory screen overlay** — "FLOOR N CLEARED" title, System quip, XP/kill/level stats, HP bar, "DESCEND ▼" button (hero HP synced to GameState before emitting)
- **Floor scaling** — enemies: +25% HP per floor, +2 attack per floor, +5 XP per floor
- **Hero class icons** — polygon silhouettes replace letter initials: Brawler=shield pentagon, Rogue=dagger blade, Arcanist=6-pointed star
- **Hero HP synced to GameState** on victory (fixing a Run 1–2 bug where HP reset each floor)
- **107 headless tests** — all passing: RNG (5), HexGrid (13), Combat (27), Movement+Abilities (24), Ability Charges+Scaling (38)

### Next Priorities (Run 4)
1. **Sounds** — minimal audio pass: hit, kill, move, ability SFX (synthesized or imported .wav)
2. **More enemy types / elite variants** — floor 5+ should have elite enemies with modifiers (armored, berserker, cursed)
3. **Boss floors** — every 5 floors, spawn a named boss with a unique AI pattern and special drops
4. **XP display in HUD** — show XP progress bar toward next level during battle
5. **Loot rarity tiers** — common/rare/epic items with distinct visual styles; epic items should have real build synergies
6. **Floor-exit mechanic** — a visible exit tile that hero must reach after clearing all enemies (rather than auto-transition)

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
  test_abilities.gd  — Ability charge/cooldown tracking, floor scaling, collision avoidance (Run 3)
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
