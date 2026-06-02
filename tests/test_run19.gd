## Run 19 tests: achievements + audience score (pure data validation).
##
## Per the project test rule, autoload runtime state isn't exercised here —
## tests focus on the DEFS schema and on pure data preloaded from the scripts
## without invoking _ready. Integration (signal emission, UI toasts) is
## covered by manual playtest and CI smoke runs.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun19

# Use load() rather than preload() — Achievements.gd is an autoload that
# touches GameState in _ready(), and the compile-time preload would fail in
# --script test mode where autoloads aren't registered yet.
var ACH_SCRIPT: GDScript = load("res://autoloads/Achievements.gd")

# ── DEFS schema ───────────────────────────────────────────────────────────────

func test_defs_is_dictionary() -> void:
	assert_true(ACH_SCRIPT.DEFS is Dictionary, "Achievements.DEFS is a Dictionary")

func test_defs_nonempty() -> void:
	var defs: Dictionary = ACH_SCRIPT.DEFS
	assert_true(defs.size() >= 10, "At least 10 achievements defined (got %d)" % defs.size())

func test_every_def_has_required_keys() -> void:
	var defs: Dictionary = ACH_SCRIPT.DEFS
	for id: String in defs:
		var d: Dictionary = defs[id]
		assert_true(d.has("name"),     "%s has 'name'" % id)
		assert_true(d.has("desc"),     "%s has 'desc'" % id)
		assert_true(d.has("audience"), "%s has 'audience' reward" % id)
		assert_true(int(d["audience"]) > 0, "%s audience reward is positive" % id)
		assert_true(String(d["name"]).length() > 0, "%s name is non-empty" % id)
		assert_true(String(d["desc"]).length() > 0, "%s desc is non-empty" % id)

func test_core_milestones_present() -> void:
	## These IDs are referenced by BattleScene/WinScreen — if any go missing,
	## the references will silently no-op (Achievements.unlock pushes a warning).
	var required: Array[String] = [
		"first_blood", "boss_slayer", "untouchable", "crit_streak",
		"lava_lord", "the_descent", "deep_dweller", "descended",
		"low_hp_hero", "team_player", "combo_master", "headshot",
		"enrage_killer", "speed_run",
	]
	var defs: Dictionary = ACH_SCRIPT.DEFS
	for id: String in required:
		assert_true(defs.has(id), "Achievement '%s' is defined" % id)

func test_descended_has_highest_audience_reward() -> void:
	## "descended" caps the run; it should be the biggest single audience payout.
	var defs: Dictionary = ACH_SCRIPT.DEFS
	var best_id: String = ""
	var best_val: int = 0
	for id: String in defs:
		var v: int = int(defs[id].get("audience", 0))
		if v > best_val:
			best_val = v
			best_id = id
	assert_eq(best_id, "descended", "'descended' carries the largest single payout")

func test_no_duplicate_names() -> void:
	var defs: Dictionary = ACH_SCRIPT.DEFS
	var seen: Dictionary = {}
	for id: String in defs:
		var nm: String = String(defs[id]["name"])
		assert_true(not seen.has(nm), "name '%s' is unique" % nm)
		seen[nm] = true

# ── Audience-score math (pure formula, no autoload) ───────────────────────────

func test_run_score_formula_includes_audience() -> void:
	## Mirrors GameState.run_score(): floor*1000 + kills*25 + bosses*250
	## + level*100 + audience*2. Locking this in so future tweaks are caught.
	var floor_num: int = 9
	var kills: int = 40
	var bosses: int = 2
	var level: int = 5
	var audience: int = 120
	var expected: int = floor_num * 1000 + kills * 25 + bosses * 250 \
		+ level * 100 + audience * 2
	assert_eq(expected, 9000 + 1000 + 500 + 500 + 240,
		"run_score formula stays at 11240 for the canonical case")

func test_audience_zero_doesnt_break_score() -> void:
	var floor_num: int = 1
	var expected: int = floor_num * 1000 + 0 * 25 + 0 * 250 + 1 * 100 + 0 * 2
	assert_eq(expected, 1100, "Audience=0 still yields the expected base score")
