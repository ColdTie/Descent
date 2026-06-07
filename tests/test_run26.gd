## Run 26 tests: Shop "lock" slots — locked items survive a reroll.
##
## Pure data-layer coverage of the new `slate(rng, floor_num, locked)` arg.
## Verifies: locked items are present in the rolled slate, never duplicated,
## occupy the leading positions, and behavior remains identical when no
## locked items are supplied (backwards compat).
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun26


var SHOP: GDScript = load("res://src/data/Shop.gd")


# ── Backwards compatibility ──────────────────────────────────────────────────

func test_slate_unchanged_when_no_locked() -> void:
	## Same seed without an explicit `locked` arg should match Run 25 behavior.
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 314
	var s_a: Array = SHOP.slate(rng_a, 5)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 314
	var s_b: Array = SHOP.slate(rng_b, 5, [])
	assert_eq(s_a.size(), s_b.size(), "default-arg vs empty-array slates match length")
	for i: int in range(s_a.size()):
		assert_eq(String((s_a[i] as Dictionary).get("id", "")),
			String((s_b[i] as Dictionary).get("id", "")),
			"slot %d identical for default vs empty locked" % i)


# ── Locked items are preserved across reroll ─────────────────────────────────

func test_slate_preserves_single_locked_item() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var locked: Array[Dictionary] = [SHOP.get_item("shop_field_kit")]
	var s: Array = SHOP.slate(rng, 5, locked)
	assert_eq(s.size(), SHOP.SLATE_SIZE, "slate is still SLATE_SIZE with one locked item")
	# Locked items go first in the returned array per Run 26 contract.
	assert_eq(String((s[0] as Dictionary).get("id", "")), "shop_field_kit",
		"locked item placed at index 0")


func test_slate_preserves_multiple_locked_items_in_order() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var locked: Array[Dictionary] = [
		SHOP.get_item("shop_field_kit"),
		SHOP.get_item("shop_sharpening_stone"),
	]
	var s: Array = SHOP.slate(rng, 5, locked)
	assert_eq(s.size(), SHOP.SLATE_SIZE, "slate is still SLATE_SIZE with two locked items")
	assert_eq(String((s[0] as Dictionary).get("id", "")), "shop_field_kit",
		"first locked item at index 0")
	assert_eq(String((s[1] as Dictionary).get("id", "")), "shop_sharpening_stone",
		"second locked item at index 1")


# ── Locked items aren't duplicated by fresh draws ────────────────────────────

func test_locked_items_not_duplicated_by_fresh_draws() -> void:
	## Across many seeds, a locked item should never appear twice in the output.
	var locked: Array[Dictionary] = [SHOP.get_item("shop_field_kit")]
	for seed_val: int in range(50):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		var s: Array = SHOP.slate(rng, 18, locked)
		var count: int = 0
		for it: Dictionary in s:
			if String(it.get("id", "")) == "shop_field_kit":
				count += 1
		assert_eq(count, 1, "seed %d: locked item appears exactly once" % seed_val)


func test_slate_items_all_unique_with_locked() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var locked: Array[Dictionary] = [
		SHOP.get_item("shop_plate_kit"),
		SHOP.get_item("shop_caffeine_pack"),
	]
	var s: Array = SHOP.slate(rng, 9, locked)
	var seen: Dictionary = {}
	for it: Dictionary in s:
		var id: String = String(it.get("id", ""))
		assert_true(not seen.has(id),
			"slate item '%s' is unique within slate" % id)
		seen[id] = true


# ── All-locked edge case ─────────────────────────────────────────────────────

func test_all_locked_returns_locked_items_only() -> void:
	## When every slot is locked, the slate is exactly those items — no fresh
	## draws happen. RNG should be untouched (we don't assert that, but the
	## output should match input length and contents).
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var locked: Array[Dictionary] = []
	# Grab any SLATE_SIZE distinct items from inventory to lock.
	for it: Dictionary in SHOP.INVENTORY:
		if locked.size() >= SHOP.SLATE_SIZE:
			break
		locked.append(it)
	var s: Array = SHOP.slate(rng, 5, locked)
	assert_eq(s.size(), SHOP.SLATE_SIZE, "all-locked slate is SLATE_SIZE")
	for i: int in range(SHOP.SLATE_SIZE):
		assert_eq(String((s[i] as Dictionary).get("id", "")),
			String((locked[i] as Dictionary).get("id", "")),
			"all-locked slot %d unchanged" % i)


func test_overflow_locked_truncated_to_slate_size() -> void:
	## Defensive: if a caller hands in more locked items than fit, the slate
	## simply truncates to SLATE_SIZE rather than overflowing.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var locked: Array[Dictionary] = []
	for it: Dictionary in SHOP.INVENTORY:
		locked.append(it)
		if locked.size() >= SHOP.SLATE_SIZE + 2:
			break
	var s: Array = SHOP.slate(rng, 5, locked)
	assert_eq(s.size(), SHOP.SLATE_SIZE, "overflow locked input still caps at SLATE_SIZE")


func test_locked_duplicate_id_skipped() -> void:
	## Defensive: handing in the same item twice in `locked` should be
	## deduplicated rather than producing duplicate output entries.
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var same: Dictionary = SHOP.get_item("shop_field_kit")
	var locked: Array[Dictionary] = [same, same]
	var s: Array = SHOP.slate(rng, 5, locked)
	var count: int = 0
	for it: Dictionary in s:
		if String(it.get("id", "")) == "shop_field_kit":
			count += 1
	assert_eq(count, 1, "duplicate locked id appears exactly once in output")
	assert_eq(s.size(), SHOP.SLATE_SIZE, "slate still fills to SLATE_SIZE")


# ── Empty / malformed locked input ──────────────────────────────────────────

func test_locked_with_empty_dict_ignored() -> void:
	## A {} entry should not block a slot (no id to track).
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var locked: Array[Dictionary] = [{}]
	var s: Array = SHOP.slate(rng, 5, locked)
	assert_eq(s.size(), SHOP.SLATE_SIZE, "empty-dict locked entry doesn't shrink slate")
