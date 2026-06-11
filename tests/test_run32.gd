## Run 32 tests: UI & arc repair —
##  - GameState.consume_xp_bonus (the previously-dead "Combat Instincts" card)
##  - New Tier 2/3 enemies (Void Wraith / Bone Colossus): schema, floor gating,
##    tint plumbing through make_combatant, and the melee-golem AI fix.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun32


var GAMESTATE: GDScript = load("res://autoloads/GameState.gd")


# ── consume_xp_bonus ─────────────────────────────────────────────────────────

func test_xp_bonus_no_bonus_passthrough() -> void:
	var gs: Node = GAMESTATE.new()
	gs.hero_base_stats = {"attack": 10}
	assert_eq(gs.consume_xp_bonus(80), 80, "no xp_bonus key -> unchanged XP")
	gs.queue_free()


func test_xp_bonus_applies_and_consumes() -> void:
	var gs: Node = GAMESTATE.new()
	gs.hero_base_stats = {"xp_bonus": 50}
	assert_eq(gs.consume_xp_bonus(100), 150, "+50% on 100 XP -> 150")
	assert_true(not gs.hero_base_stats.has("xp_bonus"),
		"bonus key erased after one use (card says 'next floor')")
	assert_eq(gs.consume_xp_bonus(100), 100, "second floor gets no bonus")
	gs.queue_free()


func test_xp_bonus_stacks_pay_out_once() -> void:
	## Taking Combat Instincts twice (+50 each) = one +100% floor.
	var gs: Node = GAMESTATE.new()
	gs.hero_base_stats = {"xp_bonus": 100}
	assert_eq(gs.consume_xp_bonus(85), 170, "+100% on 85 XP -> 170")
	gs.queue_free()


func test_xp_bonus_integer_truncation_safe() -> void:
	var gs: Node = GAMESTATE.new()
	gs.hero_base_stats = {"xp_bonus": 50}
	# 85 + 85*50/100 = 85 + 42 (int division) = 127
	assert_eq(gs.consume_xp_bonus(85), 127, "integer math: 85 -> 127")
	gs.queue_free()


func test_xp_bonus_zero_and_negative_ignored() -> void:
	var gs: Node = GAMESTATE.new()
	gs.hero_base_stats = {"xp_bonus": 0}
	assert_eq(gs.consume_xp_bonus(60), 60, "zero bonus -> unchanged")
	assert_true(gs.hero_base_stats.has("xp_bonus"),
		"zero bonus key NOT consumed (nothing was paid out)")
	gs.hero_base_stats = {"xp_bonus": -25}
	assert_eq(gs.consume_xp_bonus(60), 60, "negative bonus -> unchanged (defensive)")
	gs.queue_free()


# ── New enemy roster (Void Wraith / Bone Colossus) ──────────────────────────

func _enemy_def(id: String) -> Dictionary:
	for e: Dictionary in EnemyDefs.ENEMIES:
		if String(e.get("id", "")) == id:
			return e
	return {}


func test_new_enemy_defs_exist_with_schema() -> void:
	for id: String in ["void_wraith", "bone_colossus"]:
		var d: Dictionary = _enemy_def(id)
		assert_true(not d.is_empty(), "enemy '%s' exists" % id)
		for key: String in ["display_name", "hp", "armor", "speed", "abilities",
				"xp_reward", "sprite_key", "min_floor"]:
			assert_true(d.has(key), "enemy '%s' has '%s'" % [id, key])


func test_new_enemy_floor_gating() -> void:
	## void_wraith enters at 7 (Obsidian), bone_colossus at 13 (Void).
	var ids_f6: Array[String] = []
	for e: Dictionary in EnemyDefs.get_enemies_for_floor(6):
		ids_f6.append(String(e["id"]))
	assert_true(not ids_f6.has("void_wraith"), "no wraith on floor 6")
	assert_true(not ids_f6.has("bone_colossus"), "no colossus on floor 6")

	var ids_f7: Array[String] = []
	for e: Dictionary in EnemyDefs.get_enemies_for_floor(7):
		ids_f7.append(String(e["id"]))
	assert_true(ids_f7.has("void_wraith"), "wraith joins pool on floor 7")
	assert_true(not ids_f7.has("bone_colossus"), "colossus still gated at floor 7")

	var ids_f13: Array[String] = []
	for e: Dictionary in EnemyDefs.get_enemies_for_floor(13):
		ids_f13.append(String(e["id"]))
	assert_true(ids_f13.has("void_wraith"), "wraith in pool on floor 13")
	assert_true(ids_f13.has("bone_colossus"), "colossus joins pool on floor 13")


func test_new_enemy_abilities_are_real() -> void:
	## Every ability id on the new defs must exist in Abilities.DATA — drift
	## detector so a typo can't silently fall back to default claw data.
	for id: String in ["void_wraith", "bone_colossus"]:
		var d: Dictionary = _enemy_def(id)
		for a: String in d.get("abilities", []):
			assert_true(Abilities.DATA.has(a),
				"enemy '%s' ability '%s' exists in Abilities.DATA" % [id, a])


func test_wraith_is_fastest_mob() -> void:
	## Design lock-in: the wraith's identity is "fastest thing in the dungeon".
	var wraith: Dictionary = _enemy_def("void_wraith")
	for e: Dictionary in EnemyDefs.ENEMIES:
		if String(e["id"]) == "void_wraith":
			continue
		assert_gt(int(wraith["speed"]), int(e["speed"]),
			"wraith (%d) outspeeds %s (%d)" % [int(wraith["speed"]),
				String(e["id"]), int(e["speed"])])


func test_tint_plumbed_through_make_combatant() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wraith_def: Dictionary = _enemy_def("void_wraith")
	var c: Combatant = EnemyDefs.make_combatant(wraith_def, Vector2i.ZERO, rng, 7)
	assert_true(c.tint != Color(1.0, 1.0, 1.0), "wraith combatant carries a non-white tint")
	assert_eq(c.tint, wraith_def["tint"], "tint copied verbatim from def")

	var imp_def: Dictionary = _enemy_def("imp")
	var imp: Combatant = EnemyDefs.make_combatant(imp_def, Vector2i.ZERO, rng, 1)
	assert_eq(imp.tint, Color(1.0, 1.0, 1.0), "untinted defs default to white")


func test_combatant_default_tint_white() -> void:
	var c := Combatant.new("t1", "Test", Combatant.Faction.ENEMY, 10)
	assert_eq(c.tint, Color(1.0, 1.0, 1.0), "fresh Combatant tint defaults to white")


# ── Melee-golem AI fix (Bone Colossus must not be a statue) ─────────────────

func test_bone_colossus_advances_toward_hero() -> void:
	## Before Run 32, the "golem" AI branch only ever cast enemy_fireball and
	## never moved — a melee golem variant would idle forever. Verify the
	## colossus closes distance on its turn.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var map := DungeonMap.new()
	map.generate(1, rng)

	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i.ZERO
	hero.abilities = ["basic_attack"] as Array[String]

	var colossus: Combatant = EnemyDefs.make_combatant(
		_enemy_def("bone_colossus"), Vector2i(3, 0), rng, 13)

	var engine := BattleEngine.new(rng)
	var roster: Array[Combatant] = [hero, colossus]
	engine.setup(roster)

	var dist_before: int = HexGrid.hex_distance(colossus.position, hero.position)
	engine.enemy_ai_action(colossus, map)
	var dist_after: int = HexGrid.hex_distance(colossus.position, hero.position)
	assert_gt(dist_before, dist_after, "colossus stepped toward the hero")


func test_lava_golem_still_a_turret() -> void:
	## Regression guard: the AI fix must not give Lava Golems legs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var map := DungeonMap.new()
	map.generate(1, rng)

	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i.ZERO
	hero.abilities = ["basic_attack"] as Array[String]

	var golem: Combatant = EnemyDefs.make_combatant(
		_enemy_def("lava_golem"), Vector2i(4, 0), rng, 5)

	var engine := BattleEngine.new(rng)
	var roster: Array[Combatant] = [hero, golem]
	engine.setup(roster)

	var pos_before: Vector2i = golem.position
	engine.enemy_ai_action(golem, map)
	assert_eq(golem.position, pos_before,
		"lava golem (out of fireball range) holds position")


func test_colossus_attacks_when_adjacent() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var map := DungeonMap.new()
	map.generate(1, rng)

	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 500, 10)
	hero.position = Vector2i.ZERO
	hero.abilities = ["basic_attack"] as Array[String]

	var colossus: Combatant = EnemyDefs.make_combatant(
		_enemy_def("bone_colossus"), Vector2i(1, 0), rng, 13)

	var engine := BattleEngine.new(rng)
	var roster: Array[Combatant] = [hero, colossus]
	engine.setup(roster)

	var hp_before: int = hero.hp
	engine.enemy_ai_action(colossus, map)
	assert_gt(hp_before, hero.hp, "adjacent colossus bit the hero")
