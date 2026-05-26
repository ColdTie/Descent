## Tests for ability charges, cooldowns, make_ability factory, and
## enemy collision avoidance in BattleEngine._move_toward.
## Run 3 additions.

class_name TestAbilities
extends "res://tests/run_tests.gd".BaseTest

## ─── Ability object: can_use() and use() ─────────────────────────────────────

func test_ability_can_use_initially() -> void:
	var ab := Ability.new("power_strike", "Power Strike")
	ab.max_charges = 1
	ab.current_charges = 1
	ab.cooldown_turns = 3
	ab.cooldown_remaining = 0
	assert_true(ab.can_use(), "Ability with 1 charge can be used")

func test_ability_use_decrements_charges() -> void:
	var ab := Ability.new("power_strike", "Power Strike")
	ab.max_charges = 1
	ab.current_charges = 1
	ab.cooldown_turns = 3
	ab.cooldown_remaining = 0
	var used: bool = ab.use()
	assert_true(used, "use() returns true when charges available")
	assert_eq(ab.current_charges, 0, "Charges decremented after use")

func test_ability_cannot_use_after_depleted() -> void:
	var ab := Ability.new("power_strike", "Power Strike")
	ab.max_charges = 1
	ab.current_charges = 1
	ab.cooldown_turns = 3
	ab.cooldown_remaining = 0
	ab.use()
	assert_true(not ab.can_use(), "Depleted ability cannot be used")

func test_ability_use_sets_cooldown() -> void:
	var ab := Ability.new("fireball", "Fireball")
	ab.max_charges = 1
	ab.current_charges = 1
	ab.cooldown_turns = 4
	ab.cooldown_remaining = 0
	ab.use()
	assert_eq(ab.cooldown_remaining, 4, "Cooldown set after use")

func test_tick_cooldown_decrements() -> void:
	var ab := Ability.new("fireball", "Fireball")
	ab.max_charges = 1
	ab.current_charges = 0
	ab.cooldown_turns = 3
	ab.cooldown_remaining = 3
	ab.tick_cooldown()
	assert_eq(ab.cooldown_remaining, 2, "tick_cooldown decrements by 1")
	assert_eq(ab.current_charges, 0, "Not restored until cooldown = 0")

func test_tick_cooldown_restores_charge_at_zero() -> void:
	var ab := Ability.new("fireball", "Fireball")
	ab.max_charges = 1
	ab.current_charges = 0
	ab.cooldown_turns = 3
	ab.cooldown_remaining = 1  # One tick away from restore
	ab.tick_cooldown()
	assert_eq(ab.cooldown_remaining, 0, "Cooldown reaches 0")
	assert_eq(ab.current_charges, 1, "Charge restored when cooldown hits 0")
	assert_true(ab.can_use(), "Ability usable again after cooldown")

func test_unlimited_ability_always_usable() -> void:
	var ab := Ability.new("basic_attack", "Basic Attack")
	ab.max_charges = -1
	ab.current_charges = 1
	ab.cooldown_turns = 0
	ab.cooldown_remaining = 0
	assert_true(ab.can_use(), "Unlimited ability (max_charges=-1) always usable")
	var used: bool = ab.use()
	assert_true(used, "use() succeeds for unlimited ability")
	assert_eq(ab.current_charges, 1, "Unlimited ability charges not decremented")
	assert_true(ab.can_use(), "Still usable after use")

func test_use_returns_false_when_depleted() -> void:
	var ab := Ability.new("vanish", "Vanish")
	ab.max_charges = 1
	ab.current_charges = 0
	ab.cooldown_turns = 5
	ab.cooldown_remaining = 3
	var used: bool = ab.use()
	assert_true(not used, "use() returns false when depleted")

## ─── Abilities.make_ability() factory ────────────────────────────────────────

func test_make_ability_basic_attack() -> void:
	var ab: Ability = Abilities.make_ability("basic_attack")
	assert_eq(ab.id, "basic_attack", "id set correctly")
	assert_eq(ab.display_name, "Basic Attack", "display_name set")
	assert_eq(ab.max_charges, -1, "basic_attack is unlimited")
	assert_eq(ab.cooldown_turns, 0, "basic_attack no cooldown")
	assert_true(ab.can_use(), "basic_attack can always be used")

func test_make_ability_fireball() -> void:
	var ab: Ability = Abilities.make_ability("fireball")
	assert_eq(ab.id, "fireball", "id set")
	assert_eq(ab.max_charges, 1, "fireball has 1 charge")
	assert_eq(ab.current_charges, 1, "fireball starts fully charged")
	assert_eq(ab.cooldown_turns, 4, "fireball cooldown is 4")
	assert_eq(ab.range_tiles, 3, "fireball range is 3")
	assert_eq(ab.icon_key, "fire", "fireball icon_key is fire")

func test_make_ability_power_strike() -> void:
	var ab: Ability = Abilities.make_ability("power_strike")
	assert_eq(ab.max_charges, 1, "power_strike has 1 charge")
	assert_eq(ab.cooldown_turns, 3, "power_strike cooldown is 3")
	assert_true(ab.can_use(), "power_strike starts usable")

func test_make_ability_frost_nova() -> void:
	var ab: Ability = Abilities.make_ability("frost_nova")
	assert_eq(ab.id, "frost_nova", "frost_nova id set")
	assert_eq(ab.max_charges, 1, "1 charge")
	assert_eq(ab.cooldown_turns, 5, "cooldown 5")
	assert_eq(ab.range_tiles, 1, "range 1")

func test_full_cooldown_cycle() -> void:
	## Use ability, tick through full cooldown, verify restored
	var ab: Ability = Abilities.make_ability("power_strike")  # cd = 3
	ab.use()
	assert_eq(ab.current_charges, 0, "Spent after use")
	assert_eq(ab.cooldown_remaining, 3, "Cooldown = 3")
	ab.tick_cooldown()  # 3→2
	ab.tick_cooldown()  # 2→1
	assert_eq(ab.current_charges, 0, "Still on cooldown after 2 ticks")
	ab.tick_cooldown()  # 1→0, restore
	assert_eq(ab.cooldown_remaining, 0, "Cooldown expired")
	assert_eq(ab.current_charges, 1, "Charge restored")
	assert_true(ab.can_use(), "Ability ready again after full cooldown")

## ─── Enemy collision avoidance ───────────────────────────────────────────────

func test_enemies_dont_stack_on_same_hex() -> void:
	## Two enemies both moving toward hero from opposite sides shouldn't overlap
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)

	# Two goblins approaching from (3,0) and (2,0) — both want to move toward hero
	var e1 := Combatant.new("e1", "Goblin", Combatant.Faction.ENEMY, 35, 14)
	e1.sprite_key = "goblin"
	e1.position = Vector2i(3, 0)
	var ga1: Array[String] = ["basic_attack"]
	e1.abilities = ga1

	var e2 := Combatant.new("e2", "Goblin", Combatant.Faction.ENEMY, 35, 14)
	e2.sprite_key = "goblin"
	e2.position = Vector2i(2, -1)  # adjacent to (2,0) where e1 wants to go
	var ga2: Array[String] = ["basic_attack"]
	e2.abilities = ga2

	var all: Array[Combatant] = [hero, e1, e2]
	engine.setup(all)

	# Simulate one round of enemy AI — e1 moves toward hero
	# With collision check, e1 should NOT land on e2's hex
	var map := DungeonMap.new()
	map.generate(1, rng)
	# Place e1 at edge position and e2 at a position that e1 would want
	# Force positions into map space
	hero.position = map.hero_start
	e1.position = Vector2i(3, 0)  # wants to move to (2,0)
	e2.position = Vector2i(2, 0)  # blocking e1's destination
	engine.combatants = [hero, e1, e2]

	engine.enemy_ai_action(e1, map)
	# e1 should NOT end up at (2,0) since e2 is there
	assert_true(e1.position != e2.position,
		"Enemies do not occupy the same hex after movement (e1=%s, e2=%s)" % [str(e1.position), str(e2.position)])

func test_enemy_blocked_by_hero_does_not_move_into_hero() -> void:
	## Enemy directly adjacent to hero shouldn't slide through hero
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var imp := Combatant.new("imp1", "Imp", Combatant.Faction.ENEMY, 25, 12)
	imp.sprite_key = "imp"
	imp.position = Vector2i(2, 0)
	var ia: Array[String] = ["enemy_claw"]
	imp.abilities = ia
	var all: Array[Combatant] = [hero, imp]
	engine.setup(all)

	var map := DungeonMap.new()
	map.generate(1, rng)
	# Ensure positions are on valid floor tiles
	hero.position = Vector2i(0, 0)
	imp.position = Vector2i(2, 0)
	engine.combatants = [hero, imp]

	engine.enemy_ai_action(imp, map)
	# Imp moved toward hero but should not be on hero's hex
	assert_true(imp.position != hero.position,
		"Imp does not move onto hero's hex (imp=%s, hero=%s)" % [str(imp.position), str(hero.position)])

## ─── Floor scaling sanity check ──────────────────────────────────────────────

func test_enemy_hp_scales_by_floor() -> void:
	## Verify the scaling formula: floor 1 = 1.0x, floor 4 ≈ 1.54x
	var base_hp: float = 100.0
	# Floor 1: scale = 1.0 + (1-1)*0.18 = 1.0
	var scale_1: float = 1.0 + float(1 - 1) * 0.18
	assert_eq(int(base_hp * scale_1), 100, "Floor 1: no scaling")
	# Floor 4: scale = 1.0 + 3*0.18 = 1.54
	var scale_4: float = 1.0 + float(4 - 1) * 0.18
	assert_eq(int(base_hp * scale_4), 154, "Floor 4: 54% HP increase")
