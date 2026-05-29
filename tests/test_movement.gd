## Tests for hero movement, ability effects (vanish multiplier, frozen skip),
## enemy AI variants, and AOE perform_aoe_attack.
## Extends the run_tests.gd BaseTest class.

class_name TestMovement
extends "res://tests/run_tests.gd".BaseTest

func test_move_combatant_updates_position() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Imp", Combatant.Faction.ENEMY, 50, 8)
	enemy.position = Vector2i(2, 0)
	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)

	var moved: bool = engine.move_combatant(hero, Vector2i(1, 0))
	assert_true(moved, "move_combatant returns true")
	assert_eq(hero.position, Vector2i(1, 0), "Hero position updated after move")

func test_move_emits_hero_moved_signal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Imp", Combatant.Faction.ENEMY, 50, 8)
	enemy.position = Vector2i(3, 0)
	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)

	# Use Array as a reference so lambda mutation is visible to caller
	# (GDScript lambdas capture primitives by value — CLAUDE.md gotcha)
	var fired: Array[bool] = [false]
	engine.hero_moved.connect(func(_c: Combatant, _f: Vector2i, _t: Vector2i) -> void:
		fired[0] = true
	)
	engine.move_combatant(hero, Vector2i(1, 0))
	assert_true(fired[0], "hero_moved signal fires on hero move")

func test_enemy_move_does_not_emit_hero_moved() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Imp", Combatant.Faction.ENEMY, 50, 8)
	enemy.sprite_key = "imp"
	enemy.position = Vector2i(3, 0)
	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)

	var fired: Array[bool] = [false]
	engine.hero_moved.connect(func(_c: Combatant, _f: Vector2i, _t: Vector2i) -> void:
		fired[0] = true
	)
	engine.move_combatant(enemy, Vector2i(2, 0))
	assert_true(not fired[0], "hero_moved NOT emitted when enemy moves")

func test_is_combatant_frozen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var engine := BattleEngine.new(rng)
	var c := Combatant.new("x", "Test", Combatant.Faction.ENEMY, 50, 5)
	assert_true(not engine.is_combatant_frozen(c), "Not frozen by default")
	c.apply_status(StatusEffect.frozen(2))
	assert_true(engine.is_combatant_frozen(c), "Frozen after applying frozen status")

func test_frozen_enemy_skips_ai_action() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Goblin", Combatant.Faction.ENEMY, 50, 8)
	enemy.sprite_key = "goblin"
	enemy.position = Vector2i(1, 0)
	var ea: Array[String] = ["basic_attack"]
	enemy.abilities = ea
	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)
	enemy.apply_status(StatusEffect.frozen(2))

	var initial_hp: int = hero.hp
	engine.enemy_ai_action(enemy)
	assert_eq(hero.hp, initial_hp, "Frozen enemy does not attack hero")

func test_vanish_multiplier_applies_to_next_attack() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Dummy", Combatant.Faction.ENEMY, 200, 5)
	enemy.armor = 0
	enemy.position = Vector2i(1, 0)
	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)

	# Normal attack first to get a baseline damage
	var rng_baseline := RandomNumberGenerator.new()
	rng_baseline.seed = 99
	var engine_b := BattleEngine.new(rng_baseline)
	var hero_b := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	var dummy_b := Combatant.new("e1", "Dummy", Combatant.Faction.ENEMY, 200, 5)
	dummy_b.armor = 0
	var all_b: Array[Combatant] = [hero_b, dummy_b]
	engine_b.setup(all_b)
	var normal_dmg: int = engine_b.perform_attack(hero_b, dummy_b, "basic_attack")

	# Now with vanish
	hero.apply_status(StatusEffect.vanished(3.0))
	var vanish_dmg: int = engine.perform_attack(hero, enemy, "basic_attack")
	assert_true(vanish_dmg > normal_dmg, "Vanish multiplier increases damage (vanish=%d > normal=%d)" % [vanish_dmg, normal_dmg])
	# Vanished status should be consumed
	assert_true(not engine.is_combatant_frozen(hero), "Vanished status consumed after use (no frozen check)")
	var still_vanished: bool = false
	for eff: Dictionary in hero.status_effects:
		if eff.get("id", "") == "vanished":
			still_vanished = true
	assert_true(not still_vanished, "Vanished status removed after attack")

func test_perform_aoe_attack_hits_all_targets() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	var e1 := Combatant.new("e1", "A", Combatant.Faction.ENEMY, 50, 5)
	var e2 := Combatant.new("e2", "B", Combatant.Faction.ENEMY, 50, 5)
	var e3 := Combatant.new("e3", "C", Combatant.Faction.ENEMY, 50, 5)
	e1.armor = 0; e2.armor = 0; e3.armor = 0
	var all: Array[Combatant] = [hero, e1, e2, e3]
	engine.setup(all)

	var targets: Array[Combatant] = [e1, e2, e3]
	var results: Array[int] = engine.perform_aoe_attack(hero, targets, "basic_attack")
	assert_eq(results.size(), 3, "AOE returns 3 damage values")
	assert_true(e1.hp < 50, "e1 took damage")
	assert_true(e2.hp < 50, "e2 took damage")
	assert_true(e3.hp < 50, "e3 took damage")

func test_status_effect_frozen_data() -> void:
	var frozen: Dictionary = StatusEffect.frozen(3)
	assert_eq(frozen["id"], "frozen", "frozen id correct")
	assert_eq(frozen["duration"], 3, "frozen duration set")
	assert_eq(frozen["skips_turn"], true, "frozen skips_turn true")
	assert_eq(frozen["armor_mod"], -2, "frozen armor_mod = -2")

func test_status_effect_vanished_data() -> void:
	var v: Dictionary = StatusEffect.vanished(2.5)
	assert_eq(v["id"], "vanished", "vanished id correct")
	assert_eq(v["duration"], 3, "vanished duration = 3 (Run 5 fix)")
	assert_eq(v["damage_multiplier"], 2.5, "vanished multiplier set")

func test_attack_bonus_adds_to_damage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.attack_bonus = 50  # massive bonus
	var target := Combatant.new("t", "T", Combatant.Faction.ENEMY, 500, 5)
	target.armor = 0
	var all: Array[Combatant] = [hero, target]
	engine.setup(all)
	var dmg: int = engine.perform_attack(hero, target, "basic_attack")
	assert_true(dmg > 30, "Attack bonus of 50 pushes damage well above base (got %d)" % dmg)

func test_golem_ai_attacks_at_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var golem := Combatant.new("golem1", "Lava Golem", Combatant.Faction.ENEMY, 90, 5)
	golem.sprite_key = "golem"
	golem.position = Vector2i(2, 0)  # distance 2, in range 3 for fireball
	var ga: Array[String] = ["enemy_fireball"]
	golem.abilities = ga
	golem.armor = 0
	var all: Array[Combatant] = [hero, golem]
	engine.setup(all)

	var hp_before: int = hero.hp
	engine.enemy_ai_action(golem)
	assert_true(hero.hp < hp_before, "Golem attacks hero with ranged ability from range 2")
	# Golem should not have moved
	assert_eq(golem.position, Vector2i(2, 0), "Golem stays put (does not move)")
