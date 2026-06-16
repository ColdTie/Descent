## Run 38 tests: milestone-gated perks + lifetime boss tracking.
##
## Pure logic only — no Node tree, no scene runtime. MetaProgress is
## instantiated via GDScript.new() (matching the Run 36/37 pattern) so
## the autoload's `_ready` (load_from_disk) is bypassed and we never
## touch the player's real meta save file.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun38


var PERKS: GDScript = load("res://src/data/Perks.gd")
var META_SCRIPT: GDScript = load("res://autoloads/MetaProgress.gd")


func _fresh_meta() -> Node:
	return META_SCRIPT.new()


# ── New perk DEFS schema ─────────────────────────────────────────────────────

func test_new_perks_exist() -> void:
	## Lock in the Run 38 ids so a future refactor that drops one is caught
	## by tests instead of by a confused player.
	for pid: String in ["deep_diver", "bossbane", "steady_step",
			"war_veteran", "champions_bond"]:
		assert_true(PERKS.DEFS.has(pid), "DEFS has %s" % pid)
		var p: Dictionary = PERKS.get_perk(pid)
		assert_eq(p.get("id"), pid, "%s id matches key" % pid)
		assert_true(String(p.get("name", "")) != "", "%s name non-empty" % pid)
		assert_true(String(p.get("desc", "")) != "", "%s desc non-empty" % pid)
		assert_gt(int(p.get("cost", 0)), 0, "%s cost > 0" % pid)


func test_new_perks_have_distinct_costs() -> void:
	## Costs should not collide with the Run-36 set in a way that makes the
	## new perks look like a sidegrade. Each new perk sits at least at the
	## existing "merchant_ally" cost (45) since it's a milestone or pure
	## upgrade, except `steady_step` (no milestone, modest stat bump).
	assert_gt(PERKS.cost("deep_diver"), 40, "deep_diver above mid-tier")
	assert_gt(PERKS.cost("bossbane"), 40, "bossbane above mid-tier")
	assert_gt(PERKS.cost("war_veteran"),
		PERKS.cost("seasoned"), "war_veteran > seasoned (its baseline)")
	assert_gt(PERKS.cost("champions_bond"), 70, "champions_bond is capstone")


# ── Requirement helpers ─────────────────────────────────────────────────────

func test_requirement_returns_dict_for_gated_perks() -> void:
	var deep: Dictionary = PERKS.requirement("deep_diver")
	assert_eq(deep.get("type"), "best_floor", "deep_diver type")
	assert_eq(deep.get("count"), 9, "deep_diver count")
	var boss: Dictionary = PERKS.requirement("bossbane")
	assert_eq(boss.get("type"), "bosses_slain", "bossbane type")
	assert_eq(boss.get("count"), 3, "bossbane count")
	var war: Dictionary = PERKS.requirement("war_veteran")
	assert_eq(war.get("type"), "total_wins", "war_veteran type")
	assert_eq(war.get("count"), 1, "war_veteran count")
	var bond: Dictionary = PERKS.requirement("champions_bond")
	assert_eq(bond.get("type"), "total_wins", "champions_bond type")
	assert_eq(bond.get("count"), 1, "champions_bond count")


func test_requirement_empty_for_ungated_perks() -> void:
	## Run-36 perks must remain ungated — older saves with these owned
	## should still be valid without any milestone awareness on apply.
	for pid: String in ["seasoned", "wealthy", "iron_blood", "lucky_strike",
			"merchant_ally", "audience_darling", "hardened_traveler",
			"swift_boots", "steady_step"]:
		assert_true(PERKS.requirement(pid).is_empty(),
			"%s has no requirement" % pid)


func test_requirement_empty_for_unknown_perk_id() -> void:
	## Defensive — `requirement` is read from the MetaScreen on every card
	## render, so an unknown id must not crash.
	assert_true(PERKS.requirement("not_a_real_perk").is_empty(),
		"unknown id -> empty dict")


func test_has_milestone_predicate() -> void:
	assert_true(PERKS.has_milestone("deep_diver"), "deep_diver is gated")
	assert_true(PERKS.has_milestone("bossbane"), "bossbane is gated")
	assert_true(not PERKS.has_milestone("wealthy"), "wealthy is not gated")
	assert_true(not PERKS.has_milestone("steady_step"),
		"steady_step is not gated")


func test_is_milestone_unlocked_when_threshold_met() -> void:
	## Met exactly + exceeded both unlock.
	assert_true(PERKS.is_milestone_unlocked("deep_diver",
		{"best_floor": 9}), "exact threshold unlocks")
	assert_true(PERKS.is_milestone_unlocked("deep_diver",
		{"best_floor": 14}), "exceeding unlocks")
	assert_true(PERKS.is_milestone_unlocked("bossbane",
		{"bosses_slain": 3}), "boss threshold unlocks")


func test_is_milestone_unlocked_below_threshold_locked() -> void:
	assert_true(not PERKS.is_milestone_unlocked("deep_diver",
		{"best_floor": 8}), "floor 8 -> locked")
	assert_true(not PERKS.is_milestone_unlocked("bossbane",
		{"bosses_slain": 0}), "0 bosses -> locked")
	assert_true(not PERKS.is_milestone_unlocked("war_veteran",
		{"total_wins": 0}), "0 wins -> locked")


func test_is_milestone_unlocked_passes_for_ungated() -> void:
	## Empty stats dict must still pass for ungated perks — the player
	## should be able to buy `wealthy` from the very first run.
	assert_true(PERKS.is_milestone_unlocked("wealthy", {}),
		"ungated perk passes")
	assert_true(PERKS.is_milestone_unlocked("steady_step", {}),
		"steady_step passes even with no stats")


func test_is_milestone_unlocked_handles_null_stats() -> void:
	## Defensive — caller passing null shouldn't crash. Ungated perks pass,
	## gated perks fail closed.
	assert_true(PERKS.is_milestone_unlocked("wealthy", {}),
		"ungated + empty dict passes")
	assert_true(not PERKS.is_milestone_unlocked("deep_diver", null),
		"gated + null fails closed")


func test_is_milestone_unlocked_unknown_id_is_unlocked() -> void:
	## Unknown id -> empty requirement -> unlocked. The purchase path's
	## "unknown id" gate elsewhere refuses the buy; this helper just
	## reports the gate status defensively.
	assert_true(PERKS.is_milestone_unlocked("not_a_real_perk", {}),
		"unknown id -> no gate -> unlocked")


func test_requirement_text_renders_human_readable() -> void:
	assert_eq(PERKS.requirement_text("deep_diver"),
		"Reach floor 9 in any run", "deep_diver text")
	assert_eq(PERKS.requirement_text("bossbane"),
		"Slay 3 bosses (lifetime)", "bossbane text")
	assert_eq(PERKS.requirement_text("war_veteran"),
		"Win a run (any class)", "war_veteran text (count=1 special-cased)")
	assert_eq(PERKS.requirement_text("wealthy"), "",
		"ungated -> empty string")


# ── apply_to_run for new perks ──────────────────────────────────────────────

class _FakeState:
	## Same shape as the Run-36 _FakeState — Perks.apply_to_run reads/writes
	## the same fields. Kept local so the test file stands alone.
	var hero_level: int = 1
	var hero_gold: int = 0
	var hero_max_hp: int = 100
	var hero_hp: int = 100
	var hero_base_stats: Dictionary = {"attack": 15, "defense": 5, "speed": 8}
	var audience_score: int = 0


func test_apply_deep_diver_grants_max_hp_and_heals() -> void:
	var s: _FakeState = _FakeState.new()
	s.hero_hp = 60
	PERKS.apply_to_run(s, ["deep_diver"])
	assert_eq(s.hero_max_hp, 120, "+20 max HP")
	assert_eq(s.hero_hp, 120, "healed to new max")


func test_apply_bossbane_adds_attack() -> void:
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["bossbane"])
	assert_eq(int(s.hero_base_stats.attack), 17, "+2 attack")


func test_apply_steady_step_combo() -> void:
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["steady_step"])
	assert_eq(s.hero_max_hp, 105, "+5 max HP")
	assert_eq(int(s.hero_base_stats.speed), 9, "+1 speed")
	# Defense stays the same — steady_step is HP/SPD only.
	assert_eq(int(s.hero_base_stats.defense), 5, "defense untouched")


func test_apply_war_veteran_sets_level_3() -> void:
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["war_veteran"])
	assert_eq(s.hero_level, 3, "war_veteran -> level 3")


func test_apply_war_veteran_never_lowers_level() -> void:
	## Defensive: if some future perk also bumps level, war_veteran shouldn't
	## clobber a higher starting level — same idiom as seasoned.
	var s: _FakeState = _FakeState.new()
	s.hero_level = 5
	PERKS.apply_to_run(s, ["war_veteran"])
	assert_eq(s.hero_level, 5, "war_veteran doesn't downgrade level")


func test_apply_champions_bond_capstone() -> void:
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["champions_bond"])
	assert_eq(s.hero_max_hp, 115, "+15 max HP")
	assert_eq(s.hero_hp, 115, "healed to new max")
	assert_eq(int(s.hero_base_stats.attack), 16, "+1 attack")
	assert_eq(int(s.hero_base_stats.defense), 6, "+1 defense")
	assert_eq(s.hero_gold, 25, "+25 gold")


func test_apply_champions_bond_stacks_with_steady_step() -> void:
	## Two new perks equipped together — within MAX_EQUIPPED — should
	## stack additively, just like the Run-36 perks do.
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["steady_step", "champions_bond"])
	assert_eq(s.hero_max_hp, 120, "+5 (steady) +15 (bond) = +20")
	assert_eq(int(s.hero_base_stats.speed), 9, "+1 speed from steady_step")
	assert_eq(int(s.hero_base_stats.attack), 16, "+1 attack from bond")
	assert_eq(s.hero_gold, 25, "+25 gold from bond")


func test_war_veteran_seasoned_stack_picks_higher_level() -> void:
	## war_veteran (level 3) + seasoned (level 2) -> level 3, no double-dip.
	var s: _FakeState = _FakeState.new()
	PERKS.apply_to_run(s, ["seasoned", "war_veteran"])
	assert_eq(s.hero_level, 3, "max(2, 3) = 3")


# ── MetaProgress milestone gate ─────────────────────────────────────────────

func test_lifetime_stats_reads_meta_fields() -> void:
	var m: Node = _fresh_meta()
	m.best_floor = 12
	m.total_wins = 2
	m.lifetime_bosses_slain = 5
	var stats: Dictionary = m.lifetime_stats()
	assert_eq(int(stats.get("best_floor")), 12, "best_floor exposed")
	assert_eq(int(stats.get("total_wins")), 2, "total_wins exposed")
	assert_eq(int(stats.get("bosses_slain")), 5,
		"lifetime_bosses_slain mapped to 'bosses_slain' key")


func test_is_perk_milestone_unlocked_uses_meta_stats() -> void:
	var m: Node = _fresh_meta()
	# Fresh meta — no progress yet. Every milestone perk should be locked.
	assert_true(not m.is_perk_milestone_unlocked("deep_diver"),
		"fresh meta -> deep_diver locked")
	assert_true(not m.is_perk_milestone_unlocked("bossbane"),
		"fresh meta -> bossbane locked")
	assert_true(not m.is_perk_milestone_unlocked("war_veteran"),
		"fresh meta -> war_veteran locked")
	# Ungated perks should always be unlocked.
	assert_true(m.is_perk_milestone_unlocked("wealthy"),
		"fresh meta -> wealthy unlocked")
	# Bump the relevant stat — perk should flip.
	m.best_floor = 9
	assert_true(m.is_perk_milestone_unlocked("deep_diver"),
		"best_floor 9 -> deep_diver unlocked")


func test_purchase_perk_refuses_milestone_locked() -> void:
	var m: Node = _fresh_meta()
	m.shards = 1000  # plenty of shards
	assert_true(not m.purchase_perk("deep_diver"),
		"locked perk purchase refused")
	assert_eq(m.shards, 1000, "wallet untouched on locked refuse")
	assert_true(not m.is_owned("deep_diver"), "perk not owned")


func test_purchase_perk_succeeds_after_milestone_met() -> void:
	var m: Node = _fresh_meta()
	m.shards = 1000
	m.best_floor = 9
	assert_true(m.purchase_perk("deep_diver"), "purchase allowed after unlock")
	assert_true(m.is_owned("deep_diver"), "perk owned")
	assert_eq(m.shards, 1000 - PERKS.cost("deep_diver"), "shards deducted")


# ── lifetime_bosses_slain tracking ──────────────────────────────────────────

func test_lifetime_bosses_slain_defaults_to_zero() -> void:
	var m: Node = _fresh_meta()
	assert_eq(m.lifetime_bosses_slain, 0, "fresh meta -> 0 bosses")


func test_record_run_end_accumulates_bosses() -> void:
	var m: Node = _fresh_meta()
	m.record_run_end(7, 1, false, 0, "brawler")
	assert_eq(m.lifetime_bosses_slain, 1, "1 boss banked")
	m.record_run_end(12, 2, false, 0, "rogue")
	assert_eq(m.lifetime_bosses_slain, 3, "3 lifetime bosses")
	m.record_run_end(18, 3, true, 5000, "arcanist")
	assert_eq(m.lifetime_bosses_slain, 6, "6 lifetime bosses after full clear")


func test_record_run_end_ignores_negative_boss_count() -> void:
	## Defensive — a caller passing -1 (a bug) shouldn't decrement the
	## lifetime tally.
	var m: Node = _fresh_meta()
	m.lifetime_bosses_slain = 5
	m.record_run_end(3, -1, false, 0, "brawler")
	assert_eq(m.lifetime_bosses_slain, 5, "negative ignored")


func test_record_run_end_bosses_unlock_bossbane() -> void:
	## End-to-end: a run that crosses the bossbane threshold flips the gate.
	var m: Node = _fresh_meta()
	assert_true(not m.is_perk_milestone_unlocked("bossbane"),
		"locked at start")
	m.record_run_end(12, 3, false, 0, "rogue")
	assert_true(m.is_perk_milestone_unlocked("bossbane"),
		"unlocked after 3 lifetime bosses")


# ── snapshot / apply roundtrip ──────────────────────────────────────────────

func test_snapshot_includes_lifetime_bosses_slain() -> void:
	var m: Node = _fresh_meta()
	m.lifetime_bosses_slain = 7
	var snap: Dictionary = m.snapshot()
	assert_eq(int(snap.get("lifetime_bosses_slain", -1)), 7,
		"field present in snapshot")


func test_snapshot_apply_roundtrip_carries_lifetime_bosses() -> void:
	var m: Node = _fresh_meta()
	m.lifetime_bosses_slain = 4
	var snap: Dictionary = m.snapshot()
	var m2: Node = _fresh_meta()
	assert_true(m2.apply_snapshot(snap), "apply ok")
	assert_eq(m2.lifetime_bosses_slain, 4, "roundtrip preserves count")


func test_apply_snapshot_pre_run38_save_defaults_to_zero() -> void:
	## A meta save written before Run 38 won't carry the new field. The
	## apply path should default it to 0 instead of leaving the previous
	## instance value or crashing.
	var m: Node = _fresh_meta()
	m.lifetime_bosses_slain = 99  # stale instance value
	var pre_38_save: Dictionary = {
		"version": META_SCRIPT.SAVE_VERSION,
		"shards": 0,
		"owned_perks": [],
		"equipped_perks": [],
		"total_runs": 0,
		"total_wins": 0,
		"best_floor": 0,
		"best_score": 0,
		"classes_cleared": {},
		# no lifetime_bosses_slain key on purpose
	}
	assert_true(m.apply_snapshot(pre_38_save), "legacy save loads cleanly")
	assert_eq(m.lifetime_bosses_slain, 0,
		"missing field defaults to 0 (not stale 99)")


func test_reset_all_clears_lifetime_bosses() -> void:
	var m: Node = _fresh_meta()
	m.lifetime_bosses_slain = 12
	m.reset_all()
	assert_eq(m.lifetime_bosses_slain, 0, "reset wipes the counter")


# ── End-to-end milestone walkthrough ────────────────────────────────────────

func test_milestone_walkthrough_unlocks_each_perk() -> void:
	## Simulate the player's progression:
	## death at floor 8 (no bosses), death at floor 9 (1 boss),
	## death at floor 12 (2 bosses), full clear (3 bosses).
	## After each step verify the right set of perks is unlocked.
	var m: Node = _fresh_meta()
	# Step 1: floor 8 death. Nothing unlocks.
	m.record_run_end(8, 0, false, 0, "brawler")
	assert_true(not m.is_perk_milestone_unlocked("deep_diver"),
		"step 1: deep_diver still locked")
	assert_true(not m.is_perk_milestone_unlocked("bossbane"),
		"step 1: bossbane still locked")
	# Step 2: floor 9 death + 1 boss. deep_diver unlocks; bossbane needs more.
	m.record_run_end(9, 1, false, 0, "rogue")
	assert_true(m.is_perk_milestone_unlocked("deep_diver"),
		"step 2: deep_diver unlocked")
	assert_true(not m.is_perk_milestone_unlocked("bossbane"),
		"step 2: bossbane (1 < 3) still locked")
	# Step 3: floor 12 + 2 bosses. Bossbane unlocks (1 + 2 = 3 lifetime).
	m.record_run_end(12, 2, false, 0, "rogue")
	assert_true(m.is_perk_milestone_unlocked("bossbane"),
		"step 3: bossbane unlocked")
	assert_true(not m.is_perk_milestone_unlocked("war_veteran"),
		"step 3: war_veteran still locked (no wins)")
	# Step 4: full clear + 3 bosses. War_veteran + champions_bond unlock.
	m.record_run_end(18, 3, true, 5000, "arcanist")
	assert_true(m.is_perk_milestone_unlocked("war_veteran"),
		"step 4: war_veteran unlocked")
	assert_true(m.is_perk_milestone_unlocked("champions_bond"),
		"step 4: champions_bond unlocked")


func test_milestone_text_specific_for_every_gated_perk() -> void:
	## Every currently-gated perk MUST have specific requirement text — if
	## a new perk adds a new requirement type without updating the match
	## block, this test catches it (the fallback "Locked" string fails).
	for pid: String in PERKS.all_ids():
		if not PERKS.has_milestone(pid):
			continue
		var t: String = PERKS.requirement_text(pid)
		assert_true(t != "Locked", "%s text is specific, not fallback" % pid)
		assert_true(t != "", "%s text non-empty" % pid)
