## Run 42 tests: alt-color class skins.
##
## Skins are pure data + a tiny lookup module — every helper is exercised
## directly. MetaProgress is instantiated via GDScript.new() to bypass the
## autoload `_ready -> load_from_disk` path, matching the Run-36 onward
## detached-instance pattern. `save_to_disk()` returns false at the
## `is_inside_tree()` guard, so unit tests can't leak class-win counts or
## equipped-skin state into the real user save.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun42


var META_SCRIPT: GDScript = load("res://autoloads/MetaProgress.gd")


func _fresh_meta() -> Node:
	return META_SCRIPT.new()


# ── Skins DEFS schema ──────────────────────────────────────────────────────

func test_skins_defs_size_and_class_coverage() -> void:
	## Three classes × three skins each = nine total. A missing class would
	## leave the player with one of the three character options untintable.
	assert_eq(Skins.DEFS.size(), 9, "9 skins total (3 classes × 3 tiers)")
	for cid: String in Classes.all_ids():
		var ids: Array[String] = Skins.for_class(cid)
		assert_eq(ids.size(), 3, "class %s has 3 skins" % cid)


func test_every_skin_has_required_fields() -> void:
	## Schema lock — drift in field names would silently break the
	## MetaScreen render or the equip path.
	for sid: String in Skins.all_ids():
		var d: Dictionary = Skins.DEFS[sid]
		assert_true(d.has("id"), "%s has id" % sid)
		assert_true(d.has("class_id"), "%s has class_id" % sid)
		assert_true(d.has("name"), "%s has name" % sid)
		assert_true(d.has("desc"), "%s has desc" % sid)
		assert_true(d.has("tint"), "%s has tint" % sid)
		assert_true(d.has("requires_class_wins"), "%s has requires_class_wins" % sid)
		assert_true(d["tint"] is Color, "%s tint is a Color" % sid)
		assert_eq(String(d["id"]), sid, "%s id matches dict key" % sid)


func test_every_class_has_exactly_one_default_skin() -> void:
	## The default skin (requires_class_wins == 0) is the always-unlocked
	## floor. Exactly one per class — zero would leave a new player with no
	## skin to render, two would create an ambiguous default_for() result.
	for cid: String in Classes.all_ids():
		var count: int = 0
		for sid: String in Skins.for_class(cid):
			if Skins.requires_wins(sid) == 0:
				count += 1
		assert_eq(count, 1, "class %s has exactly one default skin" % cid)


func test_unlock_thresholds_strictly_increase_per_class() -> void:
	## Within a class the three skins ramp 0 → 1 → 3. A repeat would let a
	## single win unlock two skins at once (UX confusion: which is "the"
	## unlock); a non-monotonic ramp would put the mastery skin behind a
	## lower bar than the veteran.
	for cid: String in Classes.all_ids():
		var thresholds: Array[int] = []
		for sid: String in Skins.for_class(cid):
			thresholds.append(Skins.requires_wins(sid))
		thresholds.sort()
		for i: int in range(1, thresholds.size()):
			assert_true(thresholds[i] > thresholds[i - 1],
				"class %s thresholds strictly increase: %s" % [cid, str(thresholds)])


func test_skin_tints_distinguishable_from_default() -> void:
	## Every non-default skin should actually tint the sprite — a WHITE tint
	## on a "mastery" skin would silently render identical to the default.
	for sid: String in Skins.all_ids():
		var d: Dictionary = Skins.DEFS[sid]
		var need: int = int(d.get("requires_class_wins", 0))
		var t: Color = Skins.tint_for(sid)
		if need == 0:
			assert_eq(t, Color(1.0, 1.0, 1.0),
				"default skin %s is WHITE (no tint)" % sid)
		else:
			assert_true(t != Color(1.0, 1.0, 1.0),
				"unlock-skin %s has a non-WHITE tint" % sid)


# ── Skins lookup helpers ───────────────────────────────────────────────────

func test_tint_for_unknown_id_returns_white() -> void:
	## Unknown ids fall through to WHITE so the BattleScene tint write is a
	## no-op rather than a crash.
	assert_eq(Skins.tint_for("nonexistent_skin_id"), Color(1.0, 1.0, 1.0),
		"unknown skin id → WHITE")
	assert_eq(Skins.tint_for(""), Color(1.0, 1.0, 1.0),
		"empty skin id → WHITE")


func test_class_id_for_unknown_returns_empty() -> void:
	assert_eq(Skins.class_id_for("not_a_real_skin"), "",
		"unknown id → empty class_id")
	assert_eq(Skins.class_id_for(""), "",
		"empty id → empty class_id")


func test_for_class_unknown_returns_empty_array() -> void:
	var empty: Array[String] = Skins.for_class("")
	assert_eq(empty.size(), 0, "empty class id → no skins")
	var bogus: Array[String] = Skins.for_class("definitely_not_a_class")
	assert_eq(bogus.size(), 0, "unknown class id → no skins")


func test_default_for_returns_default_skin_id() -> void:
	## The default is the skin every player starts with — known per class.
	assert_eq(Skins.default_for("brawler"), "brawler_default",
		"brawler default")
	assert_eq(Skins.default_for("rogue"), "rogue_default",
		"rogue default")
	assert_eq(Skins.default_for("arcanist"), "arcanist_default",
		"arcanist default")
	assert_eq(Skins.default_for(""), "",
		"empty class id → empty default")
	assert_eq(Skins.default_for("not_real"), "",
		"unknown class id → empty default")


func test_requires_wins_unknown_id_fails_closed() -> void:
	## A typo'd skin id should be locked forever, never silently unlocked
	## by a low real-player counter.
	assert_eq(Skins.requires_wins("bogus_id"), 9999,
		"unknown id requires sentinel-high count")


func test_is_unlocked_default_skin_always_true_even_with_zero_wins() -> void:
	## The default is the floor — a brand-new player with 0 wins still has
	## access to it. Without this the BattleScene would render an untinted
	## hero for a new player, but the MetaScreen would still surface the
	## card as locked, which is internally inconsistent.
	assert_true(Skins.is_unlocked("brawler_default", 0),
		"default unlocked at 0 wins")
	assert_true(Skins.is_unlocked("brawler_default", 99),
		"default still unlocked at high counts")


func test_is_unlocked_veteran_requires_one_win() -> void:
	assert_true(not Skins.is_unlocked("brawler_onyx", 0),
		"onyx locked at 0 wins")
	assert_true(Skins.is_unlocked("brawler_onyx", 1),
		"onyx unlocks at 1 win")
	assert_true(Skins.is_unlocked("brawler_onyx", 5),
		"onyx still unlocked at high counts")


func test_is_unlocked_mastery_requires_three_wins() -> void:
	assert_true(not Skins.is_unlocked("brawler_gilded", 2),
		"gilded locked at 2 wins")
	assert_true(Skins.is_unlocked("brawler_gilded", 3),
		"gilded unlocks at exactly 3 wins")
	assert_true(Skins.is_unlocked("brawler_gilded", 99),
		"gilded still unlocked at high counts")


func test_is_unlocked_unknown_id_fails_closed() -> void:
	assert_true(not Skins.is_unlocked("not_a_skin", 9999),
		"unknown id stays locked even at absurd counts")


func test_is_unlocked_negative_wins_clamps_to_zero() -> void:
	## A corrupted save passing -1 shouldn't accidentally make any skin
	## unlocked. Default still unlocks (need=0), milestone skins still locked.
	assert_true(Skins.is_unlocked("brawler_default", -1),
		"default unlocked even with negative wins")
	assert_true(not Skins.is_unlocked("brawler_onyx", -1),
		"veteran locked at negative wins")


# ── Requirement text ───────────────────────────────────────────────────────

func test_requirement_text_empty_for_default() -> void:
	## Default skins have no lock — the MetaScreen branch on "" skips the
	## requirement line. Lock that contract.
	assert_eq(Skins.requirement_text("brawler_default"), "",
		"default skin requirement text is empty")
	assert_eq(Skins.requirement_text("rogue_default"), "",
		"rogue default empty")


func test_requirement_text_includes_class_name_and_count() -> void:
	## The MetaScreen LOCKED card surfaces this string — players need to
	## know both how many wins AND which class. Singular "Win a run" form
	## for 1 to read naturally.
	assert_eq(Skins.requirement_text("brawler_onyx"),
		"Win a run as Brawler",
		"veteran singular form")
	assert_eq(Skins.requirement_text("rogue_crimson"),
		"Win 3 runs as Rogue",
		"mastery plural form")
	assert_eq(Skins.requirement_text("arcanist_solar"),
		"Win 3 runs as Arcanist",
		"arcanist mastery")


func test_requirement_text_unknown_id_empty() -> void:
	assert_eq(Skins.requirement_text("not_a_skin"), "",
		"unknown id → empty requirement")


# ── MetaProgress.class_wins ────────────────────────────────────────────────

func test_class_wins_defaults_zero() -> void:
	var m: Node = _fresh_meta()
	assert_eq(m.class_win_count("brawler"), 0, "brawler defaults to 0")
	assert_eq(m.class_win_count("rogue"), 0, "rogue defaults to 0")
	assert_eq(m.class_win_count("arcanist"), 0, "arcanist defaults to 0")
	assert_eq(m.class_win_count(""), 0, "empty class id → 0")
	assert_eq(m.class_win_count("bogus"), 0, "unknown class id → 0")


func test_class_wins_bumps_on_win_only() -> void:
	## A death-run must not bump the counter — only a real win counts.
	var m: Node = _fresh_meta()
	m.record_run_end(6, 0, false, 0, "brawler")
	assert_eq(m.class_win_count("brawler"), 0,
		"death does NOT bump class_wins")
	m.record_run_end(18, 3, true, 1000, "brawler")
	assert_eq(m.class_win_count("brawler"), 1,
		"win bumps brawler counter")


func test_class_wins_accumulates_across_multiple_runs() -> void:
	var m: Node = _fresh_meta()
	m.record_run_end(18, 3, true, 1000, "brawler")
	m.record_run_end(18, 3, true, 1100, "brawler")
	m.record_run_end(18, 3, true, 1200, "brawler")
	assert_eq(m.class_win_count("brawler"), 3, "3 brawler wins accumulate")
	assert_eq(m.class_win_count("rogue"), 0,
		"rogue counter untouched by brawler wins")


func test_class_wins_keyed_per_class() -> void:
	## Wins as different classes track independently — a single win as
	## Brawler must not unlock the Rogue mastery skin.
	var m: Node = _fresh_meta()
	m.record_run_end(18, 3, true, 0, "brawler")
	m.record_run_end(18, 3, true, 0, "rogue")
	m.record_run_end(18, 3, true, 0, "arcanist")
	assert_eq(m.class_win_count("brawler"), 1, "brawler = 1")
	assert_eq(m.class_win_count("rogue"), 1, "rogue = 1")
	assert_eq(m.class_win_count("arcanist"), 1, "arcanist = 1")


func test_class_wins_ignores_empty_class_id() -> void:
	## A win with no class id (defensive caller) shouldn't park an empty key
	## in the dict. Total wins still bumps because the run did complete.
	var m: Node = _fresh_meta()
	m.record_run_end(18, 3, true, 0, "")
	assert_eq(m.class_wins.size(), 0,
		"empty class id leaves class_wins untouched")
	assert_eq(m.total_wins, 1,
		"empty class id still bumps total_wins")


# ── MetaProgress.is_skin_unlocked + equipped_skin_for ─────────────────────

func test_is_skin_unlocked_reads_live_counter() -> void:
	## Wraps Skins.is_unlocked against the class_wins counter — the live
	## gate the MetaScreen + the equip path share.
	var m: Node = _fresh_meta()
	assert_true(m.is_skin_unlocked("brawler_default"),
		"default unlocked from start")
	assert_true(not m.is_skin_unlocked("brawler_onyx"),
		"onyx locked at 0 brawler wins")
	m.record_run_end(18, 3, true, 0, "brawler")
	assert_true(m.is_skin_unlocked("brawler_onyx"),
		"onyx unlocked after 1 brawler win")
	assert_true(not m.is_skin_unlocked("brawler_gilded"),
		"gilded still locked after 1 win")


func test_is_skin_unlocked_unknown_id_false() -> void:
	var m: Node = _fresh_meta()
	assert_true(not m.is_skin_unlocked("nonexistent"),
		"unknown skin id always false")
	assert_true(not m.is_skin_unlocked(""),
		"empty skin id always false")


func test_equipped_skin_for_defaults_to_class_default() -> void:
	## A brand-new player has nothing in equipped_skins — every class falls
	## through to its default skin.
	var m: Node = _fresh_meta()
	assert_eq(m.equipped_skin_for("brawler"), "brawler_default",
		"brawler → default")
	assert_eq(m.equipped_skin_for("rogue"), "rogue_default",
		"rogue → default")
	assert_eq(m.equipped_skin_for("arcanist"), "arcanist_default",
		"arcanist → default")
	assert_eq(m.equipped_skin_for(""), "",
		"empty class id → empty")
	assert_eq(m.equipped_skin_for("not_real"), "",
		"unknown class id → empty")


func test_equipped_skin_for_falls_back_when_stale_entry_relocked() -> void:
	## A save written when the player had brawler_onyx equipped, then a
	## reset_all() wipes class_wins, should fall through to the default
	## rather than render the locked-again skin. Defense in depth — the
	## load path also trims this entry, but the live read is the safety net.
	var m: Node = _fresh_meta()
	m.equipped_skins["brawler"] = "brawler_onyx"
	# class_wins is empty → onyx is locked → equipped_skin_for falls through.
	assert_eq(m.equipped_skin_for("brawler"), "brawler_default",
		"locked entry falls through to default")


func test_equipped_skin_tint_returns_active_tint() -> void:
	var m: Node = _fresh_meta()
	assert_eq(m.equipped_skin_tint("brawler"), Color(1.0, 1.0, 1.0),
		"new player → WHITE")
	m.record_run_end(18, 3, true, 0, "brawler")
	assert_true(m.equip_skin("brawler_onyx"), "equip onyx after 1 win")
	assert_eq(m.equipped_skin_tint("brawler"),
		Skins.tint_for("brawler_onyx"),
		"equipped_skin_tint reflects active skin")


func test_equipped_skin_tint_unknown_class_white() -> void:
	## BattleScene calls this with GameState.hero_class — an empty value
	## (test mode, hot reload mid-init) must not crash.
	var m: Node = _fresh_meta()
	assert_eq(m.equipped_skin_tint(""), Color(1.0, 1.0, 1.0),
		"empty class id → WHITE")
	assert_eq(m.equipped_skin_tint("not_a_class"), Color(1.0, 1.0, 1.0),
		"unknown class id → WHITE")


# ── equip_skin / unequip_skin ─────────────────────────────────────────────

func test_equip_skin_unknown_id_refused() -> void:
	var m: Node = _fresh_meta()
	assert_true(not m.equip_skin("nonexistent_skin"),
		"unknown skin id refused")
	assert_eq(m.equipped_skins.size(), 0,
		"refused write leaves dict empty")


func test_equip_skin_locked_refused() -> void:
	## Defense in depth — even if the MetaScreen LOCKED card is somehow
	## clicked, the wallet layer refuses to write.
	var m: Node = _fresh_meta()
	assert_true(not m.equip_skin("brawler_onyx"),
		"locked skin refused at 0 wins")
	assert_eq(m.equipped_skins.size(), 0,
		"refused write leaves dict empty")


func test_equip_skin_success_after_unlock() -> void:
	var m: Node = _fresh_meta()
	m.record_run_end(18, 3, true, 0, "brawler")
	assert_true(m.equip_skin("brawler_onyx"),
		"unlocked skin equips")
	assert_eq(m.equipped_skins.get("brawler", ""), "brawler_onyx",
		"equip_skins[brawler] = onyx")


func test_equip_skin_same_value_is_no_op() -> void:
	## No-op writes should return false so the MetaScreen doesn't fire a
	## SFX/redraw for a click that didn't change anything.
	var m: Node = _fresh_meta()
	m.record_run_end(18, 3, true, 0, "brawler")
	m.equip_skin("brawler_onyx")
	assert_true(not m.equip_skin("brawler_onyx"),
		"same-value write returns false")


func test_equip_skin_swaps_within_class() -> void:
	## Equipping a different skin for the same class swaps — the player
	## doesn't need to unequip first.
	var m: Node = _fresh_meta()
	for i: int in range(3):
		m.record_run_end(18, 3, true, 0, "brawler")
	assert_true(m.equip_skin("brawler_onyx"), "equip onyx")
	assert_true(m.equip_skin("brawler_gilded"), "swap to gilded")
	assert_eq(m.equipped_skins.get("brawler", ""), "brawler_gilded",
		"gilded now active")
	# Onyx is no longer the equipped entry — only one skin per class active.
	assert_eq(m.equipped_skins.size(), 1,
		"still only one entry per class")


func test_unequip_skin_clears_entry() -> void:
	var m: Node = _fresh_meta()
	m.record_run_end(18, 3, true, 0, "brawler")
	m.equip_skin("brawler_onyx")
	assert_true(m.unequip_skin("brawler"),
		"unequip clears the entry")
	assert_eq(m.equipped_skin_for("brawler"), "brawler_default",
		"falls through to default after unequip")


func test_unequip_skin_no_entry_returns_false() -> void:
	var m: Node = _fresh_meta()
	assert_true(not m.unequip_skin("brawler"),
		"no entry → false")
	assert_true(not m.unequip_skin(""),
		"empty class id → false")


# ── unlocked_skin_count ───────────────────────────────────────────────────

func test_unlocked_skin_count_starts_at_default_count() -> void:
	## A new player has exactly the 3 default skins (one per class).
	var m: Node = _fresh_meta()
	assert_eq(m.unlocked_skin_count(), 3,
		"3 defaults unlocked from start")


func test_unlocked_skin_count_bumps_per_unlock() -> void:
	var m: Node = _fresh_meta()
	m.record_run_end(18, 3, true, 0, "brawler")
	assert_eq(m.unlocked_skin_count(), 4,
		"3 defaults + onyx after 1 brawler win")
	# Three more brawler wins should also unlock gilded.
	m.record_run_end(18, 3, true, 0, "brawler")
	m.record_run_end(18, 3, true, 0, "brawler")
	assert_eq(m.unlocked_skin_count(), 5,
		"3 defaults + onyx + gilded after 3 brawler wins")


# ── Snapshot / apply round-trip ───────────────────────────────────────────

func test_snapshot_includes_new_fields() -> void:
	## Schema lock — the persistence loop must carry the two new fields.
	var m: Node = _fresh_meta()
	var snap: Dictionary = m.snapshot()
	assert_true(snap.has("class_wins"), "snapshot has class_wins")
	assert_true(snap.has("equipped_skins"), "snapshot has equipped_skins")


func test_snapshot_apply_roundtrip_preserves_class_wins() -> void:
	var m: Node = _fresh_meta()
	for i: int in range(3):
		m.record_run_end(18, 3, true, 0, "brawler")
	m.record_run_end(18, 3, true, 0, "rogue")
	var snap: Dictionary = m.snapshot()

	var m2: Node = _fresh_meta()
	assert_true(m2.apply_snapshot(snap), "apply succeeds")
	assert_eq(m2.class_win_count("brawler"), 3,
		"class_wins[brawler] survives")
	assert_eq(m2.class_win_count("rogue"), 1,
		"class_wins[rogue] survives")


func test_snapshot_apply_roundtrip_preserves_equipped_skin() -> void:
	var m: Node = _fresh_meta()
	for i: int in range(3):
		m.record_run_end(18, 3, true, 0, "brawler")
	m.equip_skin("brawler_gilded")
	var snap: Dictionary = m.snapshot()

	var m2: Node = _fresh_meta()
	assert_true(m2.apply_snapshot(snap), "apply succeeds")
	assert_eq(m2.equipped_skins.get("brawler", ""), "brawler_gilded",
		"equipped skin survives")


func test_apply_pre_run42_save_defaults_to_empty() -> void:
	## A save written by Run 41 has no `class_wins` or `equipped_skins`
	## fields. The apply path must default to empty dicts rather than
	## refusing the whole save.
	var m: Node = _fresh_meta()
	var legacy: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 50,
		"total_runs": 5,
		"total_wins": 2,
	}
	assert_true(m.apply_snapshot(legacy), "legacy save loads")
	assert_eq(m.class_wins.size(), 0,
		"class_wins defaults empty for pre-Run-42 save")
	assert_eq(m.equipped_skins.size(), 0,
		"equipped_skins defaults empty for pre-Run-42 save")


func test_apply_negative_class_wins_clamps_to_zero() -> void:
	## A hand-edited save with -5 wins shouldn't park a class below 0 —
	## it would render unlocked status incorrectly via the int compare.
	var m: Node = _fresh_meta()
	var data: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"class_wins": {"brawler": -5},
	}
	assert_true(m.apply_snapshot(data), "apply succeeds")
	assert_eq(m.class_win_count("brawler"), 0,
		"negative win count clamps to 0")


func test_apply_drops_equipped_skin_for_unknown_id() -> void:
	## A future skin removal — the save still has the equipped-skin entry
	## but the id isn't in Skins.DEFS anymore. Trim at load so the snapshot
	## of the next save doesn't keep round-tripping it.
	var m: Node = _fresh_meta()
	var data: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"class_wins": {"brawler": 5},
		"equipped_skins": {"brawler": "removed_skin_id"},
	}
	assert_true(m.apply_snapshot(data), "apply succeeds")
	assert_eq(m.equipped_skins.size(), 0,
		"unknown skin id dropped at load")


func test_apply_drops_equipped_skin_for_now_relocked() -> void:
	## Save written when brawler_onyx was unlocked, then reset_all() wiped
	## class_wins, then this loads. The equipped_skins entry would now
	## reference a locked skin. Trim at load so the live state is honest.
	var m: Node = _fresh_meta()
	var data: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"class_wins": {},
		"equipped_skins": {"brawler": "brawler_onyx"},
	}
	assert_true(m.apply_snapshot(data), "apply succeeds")
	assert_eq(m.equipped_skins.size(), 0,
		"relocked skin trimmed at load")


func test_apply_drops_equipped_skin_for_wrong_class() -> void:
	## A corrupted save with skin id mapped to the wrong class id should
	## drop the entry rather than leave a phantom equip.
	var m: Node = _fresh_meta()
	var data: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"class_wins": {"brawler": 5, "rogue": 5},
		"equipped_skins": {"brawler": "rogue_shadow"},
	}
	assert_true(m.apply_snapshot(data), "apply succeeds")
	assert_eq(m.equipped_skins.size(), 0,
		"wrong-class entry dropped at load")


# ── reset_all ──────────────────────────────────────────────────────────────

func test_reset_all_clears_class_wins_and_equipped_skins() -> void:
	## A dev reset must wipe both fields — otherwise the player would keep
	## their unlocked skin tints after explicitly asking for a reset.
	var m: Node = _fresh_meta()
	for i: int in range(3):
		m.record_run_end(18, 3, true, 0, "brawler")
	m.equip_skin("brawler_gilded")
	assert_eq(m.class_win_count("brawler"), 3, "pre-reset wins = 3")
	assert_eq(m.equipped_skins.size(), 1, "pre-reset equipped = 1")

	m.reset_all()
	assert_eq(m.class_win_count("brawler"), 0, "post-reset wins = 0")
	assert_eq(m.equipped_skins.size(), 0, "post-reset equipped empty")
	assert_eq(m.unlocked_skin_count(), 3,
		"post-reset only defaults unlocked")


# ── End-to-end win → unlock → equip → render loop ──────────────────────────

func test_full_loop_win_unlocks_equip_render() -> void:
	## The "actual win for Run 42" — a closed loop from win → unlock → equip
	## → equipped_skin_tint returns the new color. Without a live BattleScene
	## this is the headless equivalent of "you see your earned skin".
	var m: Node = _fresh_meta()
	# Start: only default available.
	assert_eq(m.equipped_skin_tint("brawler"), Color(1.0, 1.0, 1.0),
		"start: WHITE tint")
	assert_true(not m.is_skin_unlocked("brawler_onyx"),
		"start: onyx locked")

	# Bank a brawler win.
	m.record_run_end(18, 3, true, 1000, "brawler")
	assert_true(m.is_skin_unlocked("brawler_onyx"),
		"after win: onyx unlocked")
	# Player equips it from the MetaScreen.
	assert_true(m.equip_skin("brawler_onyx"),
		"equip succeeds")
	# Next BattleScene._build_encounter would read this tint.
	assert_eq(m.equipped_skin_tint("brawler"),
		Skins.tint_for("brawler_onyx"),
		"new tint reflects the equipped skin")
	# Other classes still render at default.
	assert_eq(m.equipped_skin_tint("rogue"), Color(1.0, 1.0, 1.0),
		"rogue still at default (WHITE)")


func test_full_loop_swap_skin_changes_tint() -> void:
	## A second swap mid-session — three wins, equip mastery, see the tint
	## change again. Models the player who keeps grinding the same class.
	var m: Node = _fresh_meta()
	for i: int in range(3):
		m.record_run_end(18, 3, true, 0, "brawler")
	m.equip_skin("brawler_onyx")
	assert_eq(m.equipped_skin_tint("brawler"),
		Skins.tint_for("brawler_onyx"),
		"onyx active")
	m.equip_skin("brawler_gilded")
	assert_eq(m.equipped_skin_tint("brawler"),
		Skins.tint_for("brawler_gilded"),
		"swapped to gilded")
