## Run 3 feature tests: ability charges, floor scaling, enemy collision, lava damage.
## Extends the run_tests.gd BaseTest class.

class_name TestRun3
extends "res://tests/run_tests.gd".BaseTest

## ─── Ability Charge / Cooldown Tests ────────────────────────────────────────

func test_ability_can_use_limited_charges() -> void:
	var obj := Ability.new("power_strike", "Power Strike")
	obj.max_charges = 1
	obj.current_charges = 1
	obj.cooldown_turns = 3
	obj.cooldown_remaining = 0
	assert_true(obj.can_use(), "Ability with 1/1 charges can be used")

func test_ability_use_decrements_charges() -> void:
	var obj := Ability.new("power_strike", "Power Strike")
	obj.max_charges = 2
	obj.current_charges = 2
	obj.cooldown_turns = 2
	obj.cooldown_remaining = 0
	obj.use()
	assert_eq(obj.current_charges, 1, "Charges decremented after use (2→1)")

func test_ability_depleted_cannot_use() -> void:
	var obj := Ability.new("fireball", "Fireball")
	obj.max_charges = 1
	obj.current_charges = 0
	obj.cooldown_turns = 4
	obj.cooldown_remaining = 4
	assert_true(not obj.can_use(), "Depleted ability (0 charges, on cooldown) cannot be used")

func test_ability_unlimited_can_always_use() -> void:
	var obj := Ability.new("basic_attack", "Basic Attack")
	obj.max_charges = -1
	obj.current_charges = 1  # sentinel for unlimited
	obj.cooldown_turns = 0
	obj.cooldown_remaining = 0
	assert_true(obj.can_use(), "Unlimited ability (max_charges=-1) always can_use")
	obj.use()
	assert_true(obj.can_use(), "Unlimited ability still can_use after use()")

func test_ability_cooldown_ticks_down() -> void:
	var obj := Ability.new("frost_nova", "Frost Nova")
	obj.max_charges = 1
	obj.current_charges = 0
	obj.cooldown_turns = 3
	obj.cooldown_remaining = 3
	obj.tick_cooldown()
	assert_eq(obj.cooldown_remaining, 2, "Cooldown ticked from 3 to 2")

func test_ability_recharges_after_cooldown() -> void:
	var obj := Ability.new("taunt", "Taunt")
	obj.max_charges = 1
	obj.current_charges = 0
	obj.cooldown_turns = 2
	obj.cooldown_remaining = 1
	obj.tick_cooldown()  # remaining goes to 0, charge refills
	assert_eq(obj.cooldown_remaining, 0, "Cooldown at 0 after final tick")
	assert_eq(obj.current_charges, 1, "Charge refilled after cooldown expires")
	assert_true(obj.can_use(), "Ability is usable again after recharge")

## ─── Floor Scaling Tests ─────────────────────────────────────────────────────

func test_floor1_enemy_base_stats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var imp_def: Dictionary = {"id": "imp", "display_name": "Imp", "hp": 25, "armor": 0, "speed": 12,
		"abilities": ["enemy_claw"], "xp_reward": 20, "sprite_key": "imp", "min_floor": 1}
	var c: Combatant = EnemyDefs.make_combatant(imp_def, Vector2i.ZERO, rng, 1)
	assert_eq(c.max_hp, 25, "Floor 1 imp has base 25 HP")
	assert_eq(c.attack_bonus, 0, "Floor 1 imp has 0 attack_bonus")

func test_floor3_enemy_scaled_hp() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var imp_def: Dictionary = {"id": "imp", "display_name": "Imp", "hp": 25, "armor": 0, "speed": 12,
		"abilities": ["enemy_claw"], "xp_reward": 20, "sprite_key": "imp", "min_floor": 1}
	var c: Combatant = EnemyDefs.make_combatant(imp_def, Vector2i.ZERO, rng, 3)
	# Floor 3 scale = 1 + 2 * 0.15 = 1.30, so 25 * 1.30 = 32 (int)
	assert_gt(c.max_hp, 25, "Floor 3 imp has more HP than floor 1 (%d > 25)" % c.max_hp)
	assert_eq(c.max_hp, 32, "Floor 3 imp has 32 HP (25 * 1.30)")

func test_floor3_enemy_scaled_attack() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var imp_def: Dictionary = {"id": "imp", "display_name": "Imp", "hp": 25, "armor": 0, "speed": 12,
		"abilities": ["enemy_claw"], "xp_reward": 20, "sprite_key": "imp", "min_floor": 1}
	var c: Combatant = EnemyDefs.make_combatant(imp_def, Vector2i.ZERO, rng, 3)
	# Floor 3: (3-1) * 2 = 4 attack_bonus
	assert_eq(c.attack_bonus, 4, "Floor 3 imp has attack_bonus=4")

func test_floor5_enemy_higher_than_floor1() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var def: Dictionary = {"id": "goblin", "display_name": "Goblin", "hp": 35, "armor": 1, "speed": 14,
		"abilities": ["enemy_claw"], "xp_reward": 25, "sprite_key": "goblin", "min_floor": 1}
	var c1: Combatant = EnemyDefs.make_combatant(def, Vector2i.ZERO, rng, 1)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1
	var c5: Combatant = EnemyDefs.make_combatant(def, Vector2i.ZERO, rng2, 5)
	assert_gt(c5.max_hp, c1.max_hp, "Floor 5 goblin has more HP than floor 1 (%d > %d)" % [c5.max_hp, c1.max_hp])
	assert_gt(c5.attack_bonus, c1.attack_bonus, "Floor 5 goblin has higher attack_bonus")

## ─── Enemy Collision Avoidance Tests ─────────────────────────────────────────

func _make_test_map() -> DungeonMap:
	## Create a flat passable map for testing movement
	var map := DungeonMap.new()
	for q: int in range(-6, 7):
		for r: int in range(-6, 7):
			if HexGrid.hex_distance(Vector2i.ZERO, Vector2i(q, r)) <= 6:
				map.passable[Vector2i(q, r)] = true
				map.tile_types[Vector2i(q, r)] = "floor"
	return map

func test_enemy_collision_avoidance() -> void:
	## Two imps try to move toward hero; the second one should not stack on the first.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var map: DungeonMap = _make_test_map()

	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	# e1 is at (2,0), e2 is at (3,0). Both want to move toward hero (0,0).
	var e1 := Combatant.new("e1", "Imp1", Combatant.Faction.ENEMY, 50, 8)
	e1.sprite_key = "imp"
	e1.position = Vector2i(2, 0)
	var e2 := Combatant.new("e2", "Imp2", Combatant.Faction.ENEMY, 50, 8)
	e2.sprite_key = "imp"
	e2.position = Vector2i(3, 0)
	var ea: Array[String] = ["enemy_claw"]
	e1.abilities = ea; e2.abilities = ea

	var all: Array[Combatant] = [hero, e1, e2]
	var engine := BattleEngine.new(rng)
	engine.setup(all)

	# Move e1 first: (2,0) → (1,0)  [adjacent to hero, stops there or attacks]
	# Actually imp AI moves AND attacks if adjacent. We just want to see position after move.
	# Run AI for e2 FIRST (it's further back): should move from (3,0) toward hero.
	engine.enemy_ai_action(e2, map)  # e2 tries to move toward (0,0); best step is (2,0) but e1 is there
	# e2 should NOT be at e1's position
	assert_true(e2.position != e1.position, "e2 does not land on same hex as e1 (collision avoided)")

func test_enemy_does_not_stack_after_both_move() -> void:
	## Both enemies advance; they should always be on distinct hexes.
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var map: DungeonMap = _make_test_map()

	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	hero.position = Vector2i(0, 0)
	var e1 := Combatant.new("e1", "Imp1", Combatant.Faction.ENEMY, 50, 8)
	e1.sprite_key = "goblin"
	e1.position = Vector2i(3, 0)
	var e2 := Combatant.new("e2", "Imp2", Combatant.Faction.ENEMY, 50, 8)
	e2.sprite_key = "goblin"
	e2.position = Vector2i(4, 0)
	var ea: Array[String] = ["enemy_claw"]
	e1.abilities = ea; e2.abilities = ea

	var all: Array[Combatant] = [hero, e1, e2]
	var engine := BattleEngine.new(rng)
	engine.setup(all)

	engine.enemy_ai_action(e1, map)
	engine.enemy_ai_action(e2, map)
	assert_true(e1.position != e2.position, "Enemies on distinct hexes after both move")

## ─── Lava Damage Tests ───────────────────────────────────────────────────────

func test_lava_damage_adjacent() -> void:
	## Combatant adjacent to lava takes 3 HP of damage.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var map: DungeonMap = _make_test_map()
	# Place lava adjacent to hero position
	map.tile_types[Vector2i(1, 0)] = "lava"
	map.passable[Vector2i(1, 0)] = false

	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Dummy", Combatant.Faction.ENEMY, 50, 5)
	enemy.position = Vector2i(5, 0)
	var all: Array[Combatant] = [hero, enemy]
	var engine := BattleEngine.new(rng)
	engine.setup(all)

	var initial_hp: int = hero.hp
	engine.apply_lava_damage(hero, map)
	assert_eq(hero.hp, initial_hp - 3, "Hero takes exactly 3 lava damage when adjacent (got %d, expected %d)" % [hero.hp, initial_hp - 3])

func test_lava_no_damage_when_not_adjacent() -> void:
	## Combatant NOT adjacent to lava takes no damage.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var map: DungeonMap = _make_test_map()
	# Lava is 2+ hexes away
	map.tile_types[Vector2i(3, 0)] = "lava"
	map.passable[Vector2i(3, 0)] = false

	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Dummy", Combatant.Faction.ENEMY, 50, 5)
	enemy.position = Vector2i(5, 0)
	var all: Array[Combatant] = [hero, enemy]
	var engine := BattleEngine.new(rng)
	engine.setup(all)

	var initial_hp: int = hero.hp
	engine.apply_lava_damage(hero, map)
	assert_eq(hero.hp, initial_hp, "No lava damage when not adjacent to lava")

func test_lava_damage_bypasses_armor() -> void:
	## Lava damage is direct HP reduction (not mitigated by armor).
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var map: DungeonMap = _make_test_map()
	map.tile_types[Vector2i(1, 0)] = "lava"
	map.passable[Vector2i(1, 0)] = false

	var hero := Combatant.new("hero", "Tank", Combatant.Faction.HERO, 100, 10)
	hero.armor = 20  # very high armor — lava ignores it
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Dummy", Combatant.Faction.ENEMY, 50, 5)
	enemy.position = Vector2i(5, 0)
	var all: Array[Combatant] = [hero, enemy]
	var engine := BattleEngine.new(rng)
	engine.setup(all)

	var initial_hp: int = hero.hp
	engine.apply_lava_damage(hero, map)
	assert_eq(hero.hp, initial_hp - 3, "Lava damage bypasses armor (3 HP lost even with armor=20)")

func test_lava_damage_emits_signal() -> void:
	## lava_damaged signal fires with correct combatant and damage.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var map: DungeonMap = _make_test_map()
	map.tile_types[Vector2i(0, 1)] = "lava"
	map.passable[Vector2i(0, 1)] = false

	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Dummy", Combatant.Faction.ENEMY, 50, 5)
	enemy.position = Vector2i(5, 0)
	var all: Array[Combatant] = [hero, enemy]
	var engine := BattleEngine.new(rng)
	engine.setup(all)

	var fired: Array[bool] = [false]
	var damage_received: Array[int] = [0]
	engine.lava_damaged.connect(func(_c: Combatant, dmg: int) -> void:
		fired[0] = true
		damage_received[0] = dmg
	)
	engine.apply_lava_damage(hero, map)
	assert_true(fired[0], "lava_damaged signal was emitted")
	assert_eq(damage_received[0], 3, "lava_damaged signal carries damage=3")

func test_lava_kills_enemy_ends_battle() -> void:
	## If lava kills the last enemy, battle_ended fires with hero_won=true.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var map: DungeonMap = _make_test_map()
	map.tile_types[Vector2i(1, 0)] = "lava"
	map.passable[Vector2i(1, 0)] = false

	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Dying Imp", Combatant.Faction.ENEMY, 3, 5)
	enemy.xp_reward = 10
	enemy.position = Vector2i(0, 0)  # same hex as hero, different combatant

	# Place enemy adjacent to lava (1,0) at (0,0) — the lava is adjacent
	# Actually (1,0) is adjacent to (0,0), so enemy at (0,0) would also be adjacent
	# Let's put enemy at (2,0) instead and lava at (3,0)
	enemy.position = Vector2i(2, 0)
	map.tile_types[Vector2i(3, 0)] = "lava"
	map.passable[Vector2i(3, 0)] = false

	var all: Array[Combatant] = [hero, enemy]
	var engine := BattleEngine.new(rng)
	engine.setup(all)

	var battle_won: Array[bool] = [false]
	engine.battle_ended.connect(func(hw: bool, _xp: int) -> void:
		battle_won[0] = hw
	)

	engine.apply_lava_damage(enemy, map)
	assert_true(not enemy.is_alive(), "Enemy killed by lava (had 3 HP)")
	assert_true(battle_won[0], "Battle ended with hero_won=true after lava kills last enemy")
