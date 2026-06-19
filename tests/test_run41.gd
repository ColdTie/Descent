## Run 41 tests: persistent accessibility preferences across runs.
##
## Pure logic only — MetaProgress is instantiated via GDScript.new() so the
## autoload's `_ready -> load_from_disk` is bypassed (matching the Run-36
## onward pattern), and save_to_disk() returns false at the `is_inside_tree()`
## guard, so unit tests can't leak prefs into the real user save.
##
## GameState pieces are exercised in the same detached-instance mode. The
## persist path (GameState setter → MetaProgress.set_access_pref) requires
## both autoloads to be live at `/root/...`, which isn't true in `--script`
## mode; the setter falls through as a no-op there (covered by the existing
## Run-35/39/40 default-defended tests). The MetaProgress half of the
## persist contract is tested here directly via set_access_pref.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun41


var META_SCRIPT: GDScript = load("res://autoloads/MetaProgress.gd")
var GAMESTATE_SCRIPT: GDScript = load("res://autoloads/GameState.gd")


func _fresh_meta() -> Node:
	return META_SCRIPT.new()


func _fresh_state() -> Node:
	return GAMESTATE_SCRIPT.new()


# ── Defaults + key contract ────────────────────────────────────────────────

func test_accessibility_prefs_defaults_ship_safe() -> void:
	## A fresh meta save defaults every toggle to its shipping value so a
	## brand-new player sees identical behavior to pre-Run-41.
	var m: Node = _fresh_meta()
	assert_eq(m.accessibility_prefs.get("screen_shake", null), true,
		"screen_shake defaults true (shipping)")
	assert_eq(m.accessibility_prefs.get("damage_numbers", null), true,
		"damage_numbers defaults true (shipping)")
	assert_eq(m.accessibility_prefs.get("colorblind", null), false,
		"colorblind defaults false (shipping highlight palette)")
	assert_eq(m.accessibility_prefs.get("text_size_scale", null), 1.0,
		"text_size_scale defaults 1.0 (shipping no-scaling)")


func test_access_pref_keys_list_is_complete() -> void:
	## The ACCESS_PREF_KEYS list gates every read / write — a typo would let
	## a future toggle silently no-op. Lock the membership here.
	assert_eq(META_SCRIPT.ACCESS_PREF_KEYS.size(), 4,
		"four accessibility toggles tracked")
	assert_true(META_SCRIPT.ACCESS_PREF_KEYS.has("screen_shake"),
		"screen_shake in keys")
	assert_true(META_SCRIPT.ACCESS_PREF_KEYS.has("damage_numbers"),
		"damage_numbers in keys")
	assert_true(META_SCRIPT.ACCESS_PREF_KEYS.has("colorblind"),
		"colorblind in keys")
	assert_true(META_SCRIPT.ACCESS_PREF_KEYS.has("text_size_scale"),
		"text_size_scale in keys")


# ── get_access_pref ────────────────────────────────────────────────────────

func test_get_access_pref_returns_stored_value() -> void:
	var m: Node = _fresh_meta()
	m.accessibility_prefs["colorblind"] = true
	assert_eq(m.get_access_pref("colorblind", false), true,
		"reads the stored override")


func test_get_access_pref_returns_default_for_unknown_key() -> void:
	## A typo or future key removal should hit the caller's fallback rather
	## than coercing a missing entry into `null`.
	var m: Node = _fresh_meta()
	assert_eq(m.get_access_pref("bogus_unknown_key", 42), 42,
		"unknown key returns caller-supplied default")
	assert_eq(m.get_access_pref("", "fallback"), "fallback",
		"empty key returns default")


func test_get_access_pref_returns_default_for_missing_value() -> void:
	## If `accessibility_prefs` is somehow missing a known key (a stale
	## upgrade path), the caller default applies — not `null`.
	var m: Node = _fresh_meta()
	m.accessibility_prefs.erase("colorblind")
	assert_eq(m.get_access_pref("colorblind", false), false,
		"missing-known-key returns caller default")


# ── set_access_pref ────────────────────────────────────────────────────────

func test_set_access_pref_writes_known_key() -> void:
	var m: Node = _fresh_meta()
	assert_true(m.set_access_pref("colorblind", true),
		"write returns true on a real change")
	assert_eq(m.accessibility_prefs.get("colorblind", false), true,
		"value written through")


func test_set_access_pref_returns_false_on_no_op() -> void:
	## Same-value writes shouldn't trigger a save_to_disk(), so the helper
	## returns false. Lets the caller skip a redundant persist round-trip.
	var m: Node = _fresh_meta()
	# Initial state already has screen_shake=true.
	assert_true(not m.set_access_pref("screen_shake", true),
		"same-value write returns false")


func test_set_access_pref_refuses_unknown_key() -> void:
	## A typo from a future caller (`"highlight_outline"` etc.) must NOT
	## extend the dict with a key nothing else reads — that'd quietly bloat
	## every persisted save with dead data.
	var m: Node = _fresh_meta()
	assert_true(not m.set_access_pref("highlight_outline", true),
		"unknown key returns false")
	assert_true(not m.accessibility_prefs.has("highlight_outline"),
		"unknown key not added to dict")


func test_set_access_pref_handles_text_size_float() -> void:
	## The text-size scale is a float, not a bool. Make sure the setter
	## carries the type through cleanly.
	var m: Node = _fresh_meta()
	assert_true(m.set_access_pref("text_size_scale", 1.5),
		"text-size float write returns true")
	assert_eq(m.accessibility_prefs.get("text_size_scale", 0.0), 1.5,
		"float value stored as-is")


# ── Snapshot / apply round-trip ────────────────────────────────────────────

func test_snapshot_includes_accessibility_prefs() -> void:
	var m: Node = _fresh_meta()
	m.accessibility_prefs["colorblind"] = true
	m.accessibility_prefs["text_size_scale"] = 1.25
	var snap: Dictionary = m.snapshot()
	assert_true(snap.has("accessibility_prefs"),
		"snapshot carries the field")
	var ap: Dictionary = snap.get("accessibility_prefs", {})
	assert_eq(ap.get("colorblind", false), true,
		"snapshot value matches live state (colorblind)")
	assert_eq(ap.get("text_size_scale", 0.0), 1.25,
		"snapshot value matches live state (text_size_scale)")


func test_snapshot_prefs_are_deep_copied() -> void:
	## Mutating the snapshot output must NOT bleed into the live dict —
	## that would be a "writes through" bug for any caller inspecting the
	## snapshot before persisting it.
	var m: Node = _fresh_meta()
	var snap: Dictionary = m.snapshot()
	(snap.get("accessibility_prefs", {}) as Dictionary)["colorblind"] = true
	assert_eq(m.accessibility_prefs.get("colorblind", null), false,
		"live state unaffected by snapshot mutation")


func test_apply_snapshot_roundtrips_accessibility_prefs() -> void:
	var m: Node = _fresh_meta()
	m.accessibility_prefs["screen_shake"] = false
	m.accessibility_prefs["damage_numbers"] = false
	m.accessibility_prefs["colorblind"] = true
	m.accessibility_prefs["text_size_scale"] = 1.5
	var snap: Dictionary = m.snapshot()
	var m2: Node = _fresh_meta()
	assert_true(m2.apply_snapshot(snap), "apply ok")
	assert_eq(m2.accessibility_prefs.get("screen_shake", null), false,
		"roundtrip preserves screen_shake=false")
	assert_eq(m2.accessibility_prefs.get("damage_numbers", null), false,
		"roundtrip preserves damage_numbers=false")
	assert_eq(m2.accessibility_prefs.get("colorblind", null), true,
		"roundtrip preserves colorblind=true")
	assert_eq(m2.accessibility_prefs.get("text_size_scale", null), 1.5,
		"roundtrip preserves text_size_scale=1.5")


func test_apply_snapshot_pre_run41_save_defaults_ship_safe() -> void:
	## A meta save written before Run 41 won't carry the new field. The
	## apply path must fall back to shipping defaults rather than leaving
	## stale instance values from a fresh-meta object.
	var m: Node = _fresh_meta()
	# Plant non-default values BEFORE apply so we can detect the reset.
	m.accessibility_prefs["screen_shake"] = false
	m.accessibility_prefs["text_size_scale"] = 1.5
	var pre_41_save: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 50,
		"owned_perks": [],
		"equipped_perks": [],
		"total_runs": 2,
		"total_wins": 0,
		"best_floor": 4,
		"best_score": 1000,
		"classes_cleared": {},
		# no accessibility_prefs key on purpose
	}
	assert_true(m.apply_snapshot(pre_41_save), "legacy save loads cleanly")
	assert_eq(m.accessibility_prefs.get("screen_shake", null), true,
		"missing accessibility_prefs → screen_shake back to default true")
	assert_eq(m.accessibility_prefs.get("damage_numbers", null), true,
		"missing accessibility_prefs → damage_numbers back to default true")
	assert_eq(m.accessibility_prefs.get("colorblind", null), false,
		"missing accessibility_prefs → colorblind back to default false")
	assert_eq(m.accessibility_prefs.get("text_size_scale", null), 1.0,
		"missing accessibility_prefs → text_size_scale back to default 1.0")


func test_apply_snapshot_partial_prefs_overlay_defaults() -> void:
	## A save with only some of the toggle keys (a forward-migrated meta
	## where, e.g., colorblind was added after screen_shake) should keep
	## defaults for the missing keys rather than wiping them to null/false.
	var m: Node = _fresh_meta()
	var snap: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": [],
		"equipped_perks": [],
		"total_runs": 0,
		"total_wins": 0,
		"best_floor": 0,
		"best_score": 0,
		"classes_cleared": {},
		"accessibility_prefs": {
			"colorblind": true,
			# screen_shake / damage_numbers / text_size_scale absent
		},
	}
	assert_true(m.apply_snapshot(snap), "apply ok")
	assert_eq(m.accessibility_prefs.get("colorblind", null), true,
		"partial overlay landed colorblind=true")
	assert_eq(m.accessibility_prefs.get("screen_shake", null), true,
		"missing key kept default true")
	assert_eq(m.accessibility_prefs.get("damage_numbers", null), true,
		"missing key kept default true")
	assert_eq(m.accessibility_prefs.get("text_size_scale", null), 1.0,
		"missing key kept default 1.0")


func test_apply_snapshot_corrupted_text_size_snaps_to_option() -> void:
	## Mirror the GameState defense: a hand-edited meta with a free-form
	## text-size float should collapse to a known TEXT_SIZE_OPTIONS value
	## so the next pause-menu cycle can find the current index.
	var m: Node = _fresh_meta()
	var snap: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": [],
		"equipped_perks": [],
		"total_runs": 0,
		"total_wins": 0,
		"best_floor": 0,
		"best_score": 0,
		"classes_cleared": {},
		"accessibility_prefs": {
			"text_size_scale": 1.4,
		},
	}
	assert_true(m.apply_snapshot(snap), "apply ok")
	var scale: float = float(m.accessibility_prefs.get("text_size_scale", 0.0))
	assert_true(GAMESTATE_SCRIPT.TEXT_SIZE_OPTIONS.has(scale),
		"corrupted scale snapped to a known option (got %s)" % str(scale))


func test_apply_snapshot_non_dict_prefs_falls_back_to_defaults() -> void:
	## Defensive: a save where `accessibility_prefs` came back as a string,
	## an array, etc. must not crash and must leave a sane default dict.
	var m: Node = _fresh_meta()
	# Plant non-default values BEFORE apply so we can detect the reset.
	m.accessibility_prefs["colorblind"] = true
	var snap: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": [],
		"equipped_perks": [],
		"total_runs": 0,
		"total_wins": 0,
		"best_floor": 0,
		"best_score": 0,
		"classes_cleared": {},
		"accessibility_prefs": "not-a-dict",
	}
	assert_true(m.apply_snapshot(snap),
		"apply tolerates non-dict accessibility_prefs")
	assert_eq(m.accessibility_prefs.get("colorblind", null), false,
		"non-dict prefs → fields reset to shipping defaults")


# ── reset_all() ────────────────────────────────────────────────────────────

func test_reset_all_clears_accessibility_prefs() -> void:
	## A dev "reset progress" must wipe accessibility prefs alongside the
	## wallet so a returning player starts at shipping defaults again.
	var m: Node = _fresh_meta()
	m.accessibility_prefs["colorblind"] = true
	m.accessibility_prefs["text_size_scale"] = 1.5
	m.reset_all()
	assert_eq(m.accessibility_prefs.get("colorblind", null), false,
		"reset clears colorblind back to default")
	assert_eq(m.accessibility_prefs.get("text_size_scale", null), 1.0,
		"reset clears text_size_scale back to default")


# ── GameState start_run seeds from prefs ───────────────────────────────────
#
# `start_run` calls `get_node_or_null("/root/MetaProgress")` — in test mode
# the autoload isn't registered so the duck-typed lookup returns null and
# the shipping defaults apply. These tests cover the no-MetaProgress branch
# (a regression test that the existing Run-35/39/40 defaults still hold),
# plus the runtime branch is reviewed via the live game (the autoload IS
# present at /root/MetaProgress and `start_run` reads it).

func test_start_run_no_metaprogress_uses_shipping_defaults() -> void:
	## Detached GameState instance — no MetaProgress autoload at /root.
	## The seed step falls through to shipping defaults.
	var s: Node = _fresh_state()
	s.start_run("brawler", 1)
	assert_true(s.screen_shake_enabled,
		"shipping default: screen_shake on")
	assert_true(s.damage_numbers_enabled,
		"shipping default: damage_numbers on")
	assert_true(not s.colorblind_mode_enabled,
		"shipping default: colorblind off")
	assert_eq(s.text_size_scale, 1.0,
		"shipping default: text_size_scale 1.0")


# ── GameState setters: detached-safe no-op on persist ──────────────────────
#
# Real persist (setter → MetaProgress autoload) requires both autoloads at
# /root, which only the live game has. The setters must still mutate
# GameState locally even when MetaProgress is unreachable — those local
# mutations are what the BattleScene / engine read every frame.

func test_setters_mutate_local_state_without_metaprogress() -> void:
	var s: Node = _fresh_state()
	s.set_screen_shake(false)
	assert_true(not s.screen_shake_enabled,
		"set_screen_shake mutates GameState locally")
	s.set_damage_numbers(false)
	assert_true(not s.damage_numbers_enabled,
		"set_damage_numbers mutates GameState locally")
	s.set_colorblind_mode(true)
	assert_true(s.colorblind_mode_enabled,
		"set_colorblind_mode mutates GameState locally")
	s.set_text_size_scale(1.5)
	assert_eq(s.text_size_scale, 1.5,
		"set_text_size_scale mutates GameState locally")


func test_toggles_still_return_new_state_without_metaprogress() -> void:
	## Pause-menu buttons consume the return value to relabel themselves —
	## lock the contract for the no-MetaProgress case so the persist hook
	## can't accidentally swallow the return.
	var s: Node = _fresh_state()
	assert_true(not s.toggle_screen_shake(),
		"first toggle returns false (now off)")
	assert_true(s.toggle_screen_shake(),
		"second toggle returns true (now on again)")
	assert_true(not s.toggle_damage_numbers(),
		"damage_numbers first toggle returns false")
	assert_true(s.toggle_colorblind_mode(),
		"colorblind first toggle returns true")


func test_cycle_text_size_still_returns_new_value_without_metaprogress() -> void:
	var s: Node = _fresh_state()
	assert_eq(s.cycle_text_size_scale(), 1.25,
		"first cycle returns 1.25")
	assert_eq(s.cycle_text_size_scale(), 1.5,
		"second cycle returns 1.5")
	assert_eq(s.cycle_text_size_scale(), 1.0,
		"third cycle wraps to 1.0")


# ── Round-trip the full toggle path through MetaProgress directly ─────────
#
# The GameState side of the persist hook is detached-mode-safe (no-op).
# The persistence contract on the MetaProgress side — set_access_pref ->
# snapshot -> apply_snapshot -> get_access_pref returning the new value —
# is fully testable here and covers the loop end-to-end without needing
# a registered autoload.

func test_full_persistence_loop_landed_on_load() -> void:
	## Simulate: player toggles colorblind on (writes to MetaProgress),
	## meta snapshotted and saved, then the game restarts and reloads.
	## On the next start_run the seed step would call get_access_pref —
	## here we verify it returns the toggled value, not the default.
	var m: Node = _fresh_meta()
	m.set_access_pref("colorblind", true)
	m.set_access_pref("text_size_scale", 1.5)
	var snap: Dictionary = m.snapshot()
	# Simulate a fresh process: new MetaProgress instance loading the save.
	var m2: Node = _fresh_meta()
	assert_true(m2.apply_snapshot(snap), "load ok")
	assert_eq(m2.get_access_pref("colorblind", false), true,
		"colorblind survives save/load (the actual win for Run 41)")
	assert_eq(m2.get_access_pref("text_size_scale", 1.0), 1.5,
		"text_size_scale survives save/load")
	assert_eq(m2.get_access_pref("screen_shake", false), true,
		"untouched pref kept its default")
