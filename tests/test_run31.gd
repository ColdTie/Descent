## Run 31 tests: "Merchant's Favor" — once-per-run surprise Legendary discount.
##
## Pure data-layer coverage of the new Shop helpers (favor_chance,
## roll_merchant_favor, discounted_cost, cheapest_legendary) and the
## GameState snapshot/apply roundtrip for the `merchant_favor_used` flag.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun31


var SHOP: GDScript = load("res://src/data/Shop.gd")
var GAMESTATE: GDScript = load("res://autoloads/GameState.gd")


# ── Favor chance scaling ─────────────────────────────────────────────────────

func test_favor_chance_base_at_zero_audience() -> void:
	assert_eq(SHOP.favor_chance(0), SHOP.FAVOR_BASE_CHANCE,
		"zero audience returns exactly the base chance")


func test_favor_chance_monotonic_in_audience() -> void:
	var prev: float = SHOP.favor_chance(0)
	for a: int in [50, 100, 200, 500, 1000, 2000]:
		var cur: float = SHOP.favor_chance(a)
		assert_true(cur >= prev,
			"favor_chance(%d)=%.4f >= favor_chance(prev)=%.4f" % [a, cur, prev])
		prev = cur


func test_favor_chance_capped() -> void:
	## Very high audience scores should not push past FAVOR_CHANCE_CAP.
	var huge: float = SHOP.favor_chance(1_000_000)
	assert_eq(huge, SHOP.FAVOR_CHANCE_CAP, "huge audience clamps to cap")


func test_favor_chance_negative_audience_safe() -> void:
	## Defensive: negative audience inputs should not produce a sub-base chance.
	var c: float = SHOP.favor_chance(-500)
	assert_eq(c, SHOP.FAVOR_BASE_CHANCE,
		"negative audience floors to base chance")


# ── roll_merchant_favor ─────────────────────────────────────────────────────

func test_roll_merchant_favor_deterministic_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 12345
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 12345
	var a: bool = SHOP.roll_merchant_favor(rng_a, 100)
	var b: bool = SHOP.roll_merchant_favor(rng_b, 100)
	assert_eq(a, b, "same seed + same audience -> same outcome")


func test_roll_merchant_favor_null_rng_returns_false() -> void:
	## Defensive: a missing rng must not silently activate (would burn the
	## once-per-run flag invisibly).
	assert_eq(SHOP.roll_merchant_favor(null, 100), false,
		"null rng cannot fire favor")


func test_roll_merchant_favor_distribution_matches_chance() -> void:
	## Across many trials, the empirical hit rate should track favor_chance().
	## ~25% expected at audience 500 (base 0.18 + 5*0.015 = 0.255). Allow a
	## generous 0.10 tolerance band so the test isn't flaky.
	var hits: int = 0
	const TRIALS: int = 600
	for i: int in range(TRIALS):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + i
		if SHOP.roll_merchant_favor(rng, 500):
			hits += 1
	var observed: float = float(hits) / float(TRIALS)
	var expected: float = SHOP.favor_chance(500)
	var diff: float = abs(observed - expected)
	assert_true(diff < 0.10,
		"observed=%.3f, expected=%.3f, diff=%.3f within 0.10" % [observed, expected, diff])


# ── discounted_cost ──────────────────────────────────────────────────────────

func test_discounted_cost_halves_round_trip() -> void:
	assert_eq(SHOP.discounted_cost(300), 150, "300 -> 150 at 50% off")
	assert_eq(SHOP.discounted_cost(280), 140, "280 -> 140 at 50% off")
	assert_eq(SHOP.discounted_cost(260), 130, "260 -> 130 at 50% off")
	assert_eq(SHOP.discounted_cost(180), 90, "180 -> 90 at 50% off")


func test_discounted_cost_min_one_gold() -> void:
	## Defensive: even a hypothetical 1-gold item shouldn't round to zero.
	assert_eq(SHOP.discounted_cost(1), 1, "1 gold floors at 1 after discount")


func test_discounted_cost_zero_and_negative() -> void:
	assert_eq(SHOP.discounted_cost(0), 0, "0 in -> 0 out (no-op)")
	assert_eq(SHOP.discounted_cost(-50), 0, "negative cost coerced to 0")


# ── cheapest_legendary ───────────────────────────────────────────────────────

func test_cheapest_legendary_returns_lowest_cost() -> void:
	var leg: Dictionary = SHOP.cheapest_legendary()
	assert_true(not leg.is_empty(), "cheapest_legendary returns a non-empty item")
	assert_eq(String(leg.get("rarity", "")), "legendary", "result is a Legendary")
	# Cross-check against the full pool — no Legendary should be cheaper.
	var found_cost: int = int(leg.get("cost", -1))
	for it: Dictionary in SHOP.INVENTORY:
		if String(it.get("rarity", "")) != "legendary":
			continue
		assert_true(int(it.get("cost", 1 << 30)) >= found_cost,
			"no legendary cheaper than the returned one (%s vs %d)"
				% [String(it.get("id", "")), found_cost])


func test_cheapest_legendary_respects_exclude() -> void:
	var first: Dictionary = SHOP.cheapest_legendary()
	var excl: Dictionary = {String(first.get("id", "")): true}
	var second: Dictionary = SHOP.cheapest_legendary(excl)
	assert_true(not second.is_empty(), "still finds a legendary when one is excluded")
	assert_true(String(second.get("id", "")) != String(first.get("id", "")),
		"excluded id is not returned")


func test_cheapest_legendary_all_excluded_returns_empty() -> void:
	var excl: Dictionary = {}
	for it: Dictionary in SHOP.INVENTORY:
		if String(it.get("rarity", "")) == "legendary":
			excl[String(it.get("id", ""))] = true
	var leg: Dictionary = SHOP.cheapest_legendary(excl)
	assert_eq(leg.is_empty(), true, "fully-excluded pool returns {}")


# ── GameState merchant_favor_used flag ──────────────────────────────────────

func test_gamestate_has_flag_default_false() -> void:
	var gs: Node = GAMESTATE.new()
	assert_eq(gs.merchant_favor_used, false, "default is false")
	gs.queue_free()


func test_snapshot_includes_merchant_favor_used() -> void:
	var gs: Node = GAMESTATE.new()
	gs.hero_class = "brawler"
	gs.merchant_favor_used = true
	var snap: Dictionary = gs.snapshot()
	assert_true(snap.has("merchant_favor_used"), "snapshot includes the field")
	assert_eq(snap["merchant_favor_used"], true, "snapshot preserves true value")
	gs.queue_free()


func test_apply_snapshot_restores_flag() -> void:
	var gs: Node = GAMESTATE.new()
	gs.hero_class = "rogue"
	gs.merchant_favor_used = true
	var snap: Dictionary = gs.snapshot()
	# Round-trip through JSON to mimic the real save path.
	var raw: String = JSON.stringify(snap)
	var parsed: Variant = JSON.parse_string(raw)
	assert_true(parsed is Dictionary, "snapshot JSON parses to a Dictionary")

	var gs2: Node = GAMESTATE.new()
	var ok: bool = gs2.apply_snapshot(parsed as Dictionary)
	assert_eq(ok, true, "apply_snapshot returns true on valid input")
	assert_eq(gs2.merchant_favor_used, true, "flag restored true through JSON roundtrip")
	gs.queue_free()
	gs2.free()


func test_apply_snapshot_pre_run31_save_defaults_false() -> void:
	## Pre-Run-31 saves lack the field; apply_snapshot must default to false
	## rather than crashing or carrying stale state from a previous game.
	var gs: Node = GAMESTATE.new()
	gs.merchant_favor_used = true  # stale state from a prior run
	var fake_old_save: Dictionary = {
		"version": GAMESTATE.SAVE_VERSION,
		"hero_class": "brawler",
		"run_seed": 1,
		"floor_num": 1,
		"hero_hp": 50,
		"hero_max_hp": 100,
	}
	gs.apply_snapshot(fake_old_save)
	assert_eq(gs.merchant_favor_used, false,
		"missing field in save defaults to false (no stale carry-over)")
	gs.queue_free()


func test_start_run_resets_flag() -> void:
	var gs: Node = GAMESTATE.new()
	gs.merchant_favor_used = true
	gs.start_run("brawler", 42)
	assert_eq(gs.merchant_favor_used, false,
		"start_run wipes the prior run's favor consumption")
	gs.queue_free()


# ── Sanity check: constants live in expected ranges ──────────────────────────

func test_favor_constants_sane() -> void:
	assert_true(SHOP.FAVOR_BASE_CHANCE > 0.0,
		"base chance is positive (otherwise favor never fires without audience)")
	assert_true(SHOP.FAVOR_BASE_CHANCE < SHOP.FAVOR_CHANCE_CAP,
		"base chance is below the cap (so audience can still raise it)")
	assert_true(SHOP.FAVOR_CHANCE_CAP <= 1.0,
		"cap is a real probability")
	assert_true(SHOP.FAVOR_DISCOUNT_PCT > 0.0 and SHOP.FAVOR_DISCOUNT_PCT < 1.0,
		"discount is a proper percentage (>0 and <1)")
