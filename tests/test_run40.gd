## Run 40 tests: text-size accessibility cycle (pause-menu toggle).
##
## Pure logic only — GameState is instantiated via GDScript.new() so the
## autoload's tree-attached state (and `get_window()`) isn't exercised.
## `apply_text_size_to_window()` is guarded with `is_inside_tree()`, so a
## detached instance treats the apply path as a no-op — the cycle field
## bookkeeping is what we lock in here. The runtime apply (window scale)
## is covered by the visual / runtime smoke pattern used in Run 39 for
## the colorblind palette constants in BattleScene.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun40


var GAMESTATE_SCRIPT: GDScript = load("res://autoloads/GameState.gd")


func _fresh_state() -> Node:
	return GAMESTATE_SCRIPT.new()


# ── Defaults + constants ────────────────────────────────────────────────────

func test_text_size_default_is_one() -> void:
	## Shipping behavior — fresh state runs at 1.0× (no scaling).
	var s: Node = _fresh_state()
	assert_eq(s.text_size_scale, 1.0,
		"default scale is 1.0")


func test_text_size_options_include_default() -> void:
	## The cycle wraps through TEXT_SIZE_OPTIONS; the default MUST be a
	## member so the cycle can find the current index and advance.
	assert_true(GAMESTATE_SCRIPT.TEXT_SIZE_OPTIONS.has(GAMESTATE_SCRIPT.TEXT_SIZE_DEFAULT),
		"default sits inside the option list")


func test_text_size_options_monotonic() -> void:
	## Lock the order so a future refactor can't accidentally rearrange the
	## cycle into something like [1.5, 1.0, 1.25] (which would feel wrong on
	## the first click).
	var opts: Array = GAMESTATE_SCRIPT.TEXT_SIZE_OPTIONS
	assert_true(opts.size() >= 3, "at least three steps in the cycle")
	for i: int in range(1, opts.size()):
		assert_true(float(opts[i]) > float(opts[i - 1]),
			"options strictly increase: %s > %s" % [str(opts[i]), str(opts[i - 1])])


func test_text_size_options_first_is_one() -> void:
	## 1.0× must be the entry point so a player who's never touched the cycle
	## sees shipping behavior.
	assert_eq(float(GAMESTATE_SCRIPT.TEXT_SIZE_OPTIONS[0]), 1.0,
		"first option is 1.0 (shipping)")


# ── set_text_size_scale snap + apply contract ──────────────────────────────

func test_set_text_size_scale_writes_exact_match() -> void:
	var s: Node = _fresh_state()
	s.set_text_size_scale(1.25)
	assert_eq(s.text_size_scale, 1.25,
		"exact option value sticks")


func test_set_text_size_scale_snaps_to_nearest_option() -> void:
	## A hand-crafted call (or a corrupted save) with a not-quite-allowed
	## value should collapse to the nearest known option — otherwise the
	## pause cycle can't find the current index on the next click.
	var s: Node = _fresh_state()
	s.set_text_size_scale(1.27)
	assert_eq(s.text_size_scale, 1.25,
		"1.27 snaps to 1.25")
	s.set_text_size_scale(1.44)
	assert_eq(s.text_size_scale, 1.5,
		"1.44 snaps to 1.5")
	s.set_text_size_scale(0.4)
	assert_eq(s.text_size_scale, 1.0,
		"out-of-range low snaps to 1.0")
	s.set_text_size_scale(99.0)
	assert_eq(s.text_size_scale, 1.5,
		"out-of-range high snaps to top option")


# ── cycle_text_size_scale wrap behavior ────────────────────────────────────

func test_cycle_text_size_advances_one_step() -> void:
	var s: Node = _fresh_state()
	assert_eq(s.cycle_text_size_scale(), 1.25,
		"first cycle moves to 1.25")
	assert_eq(s.text_size_scale, 1.25,
		"field reflects return value")


func test_cycle_text_size_walks_full_loop() -> void:
	## Three steps then wrap to 1.0 — locks the full cycle so a future
	## options-array extension is a deliberate edit here.
	var s: Node = _fresh_state()
	assert_eq(s.cycle_text_size_scale(), 1.25, "step 1")
	assert_eq(s.cycle_text_size_scale(), 1.5, "step 2")
	assert_eq(s.cycle_text_size_scale(), 1.0, "wrap back to 1.0")
	assert_eq(s.cycle_text_size_scale(), 1.25, "and on around again")


func test_cycle_text_size_recovers_from_off_list_value() -> void:
	## If text_size_scale somehow holds a non-option value (a corrupted save
	## that snuck past snap, a hand-set), the cycle should land on a known
	## option rather than getting stuck or returning the off-list value.
	var s: Node = _fresh_state()
	s.text_size_scale = 2.3  # not in TEXT_SIZE_OPTIONS
	var next_v: float = s.cycle_text_size_scale()
	assert_true(GAMESTATE_SCRIPT.TEXT_SIZE_OPTIONS.has(next_v),
		"cycle from off-list lands on a known option")


# ── Snapshot / apply persistence ───────────────────────────────────────────

func test_snapshot_includes_text_size_scale() -> void:
	var s: Node = _fresh_state()
	s.hero_class = "brawler"
	s.text_size_scale = 1.5
	var snap: Dictionary = s.snapshot()
	assert_true(snap.has("text_size_scale"),
		"snapshot carries the field")
	assert_eq(float(snap.get("text_size_scale", 0.0)), 1.5,
		"value matches live state")


func test_apply_snapshot_roundtrips_text_size_scale() -> void:
	var s: Node = _fresh_state()
	s.hero_class = "rogue"
	s.text_size_scale = 1.25
	var snap: Dictionary = s.snapshot()
	var s2: Node = _fresh_state()
	assert_true(s2.apply_snapshot(snap), "apply ok")
	assert_eq(s2.text_size_scale, 1.25,
		"roundtrip preserves 1.25")


func test_apply_snapshot_pre_run40_save_defaults_to_one() -> void:
	## A save written before Run 40 won't carry the new field. The apply
	## path must default to 1.0 rather than leaving a stale instance value
	## that would silently scale the resumed run.
	var s: Node = _fresh_state()
	s.text_size_scale = 1.5  # stale instance value
	var pre_40_save: Dictionary = {
		"version": GAMESTATE_SCRIPT.SAVE_VERSION,
		"hero_class": "arcanist",
		"floor_num": 3,
		"hero_hp": 80,
		"hero_max_hp": 100,
		# no text_size_scale key on purpose
	}
	assert_true(s.apply_snapshot(pre_40_save),
		"legacy save loads cleanly")
	assert_eq(s.text_size_scale, 1.0,
		"missing key defaults to 1.0 (not stale 1.5)")


func test_apply_snapshot_corrupted_value_snaps_to_known_option() -> void:
	## Defensive: a hand-edited save with a free-form float should snap to a
	## known option so the cycle can find it on the next click.
	var s: Node = _fresh_state()
	var bad_save: Dictionary = {
		"version": GAMESTATE_SCRIPT.SAVE_VERSION,
		"hero_class": "brawler",
		"floor_num": 2,
		"hero_hp": 50,
		"hero_max_hp": 100,
		"text_size_scale": 1.4,  # nowhere in TEXT_SIZE_OPTIONS
	}
	assert_true(s.apply_snapshot(bad_save), "apply ok")
	assert_true(GAMESTATE_SCRIPT.TEXT_SIZE_OPTIONS.has(s.text_size_scale),
		"corrupted scale snaps to a known option (got %s)" % str(s.text_size_scale))


# ── Apply-to-window safety in detached mode ────────────────────────────────

func test_apply_text_size_to_window_safe_when_detached() -> void:
	## Test instances aren't in the SceneTree — touching `get_window()` would
	## error if the guard wasn't in place. Confirm the call is a clean no-op.
	var s: Node = _fresh_state()
	s.text_size_scale = 1.5
	s.apply_text_size_to_window()  # must not crash
	assert_eq(s.text_size_scale, 1.5,
		"field unchanged by safe apply")
