## Run 43 tests: 4th perk slot unlock at the 3-class-clear milestone.
##
## Builds on Run 39 (dynamic equip cap via `Perks.max_equipped(stats)`) and
## Run 42 (`MetaProgress.class_wins` per-class win counter). The new milestone
## reads `classes_won` from the lifetime-stats dict — MetaProgress derives it
## from `class_wins.size()`, so the count is distinct classes that have ever
## banked a win (NOT total wins racked up on the same class).
##
## Pure logic only — no Node tree, no scene runtime. MetaProgress is
## instantiated via GDScript.new() (matching the Run 36/37/38/39/40/41/42
## pattern) so the autoload's `_ready` (load_from_disk) is bypassed and we
## never touch the player's real meta save file.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun43


var PERKS: GDScript = load("res://src/data/Perks.gd")
var META_SCRIPT: GDScript = load("res://autoloads/MetaProgress.gd")


func _fresh_meta() -> Node:
	return META_SCRIPT.new()


# ── Perks constants ─────────────────────────────────────────────────────────

func test_fourth_slot_bonus_constants_present() -> void:
	## Lock the new constants — both > 0 (the bump is meaningful) and the
	## threshold is exactly 3 (one win per class).
	assert_gt(int(PERKS.FOURTH_SLOT_BONUS_SLOTS), 0,
		"4th-slot bonus > 0")
	assert_eq(int(PERKS.MILESTONE_FOURTH_SLOT_CLASSES_WON), 3,
		"threshold = clear all three classes")


func test_run39_constants_still_pinned() -> void:
	## Regression: the 3rd-slot constants from Run 39 must stay untouched —
	## adding the 4th-slot milestone is purely additive.
	assert_eq(int(PERKS.MAX_EQUIPPED), 2, "base cap still 2")
	assert_eq(int(PERKS.WIN_BONUS_SLOTS), 1, "3rd-slot bonus still 1")
	assert_eq(int(PERKS.MILESTONE_THIRD_SLOT_WINS), 1,
		"3rd-slot threshold still 1 win")


# ── Perks.max_equipped — composable milestone bumps ────────────────────────

func test_max_equipped_base_with_no_milestones() -> void:
	## Fresh player (0 wins, 0 classes_won) gets the base cap.
	assert_eq(PERKS.max_equipped({"total_wins": 0, "classes_won": 0}),
		PERKS.MAX_EQUIPPED, "no milestones → base cap")


func test_max_equipped_third_slot_only() -> void:
	## One win on a single class → 3rd slot unlocked, 4th slot still locked.
	assert_eq(PERKS.max_equipped({"total_wins": 1, "classes_won": 1}),
		PERKS.MAX_EQUIPPED + PERKS.WIN_BONUS_SLOTS,
		"1 win + 1 class → +1 slot (3rd only)")
	assert_eq(PERKS.max_equipped({"total_wins": 2, "classes_won": 2}),
		PERKS.MAX_EQUIPPED + PERKS.WIN_BONUS_SLOTS,
		"2 wins + 2 classes → still 3 slots (4th milestone not yet met)")


func test_max_equipped_fourth_slot_unlocks() -> void:
	## All three classes cleared → both milestones lit, cap = base + both bonuses.
	var cap: int = PERKS.max_equipped({"total_wins": 3, "classes_won": 3})
	assert_eq(cap, PERKS.MAX_EQUIPPED + PERKS.WIN_BONUS_SLOTS + PERKS.FOURTH_SLOT_BONUS_SLOTS,
		"3 wins + 3 classes → base + both bonuses (today: 4)")


func test_max_equipped_no_further_bumps_above_threshold() -> void:
	## Stats past the threshold should NOT keep growing the cap — the milestone
	## is a one-time unlock, not a per-class accumulator.
	assert_eq(PERKS.max_equipped({"total_wins": 99, "classes_won": 99}),
		PERKS.MAX_EQUIPPED + PERKS.WIN_BONUS_SLOTS + PERKS.FOURTH_SLOT_BONUS_SLOTS,
		"huge counts → still capped at base + both bonuses")


func test_max_equipped_milestones_are_independent() -> void:
	## The 4th-slot bonus is gated on classes_won independently of total_wins.
	## A pathological save with 0 wins but 3 classes_won (shouldn't naturally
	## happen, but the math should be composable) still grants the 4th-slot
	## bonus. The 3rd-slot bonus stays gated on total_wins, so this case lands
	## at base + FOURTH_SLOT_BONUS_SLOTS only.
	assert_eq(PERKS.max_equipped({"total_wins": 0, "classes_won": 3}),
		PERKS.MAX_EQUIPPED + PERKS.FOURTH_SLOT_BONUS_SLOTS,
		"0 wins + 3 classes_won → base + 4th-slot bonus only")


func test_max_equipped_handles_missing_classes_won() -> void:
	## A pre-Run-43 stats dict (no classes_won key) must keep the 3rd-slot
	## behavior intact — Run 39 callers shouldn't accidentally lose their
	## 3rd-slot bonus just because a future field went missing.
	assert_eq(PERKS.max_equipped({"total_wins": 1}),
		PERKS.MAX_EQUIPPED + PERKS.WIN_BONUS_SLOTS,
		"missing classes_won → 3rd slot still active, 4th locked")


func test_max_equipped_handles_null_and_non_dict() -> void:
	## Defensive: null / non-Dictionary input still falls through to the base
	## cap (fail closed — same Run-39 contract).
	assert_eq(PERKS.max_equipped(null), PERKS.MAX_EQUIPPED,
		"null stats → base cap")
	assert_eq(PERKS.max_equipped(42), PERKS.MAX_EQUIPPED,
		"int stats → base cap")
	assert_eq(PERKS.max_equipped("oops"), PERKS.MAX_EQUIPPED,
		"string stats → base cap")
	assert_eq(PERKS.max_equipped([]), PERKS.MAX_EQUIPPED,
		"array stats → base cap")


# ── fourth_slot_unlocked predicate ─────────────────────────────────────────

func test_fourth_slot_predicate_matches_max_equipped() -> void:
	assert_true(not PERKS.fourth_slot_unlocked({"total_wins": 0, "classes_won": 0}),
		"no milestones → 4th slot locked")
	assert_true(not PERKS.fourth_slot_unlocked({"total_wins": 1, "classes_won": 1}),
		"3rd slot only → 4th slot still locked")
	assert_true(not PERKS.fourth_slot_unlocked({"total_wins": 2, "classes_won": 2}),
		"2 of 3 classes → 4th slot still locked (just short)")
	assert_true(PERKS.fourth_slot_unlocked({"total_wins": 3, "classes_won": 3}),
		"3 of 3 classes → 4th slot unlocked")
	assert_true(PERKS.fourth_slot_unlocked({"total_wins": 99, "classes_won": 9}),
		"completionist → 4th slot stays unlocked")
	assert_true(not PERKS.fourth_slot_unlocked(null),
		"null stats → 4th slot locked (fail closed)")


func test_third_slot_predicate_still_works() -> void:
	## Run 39 contract — adding the 4th-slot helper must NOT change the
	## 3rd-slot predicate.
	assert_true(not PERKS.third_slot_unlocked({"total_wins": 0, "classes_won": 0}),
		"no wins → 3rd slot locked (Run 39 contract)")
	assert_true(PERKS.third_slot_unlocked({"total_wins": 1, "classes_won": 1}),
		"1 win → 3rd slot unlocked (Run 39 contract)")
	assert_true(PERKS.third_slot_unlocked({"total_wins": 3, "classes_won": 3}),
		"all-clear also passes 3rd-slot predicate")


# ── MetaProgress lifetime_stats wiring ─────────────────────────────────────

func test_lifetime_stats_includes_classes_won() -> void:
	## The 4th-slot gate reads `classes_won`; MetaProgress must surface it.
	var m: Node = _fresh_meta()
	var stats: Dictionary = m.lifetime_stats()
	assert_true(stats.has("classes_won"),
		"lifetime_stats carries classes_won")
	assert_eq(int(stats["classes_won"]), 0,
		"fresh meta → 0 classes won")


func test_lifetime_stats_classes_won_tracks_class_wins_size() -> void:
	## `classes_won` = number of distinct classes that have ever banked a win
	## (a player who wins 5 times with Brawler counts as 1 class_won, not 5).
	var m: Node = _fresh_meta()
	m.class_wins = {"brawler": 5}
	assert_eq(int(m.lifetime_stats()["classes_won"]), 1,
		"5 brawler wins → classes_won = 1")
	m.class_wins["rogue"] = 1
	assert_eq(int(m.lifetime_stats()["classes_won"]), 2,
		"+ 1 rogue win → classes_won = 2")
	m.class_wins["arcanist"] = 2
	assert_eq(int(m.lifetime_stats()["classes_won"]), 3,
		"all three classes → classes_won = 3")


func test_lifetime_stats_preserves_run38_run39_fields() -> void:
	## Regression: adding `classes_won` must not displace any existing field.
	var m: Node = _fresh_meta()
	m.best_floor = 12
	m.total_wins = 4
	m.lifetime_bosses_slain = 7
	var stats: Dictionary = m.lifetime_stats()
	assert_eq(int(stats["best_floor"]), 12, "best_floor still present")
	assert_eq(int(stats["total_wins"]), 4, "total_wins still present")
	assert_eq(int(stats["bosses_slain"]), 7,
		"bosses_slain still present (Run 38 contract)")


# ── MetaProgress equip cap integration ─────────────────────────────────────

func test_equip_cap_unlocks_fourth_slot_with_three_class_wins() -> void:
	## End-to-end: seed the per-class counter past the threshold and confirm
	## the live equip_cap reflects the 4th-slot bonus.
	var m: Node = _fresh_meta()
	m.total_wins = 3
	m.class_wins = {"brawler": 1, "rogue": 1, "arcanist": 1}
	assert_eq(m.equip_cap(),
		PERKS.MAX_EQUIPPED + PERKS.WIN_BONUS_SLOTS + PERKS.FOURTH_SLOT_BONUS_SLOTS,
		"all three classes cleared → 4-slot cap")


func test_equip_allows_fourth_perk_after_three_class_clear() -> void:
	var m: Node = _fresh_meta()
	m.shards = 2000
	m.total_wins = 3
	m.class_wins = {"brawler": 1, "rogue": 1, "arcanist": 1}
	for pid: String in ["wealthy", "seasoned", "iron_blood", "lucky_strike"]:
		m.purchase_perk(pid)
	assert_true(m.equip_perk("wealthy"), "1st equip ok")
	assert_true(m.equip_perk("seasoned"), "2nd equip ok")
	assert_true(m.equip_perk("iron_blood"), "3rd equip ok (post-win)")
	assert_true(m.equip_perk("lucky_strike"),
		"4th equip ok (post all-class-clear)")
	assert_eq(m.equipped_perks.size(), 4, "loadout at 4-slot cap")


func test_equip_refuses_fifth_perk_even_after_all_class_clear() -> void:
	## The 4-slot cap is hard — completing all classes doesn't grant infinite
	## slots. Defends against a future "stacking" regression where the
	## bonuses double-apply.
	var m: Node = _fresh_meta()
	m.shards = 2000
	m.total_wins = 3
	m.class_wins = {"brawler": 1, "rogue": 1, "arcanist": 1}
	for pid: String in ["wealthy", "seasoned", "iron_blood", "lucky_strike", "swift_boots"]:
		m.purchase_perk(pid)
	m.equip_perk("wealthy")
	m.equip_perk("seasoned")
	m.equip_perk("iron_blood")
	m.equip_perk("lucky_strike")
	assert_true(not m.equip_perk("swift_boots"),
		"5th equip refused — cap is 4, not unlimited")
	assert_eq(m.equipped_perks.size(), 4, "loadout still at 4-slot cap")


func test_equip_refuses_fourth_perk_before_all_class_clear() -> void:
	## Two of three classes cleared → 4th-slot milestone unmet, cap is still
	## 3 (the Run-39 cap), so the 4th equip refuses.
	var m: Node = _fresh_meta()
	m.shards = 2000
	m.total_wins = 5  # plenty of wins, but only 2 classes
	m.class_wins = {"brawler": 4, "rogue": 1}
	for pid: String in ["wealthy", "seasoned", "iron_blood", "lucky_strike"]:
		m.purchase_perk(pid)
	m.equip_perk("wealthy")
	m.equip_perk("seasoned")
	m.equip_perk("iron_blood")
	assert_true(not m.equip_perk("lucky_strike"),
		"4th equip refused — only 2 of 3 classes cleared")
	assert_eq(m.equipped_perks.size(), 3, "loadout still at 3-slot cap")


# ── End-to-end record_run_end progression ──────────────────────────────────

func test_record_run_end_three_class_clear_flips_fourth_slot() -> void:
	## Mirror the live path the game takes: three wins, each on a different
	## class, must end with the 4th slot unlocked.
	var m: Node = _fresh_meta()
	assert_eq(m.equip_cap(), PERKS.MAX_EQUIPPED, "cap = 2 pre-any-win")
	m.record_run_end(18, 3, true, 5000, "brawler")
	assert_eq(m.equip_cap(), PERKS.MAX_EQUIPPED + PERKS.WIN_BONUS_SLOTS,
		"cap = 3 after first win (Run 39 milestone)")
	assert_true(not PERKS.fourth_slot_unlocked(m.lifetime_stats()),
		"4th slot still locked after 1 class cleared")
	m.record_run_end(18, 3, true, 5000, "rogue")
	assert_true(not PERKS.fourth_slot_unlocked(m.lifetime_stats()),
		"4th slot still locked after 2 classes cleared")
	m.record_run_end(18, 3, true, 5000, "arcanist")
	assert_eq(m.equip_cap(),
		PERKS.MAX_EQUIPPED + PERKS.WIN_BONUS_SLOTS + PERKS.FOURTH_SLOT_BONUS_SLOTS,
		"cap = 4 after all three classes cleared")
	assert_true(PERKS.fourth_slot_unlocked(m.lifetime_stats()),
		"fourth_slot_unlocked predicate flips on the 3rd-class win")


func test_record_run_end_same_class_repeats_dont_advance_fourth_slot() -> void:
	## Defense against the wrong-counter regression: total_wins racking up
	## must NOT trigger the 4th-slot milestone — only distinct classes_won
	## counts.
	var m: Node = _fresh_meta()
	for _i: int in range(5):
		m.record_run_end(18, 3, true, 5000, "brawler")
	assert_eq(m.total_wins, 5, "5 wins banked")
	assert_eq(m.class_wins.size(), 1, "still only 1 distinct class won")
	assert_true(not PERKS.fourth_slot_unlocked(m.lifetime_stats()),
		"4th slot stays locked — total_wins isn't the gate, classes_won is")
	assert_eq(m.equip_cap(),
		PERKS.MAX_EQUIPPED + PERKS.WIN_BONUS_SLOTS,
		"cap still at 3 after 5 brawler wins")


# ── apply_snapshot ordering ────────────────────────────────────────────────

func test_apply_snapshot_preserves_four_equipped_with_all_class_clear() -> void:
	## Critical reorder regression: a save with 4 equipped perks + an
	## all-class clear must restore all 4. Pre-Run-43 the equip cap was
	## computed BEFORE class_wins loaded, so this case would have silently
	## trimmed back to 3 (the wins-only cap).
	var m: Node = _fresh_meta()
	var fake: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": ["wealthy", "seasoned", "iron_blood", "lucky_strike"],
		"equipped_perks": ["wealthy", "seasoned", "iron_blood", "lucky_strike"],
		"total_runs": 3,
		"total_wins": 3,
		"best_floor": 18,
		"best_score": 5000,
		"classes_cleared": {"brawler": true, "rogue": true, "arcanist": true},
		"class_wins": {"brawler": 1, "rogue": 1, "arcanist": 1},
	}
	assert_true(m.apply_snapshot(fake), "apply ok")
	assert_eq(m.equipped_perks.size(), 4,
		"all 4 perks restored — class_wins loaded before the cap trim")
	assert_eq(m.class_wins.size(), 3,
		"class_wins still loaded after the early-load reorder")


func test_apply_snapshot_trims_to_three_with_only_one_class_clear() -> void:
	## Sanity: a save with 4 equipped + a single-class win banked must trim
	## back to the 3-slot cap (the Run-39 behavior is unchanged).
	var m: Node = _fresh_meta()
	var fake: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": ["wealthy", "seasoned", "iron_blood", "lucky_strike"],
		"equipped_perks": ["wealthy", "seasoned", "iron_blood", "lucky_strike"],
		"total_runs": 1,
		"total_wins": 1,
		"best_floor": 18,
		"best_score": 5000,
		"classes_cleared": {"brawler": true},
		"class_wins": {"brawler": 1},
	}
	assert_true(m.apply_snapshot(fake), "apply ok")
	assert_eq(m.equipped_perks.size(), 3,
		"trimmed to 3-slot cap — only one class cleared")


func test_apply_snapshot_lifetime_bosses_still_loads() -> void:
	## Regression: the Run 39 reorder of `lifetime_bosses_slain` must not
	## get clobbered by the Run 43 reorder of `class_wins`. Both fields are
	## loaded BEFORE the equipped_perks trim.
	var m: Node = _fresh_meta()
	var fake: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": [],
		"equipped_perks": [],
		"total_runs": 1,
		"total_wins": 0,
		"best_floor": 5,
		"best_score": 0,
		"classes_cleared": {},
		"lifetime_bosses_slain": 4,
		"class_wins": {"brawler": 0},
	}
	assert_true(m.apply_snapshot(fake), "apply ok")
	assert_eq(m.lifetime_bosses_slain, 4,
		"Run-38 field still loads after Run-43 reorder")


func test_apply_snapshot_class_wins_still_loads() -> void:
	## Regression: moving the class_wins load up shouldn't clobber the
	## post-equipped-trim Run-42 contract (the field still ends up populated
	## with the same values).
	var m: Node = _fresh_meta()
	var fake: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": [],
		"equipped_perks": [],
		"total_runs": 2,
		"total_wins": 2,
		"best_floor": 12,
		"best_score": 0,
		"classes_cleared": {"brawler": true, "rogue": true},
		"class_wins": {"brawler": 2, "rogue": 1},
	}
	assert_true(m.apply_snapshot(fake), "apply ok")
	assert_eq(int(m.class_wins.get("brawler", 0)), 2,
		"brawler win count loads")
	assert_eq(int(m.class_wins.get("rogue", 0)), 1,
		"rogue win count loads")
	assert_eq(m.class_wins.size(), 2, "no spurious entries")


func test_apply_snapshot_pre_run42_save_keeps_fourth_slot_locked() -> void:
	## A pre-Run-42 save has no `class_wins` field at all. The fallthrough
	## must yield an empty dict → classes_won = 0 → 4th slot stays locked.
	var m: Node = _fresh_meta()
	var pre_42_save: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 100,
		"owned_perks": [],
		"equipped_perks": [],
		"total_runs": 5,
		"total_wins": 5,
		"best_floor": 18,
		"best_score": 8000,
		"classes_cleared": {"brawler": true},
		# no class_wins key — legacy
	}
	assert_true(m.apply_snapshot(pre_42_save),
		"legacy save loads cleanly")
	assert_eq(m.class_wins.size(), 0,
		"missing class_wins → empty dict")
	assert_true(not PERKS.fourth_slot_unlocked(m.lifetime_stats()),
		"4th slot locked — classes_won = 0 from empty class_wins")
	# But the 3rd slot is still unlocked (5 wins banked, Run-39 milestone).
	assert_true(PERKS.third_slot_unlocked(m.lifetime_stats()),
		"3rd slot still unlocked — Run-39 path independent of class_wins")


func test_apply_snapshot_negative_class_wins_still_clamped() -> void:
	## Run 42 contract: hand-edited negative class_wins coerce to 0. The
	## Run-43 reorder uses a duplicated coercion block (the original block
	## further down is now a no-op), so verify the clamp still works.
	var m: Node = _fresh_meta()
	var fake: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": [],
		"equipped_perks": [],
		"total_runs": 0,
		"total_wins": 0,
		"best_floor": 0,
		"best_score": 0,
		"classes_cleared": {},
		"class_wins": {"brawler": -5, "rogue": 1},
	}
	assert_true(m.apply_snapshot(fake), "apply ok")
	assert_eq(int(m.class_wins.get("brawler", 0)), 0,
		"negative count clamped to 0")
	assert_eq(int(m.class_wins.get("rogue", 0)), 1,
		"valid count preserved")


# ── End-to-end "actual win for Run 43" ─────────────────────────────────────

func test_full_walkthrough_three_class_clear_to_fourth_slot() -> void:
	## The closed loop the player walks: starts at 2 slots → wins as Brawler
	## (3 slots) → wins as Rogue (still 3) → wins as Arcanist (4 slots) →
	## buys + equips a 4th perk that was previously refused.
	var m: Node = _fresh_meta()
	m.shards = 2000
	for pid: String in ["wealthy", "seasoned", "iron_blood", "lucky_strike"]:
		m.purchase_perk(pid)
	m.equip_perk("wealthy")
	m.equip_perk("seasoned")
	assert_true(not m.equip_perk("iron_blood"),
		"3rd equip refused — no wins banked yet")
	# First win (Brawler) — unlocks the 3rd slot.
	m.record_run_end(18, 3, true, 5000, "brawler")
	assert_true(m.equip_perk("iron_blood"), "3rd equip ok after first win")
	assert_true(not m.equip_perk("lucky_strike"),
		"4th still refused — only 1 class cleared")
	# Second win (same class doesn't help) → bumps class_wins[brawler] to 2.
	m.record_run_end(18, 3, true, 5000, "brawler")
	assert_true(not m.equip_perk("lucky_strike"),
		"4th still refused — same-class repeats don't count")
	# Win as Rogue — distinct class, but only 2 of 3.
	m.record_run_end(18, 3, true, 5000, "rogue")
	assert_true(not m.equip_perk("lucky_strike"),
		"4th still refused — 2 of 3 classes")
	# Win as Arcanist — completes the all-class milestone.
	m.record_run_end(18, 3, true, 5000, "arcanist")
	assert_true(m.equip_perk("lucky_strike"),
		"4th equip ok — all three classes cleared")
	assert_eq(m.equipped_perks.size(), 4, "final loadout at 4-slot cap")
