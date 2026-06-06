## Run 25 tests: Shop rarity tiers + reroll cost helper.
##
## Pure data + math only — no autoload runtime state. Validates the new
## rarity schema on every INVENTORY entry, the per-tier weight tables,
## and that `Shop.slate()` honors the tier-weight distribution at a
## statistically detectable level over many rolls. Also locks in the
## reroll cost ramp.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun25


var SHOP: GDScript = load("res://src/data/Shop.gd")


# ── Inventory: rarity schema ──────────────────────────────────────────────────

func test_every_shop_item_has_rarity() -> void:
	var inv: Array = SHOP.INVENTORY
	for it: Dictionary in inv:
		assert_true(it.has("rarity"),
			"%s has 'rarity'" % it.get("id", "?"))


func test_shop_rarity_values_are_known() -> void:
	var allowed: Dictionary = {
		SHOP.RARITY_COMMON: true,
		SHOP.RARITY_RARE: true,
		SHOP.RARITY_LEGENDARY: true,
	}
	for it: Dictionary in SHOP.INVENTORY:
		var r: String = String(it.get("rarity", ""))
		assert_true(allowed.has(r),
			"%s rarity '%s' is one of common/rare/legendary"
				% [it.get("id", "?"), r])


func test_shop_has_at_least_one_of_each_rarity() -> void:
	var seen: Dictionary = {}
	for it: Dictionary in SHOP.INVENTORY:
		seen[it.get("rarity", "")] = true
	assert_true(seen.has(SHOP.RARITY_COMMON), "has at least one common")
	assert_true(seen.has(SHOP.RARITY_RARE), "has at least one rare")
	assert_true(seen.has(SHOP.RARITY_LEGENDARY), "has at least one legendary")


# Legendary items are intended to be the splurge category — cost should
# materially exceed Common/Rare averages so they actually feel expensive.
func test_legendary_costs_above_common_avg() -> void:
	var common_total: int = 0
	var common_n: int = 0
	var legendary_min: int = 999999
	for it: Dictionary in SHOP.INVENTORY:
		var cost: int = int(it.get("cost", 0))
		match String(it.get("rarity", "")):
			SHOP.RARITY_COMMON:
				common_total += cost
				common_n += 1
			SHOP.RARITY_LEGENDARY:
				if cost < legendary_min:
					legendary_min = cost
	var common_avg: int = common_total / max(1, common_n)
	assert_gt(legendary_min, common_avg,
		"cheapest legendary cost (%d) > common avg (%d)"
			% [legendary_min, common_avg])


# ── Per-tier rarity weight tables ─────────────────────────────────────────────

func test_rarity_weight_table_has_three_tiers() -> void:
	var t: Array = SHOP.RARITY_WEIGHTS_BY_TIER
	assert_eq(t.size(), 3, "weight table covers all 3 floor tiers")


func test_weight_table_legendary_climbs_with_depth() -> void:
	## Deeper tiers should weight Legendary higher, not lower.
	var t: Array = SHOP.RARITY_WEIGHTS_BY_TIER
	var legend_0: int = int((t[0] as Dictionary).get(SHOP.RARITY_LEGENDARY, 0))
	var legend_1: int = int((t[1] as Dictionary).get(SHOP.RARITY_LEGENDARY, 0))
	var legend_2: int = int((t[2] as Dictionary).get(SHOP.RARITY_LEGENDARY, 0))
	assert_gt(legend_1, legend_0, "tier 1 legendary weight > tier 0")
	assert_gt(legend_2, legend_1, "tier 2 legendary weight > tier 1")


func test_weight_table_common_shrinks_with_depth() -> void:
	## And Common should drop as Legendary climbs — the mix shifts down.
	var t: Array = SHOP.RARITY_WEIGHTS_BY_TIER
	var c0: int = int((t[0] as Dictionary).get(SHOP.RARITY_COMMON, 0))
	var c1: int = int((t[1] as Dictionary).get(SHOP.RARITY_COMMON, 0))
	var c2: int = int((t[2] as Dictionary).get(SHOP.RARITY_COMMON, 0))
	assert_gt(c0, c1, "tier 0 common weight > tier 1")
	assert_gt(c1, c2, "tier 1 common weight > tier 2")


func test_weight_table_positive_totals() -> void:
	for tier_idx: int in range(SHOP.RARITY_WEIGHTS_BY_TIER.size()):
		var w: Dictionary = SHOP.RARITY_WEIGHTS_BY_TIER[tier_idx]
		var total: int = 0
		for r: String in w:
			total += int(w[r])
		assert_gt(total, 0, "tier %d weight total positive" % tier_idx)


# ── Slate generation honors tier weighting ────────────────────────────────────

func test_slate_size_is_slate_size() -> void:
	## SLATE_SIZE distinct items should be returned in a normal case.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var s: Array = SHOP.slate(rng, 5)
	assert_eq(s.size(), SHOP.SLATE_SIZE, "slate returns SLATE_SIZE items")


func test_slate_items_unique_within_slate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var s: Array = SHOP.slate(rng, 10)
	var seen: Dictionary = {}
	for it: Dictionary in s:
		var id: String = String(it.get("id", ""))
		assert_true(not seen.has(id), "slate item '%s' is unique within slate" % id)
		seen[id] = true


func test_slate_deterministic_with_same_seed() -> void:
	## The same seed + floor should always produce the same slate so visits
	## stay reproducible per-run-seed (the test rng is independent of the
	## global GameRng autoload).
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 99
	var s_a: Array = SHOP.slate(rng_a, 3)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 99
	var s_b: Array = SHOP.slate(rng_b, 3)
	assert_eq(s_a.size(), s_b.size(), "same seed -> same slate length")
	for i: int in range(s_a.size()):
		assert_eq(String((s_a[i] as Dictionary).get("id", "")),
			String((s_b[i] as Dictionary).get("id", "")),
			"slot %d matches across reseed" % i)


func test_floor_1_slate_skews_common() -> void:
	## Statistical: at floor 1 (tier 0, 80% common), the majority of slate
	## entries across many rolls should be common. With 80% per slot and 4
	## slots × 60 trials = 240 picks, expected commons ≈ 192. Allow a wide
	## margin (≥ 130) so flakes from seed variance don't fail the suite.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var common_count: int = 0
	var trials: int = 60
	for i: int in range(trials):
		var s: Array = SHOP.slate(rng, 1)
		for it: Dictionary in s:
			if String(it.get("rarity", "")) == SHOP.RARITY_COMMON:
				common_count += 1
	assert_gt(common_count, 130,
		"floor 1 slate skews common (got %d / %d picks)"
			% [common_count, trials * SHOP.SLATE_SIZE])


func test_floor_18_slate_skews_rare_plus() -> void:
	## At floor 18 (tier 2: 30/45/25), rare+legendary should dominate over
	## many rolls. Expected ≈ 70% non-common; allow ≥ 50% margin.
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var non_common: int = 0
	var trials: int = 60
	var picks: int = trials * SHOP.SLATE_SIZE
	for i: int in range(trials):
		var s: Array = SHOP.slate(rng, 18)
		for it: Dictionary in s:
			if String(it.get("rarity", "")) != SHOP.RARITY_COMMON:
				non_common += 1
	assert_gt(non_common, picks / 2,
		"floor 18 slate skews rare+legendary (got %d / %d picks)"
			% [non_common, picks])


# ── Reroll cost ramp ──────────────────────────────────────────────────────────

func test_reroll_base_cost_positive() -> void:
	assert_gt(int(SHOP.REROLL_BASE_COST), 0, "reroll base cost positive")


func test_reroll_step_cost_positive() -> void:
	assert_gt(int(SHOP.REROLL_STEP_COST), 0, "reroll step cost positive")


func test_reroll_cost_monotonically_increasing() -> void:
	## Each successive reroll should cost more than the last so spam-rerolling
	## drains gold. Negative input is clamped to 0 inside the helper.
	var prev: int = SHOP.reroll_cost(0)
	for n: int in range(1, 6):
		var cur: int = SHOP.reroll_cost(n)
		assert_gt(cur, prev, "reroll %d cost > reroll %d" % [n, n - 1])
		prev = cur


func test_reroll_cost_zero_is_base() -> void:
	assert_eq(int(SHOP.reroll_cost(0)), int(SHOP.REROLL_BASE_COST),
		"reroll_cost(0) == REROLL_BASE_COST")


func test_reroll_cost_clamps_negative() -> void:
	## Defensive: a negative input shouldn't underflow the cost.
	assert_eq(int(SHOP.reroll_cost(-5)), int(SHOP.REROLL_BASE_COST),
		"negative reroll count clamps to base cost")


# ── Floor tier helper sanity ──────────────────────────────────────────────────

func test_floor_tier_boundaries() -> void:
	## Lock in the tier boundaries used by the slate roller. Mirrors
	## LootScreen + BattleScene math: 1-6 / 7-12 / 13-18.
	assert_eq(int(SHOP._floor_tier(1)), 0, "floor 1 -> tier 0")
	assert_eq(int(SHOP._floor_tier(6)), 0, "floor 6 -> tier 0")
	assert_eq(int(SHOP._floor_tier(7)), 1, "floor 7 -> tier 1")
	assert_eq(int(SHOP._floor_tier(12)), 1, "floor 12 -> tier 1")
	assert_eq(int(SHOP._floor_tier(13)), 2, "floor 13 -> tier 2")
	assert_eq(int(SHOP._floor_tier(18)), 2, "floor 18 -> tier 2")
