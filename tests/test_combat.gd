extends "res://tests/run_tests.gd".BaseTest
class_name TestCombat

func _make_rng(seed_val: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

## ─── Combatant basics ─────────────────────────────────────────────────────────

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

func test_combatant_ignore_armor() -> void:
	var c := Combatant.new("tank", "Tank", Combatant.Faction.HERO, 100, 8)
	c.armor = 10
	var dmg: int = c.take_damage(15, true)  ## ignore_armor=true
	assert_eq(dmg, 15, "Backstab ignores all armor")

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

## ─── Status effects ───────────────────────────────────────────────────────────

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

func test_frozen_skip_turn() -> void:
	## Frozen combatant reports has_skip_turn_effect()
	var c := Combatant.new("e", "E", Combatant.Faction.ENEMY, 100, 10)
	c.apply_status(StatusEffect.frozen(2))
	## Before ticking: duration=2, skip_turn=true
	assert_true(c.has_skip_turn_effect(), "Freshly frozen has skip_turn")
	c.tick_statuses()
	## After one tick: duration=1, still active
	assert_true(c.has_skip_turn_effect(), "Still frozen after 1 tick (duration=1)")
	c.tick_statuses()
	## After two ticks: expired
	assert_true(not c.has_skip_turn_effect(), "No longer frozen after 2 ticks")

func test_frozen_skips_in_engine() -> void:
	## Frozen(2) means: enemy skips its next 2 turns.
	## With hero acting first (spd=10 > spd=5), the sequence across 2 outer loop
	## iterations is: [hero acts], [enemy skip→hero acts recursively].
	## The enemy only acts in iteration 3 (after frozen expires on second tick).
	var rng := _make_rng(77)
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	hero.abilities = ["basic_attack"]
	var enemy := Combatant.new("imp", "Imp", Combatant.Faction.ENEMY, 200, 5)
	enemy.abilities = ["enemy_claw"]
	engine.setup([hero, enemy])
	enemy.apply_status(StatusEffect.frozen(2))
	## Only iterate twice: both outer calls should return the hero (enemy is skipped).
	var hero_turns: int = 0
	var enemy_turns: int = 0
	for _i: int in range(2):
		if engine.battle_over:
			break
		var active: Combatant = engine.begin_turn()
		if active == null:
			break
		if active.faction == Combatant.Faction.HERO:
			hero_turns += 1
			engine.perform_attack(active, enemy, "basic_attack")
		else:
			enemy_turns += 1
		engine.end_turn()
	assert_true(hero_turns == 2, "Hero acted twice while enemy was frozen")
	assert_true(enemy_turns == 0, "Frozen enemy got 0 turns in those 2 iterations")

## ─── Ability charges / cooldowns ─────────────────────────────────────────────

func test_ability_charges_init() -> void:
	var c := Combatant.new("h", "H", Combatant.Faction.HERO, 100, 10)
	c.abilities = ["basic_attack", "power_strike"]
	c.init_ability_states()
	assert_true(c.can_use_ability("basic_attack"), "Unlimited charges ability is usable")
	assert_true(c.can_use_ability("power_strike"), "Charged ability starts usable")

func test_ability_use_depletes_charge() -> void:
	var c := Combatant.new("h", "H", Combatant.Faction.HERO, 100, 10)
	c.abilities = ["power_strike"]
	c.init_ability_states()
	c.use_ability("power_strike")
	assert_true(not c.can_use_ability("power_strike"), "Out of charges after use")

func test_ability_cooldown_ticks() -> void:
	var c := Combatant.new("h", "H", Combatant.Faction.HERO, 100, 10)
	c.abilities = ["power_strike"]  ## 1 charge, 3-turn cooldown
	c.init_ability_states()
	c.use_ability("power_strike")
	assert_true(not c.can_use_ability("power_strike"), "On cooldown after use")
	## Tick 3 times
	c.tick_ability_cooldowns()
	c.tick_ability_cooldowns()
	c.tick_ability_cooldowns()
	assert_true(c.can_use_ability("power_strike"), "Ready again after 3 cooldown ticks")

func test_recharge_all() -> void:
	var c := Combatant.new("h", "H", Combatant.Faction.HERO, 100, 10)
	c.abilities = ["power_strike", "fireball"]
	c.init_ability_states()
	c.use_ability("power_strike")
	c.use_ability("fireball")
	c.recharge_all()
	assert_true(c.can_use_ability("power_strike"), "Recharged power_strike")
	assert_true(c.can_use_ability("fireball"), "Recharged fireball")

## ─── Vanish multiplier ────────────────────────────────────────────────────────

func test_vanish_triples_damage() -> void:
	## Use a fixed-variance RNG so we can predict exact damage
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234  ## Check this seed gives variance=1.0 exactly? Not guaranteed, so we test ratio.
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	hero.abilities = ["basic_attack", "vanish"]
	hero.attack_bonus = 0
	var enemy := Combatant.new("dummy", "Dummy", Combatant.Faction.ENEMY, 1000, 1)
	enemy.armor = 0
	enemy.abilities = ["enemy_claw"]
	engine.setup([hero, enemy])

	## Normal attack (no vanish): record base damage
	var hp_before_normal: int = enemy.hp
	engine.perform_attack(hero, enemy, "basic_attack")
	var normal_dmg: int = hp_before_normal - enemy.hp

	## Apply vanish manually (set flag), then attack
	hero.vanish_active = true
	var hp_before_vanish: int = enemy.hp
	## Use perform_attack which calls _calculate_raw_damage and checks vanish_active
	engine.perform_attack(hero, enemy, "basic_attack")
	var vanish_dmg: int = hp_before_vanish - enemy.hp

	## Vanish damage should be significantly higher (3x the raw, approximately)
	assert_true(vanish_dmg > normal_dmg * 2, "Vanish at least 2x normal damage")

## ─── BattleEngine turn flow ───────────────────────────────────────────────────

func test_battle_engine_hero_wins() -> void:
	var rng := _make_rng(100)
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 1000, 10)
	hero.abilities = ["basic_attack"]
	var enemy := Combatant.new("imp_001", "Imp", Combatant.Faction.ENEMY, 5, 5)
	enemy.abilities = ["enemy_claw"]
	enemy.xp_reward = 20
	engine.setup([hero, enemy])
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

## ─── Movement ─────────────────────────────────────────────────────────────────

func test_hero_movement() -> void:
	var rng := _make_rng(5)
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.abilities = ["basic_attack"]
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e", "E", Combatant.Faction.ENEMY, 100, 5)
	enemy.abilities = ["enemy_claw"]
	enemy.position = Vector2i(4, 0)
	var passable: Dictionary = {}
	for h: Vector2i in HexGrid.disk(Vector2i.ZERO, 5):
		passable[h] = true
	engine.setup([hero, enemy], passable)

	var dest := Vector2i(1, 0)
	engine.move_combatant(hero, dest)
	assert_eq(hero.position, dest, "Hero moved to adjacent hex")

func test_enemy_moves_toward_hero() -> void:
	var rng := _make_rng(7)
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 5)
	hero.abilities = ["basic_attack"]
	hero.position = Vector2i(0, 0)
	## Use skeleton (melee, range 1) so it must move to reach hero
	var enemy := Combatant.new("skel", "Skeleton", Combatant.Faction.ENEMY, 100, 10)
	enemy.abilities = ["enemy_claw"]
	enemy.position = Vector2i(3, 0)
	var passable: Dictionary = {}
	for h: Vector2i in HexGrid.disk(Vector2i.ZERO, 5):
		passable[h] = true
	engine.setup([hero, enemy], passable)
	var dist_before: int = HexGrid.hex_distance(enemy.position, hero.position)
	engine.begin_turn()   ## hero's turn (hero is slower, actually enemy is faster spd=10 > hero spd=5)
	## Actually let's just call enemy_ai_action directly to test movement
	enemy.position = Vector2i(3, 0)  ## reset
	engine.enemy_ai_action(enemy)
	var dist_after: int = HexGrid.hex_distance(enemy.position, hero.position)
	assert_true(dist_after < dist_before, "Enemy moved closer to hero")

## ─── AoE abilities ────────────────────────────────────────────────────────────

func test_fireball_hits_multiple_enemies() -> void:
	var rng := _make_rng(42)
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	hero.abilities = ["fireball"]
	hero.attack_bonus = 0
	hero.position = Vector2i(0, 0)
	## Pack enemies close together so fireball (range 3, hits all in range) gets all three
	var e1 := Combatant.new("e1", "Imp1", Combatant.Faction.ENEMY, 100, 5)
	e1.position = Vector2i(2, 0)
	var e2 := Combatant.new("e2", "Imp2", Combatant.Faction.ENEMY, 100, 5)
	e2.position = Vector2i(3, 0)
	var e3 := Combatant.new("e3", "Imp3", Combatant.Faction.ENEMY, 100, 5)
	e3.position = Vector2i(1, 0)
	engine.setup([hero, e1, e2, e3])

	var hp_before: int = e1.hp + e2.hp + e3.hp
	## Fireball centered on e1's position (range 3 from hero), hits all in radius 3
	engine.perform_action(hero, e1.position, "fireball")
	var hp_after: int = e1.hp + e2.hp + e3.hp
	assert_true(hp_after < hp_before, "Fireball dealt damage")
	## All three enemies should have taken damage (all within range 3 of hero)
	assert_true(e1.hp < 100, "e1 hit by fireball")
	assert_true(e2.hp < 100, "e2 hit by fireball")
	assert_true(e3.hp < 100, "e3 hit by fireball")

func test_frost_nova_freezes_adjacent() -> void:
	var rng := _make_rng(99)
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	hero.abilities = ["frost_nova"]
	hero.position = Vector2i(0, 0)
	var e1 := Combatant.new("e1", "Imp1", Combatant.Faction.ENEMY, 100, 5)
	e1.position = Vector2i(1, 0)  ## adjacent
	var e2 := Combatant.new("e2", "Imp2", Combatant.Faction.ENEMY, 100, 5)
	e2.position = Vector2i(3, 0)  ## NOT adjacent (distance 3)
	engine.setup([hero, e1, e2])

	engine.perform_action(hero, hero.position, "frost_nova")
	assert_true(e1.has_skip_turn_effect(), "Adjacent enemy is frozen")
	assert_true(not e2.has_skip_turn_effect(), "Far enemy is NOT frozen")

## ─── Map / Enemy defs ─────────────────────────────────────────────────────────

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
	var enemies: Array[Dictionary] = EnemyDefs.get_enemies_for_floor(5)
	assert_eq(enemies.size(), 5, "Floor 5 unlocks all 5 enemy types")

func test_enemy_combatant_factory() -> void:
	var rng := _make_rng(55)
	var def: Dictionary = EnemyDefs.get_enemies_for_floor(1)[0]
	var c: Combatant = EnemyDefs.make_combatant(def, Vector2i(2, -1), rng)
	assert_true(c.is_alive(), "Spawned enemy is alive")
	assert_eq(c.position, Vector2i(2, -1), "Enemy position set correctly")
	assert_true(not c.abilities.is_empty(), "Enemy has abilities")
