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

## Current State (Run 39 — Third Perk Slot Unlock + Colorblind Mode)
### Implemented ✅
**Run 39 (3rd perk slot post-win unlock + colorblind-friendly hex palette — roadmap items #4 and #1 from the Run-38 audit):**
- **`src/data/Perks.gd`** — dynamic equip cap. `MAX_EQUIPPED = 2` stays the base constant (preserving the Run-36/38 test contract), and a new `max_equipped(stats: Variant) -> int` returns base + `WIN_BONUS_SLOTS` once `total_wins >= MILESTONE_THIRD_SLOT_WINS` (currently 1 win → +1 slot, so the effective cap becomes 3). New constants `WIN_BONUS_SLOTS = 1` + `MILESTONE_THIRD_SLOT_WINS = 1` so a future hard-mode bump (5th slot after a no-hit clear, etc.) is one-line. Defensive: `null` stats / non-Dictionary / missing `total_wins` all return the base cap — fail closed so a hand-crafted call can't open a slot the player hasn't earned. New `third_slot_unlocked(stats)` predicate wraps `max_equipped(stats) > MAX_EQUIPPED` for the MetaScreen banner without duplicating the math.
- **`autoloads/MetaProgress.gd`** — three plumbing edits to the existing equip path:
  - New `equip_cap()` helper returns `Perks.max_equipped(lifetime_stats())` — the single read of the dynamic cap so the MetaScreen UI and the `equip_perk` gate stay in lockstep.
  - `equip_perk` now reads `equip_cap()` instead of `Perks.MAX_EQUIPPED`. Fresh meta still caps at 2 (`total_wins = 0`), so the Run-36 `test_equip_cap_enforced` regression still passes without modification.
  - `apply_snapshot` reordered: lifetime stats (`total_runs`, `total_wins`, `best_floor`, `best_score`, `lifetime_bosses_slain`) load BEFORE the equipped-perks trim. The trim now uses `Perks.max_equipped(lifetime_stats())` so a save with 3 equipped perks + a win on the books restores all 3 — pre-Run-39 the static cap silently trimmed the third. The Run-38 `lifetime_bosses_slain` load moved up from the end of the function to keep `lifetime_stats()` returning post-load values during the cap computation; a regression test (`test_apply_snapshot_lifetime_bosses_still_loads`) catches any future reorder that drops the field.
- **`autoloads/GameState.gd`** — new `colorblind_mode_enabled: bool` (default false), setters (`set_colorblind_mode(on)` + `toggle_colorblind_mode() -> bool`), reset in `start_run()`, snapshotted in `snapshot()`, restored in `apply_snapshot()` with a `false` default so pre-Run-39 saves load cleanly (no SAVE_VERSION bump — purely additive). The toggle returns the new state so the pause-menu button can update its label in one line, matching the Run-35 toggle idiom.
- **`scenes/BattleScene.gd`** — colorblind-aware highlight palette:
  - Four new color constants: `MOVE_CLR_CB` (cyan-blue `Color(0.20, 0.70, 1.00, 0.45)`) replaces the green MOVE fill, `ATTACK_CLR_CB` (amber `Color(1.00, 0.78, 0.10, 0.55)`) replaces the red ATTACK fill, `MOVE_RING_CLR_CB` (matching cyan ring) replaces the green move ring, `MOVE_RING_CLR` is the existing green ring extracted as a constant so the live wiring reads symmetrically.
  - Two new helpers `_attack_highlight_color()` and `_move_ring_color()` branch on `GameState.colorblind_mode_enabled` so every per-paint highlight reads the toggle live — flipping mid-run repaints the next turn's rings without a scene reload.
  - `_update_highlights` swaps the inline `ATTACK_CLR` for `_attack_highlight_color()`. `_highlight_move_ring` swaps the inline green `Color(...)` literal for `_move_ring_color()`.
  - Pause menu gains a new accessibility row (`access_row2`) below the existing SHAKE / DMG#s row, holding a 220×36 `COLORBLIND: ON/OFF` button. New row instead of crowding the existing one because the 480px panel can't fit three buttons without label clipping, and the new row leaves space for future accessibility toggles (text-size, hex-edge outline) without re-flowing the layout.
  - `_on_pause_toggle_colorblind` flips `GameState.toggle_colorblind_mode()`, updates the button label, and calls `_update_highlights()` so the live grid repaints immediately rather than waiting for the next turn — important because the pause overlay would otherwise hide the change until the player resumed.
  - Palette choice rationale: cyan vs. amber keeps both highlights legible under deuteranopia AND protanopia (the two most common red-green colorblindness variants). The amber attack hex keeps a high red component (>= 0.8) so it still reads as "danger" to non-colorblind players who flip the toggle by accident, and the cyan move ring is unambiguous against the cave's brown-orange floor palette.
- **`scenes/MetaScreen.gd`** — surfaces the dynamic cap:
  - `_refresh()` computes `Perks.max_equipped(MetaProgress.lifetime_stats())` and renders `Equipped: N / dyn_cap` instead of the static `Perks.MAX_EQUIPPED`. When `Perks.third_slot_unlocked(lifetime_stats())` is true, a warm `★ 3rd slot unlocked` suffix appends so a returning player who hasn't opened the screen since their win sees the milestone landed.
  - `_make_perk_card` EQUIP button gate reads the dynamic cap. A player who banks a win mid-session sees the previously-grey-EQUIP buttons re-enable on the next refresh (which fires via `perks_equipped_changed` whenever they equip something).
- **`tests/test_run39.gd`** (24 test functions, ~46 assertions): `max_equipped` for the win threshold (0 → 2, 1 → 3, 99 → 3 — no further bumps), defensive cases (null / non-Dictionary / missing field / random int / random string all return base), `third_slot_unlocked` predicate matches `max_equipped` truthiness; base constant locked at 2; bonus constants > 0 and threshold = 1; MetaProgress `equip_cap()` defaults / bumps; `equip_perk` refuses 3rd before win + allows 3rd after + refuses 4th even after win (cap is bumped, not unlimited); `apply_snapshot` preserves 3 equipped when win is on the books, trims to 2 when not; Run-38 `lifetime_bosses_slain` still loads (catches the reorder regression); `record_run_end` win flips the cap end-to-end. GameState: colorblind defaults off, set/toggle persistence, snapshot inclusion, JSON roundtrip, pre-Run-39 save defaults to false (not stale true).
- **Test suite total: 2337 passed, 0 failed** (up from 2291 in Run 38; +46 new).

**Run 38 (Milestone-gated perks + lifetime boss counter — Run-36 perk depth growth + roadmap item #3):**
- **`src/data/Perks.gd`** — 5 new perks, 3 of which are milestone-gated:
  - **Deep Diver** (50 shards, requires best_floor ≥ 9): +20 max HP healed at run start. The first depth-reward perk.
  - **Bossbane** (55 shards, requires 3 lifetime bosses slain): +2 attack. Tied to actual boss kills rather than just run counts.
  - **Steady Step** (40 shards, no gate): +5 max HP + 1 speed. Light combo perk for early players.
  - **War Veteran** (65 shards, requires 1 lifetime win): start at hero level 3 — the "Seasoned 2.0" only available after a clear.
  - **Champion's Bond** (80 shards, requires 1 lifetime win): +15 max HP, +1 atk, +1 def, +25 gold. Capstone perk.
  - New static helpers: `requirement(id) -> Dictionary` (returns `{type, count}` or `{}`), `has_milestone(id) -> bool`, `is_milestone_unlocked(id, stats) -> bool` (Variant stats param so callers can pass null defensively — fails closed on null/bad data), `requirement_text(id) -> String` (human-readable). Match block in `requirement_text` has a `_` fallback ("Locked") so a future requirement type without UI strings degrades gracefully.
  - `apply_to_run` gains 5 new match arms. Variable names suffixed (`b_atk`, `c_atk`, `c_def`, `s_spd`) to avoid any GDScript match-arm scoping ambiguity vs. the existing arms.
- **`autoloads/MetaProgress.gd`** — three additions threading milestone perks into the existing wallet:
  - New `lifetime_bosses_slain: int` field. Accumulated in `record_run_end` (negative-guard so a defensive caller passing -1 can't decrement). Persisted in snapshot, restored in apply with a 0 default for pre-Run-38 saves (purely additive, no SAVE_VERSION bump — matches the Run-29/31/33/35/37 idiom).
  - New `lifetime_stats() -> Dictionary` exposes `{best_floor, total_wins, bosses_slain}` — single map the milestone check consumes. Pulled out so a future stat type (longest_run, etc.) adds in one place.
  - New `is_perk_milestone_unlocked(perk_id) -> bool` — single gate used by BOTH the purchase path AND the MetaScreen card render so the lock state is consistent.
  - `purchase_perk` adds a milestone-locked refusal between the already-owned check and the spend — defense in depth so a hand-crafted call can't bypass the gate even if the UI somehow does.
  - `reset_all()` clears the new counter alongside the wallet so a dev "reset progress" doesn't strand a stale boss tally.
- **`scenes/MetaScreen.gd`** — perk cards gain a fourth state (MILESTONE_LOCKED) shown alongside LOCKED / OWNED / EQUIPPED:
  - Warm amber border (Color(0.85, 0.55, 0.18)) distinguishes milestone-locked from the muted grey "haven't bought yet" cards.
  - New requirement line (font_size 10, amber, autowrap) sits between description and status: `REQUIRES: Reach floor 9 in any run` / `Slay 3 bosses (lifetime)` / `Win a run (any class)`.
  - Status line shows `50 shards (locked)` in dim amber rather than the gold "spendable" color so a glance reads as "yes you have the shards but no you can't have it yet".
  - Action button flips to `LOCKED` (disabled, amber font_color_disabled) — same card height/layout as the other states, but unclickable so the player can't drain shards into something they haven't earned.
- **`tests/test_run38.gd`** (28 test functions, ~85 assertions): new perk DEFS schema + distinct-cost invariants; requirement helpers (returns dict for gated, empty for ungated, empty for unknown id); `has_milestone` predicate; `is_milestone_unlocked` (threshold met / exceeded / below / ungated-passes / null stats fails closed / unknown id unlocked); `requirement_text` for each known type + empty-string for ungated; per-perk `apply_to_run` (deep_diver heal-to-new-max, bossbane attack, steady_step HP+speed combo, war_veteran level 3, war_veteran never-downgrades, champions_bond capstone, stack-with-steady_step, seasoned-doesn't-clobber-war_veteran); MetaProgress `lifetime_stats` shape + `is_perk_milestone_unlocked` defaults locked + flips on stat bump; `purchase_perk` refuses locked + succeeds after unlock; `lifetime_bosses_slain` defaults 0 + accumulates across runs + ignores negative + unlocks bossbane end-to-end; snapshot includes new field + roundtrip + pre-Run-38 save defaults to 0 (not stale 99) + reset_all clears; full 4-step milestone walkthrough (floor 8 nothing / floor 9 + 1 boss unlocks deep_diver / floor 12 + 2 bosses unlocks bossbane / win + 3 bosses unlocks war_veteran + champions_bond); every gated perk has specific requirement text (catches drift between match block and DEFS).

**Run 37 (Achievement → shard payouts + Achievements gallery on MetaScreen — closing the loop Run 19 left open):**
- **`autoloads/MetaProgress.gd`** — three additions that thread the existing Run-19 achievement system into the Run-36 meta-progression wallet:
  - New `lifetime_achievements: Dictionary` field tracks every achievement id ever unlocked across runs. Distinct from Achievements' per-run `unlocked_ids` which clears on `run_started` — this one accumulates forever.
  - New `SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK: int = 5` constant. Tuned so a complete walk through all 14 achievements pays 70 shards over the run lifetime — about one mid-tier perk (Iron Blood / Audience Darling / Swift Boots) "free" for engaging with the achievement system instead of just running the same play pattern. Doesn't change the per-run audience-score reward that fires every time an achievement re-unlocks.
  - New `award_for_achievement(id) -> int` is the single payment gate. Pays the constant exactly once per id (lifetime mark blocks repeats), credits the wallet, emits `shards_changed`, and persists immediately so a crash before run-end can't lose the lifetime ledger. Defensive: blank id returns 0 with no mutation; payment for an unknown-to-Achievements id is allowed so future achievement additions auto-participate without code changes here. Two read helpers (`is_achievement_unlocked_lifetime`, `total_achievements_unlocked_lifetime`) for UI / test introspection.
  - `snapshot()` / `apply_snapshot()` now round-trip `lifetime_achievements`. Apply tolerates a missing field with an empty default so pre-Run-37 saves load cleanly (purely additive — no SAVE_VERSION bump, matching the Run-29/31/33/35 idiom). Apply also coerces dict values through `bool()` so a malformed `1`/`0` from a hand-edited save still reads correctly. `reset_all()` clears the lifetime ledger alongside the wallet so a dev "reset progress" doesn't strand a stale unlock table.
- **`autoloads/Achievements.gd`** — `unlock(id)` adds one duck-typed call after the audience award: `mp.call("award_for_achievement", id)`. Mirrors the existing GameState duck-type pattern so the script still compiles under `--script` test mode where `/root/MetaProgress` isn't registered. Ordering matters: the audience tally fires first (it's already gated on a NEW unlock), then the lifetime ledger update — so a player who happens to die mid-unlock-toast still gets both bonuses landed.
- **`scenes/MetaScreen.gd`** — two-tab UI on the existing meta panel:
  - New `TAB_PERKS` / `TAB_ACHIEVEMENTS` constants + `_active_tab` state. Two header buttons (`PERKS (N / 8)` / `ACHIEVEMENTS (N / 14)`) sit above the body grid. The active tab text is the warm gold accent; the inactive is muted grey. Mirrors the pause-menu battle-speed pip idiom from Run 27 so the affordance reads consistently across the game's settings surfaces.
  - The body grid is now wrapped in a `ScrollContainer` (1060×380 viewport, horizontal scroll disabled). The 14 achievement cards naturally exceed the fixed-height outer panel; the scroll bar appears only on the achievements tab. The perks grid (2 rows × 4 cols × 200 tall = ~414px) sits within the viewport without scrolling.
  - New `_make_achievement_card(id)` renders each entry: green border + UNLOCKED tag when in `lifetime_achievements`, muted grey + LOCKED tag otherwise. The bottom line shows `+N audience · paid 5 shards` (unlocked) or `+N audience · +5 shards on first unlock` (locked) so the player understands BOTH rewards. Defensive: any achievement with `hidden: true` AND still locked renders as `??? — HIDDEN` with a "earn it to read" stub — no current achievement uses this flag, but the rendering path is wired in case a future hidden gag-achievement is added.
  - Header stats row gains an `Achievements: N/14` segment so a player who never opens the gallery tab still sees lifetime progress on the perks landing screen.
- **`tests/test_run37.gd`** (14 test functions, ~75 assertions): lifetime ledger defaults (empty + false), first-time payout exact amount, second unlock pays 0, blank id rejected (no phantom entries), multi-id accumulation, unknown id still pays once (future-achievement-tolerance lock), `is_achievement_unlocked_lifetime` negative/positive paths, snapshot includes the new field + roundtrip via `apply_snapshot`, pre-Run-37 save default (missing key → empty + next unlock still pays), malformed-entry coercion (true/1/0), `reset_all` clears the ledger, end-to-end walk of `Achievements.DEFS` confirming every known id pays exactly once (locks in the contract that adding a new achievement auto-participates), per-unlock constant > 0, and achievement-payout stacks cleanly with `record_run_end` payout.
- **Test suite total: 2139 passed, 0 failed** (up from 2071 in Run 36; +68 new).
- **Visual audit**: a temporary `tools/r37_screenshot_tour.gd` autoload seeded `MetaProgress.shards = 80` + three unlocked achievements (first_blood, boss_slayer, lava_lord), then auto-clicked META → ACHIEVEMENTS tab and captured screenshots. Confirmed: three green-bordered UNLOCKED cards + eleven grey LOCKED cards, scrollbar visible on the right edge, reward line legible on every card, ACHIEVEMENTS tab text shows gold accent while PERKS shows the muted grey, header stats row shows `Achievements: 3/14`. Tour autoload was removed after the audit; not part of the shipping build.

**Run 36 (Roadmap item #1 — meta-progression / unlocks, the biggest remaining gap):**
- **`autoloads/MetaProgress.gd`** — NEW persistent autoload, registered in `project.godot` after `Achievements`. Distinct from `GameState`'s per-run save (`descent_save.json`) — the meta save (`descent_meta.json`) survives death / win / new run, finally closing the loop the Run 28 save was prep work for. Tracks `shards: int` (the meta currency), `owned_perks: Array[String]` (purchases), `equipped_perks: Array[String]` (active loadout, capped at `Perks.MAX_EQUIPPED = 2`), plus lifetime stats (`total_runs`, `total_wins`, `best_floor`, `best_score`, `classes_cleared: Dictionary` for first-class-win bonus accounting).
  - File I/O matches Run-28's pattern (FileAccess + JSON + best-effort, IndexedDB-safe on web). `save_to_disk()` is gated behind `is_inside_tree()` so test instances (`.new()` outside the tree) can't pollute the player's real save — a clean test-isolation pattern with no test-only flags.
  - `shards_for_run(floor, bosses, won, class_id)` is a pure helper exposed separately from `record_run_end` so the WinScreen can display the breakdown before the wallet updates. Constants: `SHARDS_PER_FLOOR=1`, `SHARDS_PER_BOSS=4`, `SHARDS_PER_WIN=25`, `SHARDS_PER_FIRST_CLASS_WIN=10` — tuned so a typical death at floor 5-7 pays ~10 shards (one cheap perk every 2-3 runs) and a full clear pays 65 first time / 55 thereafter.
  - `purchase_perk` / `equip_perk` / `unequip_perk` enforce: unknown id refused, duplicate purchase refused, broke refused, unowned can't equip, full loadout (`MAX_EQUIPPED`) blocks equip, duplicate equip refused. Every successful mutation fires a signal AND saves.
  - `apply_snapshot` defensively trims `equipped_perks` to `MAX_EQUIPPED` AND drops any entry not in both `owned_perks` and `Perks.DEFS` — guards against future perk removal / save drift so a stale save can't crash run-start.
- **`src/data/Perks.gd`** — NEW pure data module. 8 perks across HP / gold / stats / audience / shop economy:
  - `seasoned` (25): start at hero level 2.
  - `wealthy` (20): start with 30 gold.
  - `iron_blood` (30): +15 max HP, healed to new max.
  - `lucky_strike` (30): +1 attack.
  - `merchant_ally` (45): 15% shop + reroll discount.
  - `audience_darling` (30): +50 audience score at run start (sponsor offers come sooner).
  - `hardened_traveler` (40): +1 defense.
  - `swift_boots` (35): +1 speed.
  - `apply_to_run(state, equipped)` is the single mutator — stacks on top of class baseline. Duck-typed `state: Object` so tests can pass a minimal `_FakeState` without instantiating GameState (which requires `/root/GameRng`). `match` block keeps adding a perk to ≤3 lines (DEFS entry + match arm).
  - `apply_shop_discount(raw_cost, equipped)` + `shop_discount_pct(equipped)` — pure economy helper. 1-gold floor so a future cheap item can't round to free. Called from `scenes/Shop.gd._effective_cost` AND the reroll path so the discount lands everywhere prices are computed.
- **`scenes/MetaScreen.gd/.tscn`** — NEW screen reached from TitleScreen → META. Three-state perk cards: LOCKED (cost + BUY, greyed when broke), OWNED (purple border + EQUIP, greyed when loadout full), EQUIPPED (green border + UNEQUIP). Header row shows shard balance, equipped/cap, lifetime runs/wins/best-floor. BACK button returns to title via a new `meta_closed` signal so the player can re-read the updated CONTINUE state. Rebuilds on every shard/equip change (cost-affordability gating depends on the wallet, so a partial card refresh wouldn't catch all the state).
- **`scenes/TitleScreen.gd`** — new META button below the main row showing live shard count + perk-equipped suffix ("META · 80 shards · 1 perk equipped"). Emits `open_meta`. The button sits in its own row so a brand-new 0-shards player isn't distracted by it but a returning player finds it instantly.
- **`scenes/Main.gd`** — wired the route: `open_meta` → MetaScreen, `meta_closed` → TitleScreen. New `_record_meta_end(won)` helper, called from both `_on_hero_died` and the win-condition branch of `_on_loot_chosen`. Guarded by `_meta_recorded: bool` (reset on `_on_run_started`) so a quick death-during-victory edge case can't double-pay.
- **`autoloads/GameState.gd`** — `start_run` now reads `MetaProgress.equipped_perks` via duck-typed `/root/MetaProgress` lookup and calls `Perks.apply_to_run(self, equipped)` right after class data load, before `run_started.emit()`. Effects stack on the class baseline — Brawler + iron_blood + lucky_strike starts at 165 HP / 16 atk. No new fields, no SAVE_VERSION bump (perks are external to the run save).
- **`scenes/Shop.gd`** — `_effective_cost` now applies the `merchant_ally` percentage on top of the favor discount (favor first since it's larger). Reroll path calls `Perks.apply_shop_discount` too. Card cost label generalized: shows discounted/raw side-by-side whenever ANY discount applies (favor uses its existing glow color; perk-only uses the new soft-purple to mirror the META screen's accent so the source reads at a glance).
- **`scenes/WinScreen.gd`** — new row above the play-again button: "+N shards this run · total M · spend on perks from the title menu". Pulls the breakdown via `MetaProgress.shards_for_run` (re-reads the live wallet via `MetaProgress.shards`) so the player feels the loop closing on a win.
- **`tests/test_run36.gd`** (38 test functions, ~85 assertions): DEFS schema invariants + cost helper bounds; `apply_to_run` for every perk (incl. defensive `seasoned` never-downgrades, `merchant_ally` is a no-op on state, unknown-id ignored, empty/null safety); shop discount math (15% for merchant_ally, 0% for others, raw passthrough, 1-gold floor); MetaProgress currency (award/spend +/- guards, overdraft refused, wallet integrity); perk lifecycle (purchase happy-path, unknown refused, duplicate refused, broke refused, equip-needs-ownership, equip/unequip roundtrip, MAX_EQUIPPED cap, no-duplicate-equip); shard payout matrix (death-no-boss, death-with-boss, full-clear-first-time, full-clear-repeat, loss-never-gets-win-bonus); `record_run_end` plumbing (stats bump, class marked on win only, best_floor/best_score only-rises); snapshot/apply roundtrip + version stamp + defensive trim-to-cap + drop-equipped-not-owned + drop-equipped-not-in-DEFS. **Test suite total: 2071 passed, 0 failed** (up from 1937 in Run 35; +134 new).
- **Visual audit**: ran a temporary `tools/meta_tour.gd` autoload (removed after the audit) — confirmed the META screen renders the three perk states correctly (locked grey / owned purple / equipped green), BUY drains the wallet in real-time, and the unaffordable Merchant's Friend (45 shards) shows greyed BUY at 80 shards. The screen lives at `scenes/MetaScreen.tscn` reached from TitleScreen → META; the test bot file was deleted after the audit.

**Run 35 (Roadmap items #2 and #3 — status-effect tooltips & stacks + accessibility):**
- **`src/combat/StatusEffect.gd`** — single source of truth for HUD rendering. Four new pure helpers, zero scene dependency:
  - `SHORT_CODES` + `DISPLAY_NAMES` constants — bare maps for `burning/frozen/poisoned/fortified/vanished/mana_shield`. The Run 22 magic-strings inside `_update_status_label` were the only place these lived; they're now grounded in the data module so a future effect adds in one place.
  - `short_code(eff) -> String` — the three-letter code shown above each combatant. Defensive: unknown ids truncate to upper-cased first three, fully empty dicts return `???` so the HUD never renders a `[ ]` bracket.
  - `display_name(eff) -> String` — long-form name for the detail panel. Falls back to the dict's `name` field for unknown ids.
  - `summarize(eff) -> String` — multi-segment line ("Burning · 3t · 5/turn"). Always carries duration. Appends DPT only when > 0, armor mod only when != 0 (with leading `+` for positive), and substitutes "X absorb" for Mana Shield instead of a misleading "0/turn".
  - `stack(effects) -> Array[Dictionary]` — collapses duplicates by id into one row with a `stacks` field. Duration → MAX of the group (player cares when it stops applying). DPT → SUM (matches how `tick_statuses` already pays out — poison_blade re-applied twice ticks for the combined dpt). Order of first appearance preserved so the HUD doesn't flicker as effects rotate. Malformed entries (non-dicts, blank ids) are silently dropped.
- **`scenes/BattleScene.gd`** — three player-facing surfaces:
  - **Above-the-sprite status label** (`_update_status_label`): now `[BRN 3] [PSN 4 x2]` instead of `[BRN] [PSN]`. Pre-Run-35 the label didn't surface duration OR stack counts — the player could see something was on them but not when it would stop or how many stacks were burning down. Built via `StatusEffect.stack` + `short_code` + duration, so the format definition is in one place.
  - **Hero status detail section** (`_refresh_status_panel`): a new collapsible section appended to the existing Run-27 loadout panel. Divider + "STATUS" header + a multi-line label rendering `StatusEffect.summarize(eff)` for each stacked effect with a "(x2)" suffix when stacked. Hidden when the hero has no active effects so the panel stays compact between buffs/debuffs. Re-renders whenever `_update_status_label(_hero)` fires — no polling, no extra signals.
  - **Pause-menu accessibility row** (`_build_pause_menu`): two new toggle buttons — `SHAKE: ON/OFF` and `DMG #s: ON/OFF`. Sits between the SFX/MUSIC row and RESUME. Reads the GameState fields directly for the initial label so a resumed run shows the saved state.
- **`_screen_shake(intensity, duration)`** is now gated by `GameState.screen_shake_enabled`. When disabled it still kills any in-flight shake tween and snaps both world layers back to `_world_base` — important so a mid-shake disable settles cleanly instead of stranding the map on an offset frame.
- **`_show_damage_number(c, dmg, color, is_crit)`** is gated by `GameState.damage_numbers_enabled`. HP bar still drains, combat-log line still fires, hit-flash still plays — only the floating `-N` Label is suppressed. Disabling reduces visual clutter without hiding actual damage feedback.
- **`autoloads/GameState.gd`** — two new bool fields (`screen_shake_enabled`, `damage_numbers_enabled`), both default true. Reset in `start_run()` so a fresh class pick always starts with shipping behavior. Snapshotted in `snapshot()`; restored in `apply_snapshot()` with default-true fallbacks so pre-Run-35 saves load cleanly (purely additive — no SAVE_VERSION bump). Four helpers: `set_screen_shake/set_damage_numbers` (writeable from anywhere) and `toggle_*` (used by the pause-menu buttons — return the new value so the button label can be updated in one line).
- **`tests/test_run35.gd`** (29 test functions, ~80 assertions): short_code for every known id + unknown-id truncation + empty-dict placeholder; display_name for every known id + dict-name fallback; summarize covers burning (dpt), poisoned (dpt), frozen (negative armor), fortified (positive armor with `+`), mana_shield (absorb pool, no `/turn` noise), vanished (no spurious tails); stack handles empty / single passthrough / duplicate collapse / mixed-id ordering / malformed entries / mana_shield absorb summing; GameState defaults / set / toggle (returns match state) / snapshot inclusion / apply roundtrip / pre-Run-35 save defaults / start_run reset; integration assertion composes the full `[BRN 3] [PSN 4 x2]` label so future drift in either side is caught.
- **Test suite total: 1937 passed, 0 failed** (up from 1857 in Run 34).

**Run 34 (Two tier-1 enemy variants + Boss Phase 3 — both top items from the Run 33 roadmap):**
- **Tier-1 enemy roster growth** (`src/data/EnemyDefs.gd`) — until now the early run (floors 1-6) drew from the same five enemies. Both new variants reuse existing sprites via the Run 32 `Combatant.tint` system (zero new art pipeline):
  - **Cave Bat** (`cave_bat`, min_floor 2): 18 HP / 0 armor / **speed 16** — second-fastest mob in the game after the Void Wraith. Imp sprite, slate/blue tint Color(0.55, 0.62, 0.85), single `enemy_claw`. Glass-cannon flanker — gets adjacency fast, but pops in one good hit. Encourages spending a turn on it before chasing fodder.
  - **Stone Skeleton** (`stone_skeleton`, min_floor 3): 55 HP / **armor 5** / speed 6 — highest armor in the tier-1 pool by a wide margin (next-highest is the regular skeleton at 3). Skeleton sprite, brown tint Color(0.72, 0.58, 0.42), single `enemy_claw`. Punishes "spam Basic Attack" hero builds — forces backstab / fireball / power_strike usage in the early run.
  - Floor gating verified by test: bat doesn't appear at floor 1, joins floor 2; stone skeleton doesn't appear at floor 2, joins floor 3. Both flow through the existing `make_combatant` factory's `tint: Color` plumbing.
  - **Regression fix**: `tests/test_combat.gd::test_enemy_defs_floor5` previously asserted exactly 5 enemy types at floor 5. Updated to `>= 7` (the new full tier-1 pool — 5 originals + 2 Run-34 variants) so future tier-1 additions don't re-break it.
- **Boss Phase 3 — Frenzy** — when a boss drops below 15% HP (`PHASE_3_HP_THRESHOLD = 0.15`, deliberately tuned below the 0.30 enrage threshold so the player feels a clear two-step escalation), its signature moves escalate. The phase 3 trigger lives in a new `BattleEngine._check_boss_phase3` called from `perform_attack` right next to the existing `_check_boss_enrage` — same path, same "boss survived the hit" guard. New `frenzied: bool` field on Combatant (default false), new `boss_frenzied(boss)` signal. `_check_boss_phase3` only fires once (the `if boss.frenzied: return` guard mirrors enrage). When `frenzied` flips, the boss's signature cooldown shortens (`SIGNATURE_COOLDOWN_FRENZIED = 2` vs `SIGNATURE_COOLDOWN = 3`) so the escalated signature fires more often in the final stretch.
  - **Dungeon Lord — Mass Rally** (`_signature_rally` Frenzied branch): raises EVERY eligible corpse in one detonation instead of just the first one. Still consumes `rally_used` for the whole battle — the upgrade is breadth, not repeatability. The `boss_signature` payload now lists every revived combatant (not a single-element array), and BattleScene's existing rally handler iterates `affected` so each gets a fresh entity node + VFX without code changes.
  - **The Warden — Tectonic Slam** (`_signature_ground_slam` Frenzied branch): radius widens from 1 to 2, push distance grows from 2 to 3. The previous "stay out of melee" counter-play stops being enough — only range-3+ is truly safe. The `if hit.is_empty(): return false` guard still falls through to a regular attack when nobody's in the wider radius, so the boss never wastes the signature.
  - **The Abyss Keeper — Void Implosion** (`_signature_void_pull_mass`, the Frenzied branch picked off `boss.frenzied` early in `_signature_void_pull`): pulls EVERY hero in range 2-4 into the boss's ring simultaneously. Heroes are sorted closest-first so the nearest hero claims the best landing hex (a new `_nearest_free_neighbor` helper takes a `claimed: Dictionary` of already-reserved hexes this turn, so chain pulls don't collide). Already-adjacent heroes are untouched (range guard 2-4). If nobody's in the pull range, no signature fires — same fallback discipline as the base form.
- **`scenes/BattleScene.gd`** — new `_on_boss_frenzied` handler connected to `_engine.boss_frenzied`. Cosmetic-only: swaps the boss glow from crimson-orange (enrage's color) to a brighter violet (0.72, 0.14, 0.92, 0.80) with a faster pulse tween, plays the existing `enrage` SFX pitched +2 semitones, fires a heavier `_screen_shake(11.0, 0.55)`, adds a violet "ENTERS FRENZY" combat-log line, shows the `✦ NAME — FRENZIED ✦` banner, and speaks the new `boss_frenzied` quip pool. Reuses the existing GlowRing node so no .tscn changes were needed.
- **`autoloads/SystemVoice.gd`** — new `boss_frenzied` quip pool (6 lines, DCC-flavored: "The boss has descended into Phase 3. The metrics are no longer in your favor.").
- **`src/data/PatchNotes.gd`** — floor-7 v1.7 notes mention the retired tier-1 variants ("Cave Bats, Stone Skeletons. Their tier was unprofitable.") plus the Warden's Frenzied slam-radius widening. Floor-13 v1.13 notes gain three lines on dungeon-wide Phase 3 + the Dungeon Lord and Keeper Frenzied variants. The fiction stays in lockstep with the mechanics.
- **`tests/test_run34.gd`** (22 test functions, ~30 assertions): variant schema + floor gating boundaries (1/2/3) + tint plumbing + ability drift detector; design locks (Cave Bat speed >= 16, Stone Skeleton armor >= 5); Phase 3 trigger (trips below threshold, doesn't trip above, signal fires exactly once even after HP yo-yos); Frenzied rally (revives every corpse, payload lists all revived, still one-shot per battle); Frenzied slam (range-2 reach, push distance grows, skipped when nobody in radius); Frenzied void pull (mass-pulls in range, skips already-adjacent, no signature when nobody in range); cooldown is 2 when frenzied / 3 when not; Combatant.frenzied defaults to false.
- **Test suite total: 1857 passed, 0 failed** (up from 1806 in Run 33).

**Run 33 (Boss signature moves + 2 new enemy variants + loot buyback — the three roadmap items from Run 32):**
- **Boss signature moves** — every boss now has a once-per-cadence signature that fires through a new `BattleEngine._boss_ai` branch. `Combatant.signature_cd` ticks the cooldown (3 boss turns by default — `SIGNATURE_COOLDOWN`); `Combatant.rally_used` is the Dungeon Lord's once-per-battle gate. New `boss_signature(boss, move_id, affected)` signal drives all visuals — BattleScene's `_on_boss_signature` handler spawns VFX, banner, audio sting and a colored combat-log line. The boss AI dispatch is faction-gated behind `if enemy.is_boss` so non-boss enemies are untouched and the previous random-ability fallback still fires when a signature can't be used (no eligible corpse / no adjacent hero / out of pull range), keeping base boss difficulty intact.
  - **Dungeon Lord — Rally**: drags one fallen non-boss enemy back to its feet at half HP, clearing its statuses. Once per battle. Skipped (and `rally_used` not consumed) when no eligible corpse has a free spot to stand. BattleScene re-spawns the entity node so the corpse's greyed-out art is replaced with a fresh sprite + bob tween, and fires the `rally` VFX (heal cross).
  - **The Warden — Ground Slam**: AoE melee that hits *every* hero adjacent to the boss, then pushes each 2 hexes back via the existing `push_combatant` path. Skipped when nobody's adjacent — counter-play is "don't stand next to the Warden". Plays `hurt` SFX, shakes the screen.
  - **The Abyss Keeper — Void Pull**: teleports a hero at range 2-4 onto the boss's nearest free neighbor and rakes them for `void_pull` damage (armor-ignoring). Already-adjacent and out-of-range heroes are immune — distance is the trigger, melee is the counter. Plays `ability` SFX with the shadow-step VFX.
- **`src/data/Abilities.gd`** — five new ability defs: `ground_slam` and `void_pull` (for the engine to lookup base damage / ignore_armor), plus `plague_bite` (poison-applying enemy attack, 3-turn / 5 dpt poison) and `ember_claw` (burning-applying, 3-turn / 4 dpt). All are flagged as enemy-side variants so `BattleEngine.perform_attack` knows to apply the status — a new `if attacker.faction == ENEMY` block reads the `applies_poisoned`/`applies_burning` markers + duration/dpt fields and calls `apply_status`. The faction guard is critical: hero-side `poison_blade` already applies its own status in BattleScene, and applying it again here would double-stack. Tested.
- **NEW enemy variants** (`src/data/EnemyDefs.gd`) — both reuse existing sprites via Run 32's `Combatant.tint`:
  - **Plague Goblin** (min_floor 8, Obsidian): 40 HP / 1 armor / speed 14, goblin AI (flank + random ability), green tint. Carries `enemy_claw` + `plague_bite` so 50% of its hits stack poison. The plague-tier debuffer the goblin sprite was already half-built for.
  - **Ember Imp** (min_floor 13, Void): 35 HP / 0 armor / speed 13, imp AI (always rush), orange tint, single `ember_claw` ability (every hit burns). Cheap individually so a pack stacks DoT fast.
  - **AI tweak** — the imp branch previously hardcoded `perform_attack(..., "enemy_claw")`, which would have made the Ember Imp swing claws and skip its burn entirely. Branch now attacks with `enemy.abilities[0]`; regular imps still claw (their list is `[enemy_claw]`).
- **Loot Buyback — the "regret aisle"** — once per run, the merchant offers back the best loot card the player skipped:
  - **`scenes/LootScreen.gd`**: tracks `_slate_items` and, on a TAKE IT click, calls `Shop.pick_buyback_candidate(slate, chosen_id)` to find the highest-rarity card the player walked away from (legendary > rare > common; skip-type items excluded — re-applying a floor skip mid-shop would mutate `floor_num`). Stores the whole item dict in `GameState.last_skipped_loot` so it survives a floor transition. Overwritten each floor — buyback always shows the LAST skip, not the first.
  - **`src/data/Shop.gd`**: `BUYBACK_COSTS = {common: 60, rare: 120, legendary: 240}` — deliberately above the "you should have just grabbed it" line, because by definition you decided not to grab it. New `pick_buyback_candidate` + `buyback_cost` helpers, both pure-data and tested.
  - **`scenes/Shop.gd`**: a teal `BUYBACK · <name>` strip renders between the card row and the button row when `last_skipped_loot` is non-empty and `loot_buyback_used == false`. Full-width (not a 5th card — would have overflowed the 1120px panel) with the card name, the merchant's flavor text ("You walked past this once. The merchant kept it."), gold cost, "once per run" hint, and a `BUY IT BACK` button that switches to `RECLAIMED` once clicked. Survives shop rerolls — it isn't part of the slate draw. Uses LOOT_POOL schema (`type`/`value`/`stat`/`multi` keys) via a new `_apply_loot_buyback` helper rather than Shop items' `effects` dict.
  - **`autoloads/GameState.gd`**: new `last_skipped_loot: Dictionary` and `loot_buyback_used: bool`, both reset in `start_run()`, included in `snapshot()` (deep-copied so future mutations don't poison the live state), restored in `apply_snapshot()` with `{}`/`false` defaults so pre-Run-33 saves load cleanly (no SAVE_VERSION bump — purely additive).
- **`autoloads/SystemVoice.gd`** — four new quip pools (`boss_rally`, `boss_slam`, `boss_pull`, `shop_buyback`), 5-6 lines each, DCC-flavored ("The Abyss does not ask. The Abyss arrives.").
- **`src/data/PatchNotes.gd`** — floor-7/13 patch notes updated with mentions of every Run-33 addition so the fiction stays in sync with the mechanics. Run 20's test asserts `lines.size() > 2`; the additions stay well above that bar.
- **VFX wiring** (`scenes/BattleScene.gd`): five new entries in `_load_effect_textures()` — `plague_bite` → poison, `ember_claw` → lava heat, `ground_slam` → impact, `void_pull` → shadow step, `rally` → heal. All reuse existing PNGs, so no new art-generator runs.
- **`tests/test_run33.gd`** (24 test functions, ~50 assertions): variant schema + floor gating (boundaries at 7/8/13) + tint plumbing + ability drift detector; enemy plague_bite/ember_claw apply their statuses to the hero through perform_attack; hero poison_blade does NOT double-apply (faction-guard regression); each boss signature fires when conditions are right + is correctly skipped when they aren't (no corpse / no adjacent target / out of pull range); rally is once-per-battle; signature cooldown ticks down between uses; loot buyback candidate picks highest-rarity skipped + excludes chosen + excludes skip-type + returns {} for trivial slates; buyback costs climb with rarity + unknown rarity falls back; GameState buyback fields default + JSON snapshot roundtrip + pre-Run-33 save default + start_run reset.
- **Test suite total: 1806 passed, 0 failed** (up from 1746 in Run 32).
- **Visual audit**: re-ran `tools/tour_bot.gd` after the work and confirmed the merchant interlude correctly renders the teal BUYBACK strip below the slate cards with the Run-32 affordability logic still applying to the 4 main cards.

**Run 32 (UI & Arc Repair — first full visual audit via tools/tour_bot.gd):**
- **`tools/tour_bot.gd`** — NEW dev tool: an auto-play bot that drives the real game under Xvfb (find-button-by-text + `pressed.emit()`, no pixel coordinates), kills enemies through the engine to advance floors, and saves viewport screenshots to `user://tour/`. To use: temporarily add `TourBot="*res://tools/tour_bot.gd"` to `[autoload]` in project.godot, run `DISPLAY=:99 godot --path . --resolution 1280x720`, inspect PNGs, remove the autoload. NOT registered by default — it is a dev harness, not game code. This audit produced every fix below.
- **BUG FIX — Shop cards never got their initial state** (`scenes/Shop.gd`): `_refresh_card_state()` looks panels up via `_cards_container.get_child(slot_idx)`, but was called at the end of `_make_card()` — *before* the panel was added to the container — so it silently no-opped. Freshly built slates rendered with enabled BUY buttons on unaffordable items ("TOO POOR" never applied), blank LOCK buttons, and the Run-31 favor card showing "BUY" instead of "CLAIM (FAVOR)". Fix: `_rebuild_cards()` now calls `_refresh_all_cards()` after the panels are in the tree; the in-`_make_card` call was removed with an explanatory comment. Screenshot-verified.
- **BUG FIX — "Combat Instincts" was a dead upgrade** (`autoloads/GameState.gd` + `scenes/Main.gd`): the LevelUp card wrote `hero_base_stats["xp_bonus"]` and NOTHING ever read it. New `GameState.consume_xp_bonus(base_xp) -> int` applies the percentage and erases the key (one-shot, matching the card's "Next floor grants +50% XP" wording; stacked picks pay out together). Called from `Main._on_battle_complete` so the boosted number is what the VictoryScreen shows AND what `gain_xp` later consumes.
- **BUG FIX — melee golem variants were statues** (`src/combat/BattleEngine.gd`): the `"golem"` AI branch only ever cast `enemy_fireball` and never moved. A golem-sprite enemy without that ability (new Bone Colossus) would idle forever. The branch now falls through to advance-and-melee for golems *without* the ranged ability; Lava Golems always carry it, so their stationary-turret behavior is regression-guarded by test.
- **Victory screen kills card** (`scenes/VictoryScreen.gd`): was icon "ATK" + label "ENEMIES" — read as an attack stat. Now "X" + "KILLS".
- **Hero HP widget** (`scenes/BattleScene.gd`): the HP readout was a bare floating green Label (.tscn `HeroHPLabel`) — the only unframed element in the right-edge HUD column, with no owner name. Replaced by a framed `CARL  N / N` panel at (1080,12) matching the AUDIENCE/GOLD stylebox idiom, plus a 172×5 HP drain bar that recolors green→red with the existing ratio gradient. The .tscn label is hidden (not removed) and kept in sync defensively; `_update_hero_hp_label()` drives all three.
- **World-layer auto-centering** (`scenes/BattleScene.gd`): the .tscn pins HexLayer/EntityLayer at (640,340), but generated maps are rarely symmetric around the axial origin — some floors rendered hugging the top-left with a dead bottom-right quarter (screenshot-confirmed on floor 1). New `_center_world_layers()` computes the pixel bbox of all map hexes and repositions both layers so the bbox center lands on the playfield center (635,358 — the area between the side HUD columns, header, and ability bar). New `_world_base` var replaces the hardcoded base in `_screen_shake()` (which would otherwise teleport the map back to the old origin on the first hit). Clicks unaffected — hex Area2Ds live inside `_hex_layer`.
- **Combat log opening line** (`scenes/BattleScene.gd`): the log rendered as an empty bordered box until the first hit. Now seeded with `Floor N — X hostiles (boss)` in dim grey on build. Doubles as a threat count.
- **Card-button alignment** (`scenes/LootScreen.gd`, `scenes/LevelUp.gd`, `scenes/Shop.gd`): description labels now `SIZE_EXPAND_FILL` vertically so TAKE IT / BUY+LOCK rows pin to the card bottom — previously buttons floated at differing heights per description length (screenshot-confirmed).
- **NEW ENEMIES — the Tier 2/3 roster finally grows** (`src/data/EnemyDefs.gd`): before this run the enemy pool stopped growing at floor 4; floors 7–18 fought the same five enemies with bigger numbers while patch notes *narrated* new threats. Both new defs are palette-tinted variants of existing sprites (zero new art pipeline):
  - **Void Wraith** (min_floor 7, Obsidian tier): 45 HP / 2 armor / **speed 17** (fastest mob in the game — design locked by test), `enemy_claw` + `bone_volley`, violet tint. Inherits the skeleton ranged-AI branch via `sprite_key: "skeleton"` — kites from range 3 on turn one.
  - **Bone Colossus** (min_floor 13, Void tier): 110 HP (≈374 after floor-13 scaling ≈ 2 lava golems, well under boss territory) / 10 armor / speed 4, `enemy_bite`, pale bone tint on the golem sprite. Advances relentlessly via the AI fix above.
  - `Combatant.tint: Color` (default WHITE) + `make_combatant` copies the def's optional `tint`; BattleScene applies it to `sprite.self_modulate` so root-modulate animations (hit flash, death grey-out, vanish alpha) compose instead of overwriting.
  - `src/data/PatchNotes.gd`: floor-7 notes gained "+ NEW: Void Wraiths deployed. Fast. Ranged. Upset about something."; floor-13 notes gained "+ NEW: Bone Colossus units online. Slow. Inevitable. Door-shaped." — the fiction now matches the mechanics.
- **`tests/test_run32.gd`** (13 test functions, ~49 assertions): consume_xp_bonus (passthrough / apply+erase / stacking / int truncation / zero+negative guards), new-enemy schema + floor gating (6/7/13 boundaries) + abilities-exist drift detector + wraith-is-fastest design lock + tint plumbing + Combatant default, and three engine AI tests (colossus advances, colossus bites when adjacent, lava golem turret regression guard).
- **Test suite total: 1746 passed, 0 failed** (up from 1697 in Run 31).

**Run 31 (Merchant's Favor — once-per-run surprise Legendary discount):**
- **`src/data/Shop.gd`** — pure-data helpers for the "merchant takes a shine to you" event called out in the Run 30 roadmap audit. New constants `FAVOR_BASE_CHANCE = 0.18`, `FAVOR_CHANCE_PER_100_AUDIENCE = 0.015`, `FAVOR_CHANCE_CAP = 0.40`, `FAVOR_DISCOUNT_PCT = 0.50`. Four new static helpers:
  - `favor_chance(audience_score) -> float` — base + audience-scaled bonus, clamped at the cap. Negative inputs floor to base (defensive — audience never drops in practice but the invariant holds).
  - `roll_merchant_favor(rng, audience_score) -> bool` — single probabilistic roll. Defensive null-rng returns `false` so a missing rng can't silently consume the once-per-run flag.
  - `discounted_cost(original) -> int` — rounds-then-floors at 1 gold so a hypothetical 1-gold Legendary can't free itself. Zero/negative input returns 0.
  - `cheapest_legendary(exclude = {}) -> Dictionary` — used by the Shop scene to force a Legendary into the slate when favor rolls but no Legendary naturally surfaced. Respects an exclude-id-set so it never returns a duplicate of something already on the slate.
- **`autoloads/GameState.gd`** — new `merchant_favor_used: bool` flag. Reset in `start_run()`, included in `snapshot()`, restored in `apply_snapshot()` with a `false` default so pre-Run-31 saves still load cleanly (no SAVE_VERSION bump — purely additive).
- **`scenes/Shop.gd`** — entry-time favor roll:
  - In `_roll_initial_slate()`, after the regular slate is drawn, an independent `favor_rng` (seed XOR'd with prime 8629) rolls against `favor_chance(audience_score)`. On hit, calls `_activate_merchant_favor()` which finds an existing Legendary in the slate or swaps in `cheapest_legendary()` over the most expensive non-Legendary slot (so the worst marginal-value pick is what gets replaced). Sets `_favor_slot: int`, fires the `victory` SFX at -2dB, and speaks the new `shop_merchant_favor` quip pool.
  - Card chrome: a new rose/magenta `[MERCHANT'S FAVOR]` badge sits alongside the rarity and lock badges. The cost label shows the discounted price followed by the struck-through original in parens (`$ 150 gold  ($ 300)`), colored in the favor glow color. The buy button label flips from `BUY` to `CLAIM (FAVOR)` so the offer reads at a glance.
  - Border-color priority: favored > locked > rarity, so the rarest state is the most visible cue.
  - `_effective_cost(slot_idx)` is the single source of truth for the post-discount price — used by both the affordability ("TOO POOR") check and the `spend_gold()` call in `_on_buy_pressed`. Both paths use the same value so the discount can't be displayed but not honored, or vice versa.
  - On a favored purchase, `_favor_slot` resets to -1 so the badge clears, and a dedicated `speak_direct` line ("Discount claimed. The merchant's affection is, statistically, suspect.") fires instead of the generic legendary or shop_purchase quip.
  - Reroll handling: a `_reroll_slate()` re-anchors `_favor_slot` to whatever Legendary survived the redraw (or sets it to -1 if none did). Locking has no effect on favor — the player can't "preserve" the discount by locking, since the favor is per-visit and the flag has already fired.
- **`autoloads/SystemVoice.gd`** — new `shop_merchant_favor` quip pool (6 lines, dry-meta DCC tone: "The merchant has taken a shine to you. The audience approves. The accountants weep.").
- **`tests/test_run31.gd`** (18 test functions, ~40 assertions): `favor_chance()` base case + monotonicity across 6 audience points + cap behavior + negative-input safety; `roll_merchant_favor()` determinism with same seed + null-rng defensive case + statistical distribution check (600 trials at audience 500, observed within ±0.10 of `favor_chance(500) = 0.255`); `discounted_cost()` math for all 4 current Legendaries + 1-gold floor + zero/negative coercion; `cheapest_legendary()` returns lowest-cost (cross-checked against the full INVENTORY) + respects exclude + returns `{}` on fully-excluded pool; GameState flag default + snapshot inclusion + JSON roundtrip + pre-Run-31 save default + `start_run()` reset; constants-sanity invariants. Wired into `run_tests.gd`.
- **Test suite total: 1697 passed, 0 failed** (up from 1657 in Run 30).

**Run 30 (Multi-Step Sponsor Story Arcs):**
- **`src/data/Sponsors.gd`** — Run 29 shipped one 2-step arc (BIG MIKE → BIG MIKE'S RETURN). Run 30 extends the reality-show layer with three more story arcs, including the first 3-step trilogy:
  - **Spectral Cola Trilogy** — `spectral_cola` (existing Rare) → `spectral_cola_zero` (new Rare, requires `spectral_cola`) → `spectral_cola_singularity` (new Legendary, requires `spectral_cola_zero`, `chain_finale: true`). Three-step chain where each subsequent offer's `requires_taken` is the *previous* step (not the OG), so the trilogy unlocks one rung at a time as the player engages with the brand across multiple sponsor pop-ups.
  - **Bopca Insurance saga** — `bopca_insurance` (existing Rare) → `bopca_executive_plan` (new Legendary, requires `bopca_insurance`). The actuaries upgrade you to the platinum package: +50 Max HP / +4 Armor / full heal.
  - **Hyperion Megapack** — `hyperion_drink` (existing Common) → `hyperion_megapack` (new Rare, requires `hyperion_drink`). The first Common→Rare arc, deliberately low-stakes so a fresh-run player has at least one arc they can plausibly complete inside a single descent.
  - New `is_chain_finale(offer) -> bool` static helper — convenience predicate around `offer.get("chain_finale", false)` so the screen + tests don't have to know the dict-key convention.
- **`scenes/SponsorOffer.gd`** — finale-aware card chrome + accept flow:
  - Cards with `chain_finale: true` get a distinct rarity strip: `* LEGENDARY * TRILOGY FINALE`. Takes priority over the Run-29 `▸ … ENCORE` callback prefix so the trilogy capstone reads at a glance against a regular return-sponsor offer.
  - Finale accept path: plays `victory` SFX at -3 dB (slightly louder than the standard Legendary -4 dB), fires the legendary screen flash, and speaks from a dedicated `sponsor_finale` quip pool — *not* the generic Legendary `speak_direct` line — so the trilogy payoff lands narratively. Sits in front of the generic Legendary branch in `_on_card_selected` so finale wins on both flags.
  - Pre-Run-29 fallbacks (return-engagement + base Legendary + standard) are untouched.
- **`autoloads/SystemVoice.gd`** — new `sponsor_finale` quip pool (6 lines). Voice is dryly meta — "The trilogy concludes. The audience weeps." — referencing the multi-offer narrative arc, distinct from the existing `sponsor_return` (callback) and `sponsor_legendary` (slate-entry) lines. Slots between `sponsor_return` and the patch-notes pools so the file's sponsor section stays grouped.
- **`tests/test_run30.gd`** (17 test functions, ~370 assertions): all 4 new ids exist in `POOL`; each new sponsor's `requires_taken` points at the right prereq (Zero→Cola, Singularity→Zero, Executive→Insurance, Megapack→Drink); `chain_finale: true` is set on Singularity ONLY (10 other sponsors verified NOT finales); `is_chain_finale({})` defensive case; multi-step gating via `eligible_pool()` — Singularity hidden with only Cola taken, visible after both Cola+Zero; same gating verified at the `slate()` level across 80 trials (Singularity never appears with only Cola taken) and 200 trials (Singularity appears at least once with both prereqs at high taken_count); all new sponsor effect keys are ones `_apply_effects()` actually handles; end-to-end simulated walk of the Spectral Cola trilogy (step 0 → step 3) verifying eligibility flips at each rung.
- **Test suite total: 1657 passed, 0 failed** (up from 1288 in Run 29).

**Run 29 (Sponsor Variety + Rarity + Story Arcs):**
- **`src/data/Sponsors.gd`** — sponsor pool now follows the same rarity idiom as Loot (Run 24) and Shop (Run 25):
  - New `RARITY_COMMON/RARE/LEGENDARY` constants, `RARITY_COLORS` + `RARITY_LABELS` mirroring LootScreen so the card chrome reads at a glance.
  - Every existing sponsor (10) gained a `rarity` field. Stats-only sponsors stay Common (`hyperion_drink`, `iron_tassel`, `gofundit`, `rays_pizza`); meaningful-tradeoff sponsors are Rare (`big_mikes_meat`, `spectral_cola`, `bopca_insurance`, `quantec_pet`, `rumnoir_rotgut`, `exitpit_adv`).
  - 4 new sponsors: `tiny_carl_plush` (Common, +8 max HP / +40 audience), `godking_industries` (Legendary, +10 ATK / +3 DEF / +20 max HP / full heal), `neo_blood_co` (Legendary, +40 max HP / +5 ATK / -2 SPD), and `big_mikes_return` (Legendary, requires_taken: `big_mikes_meat` — the DCC reality-show callback gag).
  - **`RARITY_WEIGHTS_BY_TAKEN`** — 4-bucket table indexed by how many sponsors the player has accepted so far. Legendary share climbs monotonically (3% → 8% → 17% → 30%) and Common shrinks (70% → 55% → 38% → 22%) as the player's "show arc" deepens, same shape as LootScreen's depth-tiered table. `taken_tier(n)` does the 0 / 1-2 / 3-4 / 5+ bucketing with a negative-input guard.
  - **`slate(rng, taken_count, taken_ids) -> Array[Dictionary]`** — pure helper that mirrors `Shop.slate()`. Each of 3 slots rolls a rarity weighted by `taken_count`, then draws a non-duplicate sponsor of that rarity. Fallback walk goes Legendary → Rare → Common so a thin Common pool can't downgrade a Legendary slot. `eligible_pool(taken_ids)` pre-filters sponsors whose `requires_taken` prereq isn't in the accepted-list, so the "return engagement" story-arc sponsor only surfaces after its setup.
  - Static `sponsors_owed()` and `get_offer()` untouched — Run 20's threshold/cadence math still drives when the pop-up fires; Run 29 only changes what's *in* the pop-up.
- **`scenes/SponsorOffer.gd`** — switched from `pool.duplicate() + shuffle + slice(0,3)` to `Sponsors.slate(rng, taken_count, taken_ids)`. RNG is seeded per pop-up as `run_seed ^ (taken+1)·7919` so consecutive pop-ups within a run roll different slates AND save/resume reproduces the same slate. Card chrome adds:
  - Rarity strip at top (e.g. `LEGENDARY`, `COMMON`); return-engagement sponsors get `▸ LEGENDARY · ENCORE` so the callback is obvious.
  - Border color now driven by rarity (orange Legendary, blue Rare, grey Common) — sponsor brand color still drives the icon + name tint so each card still feels distinct.
  - Legendary cards: 4px border (vs 2px), thicker shadow, infinite shadow-pulse tween, and a soft orange screen flash on screen entry — same idiom as LootScreen / Shop, so a Legendary slate reads instantly.
  - Legendary picks play the `victory` SFX at -4dB + a `sponsor_legendary` quip. Return picks play the regular select SFX + a dedicated `sponsor_return` quip (so the callback gag lands twice — on appearance via the chevron, and on accept via the System).
  - Defensive `picks.is_empty()` fallback path to the legacy shuffle so the screen never blanks if `slate()` ever returns nothing.
  - On accept (`_on_continue`), appends `_chosen` into `GameState.sponsor_offers_taken_ids` (with an empty-id guard) so the next pop-up's `slate()` sees the updated prereq set.
- **`autoloads/GameState.gd`** — new `sponsor_offers_taken_ids: Array[String]` mirrors `sponsor_offers_taken` (the existing counter) but stores per-id history so `Sponsors.slate()` can honor `requires_taken` prereqs. Reset in `start_run()`, snapshotted in `snapshot()`, rehydrated in `apply_snapshot()` with a `[]` default so pre-Run-29 saves still load cleanly (no SAVE_VERSION bump needed — the field is purely additive).
- **`autoloads/SystemVoice.gd`** — two new quip pools:
  - `sponsor_legendary` (6 lines) — fires when a slate enters with a Legendary card present, separate from the generic `sponsor_offer` line so the cadence stays varied.
  - `sponsor_return` (6 lines) — fires when the player accepts a sponsor whose `requires_taken` prereq is in their accepted list (the callback gag).
- **`tests/test_run29.gd`** (19 test functions, ~70 assertions): rarity schema (every sponsor has rarity, values are in the allowed set, at least one of each rarity), Run-29 ids exist (`tiny_carl_plush`, `big_mikes_return`, `godking_industries`, `neo_blood_co`), the BIG MIKE story-arc wiring (`requires_taken == "big_mikes_meat"`), weight-table shape (4 tiers, Legendary climbs + Common shrinks, all tiers have positive total weight), `taken_tier()` bucket boundaries including negative-input safety, slate basics (size, in-slate uniqueness, determinism for same seed, defensive null-rng case), statistical Legendary-share-rises-with-taken-count (200 trials, low vs high), story-arc gating (return sponsor NEVER appears without prereq across 50 trials; return sponsor DOES appear with prereq + high tier across 100 trials), `eligible_pool()` strip/restore behavior, and back-compat with Run 20 helpers (`sponsors_owed`, `get_offer`).

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
- Sponsor rarity tiers + threshold-weighted slate + story-arc returning sponsors — Run 29
- Multi-step sponsor chains: Spectral Cola trilogy (3 steps, with trilogy-finale badge),
  Bopca Executive Plan (2 steps), Hyperion Megapack (2 steps, Common→Rare) — Run 30
- Merchant's Favor: once-per-run surprise Legendary discount (50% off, chance scales
  with audience score, max 40%) — Run 31
- Screenshot-audit tooling (tools/tour_bot.gd) + the fixes it surfaced: shop initial
  card state, dead Combat Instincts upgrade, world-layer centering, framed hero HP
  widget, combat-log seed line, card-button alignment — Run 32
- First Tier 2/3 enemy roster growth: Void Wraith (floor 7+) + Bone Colossus
  (floor 13+) via the new Combatant.tint variant system — Run 32
- Two more tinted enemy variants: Plague Goblin (floor 8+, poison bite) + Ember
  Imp (floor 13+, burning claws) — Run 33
- Boss signature moves: Dungeon Lord rallies a corpse, Warden ground-slams +
  pushes adjacent heroes, Abyss Keeper teleport-pulls a ranged hero — Run 33
- Loot buyback "regret aisle": once-per-run shop strip offering back the best
  loot card the player skipped, priced by rarity — Run 33
- Tier-1 enemy roster growth: Cave Bat (floor 2+, glass-cannon flanker at
  speed 16) + Stone Skeleton (floor 3+, armor-5 wall that punishes Basic
  Attack spam). Both tinted sprite variants — Run 34
- Boss Phase 3 ("Frenzy"): at sub-15% HP each boss signature escalates —
  Dungeon Lord raises every corpse at once, Warden slam grows to range 2 /
  push 3, Abyss Keeper folds every hero in pull range simultaneously.
  Cooldown shortens to 2. New violet glow + banner — Run 34
- Milestone-locked perks: Deep Diver (floor 9), Bossbane (3 lifetime
  bosses), War Veteran + Champion's Bond (any win). New amber "LOCKED
  by milestone" card state on MetaScreen + lifetime boss counter
  tracked across runs — Run 38
- Colorblind-friendly hex highlight palette (cyan MOVE + amber ATTACK
  swap from green + red, distinguishable under deuteranopia and
  protanopia) with a pause-menu toggle that repaints live; 3rd perk
  slot unlocks after the first lifetime win via dynamic
  `Perks.max_equipped(stats)` — `MAX_EQUIPPED` constant preserved at 2
  for back-compat — Run 39

### 🔜 Highest-value, easiest remaining (do next, roughly in order)
1. **Text size slider** — Run 39 added the colorblind hex toggle on a new
   pause-menu row that has space for one more accessibility control. A
   1.0×/1.25×/1.5× text-size cycle (modifying the theme default font
   size) would close the second half of the Run-35 accessibility roadmap
   item.
2. **Status-effect hover tooltips** — Run 35 surfaces every active status
   in a permanent left-edge detail panel and inline durations above the
   sprite. A hover tooltip on enemy sprites would push the same info into
   the enemy HUD without changing the layout.
3. **Alt-color class skins** — purely cosmetic unlocks tied to per-class
   win counts (`MetaProgress.classes_cleared` is the entrypoint). Reuses
   the Run-32 `Combatant.tint` plumbing; no new sprite art needed.
4. **Second milestone-slot bump** — Run 39 capped the post-win loadout at
   3 perks. A `MILESTONE_FOURTH_SLOT_WINS = 3` constant (already wired
   into `Perks.max_equipped` shape) could surface a 4th slot at the
   3-class-clear mark for the "completionist" capstone.

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
  GameState.gd       — run-persistent hero state (+run_score, total_kills, bosses_slain, audience_score, lava_push_kills, sponsor_offers_taken, sponsor_offers_taken_ids, patch_notes_seen)
  SystemVoice.gd     — The System commentary pools + signal (+sponsor_offer, patch_notes_v2, patch_notes_v3 pools as of Run 20)
  AudioManager.gd    — SFX + music player: WAV pool, play(name, pitch_var, vol_db),
                       play_music(name, fade_s), music_for_floor(n), stop_music(fade_s),
                       SFX/music toggles + volume sliders (Run 24)
  Achievements.gd    — Run 19: DCC-style achievement defs + per-run unlock state + signal
  MetaProgress.gd    — Run 36: PERSISTENT shards + owned/equipped perks + lifetime stats (descent_meta.json)

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
                       Run 29: rarity tiers on every sponsor + `slate(rng, taken, taken_ids)`
                       with weighted-by-taken-count rarity + `requires_taken` story-arc gating
                       Run 30: multi-step chains (Spectral Cola trilogy + Bopca Executive +
                       Hyperion Megapack) + `chain_finale: true` flag + `is_chain_finale()`
  PatchNotes.gd      — Run 20: per-tier patch-note payloads (floors 7, 13)
  Shop.gd            — Run 21: merchant inventory + gold-economy helpers (slate/gold_for_*/should_show_shop)
                       Run 25: rarity tiers on every item + per-tier weighted `slate(rng, floor_num)` + `reroll_cost(n)`
                       Run 26: `slate()` accepts optional `locked` arg — locked items carry through reroll
                       Run 31: Merchant's Favor — `favor_chance(audience)` + `roll_merchant_favor(rng, audience)`
                       + `discounted_cost(cost)` + `cheapest_legendary(exclude)` helpers
  Perks.gd           — Run 36: starting-perk DEFS + `apply_to_run(state, equipped)` + `apply_shop_discount`

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
  MetaScreen.tscn/.gd    — Run 36: meta-progression hub reached from TitleScreen → META

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
  test_run29.gd      — Sponsor rarity schema + weighted slate + story-arc prereq gating (Run 29)
  test_run30.gd      — Multi-step chain wiring + finale flag + slate-level gating across trials (Run 30)
  test_run31.gd      — Merchant's Favor: chance scaling + roll determinism + discount math + slate force-Legendary helper + GameState flag persistence (Run 31)
  test_run32.gd      — consume_xp_bonus math, Void Wraith/Bone Colossus schema + gating + tint, melee-golem AI fix + lava-golem turret regression (Run 32)
  test_run33.gd      — Plague Goblin/Ember Imp schema + status application + faction-guard regression, all three boss signatures + cooldown, loot buyback candidate + cost + GameState plumbing (Run 33)
  test_run34.gd      — Cave Bat/Stone Skeleton schema + gating + tints + design locks, Phase 3 trigger + once-only emit, frenzied rally/slam/pull escalation + cooldown shortening (Run 34)
  test_run35.gd      — StatusEffect short_code/display_name/summarize/stack helpers (every known id + defensive cases + duplicate collapse), GameState screen-shake + damage-numbers toggles (defaults / set / toggle / snapshot roundtrip / pre-Run-35 save default / start_run reset), integration label-format assertion (Run 35)
  test_run36.gd      — Perks DEFS schema + apply_to_run per-perk + null/empty/unknown defenses, MetaProgress currency (award/spend/overdraft), perk lifecycle (purchase/equip/unequip/cap/duplicate), shard payout matrix (death/win/repeat/first-class-win), record_run_end stat plumbing, snapshot/apply roundtrip + defensive trim-to-cap + drop-not-owned + drop-not-in-DEFS (Run 36)
  test_run37.gd      — Achievement → meta-shards loop: lifetime ledger defaults + first-time payout + duplicate gate + blank-id defense + multi-id accumulation, snapshot includes + apply roundtrip + pre-Run-37 save default + malformed-entry coercion, reset_all clears ledger, every Achievements.DEFS id pays once (auto-participation lock), achievement payout stacks with record_run_end (Run 37)
  test_run38.gd      — Milestone-gated perks: requirement helpers + is_milestone_unlocked thresholds (met/exceeded/below/ungated/null/unknown) + requirement_text per type, apply_to_run for each Run-38 perk (deep_diver heal-to-max, bossbane atk, steady_step combo, war_veteran level-3 never-downgrades, champions_bond capstone, stack ordering), MetaProgress lifetime_stats + is_perk_milestone_unlocked + purchase refuses-locked + accumulates lifetime_bosses_slain + snapshot pre-Run-38 default, end-to-end 4-step walkthrough (Run 38)
  test_run39.gd      — Perks.max_equipped dynamic cap (0/1/many wins + null/missing/non-Dict defenses) + third_slot_unlocked predicate + MAX_EQUIPPED constant pin; MetaProgress equip_cap helper + 3rd refused pre-win + 3rd ok post-win + 4th still capped; apply_snapshot keeps 3 with win banked, trims to 2 without, Run-38 lifetime_bosses_slain still loads after reorder; record_run_end win flips cap end-to-end; GameState colorblind defaults off / set / toggle / snapshot roundtrip / pre-Run-39 save default (Run 39)

tools/
  tour_bot.gd        — Run 32: screenshot-audit auto-play bot (see Run 32 notes for usage;
                       activate by temporarily adding it as an autoload, never ship enabled)
  gen_*.py           — procedural asset generators (sprites, effects, audio, music)
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
