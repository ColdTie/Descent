## Run 20 tests: sponsor offer pool + patch notes content + threshold math.
##
## Per the test rule, autoload runtime state isn't exercised here. We
## validate the pure data classes (Sponsors, PatchNotes) and the static
## math (sponsors_owed) without touching GameState.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun20

# Use load() rather than preload() — these are data classes with class_name
# declarations and we want a runtime resolution that matches how Main.gd uses
# them. Both are pure (no _ready / autoload deps) but load() is the safer
# pattern in --script test mode.
var SPONSORS: GDScript      = load("res://src/data/Sponsors.gd")
var PATCH_NOTES: GDScript   = load("res://src/data/PatchNotes.gd")

# ── Sponsors: pool schema ─────────────────────────────────────────────────────

func test_sponsor_pool_nonempty() -> void:
	var pool: Array = SPONSORS.POOL
	assert_true(pool.size() >= 6,
		"At least 6 sponsor offers defined (got %d)" % pool.size())

func test_sponsor_threshold_positive() -> void:
	assert_gt(int(SPONSORS.SPONSOR_THRESHOLD), 0,
		"SPONSOR_THRESHOLD is positive")

func test_every_sponsor_has_required_keys() -> void:
	var pool: Array = SPONSORS.POOL
	for o: Dictionary in pool:
		assert_true(o.has("id"),      "sponsor has 'id'")
		assert_true(o.has("sponsor"), "%s has 'sponsor' brand" % o.get("id", "?"))
		assert_true(o.has("name"),    "%s has 'name'" % o.get("id", "?"))
		assert_true(o.has("desc"),    "%s has 'desc'" % o.get("id", "?"))
		assert_true(o.has("effects"), "%s has 'effects'" % o.get("id", "?"))
		assert_true(String(o["id"]).length() > 0,   "sponsor id is non-empty")
		assert_true(String(o["name"]).length() > 0, "sponsor name is non-empty")

func test_sponsor_ids_unique() -> void:
	var pool: Array = SPONSORS.POOL
	var seen: Dictionary = {}
	for o: Dictionary in pool:
		var id: String = String(o.get("id", ""))
		assert_true(not seen.has(id), "sponsor id '%s' is unique" % id)
		seen[id] = true

func test_sponsor_effects_are_dicts() -> void:
	var pool: Array = SPONSORS.POOL
	var allowed: Array[String] = ["attack", "defense", "speed", "max_hp",
		"heal", "audience"]
	for o: Dictionary in pool:
		var fx: Dictionary = o.get("effects", {})
		assert_true(fx is Dictionary, "%s effects is a Dictionary" % o.get("id"))
		assert_true(fx.size() > 0, "%s has at least one effect" % o.get("id"))
		for k: String in fx.keys():
			assert_true(allowed.has(k),
				"%s effect key '%s' is in the allowed set" % [o.get("id"), k])

# ── Sponsors: threshold math ──────────────────────────────────────────────────

func test_sponsors_owed_zero_when_no_audience() -> void:
	assert_eq(SPONSORS.sponsors_owed(0, 0), 0, "0 audience → 0 owed")

func test_sponsors_owed_below_threshold() -> void:
	var t: int = int(SPONSORS.SPONSOR_THRESHOLD)
	assert_eq(SPONSORS.sponsors_owed(t - 1, 0), 0,
		"Just under the threshold → 0 owed")

func test_sponsors_owed_one_after_first_threshold() -> void:
	var t: int = int(SPONSORS.SPONSOR_THRESHOLD)
	assert_eq(SPONSORS.sponsors_owed(t, 0), 1,
		"Crossing the threshold owes exactly 1 sponsor card")

func test_sponsors_owed_two_after_double() -> void:
	var t: int = int(SPONSORS.SPONSOR_THRESHOLD)
	assert_eq(SPONSORS.sponsors_owed(t * 2, 0), 2,
		"Two thresholds crossed → 2 owed")

func test_sponsors_owed_clears_after_take() -> void:
	var t: int = int(SPONSORS.SPONSOR_THRESHOLD)
	assert_eq(SPONSORS.sponsors_owed(t, 1), 0,
		"After accepting the offer at threshold 1 → 0 owed")

func test_sponsors_owed_never_negative() -> void:
	## Edge case: in case `taken` ever overshoots (e.g. dev tools, future
	## migrations), we clamp at 0 rather than producing a phantom negative.
	assert_eq(SPONSORS.sponsors_owed(100, 5), 0,
		"taken > earned still floors at 0, no negative offers")

func test_get_offer_returns_match() -> void:
	var first_id: String = String((SPONSORS.POOL[0] as Dictionary)["id"])
	var found: Dictionary = SPONSORS.get_offer(first_id)
	assert_eq(String(found.get("id", "")), first_id,
		"get_offer returns the matching record")

func test_get_offer_returns_empty_on_miss() -> void:
	var miss: Dictionary = SPONSORS.get_offer("definitely_not_a_sponsor_id")
	assert_true(miss.is_empty(), "get_offer returns {} for unknown id")

# ── PatchNotes: content schema ────────────────────────────────────────────────

func test_patch_notes_defined_for_tier_transitions() -> void:
	## Tier 2 lives at floor 7 (after Stone tier ends at 6).
	## Tier 3 lives at floor 13 (after Obsidian tier ends at 12).
	assert_true(PATCH_NOTES.has_notes_for(7),  "Patch notes exist for floor 7 (Obsidian tier)")
	assert_true(PATCH_NOTES.has_notes_for(13), "Patch notes exist for floor 13 (Void tier)")

func test_no_patch_notes_for_regular_floors() -> void:
	for floor_num: int in [1, 2, 6, 8, 12, 14, 18]:
		assert_true(not PATCH_NOTES.has_notes_for(floor_num),
			"Floor %d has no patch notes (regular floor)" % floor_num)

func test_patch_notes_have_required_keys() -> void:
	for floor_num: int in PATCH_NOTES.all_floors():
		var d: Dictionary = PATCH_NOTES.notes_for(floor_num)
		assert_true(d.has("version"),  "floor %d has 'version'" % floor_num)
		assert_true(d.has("subtitle"), "floor %d has 'subtitle'" % floor_num)
		assert_true(d.has("lines"),    "floor %d has 'lines'" % floor_num)
		assert_true(d.has("closing"),  "floor %d has 'closing'" % floor_num)
		var lines: Array = d.get("lines", [])
		assert_gt(lines.size(), 2,
			"floor %d has more than 2 patch-note lines" % floor_num)

func test_patch_notes_for_unknown_floor_is_empty() -> void:
	var none: Dictionary = PATCH_NOTES.notes_for(99)
	assert_true(none.is_empty(), "notes_for(99) returns {}")
