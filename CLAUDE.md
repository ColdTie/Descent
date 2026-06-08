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

## Current State (Run 28 — Save / Resume a Run)
### Implemented ✅
**Run 28 (Save / Resume a Run):**
- **`autoloads/GameState.gd`** — pure snapshot/apply helpers + JSON file I/O for resuming a run:
  - `snapshot() -> Dictionary` serializes every run-relevant field (floor, class, HP/XP/level, gold, abilities, inventory, base stats, audience score, lava-push counter, sponsor offers, patch notes seen, shop visits, battle speed, run seed). Arrays are deep-copied so a downstream mutation can't poison the live state.
  - `apply_snapshot(data) -> bool` mirror that restores all fields with defensive `int()`/`float()`/`String()` coercion (JSON round-trips numbers as floats — assigning a 1.0 straight into a `: int` field would silently truncate). Rejects empty dicts and blank `hero_class` as "not a real save". Resets `audience_score_floor` to 0 so the floor-bonus tally doesn't double-count points from before the save.
  - `write_save_to_disk(extra) -> bool` / `read_save_from_disk() -> Dictionary` / `has_save_on_disk()` / `clear_save_on_disk()` — file I/O around `user://descent_save.json` (web export's IndexedDB-backed path). `read_save_from_disk` is the single defensive gate: missing file, unparseable JSON, mismatched `SAVE_VERSION`, or missing `hero_class` all return `{}` so a corrupt file can't surface CONTINUE.
  - `SAVE_VERSION` const for future format breaks. Bumping it auto-invalidates pre-existing saves.
  - **`start_run()` duck-types the `GameRng` autoload** (matching the Achievements.gd pattern) so the file compiles under `--script` test mode and the snapshot helpers can be tested headlessly.
- **`scenes/Main.gd`** — checkpoint cadence + resume routing:
  - `_persist_run()` snapshots GameState + folds in `Achievements.unlocked_ids` (since Achievements is a separate autoload) and writes once per floor. Called from `_on_floor_changed()` — every floor entry is the stable checkpoint (combat hasn't started, HP regen has applied, all between-floor picks are committed).
  - `_resume_from_save()` reads disk → `apply_snapshot()` → reseeds `GameRng` with the saved `run_seed` → rehydrates `Achievements.unlocked_ids` → loads BattleScene directly. Falls back to ClassSelect on any error (defense in depth — failing to resume shouldn't strand the player).
  - `_on_hero_died()` calls `clear_save_on_disk()` so the title screen doesn't dangle CONTINUE on a dead run.
  - `_on_loot_chosen()` clears the save when `floor_num >= TOTAL_FLOORS` (win condition).
  - New `_on_new_run_requested()` clears any stale save when the player clicks NEW RUN, so backing out to title mid-run-before-first-checkpoint can't leave a phantom CONTINUE.
- **`scenes/TitleScreen.gd`** — new `continue_run` signal + button:
  - On `_build_ui`, calls `GameState.read_save_from_disk()` once. If non-empty, prepends a green `CONTINUE  ·  <Class>  ·  Floor N` button that emits `continue_run`. The "BEGIN DESCENT" button relabels to "NEW RUN" so the action distinction reads at a glance.
  - No save → original "BEGIN DESCENT" only. Layout pixel-identical to pre-Run-28 for fresh players.
- **`tests/test_run28.gd`** (18 test functions, ~50 assertions): snapshot field coverage (version + every scalar + every array), arrays-are-independent-copies invariant, full snapshot↔apply roundtrip, `audience_score_floor` reset behavior, JSON.stringify→parse_string round-trip via `apply_snapshot`, defensive cases for empty dict / missing hero_class / blank class string, minimal-snapshot tolerance, end-to-end disk I/O roundtrip including the extra-fields plumbing for achievement state, "no file present" returns `{}`, and the `SAVE_VERSION` mismatch gate.
- **Test suite total: 952 passed, 0 failed** (up from 886 in Run 27).

**Run 27 (Loadout HUD + Ability Icons + Turn Speed + Donut Fix):**
- **Faster turns (≈ 45% baseline + per-run multiplier)** — the pre-Run-27 enemy turn rhythm was 0.55s (pre-action wait) + animation + 0.25s (post-action wait) ≈ 1.05s per enemy; with 4–5 enemies that's a 4–5s round. New baselines: 0.28 / 0.18 / 0.12 — total ≈ 0.58s/enemy at default speed (a 45% reduction). Hero move tweens trimmed too (0.18 → wrapped, push tween 0.12 → 0.10, ally move 0.25 → 0.18). All scaled through a new `_dur(secs)` helper that divides by `GameState.battle_speed`, so a 2× pick gets the player down to ~0.29s/enemy (a ~72% cut from the original).
- **Pause-menu Battle Speed selector** (`scenes/BattleScene.gd`) — new row in the pause menu with three buttons: `1x` / `1.5x` / `2x`. Selected pip pops with the warm gold stylebox idiom used elsewhere. Calls `GameState.set_battle_speed(value)` which `clamp()`s to [0.5, 3.0] defensively. Persists across floors within the run; reset on `start_run()`. No SceneTree.paused weirdness — the multiplier just affects `_dur()` reads going forward.
- **`autoloads/GameState.gd`** — two new fields:
  - `battle_speed: float = 1.0` + `set_battle_speed(mult)` setter with clamp.
  - `hero_inventory: Array[String]` + `record_purchase(item_id)` helper + `inventory_changed` signal. Defensive: empty-string id is silently rejected so the HUD doesn't render a phantom "- " row.
  - Both reset in `start_run()` so a fresh class pick starts with an empty bag at 1× speed.
- **Loadout panel HUD** (`scenes/BattleScene.gd::_build_stats_panel`) — new left-edge `PanelContainer` at (8, 308), 176×156. Header "CARL — LOADOUT", a 3-line ATK/DEF/SPD readout (reads `GameState.hero_base_stats`), a divider, and a vertical list of owned shop items rendered from `GameState.hero_inventory`. Duplicates collapse to `Name  x N` so a 10-floor potion spree doesn't blow out the box. Hooks `GameState.inventory_changed` for live updates; `_refresh_stats_panel()` also runs on every floor entry via `_build_stats_panel`. The "(none yet)" placeholder uses a muted grey so the empty-bag case reads as deliberate.
- **`scenes/Shop.gd`** — on a successful BUY (`_on_buy_pressed`), now also calls `GameState.record_purchase(id)` so the HUD picks up the new item on the next floor. Tiny one-liner; no extra scene state.
- **Ability buttons get art** (`scenes/BattleScene.gd::_build_ability_bar`) — each ability button now displays its existing `assets/effects/fx_*.png` as a top-aligned icon (28px max width, NEAREST filter via Godot's default for theme icons). Mapping table is `_effect_textures` (Run 13 — already populated for every hero ability). Properties used: `Button.icon`, `expand_icon`, `vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP`, `icon_alignment = HORIZONTAL_ALIGNMENT_CENTER`, theme constant `icon_max_width = 28`. Text label (display name + charge dots) still renders beneath the icon via `alignment = HORIZONTAL_ALIGNMENT_CENTER`. No change to the existing Run 22 stylebox logic — selected/cooldown/depleted styling still drives the border + bg colors.
- **Donut hologram sprite no longer escapes the panel** (`scenes/BattleScene.gd::_build_donut_hologram`) — root cause: `TextureRect` was missing `expand_mode = EXPAND_IGNORE_SIZE`, so it rendered at the source PNG's native 192×192 instead of the 76×76 hint. Fix: set `expand_mode = TextureRect.EXPAND_IGNORE_SIZE`, bump the rect to 100×100 inside the 162×148 panel, recenter horizontally (`PX + PW * 0.5 - 50.0`). Stretch mode still `STRETCH_KEEP_ASPECT_CENTERED` so the cat scales down with no distortion. The sprite now sits cleanly inside the hologram frame.
- **Tests** — Run 27 additions are GameState autoload helpers; the existing test runner is `--script`-mode-only (autoloads aren't resolvable in that mode), so the helpers are covered by runtime smoke instead of headless tests. The 886 prior tests still pass.

**Run 26 (Shop Lock Slots):**
- **`src/data/Shop.gd` `slate(rng, floor_num, locked = [])`** — third arg lets the caller carry items forward through a reroll. Locked items are placed at the START of the returned array and excluded from fresh random draws (no duplicates, no slot inflation). Default empty-array keeps all existing 2-arg callers byte-identical (Run 25's tests still pass without modification). Defensive guards: a `{}` or duplicate-id entry in `locked` is silently dropped; overflow beyond `SLATE_SIZE` truncates rather than crashing. The while-loop also breaks rather than infinite-looping if INVENTORY is exhausted partway through (defensive — current INVENTORY size is well above SLATE_SIZE so this only matters if items get removed).
- **`scenes/Shop.gd` per-card LOCK toggle** — each card now has a `BUY` + `LOCK` button row at the bottom. `_locked_slots: Dictionary` maps slot index → bool. Clicking LOCK pins that slot through any subsequent REROLL; clicking UNLOCK clears it. Locking is FREE (its cost is opportunity — you can't replace what you've pinned). Lock auto-clears on purchase (no point locking what you already own). Visual cues on a locked card: amber `[LOCKED]` badge appears next to the rarity label, the panel border switches to the warm `LOCK_GLOW_COLOR` (`#ffdb2e`), and the lock button label flips to `UNLOCK` in the same amber.
- **`_reroll_slate()` locked-aware** — collects locked items + their original slot positions, calls `Shop.slate(rng, floor, locked_items)` to draw fresh items excluding the locked ids, then reorders so locked positions keep their original cards and unlocked positions fill from the fresh draw in order. `_purchased` still clears on every reroll; locked items can't have been purchased (lock auto-clears on buy), so the clear is safe.
- **`scenes/Shop.gd` card-lookup refactor** — replaced the fragile "last child of vbox is the buy button" walk with explicit node names (`BuyButton`, `LockButton`, `LockBadge`). Added `_card_panel(slot_idx)` and `_card_node(slot_idx, name)` helpers. `_refresh_card_state(slot_idx)` now does a single lookup per card and handles purchased / locked / too-poor states in one place. `_refresh_all_cards()` is now a 3-line iterator.
- **`autoloads/SystemVoice.gd`** — new `shop_lock` quip pool (6 lines, fired only on the LOCK direction of the toggle so the audio chatter doesn't fire twice per click).
- **`tests/test_run26.gd`** (9 test functions, ~80 assertions): default-arg backwards-compat against Run 25 fixtures (same seed + no locked == same slate), single-locked / multi-locked placement contract (locked items at index 0/1...), 50-seed no-duplication invariant when one item is locked, in-slate uniqueness with multiple locks, all-locked degenerate case (slate == locked input), overflow truncation, locked-id dedupe, and empty-dict / malformed entry safety. Wired into `run_tests.gd`.
- **Test suite total: 886 passed, 0 failed** (up from 818 in Run 25).

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

**Run 25 (Shop Rarity Tiers + Reroll + Mana Shield HUD Bar):**
- **`src/data/Shop.gd`** — Run 24's loot-rarity pattern ported to the merchant. Every INVENTORY item now carries an explicit `rarity` field (`common`/`rare`/`legendary`). Added three new Legendaries (`shop_phoenix_ampoule` 300g, `shop_god_blade` 280g, `shop_warden_scale` 260g) and one Rare (`shop_seers_charm` 115g) — Legendary costs sit well above the Common average so they actually feel like a splurge. New `RARITY_WEIGHTS_BY_TIER` table (80/18/2 → 55/35/10 → 30/45/25, mirroring Loot's curve) drives `_pick_rarity_for_slot()` and `_draw_item_of_rarity()`. The static `slate(rng, floor_num)` now rolls each slot's rarity weighted by floor tier, then draws a non-duplicate item of that rarity (falls through to other buckets if a tier is exhausted). Old `slate(rng)` callers still work via the `floor_num: int = 1` default.
- **Reroll helper** (`src/data/Shop.gd`) — `REROLL_BASE_COST = 25`, `REROLL_STEP_COST = 20`, `reroll_cost(n)` = `25 + 20·n`. Linear ramp so spam-rerolling drains gold fast but the first reroll is cheap enough to feel inviting. Defensive clamp at `n < 0`.
- **`scenes/Shop.gd` rarity rendering** — every card now shows a top rarity label (COMMON/RARE/LEGENDARY in the rarity color), a rarity-colored border (4px for Legendary, 2px otherwise), and a tinted shadow (10px shadow + 8↔16 pulse loop for Legendary). Card height bumped 220→240 so the rarity label has room. Any Legendary on the slate triggers a soft orange screen flash on entry (and again on Legendary purchase) — same idiom as LootScreen. Buy presses on a Legendary play the `victory` SFX at -4dB instead of the regular `select` ping, plus a special `speak_direct` quip ("Legendary purchase. The merchant's smile is, regrettably, sincere.").
- **Reroll button** (`scenes/Shop.gd`) — new button sits in the bottom row next to LEAVE & DESCEND, labeled `REROLL ($N)` where N is the current cost. Spends gold via `GameState.spend_gold`, increments `_reroll_count`, plays the `ability` SFX, fires a `shop_reroll` quip, then rebuilds the slate with a reroll-aware seed (`run_seed ^ floor·7919 ^ visits·1543 ^ rerolls·6151`) so consecutive rerolls don't loop the same items. Goes disabled + grey-text when the hero can't afford the next reroll. `_purchased` clears on each reroll so previously-greyed cards don't carry over to the fresh slate.
- **Initial slate seeding fixed** (`scenes/Shop.gd`) — old code used `GameRng.shuffle()` which mutates the global autoload rng and produced an unweighted shuffle. Replaced with a per-visit seeded `RandomNumberGenerator` keyed on `run_seed ^ floor·7919 ^ visits·1543`, so the same run+visit always shows the same slate (deterministic + reproducible) and the per-tier weighting is honored.
- **Mana Shield HUD bar** (`scenes/BattleScene.gd`) — new thin blue bar sits 3px above every combatant's HP bar (`ShieldBorder` + `ShieldBg` + `ShieldBar` ColorRects on the entity root, all created hidden). `_update_mana_shield_indicator(c)` scans the combatant's `status_effects` for `mana_shield`, computes `absorb_remaining / absorb_max`, and toggles the three rects + scales the fill width accordingly. Hooks: called from `_update_all_hp_bars()` (every batch refresh), from `_on_action_taken()` after `_update_hp_bar(target)` (so the bar drains immediately when damage is absorbed), and from the `"mana_shield"` branch of `_do_hero_self_ability()` (so the bar shows up the instant the buff lands instead of waiting for the next damage tick). Pure read of the StatusEffect dict — no extra state, expiry handled automatically when `_consume_mana_shield()` drops the effect.
- **`autoloads/SystemVoice.gd`** — new `shop_reroll` quip pool (6 lines, fired on every reroll click).
- **`tests/test_run25.gd`** (21 test functions): rarity schema (every item has rarity, values are in the allowed set, at least one of each rarity), Legendary cost > Common avg invariant, weight-table shape (3 tiers, Legendary climbs + Common shrinks with depth, all tiers have positive total weight), slate generation (SLATE_SIZE returned, items unique within a slate, deterministic across reseeds), statistical floor-1-skews-common + floor-18-skews-rare-plus checks (60 trials each), reroll cost ramp (positive base/step, monotonically increasing, `reroll_cost(0)` == base, negative input clamps to base), and floor tier boundary lock-in (1/6 → 0, 7/12 → 1, 13/18 → 2). Wired into `run_tests.gd`.

**Run 24 (Ambient Music + Pause Menu + Combat Log + Loot Rarity Tiers):**
- **`tools/gen_music.py`** — new procedural ambient-music generator (stdlib only — `wave`, `struct`, `math`, `random`). Synthesizes four looping 16-bit WAVs into `assets/audio/`: `music_title` (~28s dark cinematic minor-chord pad + bell hits), `music_stone` (~30s warm low drone + slow tribal pulse + sparse harp pluck for floors 1-6), `music_obsidian` (~30s cold F# diminished pad + glassy chimes for floors 7-12), `music_void` (~30s dissonant pad + deep doom bells for floors 13-18). Each track ends with a `loop_crossfade` so the WAV loops seamlessly in `AudioStreamWAV.LOOP_FORWARD` mode.
- **`autoloads/AudioManager.gd` overhaul** — adds music subsystem alongside SFX:
  - `MUSIC_NAMES` registry preloaded same as SFX; music tracks get `loop_mode = LOOP_FORWARD` forced at load time so the WAVs loop without gaps.
  - Two dedicated `AudioStreamPlayer` instances (`_music_a`, `_music_b`) act as a crossfade pair — `play_music(name, fade_s)` ramps the new track up while the old one fades out via `volume_db` tweens.
  - `stop_music(fade_s)`, `set_music_enabled(on)`, `toggle_music_enabled()`, `set_music_volume_db(db)`, `set_sfx_volume_db(db)`. Music-enabled toggle is sticky across tracks.
  - `music_for_floor(floor_num)` maps floor → tier track (1-6 stone / 7-12 obsidian / 13-18 void). Used by BattleScene `_ready`.
  - Calling `play_music()` with the same track already playing is a no-op, so within-tier floor transitions don't restart the loop.
- **`scenes/BattleScene.gd`** — `_ready()` calls `AudioManager.play_music(AudioManager.music_for_floor(GameState.floor_num), 1.6)` so the tier track crossfades in on every floor. Floors within the same tier keep the same track playing uninterrupted; tier transitions (6→7, 12→13) get a real crossfade.
- **`scenes/TitleScreen.gd`** — `_ready()` starts `music_title`. New `MUSIC: ON/OFF` button alongside the existing `SFX: ON/OFF` toggle.
- **`scenes/ClassSelect.gd`** — `_ready()` re-plays `music_title` so the title track resumes after a death/quit returns to class select.
- **Pause menu (BattleScene)** — `_unhandled_input()` handles `KEY_ESCAPE` and toggles a `CanvasLayer` overlay built by `_build_pause_menu()`. The overlay shows: PAUSED title + System-flavor subtitle, **SFX VOLUME** slider (-40..0 dB, wired to `AudioManager.set_sfx_volume_db`), **MUSIC VOLUME** slider (wired to `set_music_volume_db`), SFX/MUSIC on-off toggles, **RESUME**, and **QUIT TO TITLE**. ESC is suppressed when the run has ended (`_hero_dead` or `_engine.battle_over`) so the death overlay and victory transition own the screen. QUIT TO TITLE emits `GameState.hero_died` so Main's existing routing returns to ClassSelect. Layer 50 sits above HUD + achievement toasts.
- **Combat log (BattleScene)** — `_build_combat_log()` sits below the gold widget at (1080, 140), 188×174px. Shows the last `COMBAT_LOG_MAX = 6` events (older entries trimmed). Lines come from existing combat hooks: `_on_action_taken` (hits + CRIT lines), `_on_combatant_died` (enemy slain / Carl down / ally fallen), `_on_status_ticked` (status damage), `_on_battle_ended` (floor cleared). Each new line flashes brighter for 0.45s so the eye catches the update. `_short_name(c)` trims multi-word combatant names ("Marcus the Steadfast" → "Marcus"). Hero hits are tinted soft green, enemy hits soft red, crits gold, status damage orange, kills bright gold. `mouse_filter = IGNORE` so the panel never eats clicks.
- **Loot rarity tiers (`scenes/LootScreen.gd`)** — Run 11's flat 8-item pool expanded with rarity metadata + 4 new items:
  - `RARITY_COMMON`, `RARITY_RARE`, `RARITY_LEGENDARY` constants with paired `RARITY_COLORS` (grey / blue / orange) and `RARITY_LABELS`.
  - Every `LOOT_POOL` entry now carries a `rarity` key; new items: `phoenix_feather` (Legendary, full heal), `obsidian_edge` (Rare, +18 Atk), `stoneforged` (Legendary, +8/+4/+30), `duelist_band` (Rare, +4 Atk +4 Spd).
  - `RARITY_WEIGHTS_BY_TIER[3]` — tier 0 (floors 1-6) is 80/18/2 common/rare/legendary; tier 1 (7-12) is 55/35/10; tier 2 (13-18) is 30/45/25. Deeper floors see more Rare/Legendary cards.
  - `_generate_choices()` rerolls per slot: pick weighted rarity → draw a non-duplicate item of that rarity (falls back to lower tiers if the chosen pool is exhausted).
  - Card rendering: rarity name label at top, rarity-color border (4px for Legendary, 2px otherwise), rarity-tinted shadow. Legendary cards pulse their `shadow_size` 8 ↔ 16 on a 1.1s sine loop.
  - Any Legendary card on the slate triggers `_flash_legendary_aura()` (soft orange screen flash) on screen entry AND on pick, plus a special `SystemVoice.speak_direct` quip.
  - `_apply_loot` `multi` branch now handles `defense` and `speed` keys (was attack + max_hp only).
- **`.github/workflows/deploy.yml`** — adds `python3 tools/gen_music.py` to the asset-generation step.
- **`tests/test_run24.gd`** (12 test functions) — LOOT_POOL schema (id/name/type/desc/rarity present, ids unique, types in apply-handler allowed-list, rarity values in known set, each rarity bucket has ≥1 item), rarity weight invariants (3 tier tables, Legendary grows + Common shrinks with depth, totals positive), audio constants lock-in (MUSIC_NAMES contains all 4 tracks, AUDIO_DIR is `res://`, VOICE_COUNT positive). Wired into `run_tests.gd`. Test suite now exercises pure data only — autoload runtime state isn't touched per `--script` mode rule.

**Run 23 (Move-vs-Ability UX — Persistent Move Rings + Dynamic Hint + Right-Click Cancel):**
- **Root issue:** With an ability armed, the player could still click an empty adjacent hex to move, but the green move tiles visually merged into (or were dominated by) the ability's fill overlays — and nothing on screen explained that move was still available. The single static "YOUR TURN — Click to move or attack" text didn't disambiguate.
- **`scenes/BattleScene.gd` `_highlight_move_ring(hex)`** — new helper. Move markers are now drawn as a thin **green outlined Line2D ring** (3px, rounded joints, `z_index = 1`) instead of a filled `Polygon2D`. The ring sits ABOVE ability-zone fills, so even on a Fireball turn the player still sees exactly where they can step. A subtle sine-wave alpha pulse (0.55 ↔ 0.95) draws the eye without being noisy. The ring uses a distinct node name (`"MoveRing"`) so it doesn't collide with the existing `"Highlight"` dedupe; `_clear_highlights()` now wipes both per hex.
- **`_update_turn_hint()`** — new dynamic turn-indicator text that adapts to the armed ability:
  - Single-enemy abilities: `YOUR TURN  •  GREEN = move  •  click ENEMY for [name]  •  right-click cancels`
  - Range-1 AOE (Frost Nova): `… AOE hits all adjacent foes …`
  - Ranged AOE (Fireball, Hellfire): `… click ORANGE tile to drop [name] …`
  - Self buffs (Taunt, Vanish, Mana Shield): `… click YOURSELF for [name] …`
  Called from turn-start AND from `_on_ability_btn` so the hint stays current as the player cycles through abilities. The `TurnIndicator` Label was 264px in the .tscn; widened at runtime to 1056px to fit the new text on one line.
- **Right-click to cancel** — `_on_hex_input` now treats `MOUSE_BUTTON_RIGHT` as "revert to Basic Attack". Frees the player from being stuck in an armed-ability state if they picked the wrong one; just right-click the grid to go back to default mode. Plays the `select` SFX at a slightly lower pitch as audible feedback.

**Run 22 (HUD + Font Polish — ASCII Icons, Bar/Widget Layout Fixes):**
- **HP numeric overlay reverted** — the `HPText` / `HPTextShadow` Labels added in the original Run 22 (centered "23 / 40" on each unit's HP bar) were visually offset and added clutter. Per player feedback, removed. Bars are now plain 50×11 green→red fills with the variance gradient.
- **Audience + Gold widget collision fixed** — the `HeroHPLabel` declared in `BattleScene.tscn` sits at `(1070, 16)` and shows "HP: NN / NN" for Carl. The new audience widget had been placed at `(1080, 12)`, exactly on top — so Carl's HP text was being covered. Moved both widgets DOWN: audience now at `(1080, 58)`, gold at `(1080, 98)`. The right-edge HUD column reads top-down: Hero HP → Audience → Gold.
- **ASCII-only icon migration** — Godot's bundled default font has no glyphs for the emoji and extended-Unicode chars the UI was using (`⚔ 🛡 ❤ ⚡ ✚ ★ ✦ ◆ ◉ ♛ 💥 ▼ ▶ ⟳ 📡` and friends); they all rendered as missing-glyph fallback boxes. Replaced every icon literal across `scenes/*.gd` and `src/data/*.gd` with a safe-ASCII equivalent so they render correctly without bundling a custom font. The mapping is consistent across all UI:
  ```
  ⚔ sword         → ATK
  🛡 shield       → DEF
  ❤ heart         → HP
  ⚡ bolt          → SPD
  ✚ cross         → +
  ★ ✦ ◆ ♛ stars  → *
  ◉ coin         → $
  💥 boom         → AoE
  ▼ ▶ ◀ ⟳ arrows → removed
  ⬡ hexagon      → o
  ↻ recycle      → "CD "
  ∞ infinity     → "(unl)"
  ```
- **In-battle status badges** changed from emoji glyphs to bracketed letter codes: `[BRN]` (burning), `[FRZ]` (frozen), `[PSN]` (poisoned), `[DEF]` (fortified), `[HID]` (vanished), `[SHD]` (mana shield).
- **Ability bar charge dots** changed from `●○` to `*.` so they render without a special font.
- **Sponsor progress widget** — `_audience_widget_text()` shows `AUDIENCE  N / T` where T is the threshold for the next sponsor offer, computed as `SPONSOR_THRESHOLD × (sponsor_offers_taken + 1)`. Previously just a bare run-total.
- **Ability button styleboxes** — replaced the subtle `modulate = SELECTED_CLR` tint approach with real `StyleBoxFlat` overrides. Selected ability now has a **bright gold border + warm amber fill + glow shadow**; on-cooldown / depleted shows a dim grey border + muted font; normal sits as bronze border on dark fill. Applied to `normal`, `hover`, `pressed`, `disabled`, `focus` slots so the styling doesn't flicker on mouseover.

**Run 21 (Gold Economy + Between-Floor Shop + Arcanist Mana Shield):**
- **`src/data/Shop.gd`** — new pure-data shop inventory + economy math. 11 items spanning healing (Field Medic Kit, Suspicious Healing Draught, Titan's Tonic), stat boosts (Mystery Whetstone, Reinforced Plating, Quickdraw Stims), multi-effects (Berserker's Brew, Surplus Tower Shield, Branded Warpaint), audience favor (Publicity Packet), and an HP/heal combo (Black-Market Transfusion). Cost range 40–180. Static `slate(rng)` returns SLATE_SIZE=4 distinct items via deterministic Fisher-Yates. `gold_for_kill/_boss/_clear(floor_num)` scale with floor depth (kill: 12–46, boss: 55–140, clear: 23–74). `should_show_shop(floor, gold)` gates the route. Zero autoload deps — testable in `--script` mode.
- **`scenes/Shop.tscn/.gd`** — new merchant interlude scene. Unlike LootScreen / SponsorOffer (pick-one), the Shop is multi-purchase: each card shows cost + effects; BUY deducts gold, marks the card PURCHASED, and re-runs affordability checks on the remaining cards (unaffordable ones flip to "TOO POOR"). Big gold balance in the header updates live via `GameState.gold_spent` signal. "LEAVE & DESCEND" continues. Matches existing PanelContainer + StyleBoxFlat visual language (warm gold/amber palette, distinct from sponsor screen).
- **`autoloads/GameState.gd`** — gold economy state. `award_gold(amount, reason)` and `spend_gold(amount, item_id)` with matching `gold_gained` / `gold_spent` signals. `shop_visits: int` resets in `start_run()`. `run_score()` now includes `hero_gold × 1` so hoarding is a real (but secondary) strategy vs. spending. `hero_gold` already existed but was never written to before this run.
- **`scenes/Main.gd`** routing — after loot pick (and after PatchNotes when tier-transitioning), `_route_to_shop_or_descend()` checks `Shop.should_show_shop()` and inserts the Shop scene before `GameState.descend()`. Shop emits `shop_left` to continue. Suppressed on Floor 1 (no gold yet) and when broke.
- **`scenes/BattleScene.gd`** — gold awards wired in:
  - `_on_combatant_died` awards `Shop.gold_for_kill(floor_num)` per enemy and `Shop.gold_for_boss(floor_num)` extra for bosses.
  - `_on_battle_ended` (hero_won) awards `Shop.gold_for_clear(floor_num)` after the audience-floor-clear bonus.
  - New HUD gold widget (`_gold_widget`) sits below the audience widget at (1080, 56), 188×32 panel with gold border. Flashes warm-gold and updates text on every `gold_gained` signal via `_on_gold_gained`.
- **`scenes/VictoryScreen.gd`** — adds GOLD stat card (6 cards now). Card width shrunk 178→156 and separation 18→12 to fit.
- **`scenes/WinScreen.gd`** — adds GOLD stat card (5 cards). Card width shrunk 270→188 and separation 24→14.
- **`autoloads/SystemVoice.gd`** — new `shop_enter` (8 lines), `shop_purchase` (6 lines), and `ability_mana_shield` (6 lines) quip pools.

**Arcanist Mana Shield (class-unique unlock — fills the audited gap from Run 20):**
- **`src/data/Abilities.gd`** — new `mana_shield` ability: self-target buff, 1 charge, 5-turn cooldown, `mana_shield_amount = 40`, marker key `applies_mana_shield: true`.
- **`src/combat/StatusEffect.gd`** — new `mana_shield(absorb, duration=10)` factory. Carries `absorb_remaining` and `absorb_max` (the latter retained for any future HUD tooltip).
- **`src/combat/Combatant.gd`** — `take_damage()` now drains the shield BEFORE armor (and HP). New private `_consume_mana_shield(incoming)` walks `status_effects`, drains, drops the effect when its pool hits zero, and returns leftover damage to fall through normally. Overflow correctly continues into the armor path (or ignores it if `ignore_armor=true`).
- **`scenes/BattleScene.gd`** `_do_hero_self_ability` — new `"mana_shield"` branch applies the status, plays the SystemVoice quip, fires the VFX, and flashes the hero hex blue.
- **`scenes/LevelUp.gd`** `CLASS_UNLOCKS["arcanist"]` — `mana_shield` added FIRST in the list (order = priority for the unlock card). Backstab/taunt remain as later cross-class fallbacks.
- **`tools/gen_effects.py`** — new `make_mana_shield()` generator: cyan-blue radial halo, three concentric arcane rings, six radial spokes, bright inner core, sparks. Registered in EFFECTS list as `fx_mana_shield.png`. `BattleScene._load_effect_textures` maps the ability id to the new texture.

- **`tests/test_run21.gd`** (22 test functions, ~148 assertions): Shop inventory schema (size, required keys, unique IDs, allowed effect keys = the ones `Shop._apply_effects` actually handles — drift-detector), gold economy helper monotonicity + boss > kill invariant + non-zero clear bonus, `should_show_shop` skip-when-broke + show-when-wealthy, slate determinism across identical seeds + uniqueness within a slate, `Abilities.mana_shield` schema, `StatusEffect.mana_shield()` factory shape, and four Combatant-integration tests for shield absorption (full absorb, overflow through armor, overflow with ignore_armor, zero-damage edge case).
- **Test suite total: 595 passed, 0 failed** (up from 447 in Run 20).

**Run 20 (DCC Reality-Show Layer — Sponsor Offers + Patch Notes):**
- **`src/data/Sponsors.gd`** — pure data + threshold math. 10 DCC-flavored sponsor offers (`hyperion_drink`, `big_mikes_meat`, `iron_tassel`, `spectral_cola`, `bopca_insurance`, `gofundit`, `rays_pizza`, `quantec_pet`, `rumnoir_rotgut`, `exitpit_adv`). Each has a `sponsor` brand name, color, icon, description, and an `effects` dict with any of `attack`/`defense`/`speed`/`max_hp`/`heal`/`audience`. `SPONSOR_THRESHOLD = 200`. Static `sponsors_owed(audience, taken)` returns `max(0, audience / 200 - taken)` — clamps at zero so over-counting can never produce phantom offers.
- **`src/data/PatchNotes.gd`** — pure data. `NOTES` dict maps the floor a hero is *entering* (7 = Obsidian tier; 13 = Void tier) to a patch payload (`version`, `subtitle`, `lines[]`, `closing`). The patch lines use `+` / `-` / `#` prefixes that the PatchNotes scene colors as green/red/accent. Pure flavor — the underlying scaling already happens via `EnemyDefs.make_combatant` and floor-gated abilities; this just narrates the difficulty spike like a live-service balance patch.
- **`scenes/SponsorOffer.tscn/.gd`** — three-card sponsor pick screen, modelled on LevelUp / LootScreen. Subtitle shows `audience_score`. `_apply_effects()` mutates `GameState.hero_base_stats` / `hero_max_hp` / heals / `award_audience`. On continue, increments `GameState.sponsor_offers_taken` and emits `sponsor_chosen`.
- **`scenes/PatchNotes.tscn/.gd`** — full-screen mocking dev-blog. Reads target floor via `prepare(data)`; falls back to `GameState.floor_num + 1` defensively. Tier 2 = warm border + amber accents; Tier 3 = void-purple. Click-through emits `patch_notes_dismissed`. Plays `descend` SFX on entry and exit.
- **`autoloads/GameState.gd`** additions — `sponsor_offers_taken: int` and `patch_notes_seen: Array[int]`, both cleared in `start_run()`.
- **`scenes/Main.gd`** routing — after VictoryScreen's `floor_cleared`, resolves XP via `gain_xp` up-front into `_pending_leveled`, then checks `Sponsors.sponsors_owed` → if owed, routes to SponsorOffer first; otherwise (or after sponsor accept) calls `_post_sponsor_route()` to fall through to LevelUp / Loot. After loot, before descending, checks `PatchNotes.has_notes_for(next_floor)` AND that the floor isn't already in `patch_notes_seen`; if so routes to PatchNotes scene. `_on_patch_notes_dismissed` appends the floor to `patch_notes_seen` and calls `descend()`. `_load_scene()` now passes `{xp, kills, floor}` to `prepare()` so PatchNotes gets the target floor.
- **`autoloads/SystemVoice.gd`** additions — new `sponsor_offer` (8 lines), `patch_notes_v2` (6 lines), and `patch_notes_v3` (6 lines) quip pools.
- **`tests/test_run20.gd`** (16 tests, ~80 assertions) — Sponsors pool schema (size, required keys, unique IDs, allowed effect keys), threshold math (zero / under / at / double / overshoot edge cases), `get_offer` hit + miss, PatchNotes presence for floors 7 and 13, absence for regular floors, schema (`version`/`subtitle`/`lines`/`closing`), and `notes_for(99)` returns empty. Uses `load()` not `preload()` for safety in `--script` test mode.
- **Test suite total: 447 passed, 0 failed.**

**Run 19 (DCC Reality-Show Layer — Achievements + Audience Score):**
- **New autoload `Achievements.gd`** (`autoloads/Achievements.gd`) — pure-data + per-run state. `DEFS` dict holds 14 DCC-flavored achievements (`first_blood`, `boss_slayer`, `untouchable`, `crit_streak`, `lava_lord`, `the_descent`, `deep_dweller`, `descended`, `low_hp_hero`, `team_player`, `combo_master`, `headshot`, `enrage_killer`, `speed_run`). Resets on `GameState.run_started`; per-floor counters reset on `floor_changed`. Signal `achievement_unlocked(id, def)` drives the toast UI. Uses `get_node_or_null("/root/GameState")` duck-typing so the script still compiles in `--script` test mode without autoload context.
- **Audience score** (`GameState`) — `audience_score` (run total), `audience_score_floor` (resets per descent), `lava_push_kills`. Signal `audience_gained(amount, reason)` so HUD widgets can react. New `award_audience(amount, reason)` adds favor and emits. Folded into `run_score()`: now `floor*1000 + kills*25 + bosses*250 + level*100 + audience*2`. Awards: kill +5, crit +10, boss kill +50, lava-push kill +15, floor clear bonus = floor_num × 10, plus each achievement's `audience` field.
- **`BattleScene.gd` integration:**
  - Top-right CanvasLayer with audience-score widget (`★ AUDIENCE N`, flashes gold on gain) and a slide-in achievement toast queue (`_build_achievement_overlay`, `_show_next_toast`). Toasts auto-dismiss after 2.6s and chain through `_pending_toasts`.
  - Subscribes to `Achievements.achievement_unlocked` and `GameState.audience_gained` in `_build_encounter` (with `is_connected` guard so reloads don't double-bind).
  - `_on_action_taken` notes crits (`Achievements.note_crit`) and damage taken by Carl (`note_hero_took_damage`).
  - `_on_combatant_died` unlocks `first_blood` / `boss_slayer` / `headshot` / `enrage_killer`. Headshot detection uses `_attack_pre_hp` (snapshotted in `_do_hero_attack`, cleared right after `perform_attack` so poison/lava deaths can't false-positive).
  - `_do_hero_attack`/`_do_hero_aoe_ability`/`_do_hero_self_ability` call `Achievements.note_ability_used(id)` for the `combo_master` 4-ability-per-floor unlock.
  - Lava-push kills (target dies during push tween into lava): increments `GameState.lava_push_kills`, awards audience, and unlocks `lava_lord` at 3.
  - `_next_turn` calls `Achievements.note_hero_turn()` so `speed_run` (clear in ≤6 turns) can be evaluated.
  - `_on_battle_ended` (hero_won) awards floor-clear audience (floor_num × 10) and runs `_evaluate_floor_clear_achievements()` for `untouchable` (no damage), `low_hp_hero` (<20% HP), `speed_run` (≤6 turns), and `team_player` (both allies still alive).
  - `_ready` fires `the_descent` on floor 9 and `deep_dweller` on floor 15.
- **`WinScreen.gd`** — unlocks `descended` on entry. New AUDIENCE stat card alongside SCORE/LEVEL/KILLS. Achievement roster row: "✦ N / 14 achievements unlocked ✦" + comma-separated list of earned-name strings.
- **`VictoryScreen.gd`** — new AUDIENCE stat card showing `audience_score_floor`. All stat cards shrunk from 200→178px wide so 5 cards fit.
- **`SystemVoice.gd`** — new `achievement_unlocked` quip pool (7 lines, fired ~50% of the time on unlock).
- **`project.godot`** — registers `Achievements` as autoload #5 after AudioManager.
- **`tests/test_run19.gd`** (8 test functions, ~120 assertions) — DEFS schema validation (every entry has name/desc/audience, names unique, all 14 core IDs present, `descended` has the largest payout) + score-formula lock-in (11240 for a canonical floor-9 run). Uses `load()` not `preload()` for Achievements.gd so the test file doesn't drag autoload references into compile.

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

## Genre Gap Analysis & Direction (audited Run 16, updated Run 21)
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
- DCC reality-show layer: achievements + audience score — Run 19
- DCC reality-show layer: sponsor offers — Run 20
- DCC reality-show layer: patch notes between tiers — Run 20
- Gold economy + between-floor shop — Run 21
- Arcanist class-specific unlock (Mana Shield) — Run 21
- HUD polish + ASCII-safe iconography (no missing-glyph boxes) — Run 22
- Move-vs-ability UX (persistent green rings + dynamic hint + right-click cancel) — Run 23
- Background music / ambient loop (per-tier procedural tracks) — Run 24
- Pause / settings menu with SFX & music volume sliders — Run 24
- Combat log panel — Run 24
- Loot rarity tiers (Common/Rare/Legendary, screen flash + per-tier weighting) — Run 24
- Shop rarity tiers (Common/Rare/Legendary, tier-weighted slate, screen flash) — Run 25
- Shop reroll button (escalating gold cost) — Run 25
- Mana Shield HUD bar (per-entity, drains on hit, hides on expiry) — Run 25
- Shop slot LOCK toggle (preserves a card through reroll) — Run 26
- Save / resume a run (per-floor JSON checkpoint on `user://`, CONTINUE button on title) — Run 28

### 🔜 Highest-value, easiest remaining (do next, roughly in order)
1. **Sponsor cooldown / variety** — Run 20 ships 10 sponsors at a flat 200-audience cadence.
   Could weight rare/legendary sponsors at higher audience thresholds, or thread sponsor
   stories across multiple offers (e.g. "Big Mike returns" with a follow-up gift).
2. **Shop "extras" — remaining** — Lock landed in Run 26. Still on the table: an occasional
   surprise-Legendary "the merchant takes a shine to you" event, or a one-per-run
   "buyback" of the last loot card the player skipped.

### 🟡 Larger / later (note, not yet scoped)
4. **More floor variety** — Per-tier hazards: Tier 1 crumbling bridges, Tier 2 freeze pools,
   Tier 3 void rifts that warp enemies. Needs DungeonMap + BattleScene tile-type support.
5. **More enemy types for Tier 2/3** — Void Wraith (phases through walls), Bone Colossus
   (huge HP, slow), Lich (resurrects skeletons).
6. **Boss signature moves** — Dungeon Lord rallies a dead enemy; Warden ground-slam knockback;
   Abyss Keeper void-pull. Per-boss scripted ability in enemy AI.
7. **Meta-progression / unlocks** — Persistent currency between runs, unlockable classes or
    starting perks. Requires save persistence (web: `user://` works in Godot web export).
8. **Status-effect depth** — Bleed, stun, vulnerability; show stacks/durations on a tooltip.
9. **Accessibility/options** — Colorblind-friendly hex highlights, text size, screen shake
    toggle. Run 24's pause menu is a natural home for these settings.

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
                 + 4 looping ambient music WAVs (from tools/gen_music.py, Run 24):
                 music_title, music_stone, music_obsidian, music_void
  effects/     — 64×64 ability VFX PNGs (from tools/gen_effects.py)

autoloads/
  GameRng.gd         — seeded RNG singleton
  GameState.gd       — run-persistent hero state (+run_score, total_kills, bosses_slain, audience_score, lava_push_kills, sponsor_offers_taken, patch_notes_seen)
  SystemVoice.gd     — The System commentary pools + signal (+sponsor_offer, patch_notes_v2, patch_notes_v3 pools as of Run 20)
  AudioManager.gd    — SFX + music player: WAV pool, play(name, pitch_var, vol_db),
                       play_music(name, fade_s), music_for_floor(n), stop_music(fade_s),
                       SFX/music toggles + volume sliders (Run 24)
  Achievements.gd    — Run 19: DCC-style achievement defs + per-run unlock state + signal

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
  Abilities.gd       — all ability definitions (+ignore_armor flag on backstab, +mana_shield Run 21)
  EnemyDefs.gd       — enemy definitions + Combatant factory (+floor_num scaling param)
  Allies.gd          — floor-scripted ally NPCs + Combatant factory (Run 18)
  Sponsors.gd        — Run 20: DCC sponsor-offer pool + threshold math (sponsors_owed)
  PatchNotes.gd      — Run 20: per-tier patch-note payloads (floors 7, 13)
  Shop.gd            — Run 21: merchant inventory + gold-economy helpers (slate/gold_for_*/should_show_shop)
                       Run 25: rarity tiers on every item + per-tier weighted `slate(rng, floor_num)` + `reroll_cost(n)`
                       Run 26: `slate()` accepts optional `locked` arg — locked items carry through reroll

scenes/
  Main.tscn/.gd      — root, scene orchestration; boots to TitleScreen, routes through VictoryScreen
                       Run 20: also routes through SponsorOffer (audience-threshold) and PatchNotes (tiers).
  TitleScreen.tscn/.gd  — main menu: branding, how-to-play, SFX toggle, BEGIN DESCENT
  ClassSelect.tscn/.gd  — class picker front end
  BattleScene.tscn/.gd  — hex battle visual driver (Run 3: charges HUD, lava heat, class glyphs)
  VictoryScreen.tscn/.gd — NEW: post-battle floor clear screen (Run 3)
  LevelUp.tscn/.gd   — upgrade screen; 3 of 6 upgrades per level
  LootScreen.tscn/.gd   — post-battle choose-one loot
  SponsorOffer.tscn/.gd  — Run 20: 3-card sponsor pick when audience score crosses a threshold
  PatchNotes.tscn/.gd    — Run 20: mocking "patch notes" overlay at floors 7 and 13
  Shop.tscn/.gd          — Run 21: between-floor merchant; multi-purchase, gold-gated cards

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
  test_run19.gd      — achievement DEFS schema + audience-score math (Run 19)
  test_run20.gd      — Sponsors pool + threshold math + PatchNotes content (Run 20)
  test_run21.gd      — Shop inventory schema + gold helpers + slate determinism + Mana Shield absorb math (Run 21)
  test_run24.gd      — Loot rarity tier schema + weight invariants + AudioManager music constants (Run 24)
  test_run25.gd      — Shop rarity tier schema + weighted slate + reroll cost ramp + floor-tier boundaries (Run 25)
  test_run26.gd      — Shop slate `locked` arg: placement, no duplication, overflow + defensive cases (Run 26)
  test_run28.gd      — Save/Resume: snapshot↔apply roundtrip, JSON safety, defensive cases, disk I/O smoke, version gate (Run 28)
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
