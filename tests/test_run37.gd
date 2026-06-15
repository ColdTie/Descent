## Run 37 tests: achievement → meta-shards loop + lifetime achievement
## tracking.
##
## Pure logic only — no Node tree, no scene runtime. We instantiate
## MetaProgress directly via GDScript.new() (matching the Run 36 pattern)
## so the autoload's `_ready` (load_from_disk) is bypassed and we never
## touch the player's real meta save file.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun37


var META_SCRIPT: GDScript = load("res://autoloads/MetaProgress.gd")
var ACH_SCRIPT: GDScript = load("res://autoloads/Achievements.gd")


func _fresh_meta() -> Node:
	return META_SCRIPT.new()


# ── Lifetime achievement bookkeeping ─────────────────────────────────────────

func test_lifetime_achievements_defaults_empty() -> void:
	var m: Node = _fresh_meta()
	assert_eq(m.total_achievements_unlocked_lifetime(), 0,
		"fresh meta -> 0 lifetime achievements")
	assert_true(not m.is_achievement_unlocked_lifetime("first_blood"),
		"never-unlocked id -> false")


func test_award_for_achievement_first_time_pays_shards() -> void:
	var m: Node = _fresh_meta()
	var paid: int = m.award_for_achievement("first_blood")
	assert_eq(paid, META_SCRIPT.SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK,
		"first unlock pays the constant")
	assert_eq(m.shards, META_SCRIPT.SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK,
		"wallet credited")
	assert_true(m.is_achievement_unlocked_lifetime("first_blood"),
		"id marked unlocked-lifetime")


func test_award_for_achievement_second_time_pays_nothing() -> void:
	var m: Node = _fresh_meta()
	m.award_for_achievement("first_blood")
	var second: int = m.award_for_achievement("first_blood")
	assert_eq(second, 0, "duplicate unlock pays 0")
	assert_eq(m.shards, META_SCRIPT.SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK,
		"wallet unchanged on repeat")


func test_award_for_achievement_handles_blank_id() -> void:
	## Defensive: a blank id should not silently bank a phantom unlock.
	var m: Node = _fresh_meta()
	assert_eq(m.award_for_achievement(""), 0, "blank id -> 0")
	assert_eq(m.shards, 0, "wallet untouched on bad input")
	assert_eq(m.total_achievements_unlocked_lifetime(), 0,
		"no phantom entry")


func test_award_for_achievement_multiple_ids_accumulate() -> void:
	var m: Node = _fresh_meta()
	m.award_for_achievement("first_blood")
	m.award_for_achievement("boss_slayer")
	m.award_for_achievement("untouchable")
	assert_eq(m.total_achievements_unlocked_lifetime(), 3,
		"three distinct unlocks tracked")
	assert_eq(m.shards, 3 * META_SCRIPT.SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK,
		"three payouts banked")


func test_award_for_achievement_unknown_id_still_pays_once() -> void:
	## Achievements.unlock is the gate that rejects unknown ids (push_warning),
	## but MetaProgress should not silently reject — that would lose payment
	## if a new achievement id arrives from a future update. We pay once for
	## any non-blank id; the lifetime mark gates repeats.
	var m: Node = _fresh_meta()
	var paid: int = m.award_for_achievement("future_unreleased_id")
	assert_eq(paid, META_SCRIPT.SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK,
		"non-blank id pays")
	assert_eq(m.award_for_achievement("future_unreleased_id"), 0,
		"second time still 0")


func test_is_achievement_unlocked_lifetime_negative_paths() -> void:
	var m: Node = _fresh_meta()
	assert_true(not m.is_achievement_unlocked_lifetime("nothing"),
		"unknown -> false")
	m.award_for_achievement("first_blood")
	assert_true(m.is_achievement_unlocked_lifetime("first_blood"),
		"unlocked -> true")
	assert_true(not m.is_achievement_unlocked_lifetime("untouchable"),
		"other still false")


# ── snapshot / apply roundtrip ───────────────────────────────────────────────

func test_snapshot_includes_lifetime_achievements() -> void:
	var m: Node = _fresh_meta()
	m.award_for_achievement("first_blood")
	m.award_for_achievement("boss_slayer")
	var snap: Dictionary = m.snapshot()
	assert_true(snap.has("lifetime_achievements"),
		"snapshot carries lifetime_achievements")
	var la: Dictionary = snap.get("lifetime_achievements", {})
	assert_eq(la.size(), 2, "two ids in snapshot")
	assert_true(la.has("first_blood"), "first_blood key")
	assert_true(la.has("boss_slayer"), "boss_slayer key")


func test_apply_snapshot_restores_lifetime_achievements() -> void:
	var m1: Node = _fresh_meta()
	m1.award_for_achievement("first_blood")
	m1.award_for_achievement("lava_lord")
	var snap: Dictionary = m1.snapshot()
	var m2: Node = _fresh_meta()
	assert_true(m2.apply_snapshot(snap), "apply ok")
	assert_eq(m2.total_achievements_unlocked_lifetime(), 2,
		"roundtripped count")
	assert_true(m2.is_achievement_unlocked_lifetime("first_blood"),
		"first_blood restored")
	assert_true(m2.is_achievement_unlocked_lifetime("lava_lord"),
		"lava_lord restored")


func test_apply_snapshot_pre_run37_save_defaults_to_empty() -> void:
	## Defensive: a save dict missing `lifetime_achievements` (any pre-Run-37
	## snapshot) should not blow up — apply tolerates the missing field with
	## an empty default so the next achievement unlock still pays out.
	var m: Node = _fresh_meta()
	var older: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 50,
		"owned_perks": ["wealthy"],
		"equipped_perks": [],
		"total_runs": 3,
		"total_wins": 0,
		"best_floor": 8,
		"best_score": 1200,
		"classes_cleared": {},
		# NOTE: deliberately no lifetime_achievements key
	}
	assert_true(m.apply_snapshot(older), "pre-Run-37 dict still applies")
	assert_eq(m.total_achievements_unlocked_lifetime(), 0,
		"missing field -> empty default")
	# Subsequent unlock should pay out (lifetime mark is fresh).
	var paid: int = m.award_for_achievement("first_blood")
	assert_eq(paid, META_SCRIPT.SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK,
		"first_blood pays after applying older save")


func test_apply_snapshot_lifetime_handles_malformed_entries() -> void:
	## Defensive: a snapshot whose lifetime_achievements contains non-bool
	## values should still be readable; bool() coerces truthy values.
	var m: Node = _fresh_meta()
	var dirty: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": [],
		"equipped_perks": [],
		"total_runs": 0,
		"total_wins": 0,
		"best_floor": 0,
		"best_score": 0,
		"classes_cleared": {},
		"lifetime_achievements": {"first_blood": true, "boss_slayer": 1, "stale": 0},
	}
	assert_true(m.apply_snapshot(dirty), "applies")
	assert_true(m.is_achievement_unlocked_lifetime("first_blood"),
		"true bool preserved")
	assert_true(m.is_achievement_unlocked_lifetime("boss_slayer"),
		"truthy int coerced")
	assert_true(not m.is_achievement_unlocked_lifetime("stale"),
		"falsy int dropped")


# ── reset_all ────────────────────────────────────────────────────────────────

func test_reset_all_clears_lifetime_achievements() -> void:
	var m: Node = _fresh_meta()
	m.award_for_achievement("first_blood")
	m.award_for_achievement("boss_slayer")
	m.reset_all()
	assert_eq(m.total_achievements_unlocked_lifetime(), 0,
		"reset clears lifetime ledger")
	assert_eq(m.shards, 0, "reset clears shards")


# ── Achievements DEFS coverage ───────────────────────────────────────────────

func test_every_known_achievement_can_pay_shards_once() -> void:
	## Walk the entire Achievements.DEFS dict — every id should be payable
	## exactly once via MetaProgress. Locks in the contract that adding a
	## new achievement automatically participates in the loop without code
	## changes here.
	var m: Node = _fresh_meta()
	var all_ids: Array = ACH_SCRIPT.DEFS.keys()
	assert_gt(all_ids.size(), 0, "at least one achievement defined")
	for raw_id: Variant in all_ids:
		var id: String = String(raw_id)
		var first: int = m.award_for_achievement(id)
		var second: int = m.award_for_achievement(id)
		assert_eq(first, META_SCRIPT.SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK,
			"%s first unlock paid" % id)
		assert_eq(second, 0, "%s second unlock = 0" % id)
	assert_eq(m.total_achievements_unlocked_lifetime(), all_ids.size(),
		"all known ids tracked exactly once")
	assert_eq(m.shards,
		all_ids.size() * META_SCRIPT.SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK,
		"wallet = ids * per-unlock constant")


# ── Constant sanity ─────────────────────────────────────────────────────────

func test_shards_per_achievement_is_positive() -> void:
	assert_gt(META_SCRIPT.SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK, 0,
		"per-unlock reward is positive")


# ── Interaction with existing shard payout ──────────────────────────────────

func test_achievement_payout_stacks_with_run_end_payout() -> void:
	## Mid-run achievement payouts and end-of-run record_run_end payouts
	## should accumulate cleanly — neither path resets the other.
	var m: Node = _fresh_meta()
	m.award_for_achievement("first_blood")
	m.award_for_achievement("boss_slayer")
	var ach_total: int = 2 * META_SCRIPT.SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK
	assert_eq(m.shards, ach_total, "achievement payouts banked")
	var run_paid: int = m.record_run_end(6, 1, false, 0, "brawler")
	assert_eq(m.shards, ach_total + run_paid,
		"run-end payout stacks on top of achievement payouts")
