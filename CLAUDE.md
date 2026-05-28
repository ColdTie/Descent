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
- `[a] + typed_array` produces an untyped `Array` — cannot assign to `Array[T]`. Use `.clear()` + `.append()` loop instead.
- `Dictionary.get("key", [])` returns an untyped `Array` even when the stored value is typed — iterate and append when assigning to `Array[String]`.

## Current State (Run 4 — Shield Bash, New Abilities, Commentary, LevelUp Unlocks)
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
- Ability charges/cooldown wired into HUD; backstab ignores armor; enemy collision avoidance; lava heat damage; VictoryScreen; floor scaling; class/enemy glyphs; 109 tests

**Run 4 (Shield Bash + New Abilities + Commentary + LevelUp Unlocks):**
- **Shield Bash** (`shield_bash`) — Brawler melee that pushes target 2 hexes. If trajectory hits lava, 22 fire damage bonus. `HexGrid.get_push_direction()` + `BattleEngine.perform_push_attack()` + `combatant_pushed` signal
- **War Cry** (`war_cry`) — Brawler self-buff: heal 25 HP + apply `rallied` status (+8 attack for 3 turns). `StatusEffect.rallied()` + `attack_mod` field in `_calculate_damage`
- **Poison Blade** (`poison_blade`) — Rogue: melee + applies `poisoned` (3 dmg/turn × 5 turns)
- **Chain Lightning** (`chain_lightning`) — Arcanist: arcs through up to 3 enemies within range 2 of each previous target
- **Ability unlocks in LevelUp** — Class-specific abilities appear as cyan "LEARN: X" cards in the upgrade pool. Available: Brawler→shield_bash/war_cry, Rogue→poison_blade, Arcanist→chain_lightning
- **Mid-battle System commentary** — 8 new categories: `low_hp` (<20% HP, fires once), `first_kill`, `backstab_hit`, `surrounded` (≥3 adjacent), `shield_bash_lava`, `war_cry`, `chain_lightning`
- **HP regen between floors** — `GameState.heal(8)` in `Main._on_floor_cleared()` before XP/loot screen
- **Rallied ⚡ icon** in status label display
- **Typed Array fixes** — `[a] + enemies` → `.clear()` + `.append_all()`; `GameState.hero_abilities` typed-array init fix
- **138 headless tests** — all passing: RNG (5), Hex (13), Combat (27), Movement+Abilities (24), Run3 (40), Run4 (29)

### Next Priorities (Run 5)
1. **Sounds** — Even a minimal audio pass: hit, kill, move sounds (Godot AudioStreamPlayer with generated beeps or imported WAV)
2. **Minimap / floor counter** — HUD indicator showing floor N of M; generate run length at run start (e.g. 8 floors)
3. **Hex-grid visual polish** — the "Dungeons of Hell" reference look: darker cavern atmosphere, more dramatic lava glow, stalagmite silhouettes in the outer ring (already placed but could be heavier)
4. **Enemy intent display** — show what enemy will do on their turn (attack/move arrows), so player can plan
5. **Floor-progression narrative** — The System gets darker/more terse as you go deeper; floor 7 quips feel different from floor 1 quips
6. **Boss encounter** — Floor 5 or 8 ends with a mini-boss (e.g. "The Warden" — high HP, special abilities like "Summon" or "Shockwave")
7. **Loot polish** — show item icons/art; add consumable items (potions, scrolls) alongside passive upgrades

## File Map
```
autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run-persistent hero state (+typed Array[String] init fix)
  SystemVoice.gd     — The System commentary pools + signal (+8 new categories in Run 4)

src/combat/
  Combatant.gd       — pure fighter data class
  BattleEngine.gd    — pure turn engine (+perform_push_attack, +combatant_pushed signal, +attack_mod in damage calc)
  Ability.gd         — charges/cooldown data object
  StatusEffect.gd    — status dict factories (+rallied with attack_mod field)

src/map/
  HexGrid.gd         — static hex math utilities (+get_push_direction)
  DungeonMap.gd      — procedural floor generator

src/data/
  Classes.gd         — class definitions (Brawler/Rogue/Arcanist)
  Abilities.gd       — all ability definitions (+shield_bash/war_cry/poison_blade/chain_lightning)
  EnemyDefs.gd       — enemy definitions + Combatant factory

scenes/
  Main.tscn/.gd      — root, scene orchestration (+HP regen on floor cleared)
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle visual driver (Run 4: push/chain/commentary)
  VictoryScreen.tscn/.gd — post-battle floor clear screen
  LevelUp.tscn/.gd   — upgrade screen (Run 4: +ability unlock cards in cyan)
  LootScreen.tscn/.gd   — post-battle choose-one loot

tests/
  run_tests.gd       — headless test runner (SceneTree)
  test_rng.gd        — RNG reproducibility/bounds tests
  test_hex.gd        — HexGrid geometry tests
  test_combat.gd     — Combatant + BattleEngine tests
  test_movement.gd   — movement, ability effects, AI variants, attack_bonus
  test_run3.gd       — ability charges, backstab armor, collision, floor scaling, env damage
  test_run4.gd       — push direction, push_attack, lava bounce, rallied, new ability data
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
