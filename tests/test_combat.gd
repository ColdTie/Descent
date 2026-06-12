extends "res://tests/run_tests.gd".BaseTest
class_name TestCombat

func _make_rng(seed_val: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

func test_combatant_take_damage() -> void:
	var c := Combatant.new("hero", "Hero", Combatant.Faction.HERO, 100, 10)
	var dmg: int = c.take_damage(30)
	assert_eq(dmg, 30, "No armor: full damage")
	assert_eq(c.hp, 70, "HP reduced correctly")

func test_combatant_armor_mitigation() -> void:
	var c := Combatant.new("tank", "Tank", Combatant.Faction.HERO, 100, 8)
	c.armor = 5
	var dmg: int = c.take_damage(10)
	assert_eq(dmg, 5, "Armor mitigates 5 damage")

func test_combatant_overkill_clamps() -> void:
	var c := Combatant.new("e", "E", Combatant.Faction.ENEMY, 50, 10)
	c.take_damage(999)
	assert_eq(c.hp, 0, "HP clamps to 0")
	assert_true(not c.is_alive(), "Dead after overkill")

func test_combatant_heal() -> void:
	var c := Combatant.new("h", "H", Combatant.Faction.HERO, 100, 10)
	c.take_damage(40)
	var healed: int = c.heal(20)
	assert_eq(healed, 20, "Healed 20")
	assert_eq(c.hp, 80, "HP at 80")

func test_combatant_heal_cap() -> void:
	var c := Combatant.new("h", "H", Combatant.Faction.HERO, 100, 10)
	c.take_damage(10)
	var healed: int = c.heal(999)
	assert_eq(healed, 10, "Heal capped at missing HP")
	assert_eq(c.hp, 100, "HP at max")

func test_status_tick_damage() -> void:
	var c := Combatant.new("e", "E", Combatant.Faction.ENEMY, 100, 10)
	c.apply_status(StatusEffect.burning(3, 5))
	var dmg: int = c.tick_statuses()
	assert_eq(dmg, 5, "Burning deals 5/turn")
	assert_eq(c.hp, 95, "HP reduced by burn")

func test_status_expires() -> void:
	var c := Combatant.new("e", "E", Combatant.Faction.ENEMY, 100, 10)
	c.apply_status(StatusEffect.burning(2, 5))
	c.tick_statuses()
	c.tick_statuses()
	assert_eq(c.status_effects.size(), 0, "Status expired after 2 ticks")

func test_battle_engine_hero_wins() -> void:
	var rng := _make_rng(100)
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 1000, 10)
	hero.abilities = ["basic_attack"]
	var enemy := Combatant.new("imp_001", "Imp", Combatant.Faction.ENEMY, 5, 5)
	enemy.abilities = ["enemy_claw"]
	enemy.xp_reward = 20
	engine.setup([hero, enemy])
	# Simulate up to 20 turns
	for _i: int in range(20):
		if engine.battle_over:
			break
		var active: Combatant = engine.begin_turn()
		if active == null:
			break
		if active.faction == Combatant.Faction.HERO:
			engine.perform_attack(active, enemy, "basic_attack")
		else:
			engine.enemy_ai_action(active)
		engine.end_turn()
	# GDScript lambdas capture by value; check state directly on engine
	assert_true(engine.battle_over, "Battle ended")
	assert_true(engine.hero_won, "Hero wins vs 5HP enemy")

func test_battle_engine_enemy_wins() -> void:
	var rng := _make_rng(200)
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 1, 10)
	hero.abilities = ["basic_attack"]
	var golem := Combatant.new("golem_001", "Golem", Combatant.Faction.ENEMY, 1000, 15)
	golem.abilities = ["enemy_claw"]
	engine.setup([hero, golem])
	for _i: int in range(20):
		if engine.battle_over:
			break
		var active: Combatant = engine.begin_turn()
		if active == null:
			break
		if active.faction == Combatant.Faction.HERO:
			engine.perform_attack(active, golem, "basic_attack")
		else:
			engine.enemy_ai_action(active)
		engine.end_turn()
	assert_true(engine.battle_over, "Battle ended (enemy wins)")
	assert_true(not engine.hero_won, "Enemy wins vs 1HP hero")

func test_turn_order_speed() -> void:
	var rng := _make_rng(1)
	var engine := BattleEngine.new(rng)
	var slow := Combatant.new("slow", "Slow", Combatant.Faction.ENEMY, 50, 3)
	var fast := Combatant.new("fast", "Fast", Combatant.Faction.HERO, 50, 15)
	engine.setup([slow, fast])
	var first: Combatant = engine.begin_turn()
	assert_eq(first.id, "fast", "Faster combatant (speed=15) goes first")

func test_dungeon_map_generates() -> void:
	var rng := _make_rng(77)
	var dungeon := DungeonMap.new()
	dungeon.generate(1, rng)
	assert_true(dungeon.spawn_points.size() >= 3, "Floor 1 has >= 3 spawn points")
	assert_true(dungeon.is_passable(Vector2i(0, 0)), "Center hex is passable")
	assert_true(not dungeon.tile_types.is_empty(), "Tile types are populated")

func test_dungeon_map_lava_not_at_center() -> void:
	var rng := _make_rng(99)
	var dungeon := DungeonMap.new()
	dungeon.generate(1, rng)
	assert_true(dungeon.get_tile_type(Vector2i(0, 0)) != "lava", "Center is never lava")

func test_dungeon_map_more_enemies_deeper() -> void:
	var rng1 := _make_rng(10)
	var d1 := DungeonMap.new()
	d1.generate(1, rng1)
	var rng2 := _make_rng(10)
	var d2 := DungeonMap.new()
	d2.generate(5, rng2)
	assert_true(d2.spawn_points.size() >= d1.spawn_points.size(), "Deeper floors have more spawns")

func test_enemy_defs_floor1() -> void:
	var enemies: Array[Dictionary] = EnemyDefs.get_enemies_for_floor(1)
	assert_true(enemies.size() >= 2, "Floor 1 has at least 2 enemy types")

func test_enemy_defs_floor5() -> void:
	## Floor 5 unlocks the full tier-1 pool: the 5 originals (imp, goblin,
	## skeleton, demon_grunt, lava_golem) plus the Run-34 tier-1 variants
	## (cave_bat at floor 2, stone_skeleton at floor 3) = 7 entries. Use >=
	## so future tier-1 additions don't break this.
	var enemies: Array[Dictionary] = EnemyDefs.get_enemies_for_floor(5)
	assert_true(enemies.size() >= 7, "Floor 5 unlocks the full tier-1 pool")

func test_enemy_combatant_factory() -> void:
	var rng := _make_rng(55)
	var def: Dictionary = EnemyDefs.get_enemies_for_floor(1)[0]
	var c: Combatant = EnemyDefs.make_combatant(def, Vector2i(2, -1), rng)
	assert_true(c.is_alive(), "Spawned enemy is alive")
	assert_eq(c.position, Vector2i(2, -1), "Enemy position set correctly")
	assert_true(not c.abilities.is_empty(), "Enemy has abilities")
