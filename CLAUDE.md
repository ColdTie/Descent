# DESCENT — Developer Guide

## ⚠️ WORKFLOW RULE — ALWAYS PUSH AFTER COMMITTING
After every `git commit`, immediately run `git push -u origin main`.
Never end a task with uncommitted or unpushed changes. Verify with `git status` and
`git log --oneline -3` that the remote is up to date before reporting the task complete.

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

## Current State (Run 8 — Better Sprites + Combat Polish)
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

**Run 5 (Sprites + Boss + 18 Floors + Vanish Fix):**
- **PNG sprites** — all 9 characters (hero_brawler, hero_rogue, hero_arcanist + 5 enemy types + enemy_boss) generated via `tools/gen_sprites.py`; PNG works headlessly without editor import
- **Boss system** — `EnemyDefs.BOSSES[]` + `get_boss_for_floor()` + `make_boss()`; 3 tier bosses: Dungeon Lord (1-6), The Warden (7-12), Abyss Keeper (13-18); spawns at `DungeonMap.boss_spawn` (southern hex ring)
- **18 floors** — `GameState.TOTAL_FLOORS = 18`; win condition in `Main._on_loot_chosen()` routes to WinScreen when floor_num >= TOTAL_FLOORS
- **WinScreen** — "YOU WIN" screen with reluctant-System quips, run stats, "Play Again" button
- **Floor progress label** — "Floor X / 18" in HUD
- **Boss HP bar** — top-center purple HP bar showing boss health during battle
- **Vanish fixed (3 bugs):**
  1. `StatusEffect.vanished()` duration: 1 → 3 (hero can actually attack while invisible)
  2. `BattleEngine.enemy_ai_action()` now checks for vanished hero — enemies idle if all heroes vanished
  3. `BattleScene._sync_hero_alpha()` — restores hero alpha to 1.0 when vanish expires
- **HP regen between floors** — `GameState.regen_between_floors()` heals 10% max HP between floors
- **deploy.yml** — added `godot --headless --import` step before export so PNG assets are imported

**Run 6 (Visual Overhaul — Portraits + Hit Flash + UI Polish):**
- **`tools/gen_sprites_v2.py`** — Complete sprite redesign: improved proportions (heads ~25% of height), stronger outlines, more saturated colors, 5× supersampling (480→96 LANCZOS)
- **`assets/portraits/`** — New 200×190 portrait images for ClassSelect: `brawler.png`, `rogue.png`, `arcanist.png`. Bust-shot close-ups with background gradient and glow effects.
- **ClassSelect redesign** — Portrait images used instead of stretched battle sprites; class-colored card borders + divider strip; stats row; styled SELECT button with class color; background column tints per class; pulse animation on card selection.
- **Hit flash** — `BattleScene._hit_flash()`: white brightness flare (modulate→2.5) for 50ms then back to 1.0 on every hit, giving combat visual punch.
- **deploy.yml** — Updated to run `gen_sprites_v2.py` (replaces `gen_sprites_pillow.py`)

**Run 4 (Sprites + Visual Upgrade):**
- **SVG sprites** for all 3 hero classes and 5 enemy types in `assets/sprites/`
  - Heroes: `hero_brawler.svg`, `hero_rogue.svg`, `hero_arcanist.svg`
  - Enemies: `enemy_imp.svg`, `enemy_goblin.svg`, `enemy_skeleton.svg`, `enemy_demon.svg`, `enemy_golem.svg`
- **`BattleScene._get_sprite_path(c)`** — maps combatant to sprite path; hero uses `GameState.hero_class`, enemy uses `c.sprite_key`
- **`Sprite2D` in entity nodes** — replaces old body-polygon + glyph-label pair; scale 0.58 @ position y=-6
- **`TextureRect` portraits** in `ClassSelect` class cards — replaces flat color swatch
- **Fallback**: both systems degrade gracefully to glyph/swatch when assets haven't been imported by the editor yet
- **Import note**: Open project in Godot editor once after pulling — editor auto-imports all SVGs into `.godot/imported/`

**Run 7 (Pixel Art Sprites — DCSS CC0):**
- **`tools/gen_sprites_v3.py`** — Downloads 32×32 sprites from Dungeon Crawl: Stone Soup (CC0 license) via raw GitHub and scales to 96×96 with NEAREST interpolation for crispy pixel art
- **Battle sprite mapping:**
  - `hero_brawler` ← `death_knight.png` | `hero_rogue` ← `occultist.png` | `hero_arcanist` ← `arcanist.png`
  - `enemy_imp` ← `crimson_imp.png` | `enemy_goblin` ← `goblin.png` | `enemy_skeleton` ← `skeletal_warrior.png`
  - `enemy_demon` ← `orange_demon.png` | `enemy_golem` ← `blazeheart_golem.png`
  - `enemy_boss_dungeon_lord` ← `dispater.png` | `enemy_boss_warden` ← `vault_warden.png` | `enemy_boss_abyss_keeper` ← `ereshkigal.png`
- **Portraits** — same DCSS sprites scaled 5× (160×160) on class-specific gradient backgrounds with accent strip
- **`BattleScene.gd`** — `TEXTURE_FILTER_NEAREST` (was LINEAR) for pixel-perfect rendering; sprite scale 1.00/1.28 (was 0.95/1.22)
- **`deploy.yml`** — runs `gen_sprites_v3.py` instead of `gen_sprites_v2.py`
- **Attribution**: Sprites © Dungeon Crawl: Stone Soup contributors, CC0 1.0 Universal

**Run 8 (Visual Overhaul — Better Pixel Art Sprites + Combat Polish):**
- **`tools/gen_sprites_v4.py`** — Improved DCSS sprite pipeline:
  - 4× NEAREST scale (32→128px, was 96px) — crisper pixel art at 33% larger display
  - 2px dark pixel-art outline on all battle sprites for hex-grid contrast
  - Better sprite selections: `hell_knight` (brawler), `sonja` (rogue), `executioner` (demon), `gloorx_vloq` (Abyss Keeper)
  - Taller portraits (200×220 vs 200×190) with stronger radial glow
- **`BattleScene.gd` combat polish:**
  - `_start_idle_bob()` — each entity sprite gently breathes/bobs (hero: 1.8s period; enemies: 1.2s)
  - Dark disc backdrop behind sprites (semi-transparent) for readability against any hex colour
  - Enemy name tag displayed above HP bar
  - Larger HP bar (46px wide, was 40px) with updated `_update_hp_bar`
  - `_hit_flash()` — squish-and-recover scale pulse (`1.10×0.88`) in addition to white flare
  - Sprite scale 0.95/1.20 (was 0.85/1.10)
- **`ClassSelect.gd`** — Cards enlarged (240×420, was 230×390); portrait area 248px tall; NEAREST filter for pixel-art sprites
- **`deploy.yml`** — runs `gen_sprites_v4.py` instead of `gen_sprites_hq.py`

**Run 9 (Custom SVG Sprite Pipeline):**
- **`tools/gen_sprites_v5.py`** — Renders the bespoke SVG character art (stored in `assets/sprites/*.svg`) to 192×192 anti-aliased PNGs using `cairosvg`. Replaces the DCSS pixel-art download pipeline entirely for all 11 characters.
  - Heroes and all 5 enemy types + 3 boss tiers each have a hand-crafted SVG with anatomy, weapons, armour, facial expressions
  - 192px output (was 128px) gives more detail at same display size
  - DCSS fallback retained only for `enemy_boss` generic key (no custom SVG needed — bosses always use named tier sprites)
  - Portraits now rendered from hero SVGs at 170px on 200×220 gradient bg with stronger glow
- **`BattleScene.gd`** — `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` (was `NEAREST` — NEAREST was for pixel art; SVG art needs anti-aliasing); sprite scale 0.68/0.85 (was 0.95/1.20 — adjusted for 192px source)
- **`ClassSelect.gd`** — portrait filter changed to `LINEAR_WITH_MIPMAPS` to match
- **`deploy.yml`** — installs `libcairo2` + `cairosvg`, runs `gen_sprites_v5.py`

### Next Priorities (Run 5) (was Run 4)
1. **Sounds** — Even a minimal audio pass: hit, kill, move, ability sounds (use Godot's AudioStreamGenerator or import simple beeps)
2. **Class abilities tab on upgrade screen** — the Level-up screen currently only shows stat upgrades; add a "NEW ABILITY" option so hero can unlock fireball/backstab/etc. mid-run
3. **Pushback mechanic** — the Brawler class should have a "Shield Bash" that pushes enemies toward lava; makes lava truly tactical
4. **Multi-floor run feel** — currently each floor starts fresh; heroes should FEEL stronger on floor 5 vs floor 1 — the scaling helps enemies but hero stat upgrades should visibly compound
5. **The System mid-battle commentary** — trigger quips on: hero surviving below 20% HP, first kill of run, using backstab successfully, hero standing adjacent to lava, enemies surrounding hero
6. **HP regeneration between floors** — currently hero HP is frozen between floors unless they take healing loot; add small passive regen (5-10 HP) between floors as a quality-of-life change
7. **Minimap / floor preview** — small indicator showing which floor you're on out of N (generate run length at run start)

## File Map
```
assets/
  sprites/     — 192×192 PNG battle sprites (rendered from custom SVGs via tools/gen_sprites_v5.py)
                 SVG source files also live here (*.svg) — edit SVGs to update art
  portraits/   — 200×220 PNG class portraits for ClassSelect (generated by gen_sprites_v5.py from hero SVGs)

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
