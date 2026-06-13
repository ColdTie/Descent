## Run 35 tests: status-effect HUD depth (short codes, summaries, stacking)
## and accessibility toggles (screen shake + damage numbers) on GameState.
##
## Pure logic only — no Node tree, no scene runtime. The BattleScene wiring
## that consumes these helpers is exercised by the existing 1857-test
## regression suite under `--script`.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun35


var STATUS: GDScript = load("res://src/combat/StatusEffect.gd")
var GS_SCRIPT: GDScript = load("res://autoloads/GameState.gd")


# ── short_code ───────────────────────────────────────────────────────────────

func test_short_code_known_ids() -> void:
	assert_eq(STATUS.short_code(STATUS.burning()),    "BRN", "burning -> BRN")
	assert_eq(STATUS.short_code(STATUS.frozen()),     "FRZ", "frozen -> FRZ")
	assert_eq(STATUS.short_code(STATUS.poisoned()),   "PSN", "poisoned -> PSN")
	assert_eq(STATUS.short_code(STATUS.fortified()),  "DEF", "fortified -> DEF")
	assert_eq(STATUS.short_code(STATUS.vanished()),   "HID", "vanished -> HID")
	assert_eq(STATUS.short_code(STATUS.mana_shield()),"SHD", "mana_shield -> SHD")


func test_short_code_unknown_id_falls_back_to_first_three() -> void:
	## Future-proofing: a brand-new effect dict still produces a non-empty
	## three-letter code instead of a blank bracket.
	var eff: Dictionary = {"id": "stunlocked"}
	assert_eq(STATUS.short_code(eff), "STU", "unknown id truncates to upper-3")


func test_short_code_empty_id_returns_placeholder() -> void:
	## Defensive — a malformed dict shouldn't render a `[ ]` bracket.
	assert_eq(STATUS.short_code({}), "???", "empty id returns ???")


# ── display_name ─────────────────────────────────────────────────────────────

func test_display_name_known_ids() -> void:
	assert_eq(STATUS.display_name(STATUS.burning()),    "Burning",     "burning name")
	assert_eq(STATUS.display_name(STATUS.frozen()),     "Frozen",      "frozen name")
	assert_eq(STATUS.display_name(STATUS.poisoned()),   "Poisoned",    "poisoned name")
	assert_eq(STATUS.display_name(STATUS.fortified()),  "Fortified",   "fortified name")
	assert_eq(STATUS.display_name(STATUS.vanished()),   "Vanished",    "vanished name")
	assert_eq(STATUS.display_name(STATUS.mana_shield()),"Mana Shield", "mana shield name")


func test_display_name_falls_back_to_dict_name() -> void:
	## Unknown id → use the dict's `name` field if present.
	var eff: Dictionary = {"id": "fake", "name": "Whatever"}
	assert_eq(STATUS.display_name(eff), "Whatever",
		"unknown id falls through to dict name")


# ── summarize ────────────────────────────────────────────────────────────────

func test_summarize_burning_includes_dpt() -> void:
	## Burning prints duration + per-turn damage so the player can see what
	## the next two turns cost without hovering anything.
	var s: String = STATUS.summarize(STATUS.burning(3, 5))
	assert_true(s.contains("Burning"), "summary names the effect")
	assert_true(s.contains("3t"),      "summary lists duration")
	assert_true(s.contains("5/turn"),  "summary lists damage per turn")


func test_summarize_poisoned_includes_dpt() -> void:
	var s: String = STATUS.summarize(STATUS.poisoned(4, 3))
	assert_true(s.contains("Poisoned"), "poisoned name")
	assert_true(s.contains("4t"),       "poisoned duration")
	assert_true(s.contains("3/turn"),   "poisoned dpt")


func test_summarize_frozen_lists_armor_penalty() -> void:
	## Frozen has armor_mod = -2 + skips_turn but no DPT. The negative armor
	## mod is the player-visible cost — surface it.
	var s: String = STATUS.summarize(STATUS.frozen(2))
	assert_true(s.contains("Frozen"),   "frozen name")
	assert_true(s.contains("2t"),       "frozen duration")
	assert_true(s.contains("-2 armor"), "frozen armor penalty visible")
	assert_true(not s.contains("/turn"),"no spurious dpt for frozen")


func test_summarize_fortified_lists_armor_bonus() -> void:
	## Fortified bumps armor — show the positive number with a leading '+'.
	var s: String = STATUS.summarize(STATUS.fortified(2, 3))
	assert_true(s.contains("Fortified"), "fortified name")
	assert_true(s.contains("2t"),        "fortified duration")
	assert_true(s.contains("+3 armor"),  "fortified armor bonus visible")


func test_summarize_mana_shield_lists_absorb_pool() -> void:
	## Mana Shield's "damage" is its absorb pool, not a DPT. The summary
	## should surface the remaining pool, not a misleading "0/turn".
	var s: String = STATUS.summarize(STATUS.mana_shield(40, 10))
	assert_true(s.contains("Mana Shield"), "shield name")
	assert_true(s.contains("10t"),         "shield duration")
	assert_true(s.contains("40 absorb"),   "shield pool visible")
	assert_true(not s.contains("/turn"),   "no dpt line on a shield")


func test_summarize_vanished_omits_zero_fields() -> void:
	## Vanished carries 0 DPT and 0 armor mod; the summary should NOT lie
	## by appending dead "0/turn" tail noise.
	var s: String = STATUS.summarize(STATUS.vanished(3.0))
	assert_true(s.contains("Vanished"), "vanished name")
	assert_true(s.contains("3t"),       "vanished duration")
	assert_true(not s.contains("/turn"),"vanished has no dpt line")
	assert_true(not s.contains("armor"),"vanished has no armor line")


# ── stack ────────────────────────────────────────────────────────────────────

func test_stack_empty_returns_empty() -> void:
	assert_eq(STATUS.stack([]).size(), 0, "empty list -> empty stack")


func test_stack_single_effect_passthrough() -> void:
	var stacked: Array[Dictionary] = STATUS.stack([STATUS.burning(3, 5)])
	assert_eq(stacked.size(), 1, "single effect -> single row")
	assert_eq(int(stacked[0].get("stacks", 0)), 1, "stack count = 1")
	assert_eq(String(stacked[0].get("id", "")), "burning", "id preserved")
	assert_eq(int(stacked[0].get("duration", 0)), 3, "duration preserved")


func test_stack_duplicate_ids_collapse() -> void:
	## Two poisons applied — the HUD should show ONE row with stacks=2 and
	## the longer of the two durations (player cares when it stops applying).
	var stacked: Array[Dictionary] = STATUS.stack([
		STATUS.poisoned(2, 3),
		STATUS.poisoned(5, 3),
	])
	assert_eq(stacked.size(), 1, "duplicates collapse to one row")
	assert_eq(int(stacked[0].get("stacks", 0)), 2, "stacks = 2")
	assert_eq(int(stacked[0].get("duration", 0)), 5,
		"duration = max of the group")
	assert_eq(int(stacked[0].get("damage_per_turn", 0)), 6,
		"dpt sums (3 + 3 = 6) — matches tick_statuses payout")


func test_stack_distinct_ids_kept_in_order() -> void:
	## Two different effects stay as two rows in the order first seen — the
	## HUD shouldn't flicker as effects rotate in and out.
	var stacked: Array[Dictionary] = STATUS.stack([
		STATUS.burning(3, 5),
		STATUS.poisoned(4, 3),
	])
	assert_eq(stacked.size(), 2, "two distinct rows")
	assert_eq(String(stacked[0].get("id", "")), "burning",
		"burning first (was first in input)")
	assert_eq(String(stacked[1].get("id", "")), "poisoned",
		"poisoned second")


func test_stack_skips_malformed_entries() -> void:
	## Non-dict items + dicts with no id are silently dropped — the HUD
	## never gets a blank `[ ]` row from a bad input.
	var stacked: Array[Dictionary] = STATUS.stack([
		STATUS.burning(3, 5),
		{},
		{"id": ""},
		42,
		"not a dict",
		STATUS.poisoned(2, 3),
	])
	assert_eq(stacked.size(), 2, "malformed entries dropped")
	assert_eq(String(stacked[0].get("id", "")), "burning", "burning kept")
	assert_eq(String(stacked[1].get("id", "")), "poisoned", "poisoned kept")


func test_stack_mana_shield_sums_absorb_pool() -> void:
	## Two simultaneous shields (a contrived edge case, but Run 21's
	## structure permits it) should report combined absorb so the
	## summary panel matches what take_damage will drain.
	var stacked: Array[Dictionary] = STATUS.stack([
		STATUS.mana_shield(40, 10),
		STATUS.mana_shield(25, 8),
	])
	assert_eq(stacked.size(), 1, "shields collapse to one row")
	assert_eq(int(stacked[0].get("stacks", 0)), 2, "stacks = 2")
	assert_eq(int(stacked[0].get("absorb_remaining", 0)), 65,
		"absorb pool sums (40 + 25)")


# ── GameState accessibility toggles ──────────────────────────────────────────

func test_accessibility_defaults_are_on() -> void:
	var gs: Node = GS_SCRIPT.new()
	assert_true(gs.screen_shake_enabled, "screen shake defaults ON")
	assert_true(gs.damage_numbers_enabled, "damage numbers default ON")
	gs.queue_free()


func test_set_screen_shake_writes_through() -> void:
	var gs: Node = GS_SCRIPT.new()
	gs.set_screen_shake(false)
	assert_true(not gs.screen_shake_enabled, "set_screen_shake(false) disables")
	gs.set_screen_shake(true)
	assert_true(gs.screen_shake_enabled, "set_screen_shake(true) re-enables")
	gs.queue_free()


func test_set_damage_numbers_writes_through() -> void:
	var gs: Node = GS_SCRIPT.new()
	gs.set_damage_numbers(false)
	assert_true(not gs.damage_numbers_enabled, "set_damage_numbers(false) disables")
	gs.set_damage_numbers(true)
	assert_true(gs.damage_numbers_enabled, "set_damage_numbers(true) re-enables")
	gs.queue_free()


func test_toggle_screen_shake_flips_and_returns_new_value() -> void:
	## Pause menu reads the return value to update the button label, so the
	## returned bool must match the field after the call.
	var gs: Node = GS_SCRIPT.new()
	var v1: bool = gs.toggle_screen_shake()
	assert_eq(v1, gs.screen_shake_enabled, "returned value matches state")
	assert_true(not v1, "first toggle from default ON flips to OFF")
	var v2: bool = gs.toggle_screen_shake()
	assert_eq(v2, gs.screen_shake_enabled, "returned value matches state (back)")
	assert_true(v2, "second toggle flips back to ON")
	gs.queue_free()


func test_toggle_damage_numbers_flips_and_returns_new_value() -> void:
	var gs: Node = GS_SCRIPT.new()
	var v1: bool = gs.toggle_damage_numbers()
	assert_eq(v1, gs.damage_numbers_enabled, "returned value matches state")
	assert_true(not v1, "first toggle from default ON flips to OFF")
	var v2: bool = gs.toggle_damage_numbers()
	assert_true(v2, "second toggle flips back to ON")
	gs.queue_free()


# ── GameState snapshot / apply / restore plumbing ─────────────────────────────

func test_snapshot_includes_accessibility_flags() -> void:
	var gs: Node = GS_SCRIPT.new()
	gs.hero_class = "rogue"
	gs.screen_shake_enabled = false
	gs.damage_numbers_enabled = false
	var s: Dictionary = gs.snapshot()
	assert_true(s.has("screen_shake_enabled"),
		"snapshot carries screen_shake_enabled")
	assert_true(s.has("damage_numbers_enabled"),
		"snapshot carries damage_numbers_enabled")
	assert_eq(bool(s["screen_shake_enabled"]), false,
		"snapshot reflects current shake state")
	assert_eq(bool(s["damage_numbers_enabled"]), false,
		"snapshot reflects current dmg-nums state")
	gs.queue_free()


func test_apply_snapshot_restores_accessibility_flags() -> void:
	var src: Node = GS_SCRIPT.new()
	src.hero_class = "rogue"
	src.screen_shake_enabled = false
	src.damage_numbers_enabled = false
	var snap: Dictionary = src.snapshot()
	src.queue_free()

	var dst: Node = GS_SCRIPT.new()
	assert_true(dst.apply_snapshot(snap), "apply_snapshot accepts the dict")
	assert_true(not dst.screen_shake_enabled,
		"restored screen_shake = false")
	assert_true(not dst.damage_numbers_enabled,
		"restored damage_numbers = false")
	dst.queue_free()


func test_apply_snapshot_pre_run35_save_defaults_on() -> void:
	## A save written before Run 35 lacks both keys. We default to ON so the
	## restored run behaves identically to a fresh checkpoint — no surprise
	## "where did the shake go?" after a resume.
	var dst: Node = GS_SCRIPT.new()
	var legacy: Dictionary = {
		"version": GS_SCRIPT.SAVE_VERSION,
		"hero_class": "rogue",
		"floor_num": 3,
	}
	assert_true(dst.apply_snapshot(legacy), "apply legacy snapshot")
	assert_true(dst.screen_shake_enabled,
		"pre-Run-35 save -> screen shake defaults ON")
	assert_true(dst.damage_numbers_enabled,
		"pre-Run-35 save -> damage numbers default ON")
	dst.queue_free()


func test_start_run_resets_accessibility_to_on() -> void:
	## A class-pick at the title screen should always start with shipping
	## behavior (in case the previous run left them disabled).
	var gs: Node = GS_SCRIPT.new()
	gs.screen_shake_enabled = false
	gs.damage_numbers_enabled = false
	gs.start_run("brawler", 7)
	assert_true(gs.screen_shake_enabled, "start_run resets shake ON")
	assert_true(gs.damage_numbers_enabled, "start_run resets dmg-nums ON")
	gs.queue_free()


# ── Integration: HUD label format hasn't regressed ──────────────────────────

func test_status_label_format_carries_duration_and_stacks() -> void:
	## End-to-end: the BattleScene status label uses stack() + short_code() +
	## duration to build `[BRN 3] [PSN 4 x2]`-style text. Reproduce the same
	## composition here so a future refactor of either side can't silently
	## strip the duration or the stack suffix.
	var effs: Array = [
		STATUS.burning(3, 5),
		STATUS.poisoned(2, 3),
		STATUS.poisoned(4, 3),
	]
	var pieces: Array[String] = []
	for eff: Dictionary in STATUS.stack(effs):
		var code: String = STATUS.short_code(eff)
		var dur: int = int(eff.get("duration", 0))
		var n: int = int(eff.get("stacks", 1))
		if n > 1:
			pieces.append("[%s %d x%d]" % [code, dur, n])
		else:
			pieces.append("[%s %d]" % [code, dur])
	var text: String = " ".join(pieces)
	assert_eq(text, "[BRN 3] [PSN 4 x2]",
		"composed status label exact-match")
