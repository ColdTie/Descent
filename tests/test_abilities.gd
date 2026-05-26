## Tests for Ability charge/cooldown tracking (pure class — no Node/autoload dependency).
## Also covers EnemyDefs floor scaling.

class_name TestAbilities
extends "res://tests/run_tests.gd".BaseTest

## ── Ability charge tracking ────────────────────────────────────────────────

func test_ability_can_use_when_charged() -> void:
	var abl := Ability.new("power_strike", "Power Strike")
	abl.max_charges = 1
	abl.current_charges = 1
	abl.cooldown_turns = 3
	abl.cooldown_remaining = 0
	assert_true(abl.can_use(), "can_use true when charge available and no cooldown")

func test_ability_cannot_use_when_depleted_and_on_cooldown() -> void:
	var abl := Ability.new("power_strike", "Power Strike")
	abl.max_charges = 1
	abl.current_charges = 0
	abl.cooldown_turns = 3
	abl.cooldown_remaining = 3
	assert_true(not abl.can_use(), "can_use false when depleted and on cooldown")

func test_ability_use_decrements_charge_and_sets_cooldown() -> void:
	var abl := Ability.new("power_strike", "Power Strike")
	abl.max_charges = 1
	abl.current_charges = 1
	abl.cooldown_turns = 3
	abl.cooldown_remaining = 0
	var ok: bool = abl.use()
	assert_true(ok, "use() returns true when usable")
	assert_eq(abl.current_charges, 0, "charge decremented after use")
	assert_eq(abl.cooldown_remaining, 3, "cooldown set after use")

func test_ability_use_fails_when_depleted() -> void:
	var abl := Ability.new("fireball", "Fireball")
	abl.max_charges = 1
	abl.current_charges = 0
	abl.cooldown_turns = 4
	abl.cooldown_remaining = 2
	var ok: bool = abl.use()
	assert_true(not ok, "use() returns false when depleted")
	assert_eq(abl.current_charges, 0, "charges unchanged after failed use")

func test_ability_tick_cooldown_recharges_after_full_wait() -> void:
	var abl := Ability.new("power_strike", "Power Strike")
	abl.max_charges = 1
	abl.current_charges = 0
	abl.cooldown_turns = 3
	abl.cooldown_remaining = 3
	abl.tick_cooldown()
	assert_eq(abl.cooldown_remaining, 2, "cooldown at 2 after 1 tick")
	assert_eq(abl.current_charges, 0, "not recharged yet after 1 tick")
	abl.tick_cooldown()
	assert_eq(abl.cooldown_remaining, 1, "cooldown at 1 after 2 ticks")
	abl.tick_cooldown()
	assert_eq(abl.cooldown_remaining, 0, "cooldown at 0 after 3 ticks")
	assert_eq(abl.current_charges, 1, "charge restored after full cooldown")
	assert_true(abl.can_use(), "can_use true after full cooldown elapsed")

func test_infinite_ability_never_depletes() -> void:
	var abl := Ability.new("basic_attack", "Basic Attack")
	abl.max_charges = -1
	abl.current_charges = 99   # sentinel for infinite
	abl.cooldown_turns = 0
	abl.cooldown_remaining = 0
	for i: int in range(10):
		var ok: bool = abl.use()
		assert_true(ok, "infinite ability use() always returns true (iter %d)" % i)
	assert_true(abl.can_use(), "infinite ability always usable after 10 uses")
	assert_eq(abl.current_charges, 99, "infinite ability charges unchanged (sentinel)")

func test_recharge_full_restores_charges_and_clears_cooldown() -> void:
	var abl := Ability.new("fireball", "Fireball")
	abl.max_charges = 2
	abl.current_charges = 0
	abl.cooldown_turns = 4
	abl.cooldown_remaining = 3
	abl.recharge_full()
	assert_eq(abl.current_charges, 2, "recharge_full restores all charges")
	assert_eq(abl.cooldown_remaining, 0, "recharge_full clears cooldown")
	assert_true(abl.can_use(), "can_use true after recharge_full")

func test_multi_charge_ability_depletes_one_at_a_time() -> void:
	var abl := Ability.new("backstab", "Backstab")
	abl.max_charges = 2
	abl.current_charges = 2
	abl.cooldown_turns = 2
	abl.cooldown_remaining = 0
	abl.use()
	assert_eq(abl.current_charges, 1, "first use removes one charge")
	assert_true(abl.can_use(), "still usable with 1 charge left")
	abl.use()
	assert_eq(abl.current_charges, 0, "second use removes last charge")
	assert_true(not abl.can_use(), "not usable when all charges gone")

## ── Enemy floor scaling ──────────────────────────────────────────────────────

func test_enemy_scales_hp_with_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var def: Dictionary = EnemyDefs.ENEMIES[0]   # imp: base HP 25
	var base_hp: int = def["hp"]

	var c1: Combatant = EnemyDefs.make_combatant(def, Vector2i.ZERO, rng, 1)
	assert_eq(c1.max_hp, base_hp, "floor 1 enemy has base HP (%d)" % base_hp)

	var c5: Combatant = EnemyDefs.make_combatant(def, Vector2i.ZERO, rng, 5)
	var expected_hp: int = int(float(base_hp) * (1.0 + 4.0 * 0.25))  # +100% → 50
	assert_eq(c5.max_hp, expected_hp, "floor 5 enemy HP scaled correctly (%d vs %d)" % [c5.max_hp, expected_hp])

func test_enemy_attack_bonus_scales_with_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var def: Dictionary = EnemyDefs.ENEMIES[0]

	var c1: Combatant = EnemyDefs.make_combatant(def, Vector2i.ZERO, rng, 1)
	assert_eq(c1.attack_bonus, 0, "floor 1 enemy has zero attack bonus")

	var c4: Combatant = EnemyDefs.make_combatant(def, Vector2i.ZERO, rng, 4)
	assert_eq(c4.attack_bonus, 6, "floor 4 enemy has +6 attack bonus (3 floors × 2)")

func test_enemy_xp_scales_with_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var def: Dictionary = EnemyDefs.ENEMIES[0]   # imp: base xp 20

	var c1: Combatant = EnemyDefs.make_combatant(def, Vector2i.ZERO, rng, 1)
	var c3: Combatant = EnemyDefs.make_combatant(def, Vector2i.ZERO, rng, 3)
	assert_true(c3.xp_reward > c1.xp_reward,
		"higher floor enemy yields more XP (%d vs %d)" % [c3.xp_reward, c1.xp_reward])

## ── Enemy collision avoidance ────────────────────────────────────────────────

func test_move_toward_avoids_occupied_hex() -> void:
	## Two enemies both trying to reach the same target hex — second one
	## should not land on the first one's position.
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	# e1 is one step from hero — already adjacent, won't move
	var e1 := Combatant.new("e1", "Imp1", Combatant.Faction.ENEMY, 50, 8)
	e1.sprite_key = "imp"
	e1.position = Vector2i(1, 0)

	# e2 is two steps away, should want to move to (1,0) but it's occupied by e1
	var e2 := Combatant.new("e2", "Imp2", Combatant.Faction.ENEMY, 50, 8)
	e2.sprite_key = "imp"
	e2.position = Vector2i(2, 0)

	var all: Array[Combatant] = [hero, e1, e2]
	engine.setup(all)

	# Build a minimal passable map covering these hexes
	var map := DungeonMap.new()
	map.floor_num = 1
	var passable_hexes: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(1, -1), Vector2i(2, -1), Vector2i(1, 1), Vector2i(2, 1),
	]
	for h: Vector2i in passable_hexes:
		map.passable[h] = true
		map.tile_types[h] = "floor"

	# e2 AI action — tries to move toward hero; (1,0) is occupied so it should
	# pick an alternate hex or stay put, but NEVER land on (1,0)
	engine.enemy_ai_action(e2, map)
	assert_true(e2.position != Vector2i(1, 0),
		"e2 does not collide with e1 at (1,0) (e2 pos: %s)" % str(e2.position))
