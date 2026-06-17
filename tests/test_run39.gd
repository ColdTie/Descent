## Run 39 tests: 3rd perk slot unlock + colorblind highlight palette.
##
## Pure logic only — no Node tree, no scene runtime. MetaProgress is
## instantiated via GDScript.new() (matching the Run 36/37/38 pattern)
## so the autoload's `_ready` (load_from_disk) is bypassed and we never
## touch the player's real meta save file.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun39


var PERKS: GDScript = load("res://src/data/Perks.gd")
var META_SCRIPT: GDScript = load("res://autoloads/MetaProgress.gd")
var GAMESTATE_SCRIPT: GDScript = load("res://autoloads/GameState.gd")


func _fresh_meta() -> Node:
	return META_SCRIPT.new()


func _fresh_state() -> Node:
	return GAMESTATE_SCRIPT.new()


# ── Perks.max_equipped helper ───────────────────────────────────────────────

func test_max_equipped_default_is_base_cap() -> void:
	## With zero wins on the books the dynamic cap should match the constant.
	assert_eq(PERKS.max_equipped({"total_wins": 0}), PERKS.MAX_EQUIPPED,
		"zero wins -> base cap")


func test_max_equipped_bumps_after_first_win() -> void:
	assert_eq(PERKS.max_equipped({"total_wins": 1}), PERKS.MAX_EQUIPPED + 1,
		"1 win -> base + 1 slot")
	assert_eq(PERKS.max_equipped({"total_wins": 5}), PERKS.MAX_EQUIPPED + 1,
		"5 wins -> still base + 1 (no further bumps)")


func test_max_equipped_handles_missing_field() -> void:
	## A stats dict without `total_wins` should still return the base cap
	## rather than crashing or somehow opening the bonus slot.
	assert_eq(PERKS.max_equipped({}), PERKS.MAX_EQUIPPED,
		"empty dict -> base cap")


func test_max_equipped_handles_null_stats() -> void:
	## Defensive: a hand-crafted call without lifetime stats must fail closed.
	assert_eq(PERKS.max_equipped(null), PERKS.MAX_EQUIPPED,
		"null stats -> base cap (fail closed)")


func test_max_equipped_handles_non_dict_stats() -> void:
	## Variant-typed param means an `int` or other shape shouldn't crash.
	assert_eq(PERKS.max_equipped(42), PERKS.MAX_EQUIPPED,
		"int stats -> base cap")
	assert_eq(PERKS.max_equipped("oops"), PERKS.MAX_EQUIPPED,
		"string stats -> base cap")


func test_third_slot_predicate_matches_max_equipped() -> void:
	assert_true(not PERKS.third_slot_unlocked({"total_wins": 0}),
		"0 wins -> third slot locked")
	assert_true(PERKS.third_slot_unlocked({"total_wins": 1}),
		"1 win -> third slot unlocked")
	assert_true(PERKS.third_slot_unlocked({"total_wins": 99}),
		"many wins -> third slot stays unlocked")
	assert_true(not PERKS.third_slot_unlocked(null),
		"null stats -> third slot locked (fail closed)")


func test_base_max_equipped_constant_unchanged() -> void:
	## Lock the constant at 2 so existing Run-36/38 tests stay green and a
	## future bump is a deliberate edit here.
	assert_eq(PERKS.MAX_EQUIPPED, 2, "base cap is 2")


func test_bonus_constants_present() -> void:
	## Sanity invariants on the new constants — both > 0 so the bump is
	## meaningful, and the milestone is a single win (not a hard-mode clear,
	## not a class-specific clear).
	assert_gt(int(PERKS.WIN_BONUS_SLOTS), 0, "bonus slots > 0")
	assert_eq(int(PERKS.MILESTONE_THIRD_SLOT_WINS), 1,
		"threshold is one lifetime win")


# ── MetaProgress equip cap integration ───────────────────────────────────────

func test_equip_cap_helper_returns_two_at_start() -> void:
	var m: Node = _fresh_meta()
	assert_eq(m.equip_cap(), PERKS.MAX_EQUIPPED,
		"fresh meta -> base cap")


func test_equip_cap_helper_bumps_after_win() -> void:
	var m: Node = _fresh_meta()
	m.total_wins = 1
	assert_eq(m.equip_cap(), PERKS.MAX_EQUIPPED + 1,
		"1 win -> cap = base + 1")


func test_equip_refuses_third_perk_before_first_win() -> void:
	## End-to-end regression of the Run-36 cap behavior — fresh meta still
	## caps at 2 even with the new dynamic helper.
	var m: Node = _fresh_meta()
	m.shards = 1000
	m.purchase_perk("wealthy")
	m.purchase_perk("seasoned")
	m.purchase_perk("iron_blood")
	assert_true(m.equip_perk("wealthy"), "1st equip ok")
	assert_true(m.equip_perk("seasoned"), "2nd equip ok")
	assert_true(not m.equip_perk("iron_blood"),
		"3rd refused — no win banked yet")
	assert_eq(m.equipped_perks.size(), 2, "loadout still at base cap")


func test_equip_allows_third_perk_after_first_win() -> void:
	var m: Node = _fresh_meta()
	m.shards = 1000
	m.purchase_perk("wealthy")
	m.purchase_perk("seasoned")
	m.purchase_perk("iron_blood")
	m.equip_perk("wealthy")
	m.equip_perk("seasoned")
	# Bank the win — pure field mutation so we don't need to seed the rest
	# of record_run_end's plumbing.
	m.total_wins = 1
	assert_true(m.equip_perk("iron_blood"),
		"3rd equip ok after win")
	assert_eq(m.equipped_perks.size(), 3, "loadout at bumped cap")


func test_equip_refuses_fourth_perk_even_after_win() -> void:
	## The post-win cap is 3, not unbounded — bank an unrelated upgrade
	## and confirm the 4th equip still refuses.
	var m: Node = _fresh_meta()
	m.shards = 2000
	m.total_wins = 1
	for pid: String in ["wealthy", "seasoned", "iron_blood", "lucky_strike"]:
		m.purchase_perk(pid)
	m.equip_perk("wealthy")
	m.equip_perk("seasoned")
	m.equip_perk("iron_blood")
	assert_true(not m.equip_perk("lucky_strike"),
		"4th refused — bumped cap is 3, not unlimited")
	assert_eq(m.equipped_perks.size(), 3, "loadout at bumped cap")


# ── apply_snapshot dynamic cap ───────────────────────────────────────────────

func test_apply_snapshot_preserves_three_equipped_with_win_banked() -> void:
	## A save written after the player banked a win + equipped 3 perks must
	## round-trip all three. Pre-Run-39 the cap was hardcoded at 2, so this
	## case used to silently trim — the test catches a regression where
	## someone reads the cap before total_wins.
	var m: Node = _fresh_meta()
	var fake: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": ["wealthy", "seasoned", "iron_blood"],
		"equipped_perks": ["wealthy", "seasoned", "iron_blood"],
		"total_runs": 1,
		"total_wins": 1,
		"best_floor": 18,
		"best_score": 5000,
		"classes_cleared": {"brawler": true},
	}
	assert_true(m.apply_snapshot(fake), "apply ok")
	assert_eq(m.equipped_perks.size(), 3,
		"all 3 perks restored when win is on the books")


func test_apply_snapshot_trims_to_base_cap_without_win() -> void:
	## A save with 3 equipped + no win banked must trim back to the base
	## cap. Pre-Run-39 the cap was static 2 — this still holds.
	var m: Node = _fresh_meta()
	var fake: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": ["wealthy", "seasoned", "iron_blood"],
		"equipped_perks": ["wealthy", "seasoned", "iron_blood"],
		"total_runs": 0,
		"total_wins": 0,
		"best_floor": 0,
		"best_score": 0,
		"classes_cleared": {},
	}
	assert_true(m.apply_snapshot(fake), "apply ok")
	assert_eq(m.equipped_perks.size(), 2,
		"trimmed to base cap when no win on the books")


func test_apply_snapshot_lifetime_bosses_still_loads() -> void:
	## Regression: the Run 38 lifetime_bosses_slain field is now loaded
	## earlier in apply_snapshot (alongside total_wins) for Run 39. Make
	## sure the value still threads through correctly.
	var m: Node = _fresh_meta()
	var snap: Dictionary = {
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
	}
	assert_true(m.apply_snapshot(snap), "apply ok")
	assert_eq(m.lifetime_bosses_slain, 4,
		"Run-38 field still loads after Run-39 reorder")


# ── End-to-end progression walkthrough ──────────────────────────────────────

func test_record_run_end_win_unlocks_third_slot() -> void:
	## Banking the first win via record_run_end must immediately flip the
	## equip cap. Mirrors the path the live game takes on a win.
	var m: Node = _fresh_meta()
	assert_eq(m.equip_cap(), PERKS.MAX_EQUIPPED, "cap = 2 pre-win")
	m.record_run_end(18, 3, true, 5000, "arcanist")
	assert_eq(m.equip_cap(), PERKS.MAX_EQUIPPED + 1, "cap = 3 post-win")
	assert_true(PERKS.third_slot_unlocked(m.lifetime_stats()),
		"third_slot_unlocked predicate flips on the same win")


# ── GameState colorblind toggle ─────────────────────────────────────────────

func test_colorblind_default_is_off() -> void:
	## Shipping behavior — the highlight palette stays green/red unless the
	## player flips the pause-menu toggle.
	var s: Node = _fresh_state()
	assert_true(not s.colorblind_mode_enabled,
		"default off (shipping highlight palette)")


func test_set_colorblind_mode_writes_field() -> void:
	var s: Node = _fresh_state()
	s.set_colorblind_mode(true)
	assert_true(s.colorblind_mode_enabled, "set true sticks")
	s.set_colorblind_mode(false)
	assert_true(not s.colorblind_mode_enabled, "set false sticks")


func test_toggle_colorblind_mode_returns_new_state() -> void:
	## The pause-menu button consumes the return value to relabel itself —
	## lock the contract here so a future refactor doesn't strip it.
	var s: Node = _fresh_state()
	assert_true(s.toggle_colorblind_mode(),
		"first toggle returns true (now on)")
	assert_true(s.colorblind_mode_enabled, "field reflects return")
	assert_true(not s.toggle_colorblind_mode(),
		"second toggle returns false (now off)")
	assert_true(not s.colorblind_mode_enabled, "field reflects return")


func test_snapshot_includes_colorblind_mode() -> void:
	var s: Node = _fresh_state()
	s.hero_class = "brawler"
	s.colorblind_mode_enabled = true
	var snap: Dictionary = s.snapshot()
	assert_true(snap.has("colorblind_mode_enabled"),
		"snapshot carries the field")
	assert_true(bool(snap.get("colorblind_mode_enabled", false)),
		"value is the live one (true)")


func test_apply_snapshot_roundtrips_colorblind_mode() -> void:
	var s: Node = _fresh_state()
	s.hero_class = "rogue"
	s.colorblind_mode_enabled = true
	var snap: Dictionary = s.snapshot()
	var s2: Node = _fresh_state()
	assert_true(s2.apply_snapshot(snap), "apply ok")
	assert_true(s2.colorblind_mode_enabled, "roundtrip preserves true")


func test_apply_snapshot_pre_run39_save_defaults_off() -> void:
	## A save written before Run 39 won't carry the new field. The apply
	## path should default it to false (shipping behavior) rather than
	## leaving a stale instance value or crashing.
	var s: Node = _fresh_state()
	s.colorblind_mode_enabled = true  # stale instance value
	var pre_39_save: Dictionary = {
		"version": GAMESTATE_SCRIPT.SAVE_VERSION,
		"hero_class": "brawler",
		"floor_num": 4,
		"hero_hp": 90,
		"hero_max_hp": 100,
		# no colorblind_mode_enabled key on purpose
	}
	assert_true(s.apply_snapshot(pre_39_save),
		"legacy save loads cleanly")
	assert_true(not s.colorblind_mode_enabled,
		"missing key defaults to false (not stale true)")


# Note: the colorblind palette CONSTANTS live in scenes/BattleScene.gd, which
# references the GameState autoload — that file won't compile under `--script`
# test mode. The toggle BEHAVIOR (default off / set / toggle / snapshot
# roundtrip / pre-Run-39 default) is fully covered above; the palette
# definition itself is reviewed via the runtime + screenshot audit pattern
# used by every prior visual change (see Run 32 tour_bot, Run 37 r37 tour).
