## Run 24 tests: loot rarity tiers + audio music-tier mapping.
##
## Per the project's --script test mode rules, autoload runtime state isn't
## exercised here. We validate pure-data: LootScreen.LOOT_POOL schema +
## rarity weights, and the music_for_floor mapping (run as a static-style
## check by reading the constants on the AudioManager script).
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun24


var LOOT: GDScript  = load("res://scenes/LootScreen.gd")
var AUDIO_MGR: GDScript = load("res://autoloads/AudioManager.gd")


# ── Loot pool schema ─────────────────────────────────────────────────────────

func test_loot_pool_nonempty() -> void:
	var pool: Array = LOOT.LOOT_POOL
	assert_gt(pool.size(), 6, "LOOT_POOL has more than 6 items after rarity expansion")


func test_every_loot_item_has_required_keys() -> void:
	var pool: Array = LOOT.LOOT_POOL
	for it: Dictionary in pool:
		assert_true(it.has("id"),     "item has 'id'")
		assert_true(it.has("name"),   "%s has 'name'" % it.get("id", "?"))
		assert_true(it.has("type"),   "%s has 'type'" % it.get("id", "?"))
		assert_true(it.has("desc"),   "%s has 'desc'" % it.get("id", "?"))
		# Run 24: every item has an explicit rarity field
		assert_true(it.has("rarity"), "%s has 'rarity'" % it.get("id", "?"))


func test_loot_ids_unique() -> void:
	var pool: Array = LOOT.LOOT_POOL
	var seen: Dictionary = {}
	for it: Dictionary in pool:
		var id: String = String(it.get("id", ""))
		assert_true(not seen.has(id), "loot id '%s' is unique" % id)
		seen[id] = true


func test_rarity_values_are_known() -> void:
	## Every item's rarity must match one of the three known buckets;
	## drift here would silently fall through to common in the picker.
	var pool: Array = LOOT.LOOT_POOL
	var allowed: Array[String] = [LOOT.RARITY_COMMON, LOOT.RARITY_RARE, LOOT.RARITY_LEGENDARY]
	for it: Dictionary in pool:
		var r: String = String(it.get("rarity", ""))
		assert_true(allowed.has(r),
			"%s has a recognised rarity (got '%s')" % [it.get("id"), r])


func test_loot_types_in_apply_handler_set() -> void:
	## Defensive: a new item with an unhandled `type` would silently do
	## nothing in _apply_loot. Keep the allowed-list locked.
	var pool: Array = LOOT.LOOT_POOL
	var allowed: Array[String] = ["heal", "stat", "multi", "skip"]
	for it: Dictionary in pool:
		var t: String = String(it.get("type", ""))
		assert_true(allowed.has(t),
			"%s type '%s' is in the apply-handler allowed set" % [it.get("id"), t])


func test_pool_includes_at_least_one_of_each_rarity() -> void:
	## The picker downshifts to lower rarities when the target pool is empty;
	## the pool must seed at least one item of each rarity so deep-floor
	## slots have something legendary to actually pick.
	var pool: Array = LOOT.LOOT_POOL
	var counts: Dictionary = {
		LOOT.RARITY_COMMON: 0, LOOT.RARITY_RARE: 0, LOOT.RARITY_LEGENDARY: 0,
	}
	for it: Dictionary in pool:
		var r: String = String(it.get("rarity", ""))
		if counts.has(r):
			counts[r] += 1
	for r2: String in counts:
		assert_gt(int(counts[r2]), 0,
			"pool has at least one item of rarity '%s'" % r2)


# ── Rarity weight tables (per tier) ──────────────────────────────────────────

func test_rarity_weights_three_tiers() -> void:
	var tbl: Array = LOOT.RARITY_WEIGHTS_BY_TIER
	assert_eq(tbl.size(), 3, "three tier weight tables (stone/obsidian/void)")


func test_rarity_weights_legendary_grows_with_depth() -> void:
	## The whole point of rarity-by-tier: deep floors must be likelier to
	## see Legendary loot than the early ones. This locks the invariant.
	var tbl: Array = LOOT.RARITY_WEIGHTS_BY_TIER
	var t0_leg: int = int((tbl[0] as Dictionary).get(LOOT.RARITY_LEGENDARY, 0))
	var t1_leg: int = int((tbl[1] as Dictionary).get(LOOT.RARITY_LEGENDARY, 0))
	var t2_leg: int = int((tbl[2] as Dictionary).get(LOOT.RARITY_LEGENDARY, 0))
	assert_gt(t1_leg, t0_leg, "tier 1 legendary weight > tier 0")
	assert_gt(t2_leg, t1_leg, "tier 2 legendary weight > tier 1")


func test_rarity_weights_common_shrinks_with_depth() -> void:
	## Conversely, Common shouldn't be the dominant pick by the void tier.
	var tbl: Array = LOOT.RARITY_WEIGHTS_BY_TIER
	var t0_c: int = int((tbl[0] as Dictionary).get(LOOT.RARITY_COMMON, 0))
	var t2_c: int = int((tbl[2] as Dictionary).get(LOOT.RARITY_COMMON, 0))
	assert_gt(t0_c, t2_c, "tier 0 common weight > tier 2 common")


func test_rarity_weights_all_positive_total() -> void:
	for tier_weights: Dictionary in LOOT.RARITY_WEIGHTS_BY_TIER:
		var total: int = 0
		for r: String in tier_weights:
			total += int(tier_weights[r])
		assert_gt(total, 0, "weight total is positive")


# ── Audio music-by-tier mapping ──────────────────────────────────────────────

func test_audio_music_names_contains_four_tracks() -> void:
	var names: Array = AUDIO_MGR.MUSIC_NAMES
	assert_true(names.has("music_title"),    "music_title is registered")
	assert_true(names.has("music_stone"),    "music_stone is registered")
	assert_true(names.has("music_obsidian"), "music_obsidian is registered")
	assert_true(names.has("music_void"),     "music_void is registered")


func test_audio_constants_defined() -> void:
	# These are referenced from scenes; locking the shape prevents accidental
	# rename/removal silently breaking the music pipeline.
	assert_gt(int(AUDIO_MGR.VOICE_COUNT), 0, "VOICE_COUNT positive")
	assert_true(String(AUDIO_MGR.AUDIO_DIR).begins_with("res://"),
		"AUDIO_DIR is a res:// path")
	assert_gt((AUDIO_MGR.MUSIC_NAMES as Array).size(), 0,
		"MUSIC_NAMES is non-empty")
