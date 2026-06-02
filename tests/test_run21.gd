## Run 21 tests: Shop economy + Mana Shield ability + take_damage absorb path.
##
## Per the project test rule, autoload runtime state isn't exercised here.
## We validate the pure data classes (Shop, Abilities, StatusEffect) and the
## absorb mechanic via headless Combatant instances.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun21

# load() (not preload()) so the script resolves at test runtime — matches the
# pattern used in test_run19.gd / test_run20.gd. Both Shop and StatusEffect
# are pure (no autoload references).
var SHOP: GDScript          = load("res://src/data/Shop.gd")
var STATUS: GDScript        = load("res://src/combat/StatusEffect.gd")
var COMBATANT: GDScript     = load("res://src/combat/Combatant.gd")
var ABILITIES: GDScript     = load("res://src/data/Abilities.gd")


# ── Shop: inventory schema ────────────────────────────────────────────────────

func test_shop_inventory_nonempty() -> void:
	var inv: Array = SHOP.INVENTORY
	assert_true(inv.size() >= SHOP.SLATE_SIZE,
		"Inventory has at least SLATE_SIZE items (got %d)" % inv.size())

func test_shop_slate_size_positive() -> void:
	assert_gt(int(SHOP.SLATE_SIZE), 0, "SLATE_SIZE is positive")

func test_every_shop_item_has_required_keys() -> void:
	var inv: Array = SHOP.INVENTORY
	for it: Dictionary in inv:
		assert_true(it.has("id"),      "item has 'id'")
		assert_true(it.has("name"),    "%s has 'name'" % it.get("id", "?"))
		assert_true(it.has("desc"),    "%s has 'desc'" % it.get("id", "?"))
		assert_true(it.has("cost"),    "%s has 'cost'" % it.get("id", "?"))
		assert_true(it.has("effects"), "%s has 'effects'" % it.get("id", "?"))
		assert_gt(int(it.get("cost", 0)), 0, "%s cost > 0" % it.get("id", "?"))

func test_shop_ids_unique() -> void:
	var inv: Array = SHOP.INVENTORY
	var seen: Dictionary = {}
	for it: Dictionary in inv:
		var id: String = String(it.get("id", ""))
		assert_true(not seen.has(id), "shop id '%s' is unique" % id)
		seen[id] = true

func test_shop_effects_allowed_keys() -> void:
	## Effect keys must match what Shop.gd._apply_effects() actually handles.
	## Drift here = silently-ignored stat changes, which is the kind of bug
	## tests should catch before it ships.
	var inv: Array = SHOP.INVENTORY
	var allowed: Array[String] = ["attack", "defense", "speed", "max_hp",
		"heal", "audience", "full_heal"]
	for it: Dictionary in inv:
		var fx: Dictionary = it.get("effects", {})
		assert_gt(fx.size(), 0, "%s has at least one effect" % it.get("id"))
		for k: String in fx.keys():
			assert_true(allowed.has(k),
				"%s effect key '%s' is in the allowed set" % [it.get("id"), k])

func test_shop_get_item_round_trip() -> void:
	var first_id: String = String((SHOP.INVENTORY[0] as Dictionary)["id"])
	var found: Dictionary = SHOP.get_item(first_id)
	assert_eq(String(found.get("id", "")), first_id,
		"get_item returns the matching record")

func test_shop_get_item_miss_returns_empty() -> void:
	var miss: Dictionary = SHOP.get_item("definitely_not_a_shop_id")
	assert_true(miss.is_empty(), "get_item returns {} for unknown id")

# ── Shop: gold economy helpers ────────────────────────────────────────────────

func test_gold_per_kill_scales_with_floor() -> void:
	## Higher floors should pay more per kill so the player can afford the
	## proportionally pricier mid- and late-shop items.
	var floor_1: int = SHOP.gold_for_kill(1)
	var floor_18: int = SHOP.gold_for_kill(18)
	assert_gt(floor_18, floor_1, "Floor 18 kill > Floor 1 kill")
	assert_gt(floor_1, 0, "Floor 1 kill awards positive gold")

func test_gold_per_boss_dominates_per_kill() -> void:
	## Bosses should be a meaningful payday vs. a regular enemy on the same floor.
	for f: int in [1, 6, 12, 18]:
		assert_gt(SHOP.gold_for_boss(f), SHOP.gold_for_kill(f),
			"Floor %d boss gold > kill gold" % f)

func test_gold_for_clear_positive() -> void:
	for f: int in [1, 6, 12, 18]:
		assert_gt(SHOP.gold_for_clear(f), 0,
			"Floor %d clear awards positive gold" % f)

func test_should_show_shop_skips_when_broke() -> void:
	## A player with 0 gold shouldn't see a useless shop screen.
	assert_true(not SHOP.should_show_shop(5, 0),
		"Broke hero on Floor 5 skips the shop")

func test_should_show_shop_when_wealthy() -> void:
	assert_true(SHOP.should_show_shop(5, 80),
		"Hero with gold on Floor 5 sees the shop (default cadence = 1)")

# ── Shop: slate generation determinism ────────────────────────────────────────

func test_shop_slate_deterministic_for_same_seed() -> void:
	## Two slates from the same seed must match — protects the per-run seed
	## guarantee even when the merchant is part of the route.
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 424242
	var slate_a: Array = SHOP.slate(rng_a)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 424242
	var slate_b: Array = SHOP.slate(rng_b)
	assert_eq(slate_a.size(), slate_b.size(), "Slate sizes equal")
	for i: int in range(slate_a.size()):
		assert_eq(String((slate_a[i] as Dictionary)["id"]),
			String((slate_b[i] as Dictionary)["id"]),
			"Slate item %d matches across runs" % i)

func test_shop_slate_returns_unique_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var slate: Array = SHOP.slate(rng)
	var seen: Dictionary = {}
	for it: Dictionary in slate:
		var id: String = String(it.get("id", ""))
		assert_true(not seen.has(id), "slate has no duplicates: %s" % id)
		seen[id] = true

# ── Mana Shield ability data ──────────────────────────────────────────────────

func test_mana_shield_ability_exists() -> void:
	var abl: Dictionary = ABILITIES.DATA.get("mana_shield", {})
	assert_true(not abl.is_empty(), "mana_shield is defined in Abilities.DATA")
	assert_eq(String(abl.get("target", "")), "self", "mana_shield targets self")
	assert_true(abl.get("applies_mana_shield", false),
		"mana_shield has applies_mana_shield=true marker")
	assert_gt(int(abl.get("mana_shield_amount", 0)), 0,
		"mana_shield_amount is positive")

func test_mana_shield_status_factory() -> void:
	var s: Dictionary = STATUS.mana_shield(40)
	assert_eq(String(s.get("id", "")), "mana_shield", "status id = mana_shield")
	assert_eq(int(s.get("absorb_remaining", 0)), 40,
		"absorb_remaining = constructor argument")
	assert_eq(int(s.get("absorb_max", 0)), 40,
		"absorb_max retained for HUD display")

# ── Mana Shield damage absorption (Combatant integration) ─────────────────────

func test_mana_shield_absorbs_full_hit() -> void:
	## A 30-damage hit against a 40-point shield: 0 damage through, 10 shield left.
	var c: Combatant = COMBATANT.new("t", "Tester", Combatant.Faction.HERO, 100, 10)
	c.apply_status(STATUS.mana_shield(40))
	var dealt: int = c.take_damage(30)
	assert_eq(dealt, 0, "Hit fully absorbed by shield → 0 dealt")
	assert_eq(c.hp, 100, "HP unchanged when shield absorbs")
	# Shield should still be present with reduced pool.
	var found_shield: bool = false
	for eff: Dictionary in c.status_effects:
		if eff.get("id", "") == "mana_shield":
			found_shield = true
			assert_eq(int(eff.get("absorb_remaining", 0)), 10,
				"Shield pool reduced to 10")
	assert_true(found_shield, "Shield still active after partial drain")

func test_mana_shield_overflow_falls_through_to_armor() -> void:
	## A 60-damage hit against a 40-point shield with 5 armor:
	## shield eats 40, 20 falls through, armor reduces to 15 actual.
	var c: Combatant = COMBATANT.new("t", "Tester", Combatant.Faction.HERO, 100, 10)
	c.armor = 5
	c.apply_status(STATUS.mana_shield(40))
	var dealt: int = c.take_damage(60)
	assert_eq(dealt, 15, "Overflow (20) minus armor (5) = 15 dealt")
	assert_eq(c.hp, 85, "HP reduced by 15")
	# Shield must be consumed.
	for eff: Dictionary in c.status_effects:
		assert_true(eff.get("id", "") != "mana_shield",
			"Shield removed after being drained")

func test_mana_shield_ignore_armor_still_overflows() -> void:
	## ignore_armor=true (e.g. backstab) doesn't bypass the shield — the shield
	## eats first, and only overflow gets the ignore-armor treatment.
	var c: Combatant = COMBATANT.new("t", "Tester", Combatant.Faction.HERO, 100, 10)
	c.armor = 5
	c.apply_status(STATUS.mana_shield(40))
	var dealt: int = c.take_damage(60, true)  # ignore_armor
	assert_eq(dealt, 20, "Overflow (20) ignores armor → 20 dealt")
	assert_eq(c.hp, 80, "HP reduced by 20")

func test_mana_shield_zero_damage_is_zero() -> void:
	## Edge case: 0-damage hit (e.g. a min-damage 1 reduced to 0 by armor in
	## the calling path) shouldn't crash or change the shield.
	var c: Combatant = COMBATANT.new("t", "Tester", Combatant.Faction.HERO, 100, 10)
	c.apply_status(STATUS.mana_shield(40))
	var dealt: int = c.take_damage(0)
	assert_eq(dealt, 0, "0-damage hit deals 0")
	for eff: Dictionary in c.status_effects:
		if eff.get("id", "") == "mana_shield":
			assert_eq(int(eff.get("absorb_remaining", 0)), 40,
				"Shield pool unchanged by 0-damage hit")
