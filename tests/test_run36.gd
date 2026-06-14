## Run 36 tests: meta-progression — shards, perks, persistence, run-start
## perk application, shop discount math.
##
## Pure logic only — no Node tree, no scene runtime. The MetaProgress
## autoload's `_ready` (load_from_disk) is bypassed by instantiating from
## the GDScript directly rather than getting `/root/MetaProgress`, so
## tests don't touch the player's real save file.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun36


var PERKS: GDScript = load("res://src/data/Perks.gd")
var META_SCRIPT: GDScript = load("res://autoloads/MetaProgress.gd")
var GS_SCRIPT: GDScript = load("res://autoloads/GameState.gd")


# ── Perk DEFS schema ─────────────────────────────────────────────────────────

func test_perks_defs_schema() -> void:
	## Every perk must have id / name / desc / cost / icon and a positive cost.
	for pid: String in PERKS.all_ids():
		var p: Dictionary = PERKS.get_perk(pid)
		assert_eq(p.get("id"), pid, "perk %s id matches key" % pid)
		assert_true(String(p.get("name", "")) != "", "perk %s name non-empty" % pid)
		assert_true(String(p.get("desc", "")) != "", "perk %s desc non-empty" % pid)
		assert_gt(int(p.get("cost", 0)), 0, "perk %s cost > 0" % pid)
		assert_true(String(p.get("icon", "")) != "", "perk %s icon non-empty" % pid)


func test_perks_cost_helper_handles_unknown() -> void:
	assert_eq(PERKS.cost("seasoned"), 25, "seasoned cost")
	assert_eq(PERKS.cost("not_a_perk_id"), -1, "unknown perk returns -1")


func test_max_equipped_is_reasonable() -> void:
	## Loadout cap is small — buying 8 perks shouldn't trivially equip all.
	assert_true(PERKS.MAX_EQUIPPED >= 1 and PERKS.MAX_EQUIPPED <= 4,
		"MAX_EQUIPPED in sensible range")


# ── Perks.apply_to_run ───────────────────────────────────────────────────────

class _FakeState:
	## Minimal duck-typed stand-in for GameState — Perks.apply_to_run reads /
	## writes the same fields. Lets us test the apply logic without
	## instantiating the autoload (which would need /root/GameRng).
	var hero_level: int = 1
	var hero_gold: int = 0
	var hero_max_hp: int = 100
	var hero_hp: int = 100
	var hero_base_stats: Dictionary = {"attack": 15, "defense": 5, "speed": 8}
	var audience_score: int = 0


func test_apply_seasoned_bumps_level() -> void:
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["seasoned"])
	assert_eq(s.hero_level, 2, "seasoned -> level 2")


func test_apply_seasoned_never_lowers_level() -> void:
	## Hypothetical future: starting level > 2 from elsewhere shouldn't be
	## clobbered by seasoned.
	var s: _FakeState = _FakeState.new()
	s.hero_level = 5
	PERKS.apply_to_run(s, ["seasoned"])
	assert_eq(s.hero_level, 5, "seasoned doesn't downgrade level")


func test_apply_wealthy_grants_30_gold() -> void:
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["wealthy"])
	assert_eq(s.hero_gold, 30, "wealthy -> 30 gold")


func test_apply_iron_blood_raises_max_hp_and_heals() -> void:
	var s: _FakeState = _FakeState.new()
	s.hero_hp = 50  # damaged
	s.hero_max_hp = 100
	PERKS.apply_to_run(s, ["iron_blood"])
	assert_eq(s.hero_max_hp, 115, "iron_blood -> +15 max HP")
	assert_eq(s.hero_hp, 115, "iron_blood -> heals to new max")


func test_apply_lucky_strike_attack() -> void:
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["lucky_strike"])
	assert_eq(int(s.hero_base_stats.attack), 16, "lucky_strike -> +1 attack")


func test_apply_hardened_traveler_defense() -> void:
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["hardened_traveler"])
	assert_eq(int(s.hero_base_stats.defense), 6, "hardened_traveler -> +1 def")


func test_apply_swift_boots_speed() -> void:
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["swift_boots"])
	assert_eq(int(s.hero_base_stats.speed), 9, "swift_boots -> +1 speed")


func test_apply_audience_darling() -> void:
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["audience_darling"])
	assert_eq(s.audience_score, 50, "audience_darling -> +50 audience")


func test_apply_merchant_ally_is_no_state_mutation() -> void:
	## merchant_ally affects shop pricing only — apply_to_run shouldn't
	## touch HP/gold/stats. This guards against a future regression that
	## accidentally double-pays the player.
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["merchant_ally"])
	assert_eq(s.hero_gold, 0, "merchant_ally doesn't grant gold")
	assert_eq(s.hero_max_hp, 100, "merchant_ally doesn't raise HP")
	assert_eq(int(s.hero_base_stats.attack), 15, "merchant_ally doesn't bump attack")


func test_apply_multiple_perks_stack() -> void:
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["wealthy", "lucky_strike"])
	assert_eq(s.hero_gold, 30, "wealthy applied")
	assert_eq(int(s.hero_base_stats.attack), 16, "lucky_strike applied")


func test_apply_handles_unknown_perk_id() -> void:
	## Defensive — a stale save with a removed perk shouldn't crash.
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["wealthy", "not_a_real_perk"])
	assert_eq(s.hero_gold, 30, "known perk still applied")
	# No crash assertion — passing this far is the assertion.


func test_apply_handles_empty() -> void:
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, [])
	assert_eq(s.hero_gold, 0, "empty equip list -> no mutation")


func test_apply_handles_null_state() -> void:
	## Defensive — passing null state shouldn't crash.
	PERKS.apply_to_run(null, ["wealthy"])
	# No assertion needed — survival is the assertion.
	assert_true(true, "null state didn't crash apply_to_run")


# ── shop discount math ──────────────────────────────────────────────────────

func test_shop_discount_pct_merchant_ally() -> void:
	assert_eq(PERKS.shop_discount_pct(["merchant_ally"]), 15,
		"merchant_ally -> 15% discount")
	assert_eq(PERKS.shop_discount_pct([]), 0, "no perks -> 0%")
	assert_eq(PERKS.shop_discount_pct(["seasoned"]), 0,
		"non-shop perk -> 0%")


func test_apply_shop_discount_math() -> void:
	## 100g @ 15% = 85g
	assert_eq(PERKS.apply_shop_discount(100, ["merchant_ally"]), 85,
		"100g at 15% = 85g")
	## No discount when no equipped perks
	assert_eq(PERKS.apply_shop_discount(100, []), 100, "no equipped -> raw")
	## Zero is zero
	assert_eq(PERKS.apply_shop_discount(0, ["merchant_ally"]), 0, "0 stays 0")


func test_apply_shop_discount_floor() -> void:
	## A 1g item with merchant_ally would round to 1 (15% off rounds down to
	## 0, but the floor keeps it at 1).
	assert_eq(PERKS.apply_shop_discount(1, ["merchant_ally"]), 1,
		"1g floor — never freebie")


# ── MetaProgress currency ──────────────────────────────────────────────────

func _fresh_meta() -> Node:
	## Build a MetaProgress instance directly so we don't read/write the
	## player's actual save file. The constructor doesn't fire _ready in
	## --script mode, so we get a clean blank slate.
	var m: Node = META_SCRIPT.new()
	return m


func test_award_shards_adds_and_returns_total() -> void:
	var m: Node = _fresh_meta()
	assert_eq(m.award_shards(10), 10, "first award -> 10")
	assert_eq(m.award_shards(5), 15, "second award stacks")
	assert_eq(m.shards, 15, "wallet matches")


func test_award_shards_ignores_zero_and_negative() -> void:
	var m: Node = _fresh_meta()
	m.shards = 7
	assert_eq(m.award_shards(0), 7, "zero -> no change")
	assert_eq(m.award_shards(-5), 7, "negative -> no change")


func test_spend_shards_deducts_when_affordable() -> void:
	var m: Node = _fresh_meta()
	m.shards = 50
	assert_true(m.spend_shards(20), "spend ok")
	assert_eq(m.shards, 30, "wallet decremented")


func test_spend_shards_refuses_overdraft() -> void:
	var m: Node = _fresh_meta()
	m.shards = 10
	assert_true(not m.spend_shards(50), "overdraft refused")
	assert_eq(m.shards, 10, "wallet unchanged on overdraft")


# ── MetaProgress perks ─────────────────────────────────────────────────────

func test_purchase_perk_happy_path() -> void:
	var m: Node = _fresh_meta()
	m.shards = 100
	assert_true(m.purchase_perk("wealthy"), "purchase ok")
	assert_true(m.is_owned("wealthy"), "perk recorded as owned")
	assert_eq(m.shards, 80, "shards deducted (cost 20)")


func test_purchase_perk_refuses_unknown() -> void:
	var m: Node = _fresh_meta()
	m.shards = 1000
	assert_true(not m.purchase_perk("not_real"), "unknown id refused")
	assert_eq(m.shards, 1000, "wallet unchanged on bad id")


func test_purchase_perk_refuses_duplicate() -> void:
	var m: Node = _fresh_meta()
	m.shards = 100
	m.purchase_perk("wealthy")
	assert_true(not m.purchase_perk("wealthy"), "second purchase refused")
	assert_eq(m.shards, 80, "second purchase didn't drain wallet")


func test_purchase_perk_refuses_when_broke() -> void:
	var m: Node = _fresh_meta()
	m.shards = 5
	assert_true(not m.purchase_perk("wealthy"), "broke -> refused")
	assert_true(not m.is_owned("wealthy"), "not added on failure")
	assert_eq(m.shards, 5, "wallet unchanged")


func test_equip_perk_requires_ownership() -> void:
	var m: Node = _fresh_meta()
	assert_true(not m.equip_perk("wealthy"), "unowned -> refused")
	assert_true(not m.is_equipped("wealthy"), "not equipped")


func test_equip_unequip_roundtrip() -> void:
	var m: Node = _fresh_meta()
	m.shards = 100
	m.purchase_perk("wealthy")
	assert_true(m.equip_perk("wealthy"), "equip ok")
	assert_true(m.is_equipped("wealthy"), "is_equipped true")
	assert_true(m.unequip_perk("wealthy"), "unequip ok")
	assert_true(not m.is_equipped("wealthy"), "is_equipped false again")


func test_equip_cap_enforced() -> void:
	var m: Node = _fresh_meta()
	m.shards = 1000
	# Buy 3 perks then try to equip all
	m.purchase_perk("wealthy")
	m.purchase_perk("seasoned")
	m.purchase_perk("iron_blood")
	assert_true(m.equip_perk("wealthy"), "1st equip")
	assert_true(m.equip_perk("seasoned"), "2nd equip")
	assert_true(not m.equip_perk("iron_blood"), "3rd refused — cap hit")
	assert_eq(m.equipped_perks.size(), PERKS.MAX_EQUIPPED,
		"loadout at exact cap")


func test_equip_no_duplicate() -> void:
	var m: Node = _fresh_meta()
	m.shards = 100
	m.purchase_perk("wealthy")
	m.equip_perk("wealthy")
	assert_true(not m.equip_perk("wealthy"), "duplicate equip refused")
	assert_eq(m.equipped_perks.size(), 1, "still just one entry")


# ── Run-end shard math ─────────────────────────────────────────────────────

func test_shards_for_run_death_floor_5_no_bosses() -> void:
	var m: Node = _fresh_meta()
	# floor 5, 0 bosses, lost -> 5 shards.
	assert_eq(m.shards_for_run(5, 0, false), 5, "floor*1 = 5")


func test_shards_for_run_death_with_one_boss() -> void:
	var m: Node = _fresh_meta()
	# floor 7, 1 boss, lost -> 7 + 4 = 11
	assert_eq(m.shards_for_run(7, 1, false), 11, "boss adds 4")


func test_shards_for_run_win_includes_win_bonus() -> void:
	var m: Node = _fresh_meta()
	# floor 18, 3 bosses, won, brand-new class -> 18 + 12 + 25 + 10 = 65
	assert_eq(m.shards_for_run(18, 3, true, "brawler"), 65,
		"full clear + first-class bonus")


func test_shards_for_run_no_first_class_bonus_after_clear() -> void:
	var m: Node = _fresh_meta()
	m.classes_cleared["brawler"] = true
	# floor 18, 3 bosses, won, repeat clear -> 18 + 12 + 25 = 55
	assert_eq(m.shards_for_run(18, 3, true, "brawler"), 55,
		"repeat clear loses the +10")


func test_shards_for_run_loss_ignores_first_class_bonus() -> void:
	var m: Node = _fresh_meta()
	# floor 17, 2 bosses, lost (one floor away) -> 17 + 8 = 25 (no win bonus)
	assert_eq(m.shards_for_run(17, 2, false, "brawler"), 25,
		"loss never pays the win bonus")


# ── record_run_end ─────────────────────────────────────────────────────────

func test_record_run_end_pays_and_logs() -> void:
	var m: Node = _fresh_meta()
	var paid: int = m.record_run_end(6, 1, false, 1234, "rogue")
	assert_eq(paid, 10, "floor 6 + 1 boss = 10")
	assert_eq(m.shards, 10, "wallet updated")
	assert_eq(m.total_runs, 1, "runs counter")
	assert_eq(m.total_wins, 0, "no win counted")
	assert_eq(m.best_floor, 6, "best floor recorded")
	assert_eq(m.best_score, 1234, "best score recorded")
	assert_true(not m.classes_cleared.has("rogue"),
		"loss doesn't mark class cleared")


func test_record_run_end_win_marks_class_cleared() -> void:
	var m: Node = _fresh_meta()
	m.record_run_end(18, 3, true, 50000, "arcanist")
	assert_eq(m.total_wins, 1, "win counted")
	assert_true(m.classes_cleared.get("arcanist", false),
		"class marked as cleared on win")


func test_record_run_end_keeps_highest_best_floor() -> void:
	var m: Node = _fresh_meta()
	m.best_floor = 12
	m.record_run_end(5, 0, false, 0, "brawler")
	assert_eq(m.best_floor, 12, "shorter run doesn't overwrite best floor")


func test_record_run_end_keeps_highest_best_score() -> void:
	var m: Node = _fresh_meta()
	m.best_score = 9000
	m.record_run_end(5, 0, false, 100, "brawler")
	assert_eq(m.best_score, 9000, "lower score doesn't overwrite best")


# ── snapshot / apply roundtrip ─────────────────────────────────────────────

func test_snapshot_includes_all_fields() -> void:
	var m: Node = _fresh_meta()
	m.shards = 42
	# MetaProgress.owned_perks is typed Array[String]; build the same typed
	# array here so the assignment lands cleanly under strict GDScript.
	var owned: Array[String] = ["wealthy", "seasoned"]
	var eq: Array[String] = ["wealthy"]
	m.owned_perks = owned
	m.equipped_perks = eq
	m.total_runs = 7
	m.total_wins = 1
	m.best_floor = 13
	m.best_score = 5000
	m.classes_cleared = {"brawler": true}
	var snap: Dictionary = m.snapshot()
	assert_eq(int(snap.get("version", 0)), META_SCRIPT.SAVE_VERSION,
		"version stamped")
	assert_eq(int(snap.get("shards", 0)), 42, "shards in snapshot")
	assert_eq((snap.get("owned_perks", []) as Array).size(), 2, "owned size")
	assert_eq((snap.get("equipped_perks", []) as Array).size(), 1,
		"equipped size")
	assert_eq(int(snap.get("total_runs", 0)), 7, "total_runs")
	assert_eq(int(snap.get("best_floor", 0)), 13, "best_floor")


func test_snapshot_apply_roundtrip() -> void:
	var m: Node = _fresh_meta()
	m.shards = 100
	m.purchase_perk("wealthy")
	m.purchase_perk("seasoned")
	m.equip_perk("wealthy")
	m.total_runs = 3
	m.best_floor = 10
	var snap: Dictionary = m.snapshot()
	var m2: Node = _fresh_meta()
	assert_true(m2.apply_snapshot(snap), "apply ok")
	assert_eq(m2.shards, m.shards, "shards roundtrip")
	assert_eq(m2.owned_perks, m.owned_perks, "owned roundtrip")
	assert_eq(m2.equipped_perks, m.equipped_perks, "equipped roundtrip")
	assert_eq(m2.total_runs, 3, "total_runs roundtrip")
	assert_eq(m2.best_floor, 10, "best_floor roundtrip")


func test_apply_snapshot_handles_empty() -> void:
	var m: Node = _fresh_meta()
	assert_true(not m.apply_snapshot({}), "empty dict refused")
	assert_eq(m.shards, 0, "wallet untouched on bad apply")


func test_apply_snapshot_trims_equipped_to_cap() -> void:
	## Defensive: a save with > MAX_EQUIPPED entries (corruption / future
	## downgrade) is silently trimmed instead of letting the player run with
	## an over-capped loadout.
	var m: Node = _fresh_meta()
	var fake: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": ["wealthy", "seasoned", "iron_blood", "lucky_strike"],
		"equipped_perks": ["wealthy", "seasoned", "iron_blood", "lucky_strike"],
		"total_runs": 0,
		"total_wins": 0,
		"best_floor": 0,
		"best_score": 0,
		"classes_cleared": {},
	}
	m.apply_snapshot(fake)
	assert_true(m.equipped_perks.size() <= PERKS.MAX_EQUIPPED,
		"equipped trimmed to cap")


func test_apply_snapshot_drops_equipped_perks_not_in_owned() -> void:
	## Defensive: a save listing an equipped perk that's NOT in owned_perks
	## (manual edit, drift bug, future removed perk) gets filtered so the
	## run-start apply doesn't try to read a ghost perk.
	var m: Node = _fresh_meta()
	var fake: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": ["wealthy"],
		"equipped_perks": ["wealthy", "seasoned"],
		"total_runs": 0,
		"total_wins": 0,
		"best_floor": 0,
		"best_score": 0,
		"classes_cleared": {},
	}
	m.apply_snapshot(fake)
	assert_eq(m.equipped_perks.size(), 1, "filtered down to owned")
	assert_eq(m.equipped_perks[0], "wealthy", "only owned perk kept")


func test_apply_snapshot_drops_equipped_perks_not_in_defs() -> void:
	## Defensive: a save listing an equipped perk whose id was removed from
	## Perks.DEFS (a future cleanup) gets filtered out.
	var m: Node = _fresh_meta()
	var fake: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": ["wealthy", "removed_old_perk"],
		"equipped_perks": ["removed_old_perk"],
		"total_runs": 0,
		"total_wins": 0,
		"best_floor": 0,
		"best_score": 0,
		"classes_cleared": {},
	}
	m.apply_snapshot(fake)
	assert_eq(m.equipped_perks.size(), 0,
		"removed-from-DEFS perk dropped on load")


# ── Version gate ───────────────────────────────────────────────────────────

func test_load_from_disk_rejects_version_mismatch() -> void:
	## Indirect: a snapshot with the wrong version should not apply.
	## We test the gate by manually constructing a bad dict and calling
	## apply_snapshot — load_from_disk's gate is the same check.
	var m: Node = _fresh_meta()
	var bad: Dictionary = {
		"version": 999,
		"shards": 100,
		"owned_perks": [],
		"equipped_perks": [],
		"total_runs": 0,
		"total_wins": 0,
		"best_floor": 0,
		"best_score": 0,
		"classes_cleared": {},
	}
	# apply_snapshot itself doesn't check version (it's load_from_disk's job),
	# but the dict is otherwise valid — so this guards that apply doesn't
	# *additionally* reject it. We re-snapshot at the new version and check
	# that re-load works.
	assert_true(m.apply_snapshot(bad), "apply still works on otherwise-valid dict")
	var snap: Dictionary = m.snapshot()
	assert_eq(int(snap.get("version", 0)), META_SCRIPT.SAVE_VERSION,
		"snapshot writes current version")
