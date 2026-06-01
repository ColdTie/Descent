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
3. **Autoloads**: `GameRng`, `GameState`, `SystemVoice`, `AudioManager` — always available
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

## Current State (Run 18 — Floor-3 Allies)
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

**Run 12 (Shield Bash + Ability Unlocks + Floor Themes + Contextual Commentary):**
- **Shield Bash ability** (`Abilities.gd`) — new Brawler ability: 18 damage, pushes enemy 2 hexes, 2 charges, 2-turn cooldown. If pushed into lava, takes 28 bonus env damage (armor-bypassed).
- **Two more unlockable abilities** (`Abilities.gd`): `poison_blade` (Rogue/cross-class: 10 dmg + 6 dpt poison for 4 turns, 2 charges, range 1, ignore-armor tick), `arcane_surge` (Arcanist/cross-class: 50 dmg ignore armor, 1 charge, range 2).
- **Push mechanic** (`BattleEngine.gd`): `push_combatant(pusher, pushed, distance, map)` + `_push_direction()` helper — returns traversed hex path for lava-contact detection.
- **Push animation** (`BattleScene.gd`): `_animate_push()` coroutine slides entity node hex-by-hex via tweens; `_do_hero_attack` awaits it then deals lava contact damage if final hex is lava.
- **Ability unlocks on LevelUp** (`LevelUp.gd`): `CLASS_UNLOCKS` dict (brawler→shield_bash; rogue→power_strike,frost_nova; arcanist→backstab,taunt). `_generate_choices()` checks hero class + existing abilities and injects a gold ✦ "Learn: X" card (~60% chance) in place of one stat card. `_apply_upgrade()` handles `type=="ability"` to add ability to `GameState.hero_abilities`.
- **Floor tile themes** (`BattleScene.gd`): `_setup_floor_theme()` called in `_ready()` sets `FLOOR_COLOR`, `FLOOR_ALT`, `STONE_EDGE`, `LAVA_COLOR`, `LAVA_GLOW`, `LAVA_BORDER`, `ATMO_COLOR` based on floor tier: Stone (1-6) / Obsidian blue-black (7-12) / Void purple (13-18). Lava pulse tween and `CanvasModulate` both update to match.
- **Contextual commentary** — 3 new triggers:
  - Enemy hits hero → `took_hit_comment` (~40% chance)
  - 3+ enemies adjacent to hero at end of enemy turn → `surrounded` (~50% chance)
  - Shield bash → `shield_bash` quip pool; pushed into lava → `pushed_into_lava` quip pool
- **New SystemVoice categories**: `shield_bash` (7 lines), `pushed_into_lava` (6 lines), `surrounded` (8 lines), `took_hit_comment` (6 lines).

**Run 13 (DCSS Pixel Art Sprites + Ability VFX System):**
- **DCSS CC0 pixel art sprites** — replaced all custom SVG art with authentic dungeon-crawler pixel art sourced from Dungeon Crawl: Stone Soup (CC0 1.0). All 12 battle sprites + 3 class portraits regenerated at 192×192 via `tools/gen_sprites_v6.py` (4× NEAREST upscale from 32×32 originals). Sprite attributon: DCSS contributors, CC0 Universal.
- **Ability VFX system** (`BattleScene.gd`): `_load_effect_textures()` pre-loads 64×64 pixel-art effect sprites for every ability; `_play_ability_effect(hex, ability_id)` spawns a brief pop-scale-fade animation at any hex. Effects fire on: all hero ability uses (attack, aoe, self-target), all enemy attacks via `action_taken` signal, and lava heat.
- **`tools/gen_effects.py`** — generates 10 ability VFX PNGs in `assets/effects/`:
  - `fx_fireball`: orange-red radial flame with sparks
  - `fx_frost`: six-arm snowflake crystal with branching
  - `fx_impact`: white-orange 8-ray starburst (basic attacks, shield bash)
  - `fx_backstab`: dark-red diagonal slash X
  - `fx_power_strike`: golden 6-ray starburst
  - `fx_heal`: green cross with sparkles
  - `fx_poison`: green bubbles with shine highlights
  - `fx_vanish`: purple smoke wisps
  - `fx_taunt`: red shield with exclamation
  - `fx_lava_heat`: orange upward flame columns
- **NEAREST texture filter** — `BattleScene.gd` sprite and effect `texture_filter` updated to `TEXTURE_FILTER_NEAREST` for crispy pixel-perfect rendering; `ClassSelect.gd` portrait filter also updated.
- **deploy.yml** — removes `cairosvg`/`libcairo2` dependency; now runs `gen_sprites_v6.py` + `gen_effects.py` (Pillow only).

**Run 11b (SVG Sprite Pipeline + Glow Aura Visual Overhaul):**
- **Sprite pipeline switched back to custom SVG art** (`gen_sprites_v5.py`): sprites are 5–9× richer (14–33 KB each vs 2–4 KB DCSS). All 15 characters rendered at 192×192 via cairosvg.
- **`BattleScene.gd` display improvements:**
  - `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` (replaces NEAREST — SVG art needs anti-aliasing)
  - Sprite scale 0.78 / 0.95 (was 0.72 / 0.90)
  - **Colored glow polygon** behind each entity: class color for hero, blood-red for enemies, void-purple for bosses
  - **Boss glow pulses** with breathing sine-wave tween (0.28–0.68 alpha, ~2.5 s cycle)
  - Draw order: ground shadow → glow ring → dark disc → sprite
- **`ClassSelect.gd`** — portrait filter updated to `LINEAR_WITH_MIPMAPS`
- **`deploy.yml`** — `pip install Pillow cairosvg`, runs `gen_sprites_v5.py`

**Run 11a (DCSS Pixel Art + Full UI Panel Overhaul):**
- **UI visual overhaul** — all interstitial screens redesigned with stone-dungeon `PanelContainer` style (dark bg, gold border, drop shadows):
  - `VictoryScreen`: floor progress bar, "CLEARED!" with drop shadow, stat cards with borders
  - `LevelUp`: upgrade cards with category icon + type-colored border, brightens on hover/selection
  - `LootScreen`: item cards with type-based color coding (heal/stat/utility)
  - `WinScreen`: gold-bordered panel, "YOU WIN" drop shadow title, styled stat cards
- Sprites: DCSS CC0 pixel art (superseded in Run 11b by custom SVG art)

**Run 10 (Gradient SVG Sprite Overhaul):**
- **Full visual redesign** of all 11 characters (3 heroes + 5 enemies + 3 bosses):
  - All SVGs rewritten with `linearGradient`/`radialGradient` fills for 3D depth and lighting
  - Complex `<path>` elements replace basic rects/ellipses for organic silhouettes
  - Layered shading: highlight layer + mid-tone fill + shadow layer per body part
  - Hero sprites: Brawler (guard stance, scar, gradient skin), Rogue (cowl, daggers, glowing eyes), Arcanist (hat, rune emblem, staff orb, magic aura)
  - Enemy sprites: Imp (leathery bat wings, slit pupils, spade tail), Goblin (riveted helmet, tusk, shield), Skeleton (exposed ribs, glowing green sockets), Demon (lava-vein wings, fire crown, white-blazing eyes), Golem (lava fissures, glowing mouth)
  - Boss sprites: Dungeon Lord (crown-helm with gemstones, twin swords, crimson eye glow), Warden (tower shield with star emblem, spiked mace + chain, knuckle spikes), Abyss Keeper (5 distinct multi-colour eyes, tentacles with suckers, void-tear mouth)
- All 11 SVGs regenerated to 192×192 RGBA PNGs via cairosvg pipeline (unchanged)
- Class portraits also regenerated from updated hero SVGs

**Run 9 (Custom SVG Sprite Pipeline):**
- **`tools/gen_sprites_v5.py`** — Renders the bespoke SVG character art (stored in `assets/sprites/*.svg`) to 192×192 anti-aliased PNGs using `cairosvg`. Replaces the DCSS pixel-art download pipeline entirely for all 11 characters.
  - Heroes and all 5 enemy types + 3 boss tiers each have a hand-crafted SVG with anatomy, weapons, armour, facial expressions
  - 192px output (was 128px) gives more detail at same display size
  - DCSS fallback retained only for `enemy_boss` generic key (no custom SVG needed — bosses always use named tier sprites)
  - Portraits now rendered from hero SVGs at 170px on 200×220 gradient bg with stronger glow
- **`BattleScene.gd`** — `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` (was `NEAREST` — NEAREST was for pixel art; SVG art needs anti-aliasing); sprite scale 0.68/0.85 (was 0.95/1.20 — adjusted for 192px source)
- **`ClassSelect.gd`** — portrait filter changed to `LINEAR_WITH_MIPMAPS` to match
- **`deploy.yml`** — installs `libcairo2` + `cairosvg`, runs `gen_sprites_v5.py`

**Run 18 (Floor-3 Allies — Marcus + Lina):**
- **Two AI-controlled allies join Carl on Floor 3** (the first boss floor, vs. the Dungeon Lord). Survivors he encounters before the first boss fight; they fight one battle and don't persist past it.
  - **Marcus the Steadfast** — knight: 70 HP, 3 armor, speed 11, attack +4. Tankier melee.
  - **Lina Hexweaver** — hooded mage: 55 HP, 0 armor, speed 13, attack +6. Glassy hitter.
- **`src/data/Allies.gd`** — pure data class with `ALLIES_BY_FLOOR` dict, `get_allies_for_floor(floor_num)`, `has_allies_on_floor(floor_num)`, and `make_ally(def, position, rng)` factory returning a HERO-faction `Combatant`.
- **`tools/gen_allies.py`** — generates 192×192 PNGs `assets/sprites/ally_marcus.png` (knight with kite shield + sword + blue cloak + gold cross emblem) and `assets/sprites/ally_lina.png` (hooded mage with glowing arcane staff + hex amulet). Pillow only; matches existing sprite pipeline.
- **`BattleScene.gd`** changes:
  - `_build_encounter()` spawns ally Combatants via `Allies.make_ally()`. `_find_ally_spawn_hexes(count)` picks passable, unoccupied hexes in ring 1 around `_map.hero_start` (falls back to ring 2).
  - `_get_sprite_path()` routes `sprite_key.begins_with("ally_")` to the ally PNG.
  - `_spawn_entity_node()` gives allies a custom glow color from `Allies.ALLIES_BY_FLOOR` (gold for Marcus, teal for Lina) and a short first-name tag above their HP bar.
  - `_next_turn()` adds a new branch: if `active == _hero` → player turn (Carl); else if `active.faction == HERO` → ally AI turn calling `_resolve_ally_turn(ally)`.
  - `_resolve_ally_turn(ally)` — moves toward the nearest living enemy via `_engine.move_toward()` and basic-attacks if adjacent.
  - `_on_combatant_died()` now special-cases on `c == _hero` (not just HERO faction) so an ally falling does NOT end the run. Ally-fell branch greys out the entity, plays a System banner + Donut quip pool.
  - `_build_ally_panel()` builds one HP label per ally stacked under the hero HP label (top-left), updated in `_update_all_hp_bars()` and from `_on_action_taken()` when an ally is the target.
  - `_on_hero_moved()` now uses the moved combatant's id (was hardcoded `_hero.id`) so any HERO-faction move animates.
- **SystemVoice additions** — `allies_arrive` (6 lines) and `ally_fell` (5 lines) pools. Triggered: arrival on floor entry (1.2s delay), fall on ally death.
- **Donut `DONUT_LINES`** — adds `allies_arrive` (6 cat-princess quips about Carl having "friends") and `ally_fell` (5 mournful lines).
- **9 new headless tests** in `tests/test_run17_allies.gd`: floor 3 spawns two allies; floors 1/2/4/6/9/18 spawn zero; Marcus and Lina stats; sprite-key uniqueness; engine invariant that ally death alone doesn't trigger battle end.

**Run 17 (Donut Hologram + Button Click Fix):**
- **Ability button fix** — Vignette `ColorRect` nodes in `_draw_cave_background()` were missing `mouse_filter = MOUSE_FILTER_IGNORE`. The bottom vignette (y=640–720) covered most of the HUD panel (y=628–720), eating all mouse input. Result: basic attack, power strike, and taunt were only clickable in the top ~12px. Fix: `cr.mouse_filter = Control.MOUSE_FILTER_IGNORE` on all four vignette rects.
- **Donut hologram advisor** — Donut is no longer a combat `Combatant` on the hex grid. She appears as a holographic projection in the bottom-left corner (x=8, y=476, 162×148px) with a teal scanline overlay and border-flicker tween. Speech bubbles fade in/out above the hologram panel. She speaks up at: floor entry, enemy kills (~42% chance), boss encounter, hero takes damage (~28% chance), hero near death (~45% chance), ability uses (~22% chance), victory, and hero death. All hologram elements have `mouse_filter=IGNORE` to avoid blocking hex grid clicks. `DONUT_LINES` constant in `BattleScene.gd` holds 8 categories of snarky cat-princess lines.
- **Removed from BattleScene:** `_donut: Combatant`, `_donut_hp_label`, `_resolve_donut_turn()`, `_get_nearest_enemy_to()`, `_build_donut_hp_label()`, `_update_donut_hp_label()`. Donut's turn was also removed from `_next_turn()`.

**Run 16 (Audio + Critical Hits + Boss Floors + Title Screen + Score):**
- **Procedural audio system** — first sound in the game. `tools/gen_audio.py` synthesizes 16 short 16-bit WAV SFX using ONLY the Python stdlib (`wave`/`struct`/`math` — no Pillow/no deps): hit, crit, kill, hurt, move, select, ability, fire, frost, heal, enrage, levelup, victory, defeat, descend, lava. New autoload `AudioManager` (`autoloads/AudioManager.gd`) preloads them, plays through an 8-voice `AudioStreamPlayer` pool with optional pitch variation, and is **defensive** (missing file = silent no-op). Wired into combat (hit/crit/kill/hurt/lava/enrage/ability casts), movement, victory/defeat, and all UI screens (select/levelup/heal/descend). SFX on/off toggle on the title screen. `project.godot` autoload + `deploy.yml` run `gen_audio.py`.
- **Critical hits** — hero-favouring combat depth. `BattleEngine` rolls `hero_crit_chance` (default 0.15) on hero/Donut damaging attacks; crits deal `CRIT_MULT` (2×) and set `last_attack_was_crit`. Enemies never crit (keeps it player-positive). `BattleScene._on_action_taken` reads the flag → gold enlarged "-N CRIT!" number, crit SFX, and a `critical_hit` System quip pool (7 lines).
- **Bosses on milestone floors only** — `EnemyDefs.is_boss_floor(n)` returns true every 3rd floor (3/6/9/12/15/18 = 6 boss fights). Previously EVERY floor spawned a "boss", which diluted the concept. `BattleScene._build_encounter` only spawns the boss on boss floors; regular floors are pure enemy waves. Makes boss floors a real difficulty spike.
- **Title / main menu screen** — `scenes/TitleScreen.tscn/.gd`. Branded "DESCENT" title with drop shadow + fade-in, tagline, how-to-play text, a System intro quip (`title` pool, 8 lines), BEGIN DESCENT → ClassSelect, and an SFX toggle. `Main` now boots here first (`_go_to_title`), wires the `start_game` signal.
- **Run score + stats** — `GameState.total_kills`, `bosses_slain` (reset in `start_run`, accumulated in `Main._on_battle_complete`), and `run_score()` = floor×1000 + kills×25 + bosses×250 + level×100. Shown on WinScreen (SCORE/LEVEL/KILLS cards) and the death overlay summary line.
- **Loot cleanup** — replaced the dead `recharge_all` item (did nothing across floors since abilities reset each battle) with **Warlord's Brand** (`multi` type: +6 Attack & +15 Max HP). New `multi` loot type handler + color.
- **24 new headless tests** — `tests/test_run16.gd` (crits ×5, boss floors ×3, score formula ×2 — autoload-free per the test-mode rule).

**Run 15 (Boss Phase 2 + Enemy Ability Unlocks + Shadow Step):**
- **Boss Phase 2 (enrage)** — Each boss enters an enraged state when HP drops below 30%: speed +4, attack_bonus +4. `Combatant.is_boss` and `Combatant.is_enraged` flags added. `BattleEngine._check_boss_enrage()` fires after every hit; emits `boss_enraged` signal. `BattleScene._on_boss_enraged()` switches the boss glow ring from void-purple to crimson-orange (kills old tween, starts new rage pulse), changes HP bar to enrage color, shows banner with System quip. `SystemVoice` has new `boss_enraged` pool (8 lines).
- **Skeleton Bone Volley (floor 10+)** — Skeletons on floors 10+ automatically gain `bone_volley` (ranged, 20 dmg, range 3, 2-charge). `EnemyDefs.make_combatant` conditionally appends the ability by enemy ID + floor. Skeleton AI in `BattleEngine.enemy_ai_action` now matches on `sprite_key == "skeleton"` and uses Bone Volley from range instead of closing to melee.
- **Demon Hellfire AoE (floor 13+)** — Demons on floors 13+ gain `hellfire_aoe` (AoE 22 dmg, range 2 against all heroes). Demon AI matches on `sprite_key == "demon"` and fires hellfire when any hero is in range; falls back to melee/ranged otherwise.
- **Rogue Shadow Step** — New hero ability: teleport to adjacent hex of target within range 3, then strike for 30 damage (ignores armor). 2 charges, 4-turn cooldown. `teleport_to_target: true` flag in Abilities data. `BattleScene._find_teleport_hex_near()` finds best landing hex; `_do_hero_attack` awaits teleport tween before attacking. New `fx_shadow_step.png` VFX (deep violet ring + rays + bright core) added via `gen_effects.py`. Replaces `power_strike` in Rogue's `CLASS_UNLOCKS` (Rogue now unlocks `shadow_step` and `frost_nova`).
- **SystemVoice additions** — `shadow_step` quip pool (6 lines), `boss_enraged` (8 lines), `enemy_bone_volley` (3 lines), `enemy_hellfire` (3 lines).
- **16 new headless tests** in `tests/test_run15.gd` — boss enrage (6), enemy ability unlocks (5), shadow step / ability data (5).

**Run 14 (Donut + Layout + Fixes):**
- **Donut companion** — Princess cat from DCC joins every run. She's a HERO-faction `Combatant` (50 HP, speed 12, attack_bonus 3) who auto-acts on her turn: moves toward and attacks the nearest enemy. She has her own HP label in the top-left UI. Dying doesn't end the run (only player hero death does). Visual: orange tabby sprite generated by `tools/gen_donut.py` — tiara, large round dark sunglasses, red collar with gold bell. Gold glow ring.
- **Inferno map** — Bottom-right funnel panel inspired by Dante's Inferno. 18 horizontal slices taper from wide (floor 1) to narrow (floor 18). Cleared floors: dim ember. Current floor: bright gold with `▶ N` label. Future floors: dark/deep.
- **HUD layout fix** — HUD Panel top raised from y=668 to y=628, giving buttons their full 64px height. Buttons were previously clipped and unreachable.
- **Ability display names** — ClassSelect now shows "Basic Attack", "Power Strike" etc. instead of raw IDs.
- **Lava reduced 50%** — DungeonMap now places 5–8% lava (was 10–15%). Inner radius-2 zone around hero start is always lava-free; prevents start-of-floor heat damage.
- **Death grey-out fixed** — Enemy sprites now grey out correctly after the hit-flash tween finishes (0.22s delay). Previously the flash tween was overwriting the dead modulate.
- **`Ability.can_use()` fixed** — Logic was `charges > 0 OR cooldown == 0`; corrected to `charges > 0` (unlimited = always true). Prevents edge-case where depleted abilities appeared available.
- **Sprite scale −30%** — All battle sprites: boss 0.67 (was 0.95), regular 0.55 (was 0.78).
- **Enemy AI targeting** — Enemies now target the nearest visible hero (player or Donut), not just `visible_heroes[0]`.
- **`BattleEngine.move_toward()`** — Public wrapper around `_move_toward()` for companion AI use.
- **SystemVoice** — New line when Donut is knocked out.

## Genre Gap Analysis & Direction (audited Run 16, updated Run 18)
Compared against tactical roguelike / DCC-style peers (Slay the Spire, Into the Breach,
FTL, traditional roguelikes). Status of the "what are we missing" audit:

### ✅ Done / no longer a gap
- Audio (SFX) — Run 16
- Critical hits — Run 16
- Bosses as milestone spikes (not every floor) — Run 16
- Title/main menu screen — Run 16
- Run score + end-of-run summary — Run 16
- Companion (Donut) — Run 14
- Boss phase 2 / enrage — Run 15
- Floor-scaled enemy abilities — Run 15
- Class-specific unlockable abilities (mostly) — Runs 12/15
- Floor-scripted ally NPCs (Marcus + Lina on floor 3) — Run 18

### 🔜 Highest-value, easiest remaining (do next, roughly in order)
1. **Background music / ambient loop** — SFX exist now; a low droning ambient loop per
   tier would massively lift atmosphere. Can be procedurally generated (longer WAV, looped
   AudioStreamPlayer with `loop`). Medium effort; AudioManager already exists to host it.
2. **Gold economy + between-floor shop** — `GameState.hero_gold` exists but is never earned
   or spent. Award gold per kill, add a simple Shop screen between floors (buy heals, stat
   boosts, ability recharges, reroll loot). Big DCC flavour ("the dungeon's storefront").
3. **Pause / settings menu (in-battle)** — No way to pause, restart, quit, or change volume
   mid-run. Add an ESC overlay: Resume / Restart Run / Quit to Title + SFX volume slider.
4. **Arcanist class-specific unlock** — Arcanist still inherits Backstab/Taunt cross-class.
   Give it an exclusive (e.g. Mana Shield: absorb next 40 dmg; or Chain Lightning).
5. **Combat log panel** — Only transient System banners exist. A small scrolling log of the
   last ~6 events helps readability. Pure-UI, low risk.
6. **Loot rarity tiers** — Common/Rare/Legendary with color + a Legendary screen flash and
   special quip. Extends the existing LootScreen with minimal new code.

### 🟡 Larger / later (note, not yet scoped)
7. **More floor variety** — Per-tier hazards: Tier 1 crumbling bridges, Tier 2 freeze pools,
   Tier 3 void rifts that warp enemies. Needs DungeonMap + BattleScene tile-type support.
8. **More enemy types for Tier 2/3** — Void Wraith (phases through walls), Bone Colossus
   (huge HP, slow), Lich (resurrects skeletons).
9. **Boss signature moves** — Dungeon Lord rallies a dead enemy; Warden ground-slam knockback;
   Abyss Keeper void-pull. Per-boss scripted ability in enemy AI.
10. **Meta-progression / unlocks** — Persistent currency between runs, unlockable classes or
    starting perks. Requires save persistence (web: `user://` works in Godot web export).
11. **Save / resume a run** — Serialize GameState to `user://` so a run survives a refresh.
12. **Status-effect depth** — Bleed, stun, vulnerability; show stacks/durations on a tooltip.
13. **Accessibility/options** — Screen shake toggle, colorblind-friendly hex highlights,
    text size. Cheap goodwill once a settings menu exists (#3).

### Long-term vision
DESCENT should feel like a **tight, replayable tactical roguelike** wearing a Dungeon Crawler
Carl skin: every floor is a bite-sized hex puzzle, the System narrates your hubris, bosses are
set-piece spikes, and loot/level-up choices build a run. The next phase is **economy + audio
atmosphere + run meta** (shop, music, persistence) to turn a good combat prototype into a
loop players return to.

## File Map
```
assets/
  sprites/     — 192×192 PNG battle sprites (rendered from custom SVGs via tools/gen_sprites_v5.py)
                 SVG source files also live here (*.svg) — edit SVGs to update art
  portraits/   — 200×220 PNG class portraits for ClassSelect (generated by gen_sprites_v5.py from hero SVGs)

assets/
  audio/       — 16 procedurally-generated WAV SFX (from tools/gen_audio.py, stdlib only)
  effects/     — 64×64 ability VFX PNGs (from tools/gen_effects.py)

autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run-persistent hero state (+run_score, total_kills, bosses_slain)
  SystemVoice.gd     — The System commentary pools + signal
  AudioManager.gd    — SFX player: preloads WAV pool, play(name, pitch_var, vol_db), SFX toggle

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
  Allies.gd          — floor-scripted ally NPCs + Combatant factory (Run 18)

scenes/
  Main.tscn/.gd      — root, scene orchestration; boots to TitleScreen, routes through VictoryScreen
  TitleScreen.tscn/.gd  — main menu: branding, how-to-play, SFX toggle, BEGIN DESCENT
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
  test_run15.gd      — boss enrage, enemy ability unlocks, shadow step (Run 15)
  test_run16.gd      — critical hits, boss-floor milestones, score formula (Run 16)
  test_run17_allies.gd — floor-3 ally spawn, factory, engine integration (Run 18)
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
