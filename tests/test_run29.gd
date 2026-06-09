## Run 29 tests: sponsor rarity tiers + threshold-weighted slate +
## story-arc prereq gating.
##
## Pure data + math only — no autoload runtime state. Validates the new
## `rarity` field on every sponsor, the weight-by-taken-count table shape,
## that `Sponsors.slate()` is deterministic, doesn't duplicate within a
## slate, tilts toward Legendary as `taken_count` rises (statistically), and
## respects `requires_taken` prereqs.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun29


var SPONSORS: GDScript = load("res://src/data/Sponsors.gd")


# ── Sponsor pool: rarity schema ───────────────────────────────────────────────

func test_every_sponsor_has_rarity() -> void:
	var pool: Array = SPONSORS.POOL
	for o: Dictionary in pool:
		assert_true(o.has("rarity"),
			"%s has 'rarity' field" % o.get("id", "?"))


func test_sponsor_rarity_values_are_known() -> void:
	var allowed: Dictionary = {
		SPONSORS.RARITY_COMMON: true,
		SPONSORS.RARITY_RARE: true,
		SPONSORS.RARITY_LEGENDARY: true,
	}
	for o: Dictionary in SPONSORS.POOL:
		var r: String = String(o.get("rarity", ""))
		assert_true(allowed.has(r),
			"%s rarity '%s' is common/rare/legendary"
				% [o.get("id", "?"), r])


func test_pool_has_at_least_one_of_each_rarity() -> void:
	var seen: Dictionary = {}
	for o: Dictionary in SPONSORS.POOL:
		seen[String(o.get("rarity", ""))] = true
	assert_true(seen.has(SPONSORS.RARITY_COMMON),    "at least one common")
	assert_true(seen.has(SPONSORS.RARITY_RARE),      "at least one rare")
	assert_true(seen.has(SPONSORS.RARITY_LEGENDARY), "at least one legendary")


func test_pool_has_new_run29_ids() -> void:
	## Run 29 added 4 specific sponsors — lock them in so a future refactor
	## doesn't silently drop one and break the story arc.
	var required: Array[String] = [
		"tiny_carl_plush", "big_mikes_return",
		"godking_industries", "neo_blood_co",
	]
	var seen: Dictionary = {}
	for o: Dictionary in SPONSORS.POOL:
		seen[String(o.get("id", ""))] = true
	for id: String in required:
		assert_true(seen.has(id), "POOL contains new sponsor '%s'" % id)


func test_big_mikes_return_requires_big_mikes_meat() -> void:
	## Locks the story-arc wiring in place. If someone renames `big_mikes_meat`
	## the test screams.
	var ret: Dictionary = SPONSORS.get_offer("big_mikes_return")
	assert_true(not ret.is_empty(), "big_mikes_return exists")
	assert_eq(String(ret.get("requires_taken", "")), "big_mikes_meat",
		"big_mikes_return.requires_taken points at big_mikes_meat")


# ── Weight table shape ────────────────────────────────────────────────────────

func test_weight_table_has_four_tiers() -> void:
	var t: Array = SPONSORS.RARITY_WEIGHTS_BY_TAKEN
	assert_eq(t.size(), 4, "weight table has 4 taken-count buckets")


func test_weight_table_legendary_climbs_with_taken() -> void:
	## Deeper into the show, Legendary share rises monotonically.
	var t: Array = SPONSORS.RARITY_WEIGHTS_BY_TAKEN
	var prev: int = -1
	for i: int in range(t.size()):
		var d: Dictionary = t[i]
		var v: int = int(d.get(SPONSORS.RARITY_LEGENDARY, 0))
		assert_gt(v, prev, "tier %d legendary weight (%d) > tier %d (%d)"
			% [i, v, i - 1, prev])
		prev = v


func test_weight_table_common_shrinks_with_taken() -> void:
	## And Common drops as Legendary climbs — mix shifts away from filler.
	var t: Array = SPONSORS.RARITY_WEIGHTS_BY_TAKEN
	var prev: int = 99999
	for i: int in range(t.size()):
		var d: Dictionary = t[i]
		var v: int = int(d.get(SPONSORS.RARITY_COMMON, 0))
		assert_true(v < prev,
			"tier %d common weight (%d) < tier %d (%d)"
				% [i, v, i - 1, prev])
		prev = v


func test_weight_table_all_tiers_positive_total() -> void:
	## Defensive: a zero-weight tier would crash `_pick_rarity()`.
	for d: Dictionary in SPONSORS.RARITY_WEIGHTS_BY_TAKEN:
		var total: int = 0
		for r: String in d:
			total += int(d[r])
		assert_gt(total, 0, "each weight tier has a positive total")


func test_taken_tier_buckets() -> void:
	## Lock the 0 / 1-2 / 3-4 / 5+ boundaries so a future bucket change
	## doesn't silently re-shape the rarity ramp.
	assert_eq(SPONSORS.taken_tier(0), 0, "0 taken → tier 0")
	assert_eq(SPONSORS.taken_tier(1), 1, "1 taken → tier 1")
	assert_eq(SPONSORS.taken_tier(2), 1, "2 taken → tier 1")
	assert_eq(SPONSORS.taken_tier(3), 2, "3 taken → tier 2")
	assert_eq(SPONSORS.taken_tier(4), 2, "4 taken → tier 2")
	assert_eq(SPONSORS.taken_tier(5), 3, "5 taken → tier 3")
	assert_eq(SPONSORS.taken_tier(99), 3, "99 taken → tier 3 (no overflow)")
	assert_eq(SPONSORS.taken_tier(-3), 0, "negative taken still clamps to tier 0")


# ── slate(): basic guarantees ─────────────────────────────────────────────────

func test_slate_returns_three_cards_by_default() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var picks: Array = SPONSORS.slate(rng, 0, [])
	assert_eq(picks.size(), int(SPONSORS.SLATE_SIZE),
		"slate returns SLATE_SIZE cards on a healthy pool")


func test_slate_items_are_unique_within_slate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for trial: int in range(20):
		rng.seed = 1000 + trial
		var picks: Array = SPONSORS.slate(rng, 3, [])
		var seen: Dictionary = {}
		for o: Dictionary in picks:
			var id: String = String(o.get("id", ""))
			assert_true(not seen.has(id),
				"trial %d: id '%s' appears at most once per slate"
					% [trial, id])
			seen[id] = true


func test_slate_is_deterministic_for_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 999
	rng_b.seed = 999
	var a: Array = SPONSORS.slate(rng_a, 2, ["big_mikes_meat"])
	var b: Array = SPONSORS.slate(rng_b, 2, ["big_mikes_meat"])
	assert_eq(a.size(), b.size(), "same seed → same slate size")
	for i: int in range(a.size()):
		var ai: String = String((a[i] as Dictionary).get("id", ""))
		var bi: String = String((b[i] as Dictionary).get("id", ""))
		assert_eq(ai, bi, "slot %d matches across rng with same seed" % i)


func test_slate_returns_empty_for_null_rng() -> void:
	var picks: Array = SPONSORS.slate(null, 0, [])
	assert_true(picks.is_empty(),
		"slate(null, ...) returns [] defensively")


# ── slate(): rarity weighting ─────────────────────────────────────────────────

func test_slate_legendary_share_rises_with_taken_count() -> void:
	## Statistical check: across many seeds, a high-taken_count slate should
	## contain more Legendaries on average than a fresh-run slate. We compare
	## taken_count=0 vs taken_count=6.
	var legendary_count_low: int = 0
	var legendary_count_high: int = 0
	var trials: int = 200
	# Provide the prereq for big_mikes_return so the Legendary pool isn't
	# artificially shrunk for the high-taken_count case (otherwise we'd be
	# testing a pool difference rather than the weight difference).
	var prereqs: Array = ["big_mikes_meat"]
	var rng := RandomNumberGenerator.new()
	for trial: int in range(trials):
		rng.seed = 10_000 + trial
		var lo: Array = SPONSORS.slate(rng, 0, prereqs)
		for o: Dictionary in lo:
			if String(o.get("rarity", "")) == SPONSORS.RARITY_LEGENDARY:
				legendary_count_low += 1
		rng.seed = 20_000 + trial
		var hi: Array = SPONSORS.slate(rng, 6, prereqs)
		for o: Dictionary in hi:
			if String(o.get("rarity", "")) == SPONSORS.RARITY_LEGENDARY:
				legendary_count_high += 1
	assert_gt(legendary_count_high, legendary_count_low,
		"high taken_count (%d legendaries) > low taken_count (%d legendaries) over %d trials"
			% [legendary_count_high, legendary_count_low, trials])


# ── slate(): story-arc gating ─────────────────────────────────────────────────

func test_return_sponsor_never_appears_without_prereq() -> void:
	## Across 50 random slates with no prereqs in `taken_ids`, the return
	## sponsor must never appear.
	var rng := RandomNumberGenerator.new()
	for trial: int in range(50):
		rng.seed = 5000 + trial
		var picks: Array = SPONSORS.slate(rng, 4, [])
		for o: Dictionary in picks:
			assert_true(String(o.get("id", "")) != "big_mikes_return",
				"trial %d: big_mikes_return excluded when prereq missing"
					% trial)


func test_return_sponsor_can_appear_when_prereq_satisfied() -> void:
	## With prereq satisfied AND high taken_count (high Legendary weight),
	## across many trials we expect to see big_mikes_return at least once.
	## Statistical guarantee: with Legendary weight 30 at tier-3, 3 slots/slate,
	## ~3 legendaries in the pool, 100 trials should land it many times over.
	var rng := RandomNumberGenerator.new()
	var saw_return: bool = false
	for trial: int in range(100):
		rng.seed = 30_000 + trial
		var picks: Array = SPONSORS.slate(rng, 6, ["big_mikes_meat"])
		for o: Dictionary in picks:
			if String(o.get("id", "")) == "big_mikes_return":
				saw_return = true
				break
		if saw_return:
			break
	assert_true(saw_return,
		"big_mikes_return appears at least once across 100 high-tier slates with prereq")


func test_eligible_pool_strips_return_sponsors_without_prereq() -> void:
	var elig: Array = SPONSORS.eligible_pool([])
	var has_return: bool = false
	for o: Dictionary in elig:
		if String(o.get("id", "")) == "big_mikes_return":
			has_return = true
	assert_true(not has_return,
		"eligible_pool([]) does not include big_mikes_return")


func test_eligible_pool_restores_return_sponsors_with_prereq() -> void:
	var elig: Array = SPONSORS.eligible_pool(["big_mikes_meat"])
	var has_return: bool = false
	for o: Dictionary in elig:
		if String(o.get("id", "")) == "big_mikes_return":
			has_return = true
	assert_true(has_return,
		"eligible_pool with prereq includes big_mikes_return")


# ── Back-compat with Run 20 ───────────────────────────────────────────────────

func test_sponsors_owed_still_works() -> void:
	var t: int = int(SPONSORS.SPONSOR_THRESHOLD)
	assert_eq(SPONSORS.sponsors_owed(0, 0), 0,    "0 audience → 0 owed")
	assert_eq(SPONSORS.sponsors_owed(t, 0), 1,    "1 threshold crossed → 1 owed")
	assert_eq(SPONSORS.sponsors_owed(t, 1), 0,    "owed clears after take")


func test_get_offer_works_for_new_ids() -> void:
	var g: Dictionary = SPONSORS.get_offer("godking_industries")
	assert_eq(String(g.get("id", "")), "godking_industries",
		"get_offer finds new Run-29 ids")
	var miss: Dictionary = SPONSORS.get_offer("not_a_real_sponsor")
	assert_true(miss.is_empty(),
		"get_offer still returns {} for unknown id")
