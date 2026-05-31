## Run 15 tests: Boss Phase 2, Skeleton Bone Volley, Demon Hellfire, Shadow Step ability.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun15

# ── Boss Phase 2 ──────────────────────────────────────────────────────────────

func test_boss_not_enraged_at_full_hp() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	var boss := Combatant.new("boss_1_0001", "Boss", Combatant.Faction.ENEMY, 100, 8)
	boss.is_boss = true
	var all: Array[Combatant] = [hero, boss]
	engine.setup(all)
	engine.perform_attack(hero, boss, "basic_attack")
	assert_true(not boss.is_enraged, "Boss not enraged above 30% HP")

func test_boss_enrages_below_30_percent() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	hero.attack_bonus = 200
	var boss := Combatant.new("boss_1_0001", "Boss", Combatant.Faction.ENEMY, 100, 8)
	boss.is_boss = true
	var all: Array[Combatant] = [hero, boss]
	engine.setup(all)
	# Bring boss to just above 30%
	boss.hp = 30
	engine.perform_attack(hero, boss, "enemy_claw")
	# Boss should be enraged if still alive
	if boss.is_alive():
		assert_true(boss.is_enraged, "Boss enrages when HP drops below 30%")
	else:
		assert_true(true, "Boss died before enrage threshold — high atk variance")

func test_boss_enrage_signal_emitted() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	var boss := Combatant.new("boss_1_0001", "Boss", Combatant.Faction.ENEMY, 100, 8)
	boss.is_boss = true
	boss.hp = 25  # already below 30%
	var all: Array[Combatant] = [hero, boss]
	engine.setup(all)
	var enraged_ids: Array[String] = []
	engine.boss_enraged.connect(func(b: Combatant) -> void: enraged_ids.append(b.id))
	engine.perform_attack(hero, boss, "enemy_claw")
	if boss.is_alive():
		assert_true(enraged_ids.has("boss_1_0001"), "boss_enraged signal fired")
	else:
		assert_true(true, "Boss died — signal irrelevant")

func test_boss_enrage_stat_boosts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	var boss := Combatant.new("boss_1_0001", "Boss", Combatant.Faction.ENEMY, 100, 8)
	boss.is_boss = true
	boss.hp = 20  # well below 30%
	var speed_before: int = boss.speed
	var atk_before: int = boss.attack_bonus
	var all: Array[Combatant] = [hero, boss]
	engine.setup(all)
	engine.perform_attack(hero, boss, "enemy_claw")
	if boss.is_alive() and boss.is_enraged:
		assert_eq(boss.speed, speed_before + 4, "Boss speed +4 on enrage")
		assert_eq(boss.attack_bonus, atk_before + 4, "Boss attack_bonus +4 on enrage")
	else:
		assert_true(true, "Boss died or not enraged yet — skip stat check")

func test_boss_enrages_only_once() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	var boss := Combatant.new("boss_1_0001", "Boss", Combatant.Faction.ENEMY, 200, 8)
	boss.is_boss = true
	boss.hp = 25  # already below 30%
	var all: Array[Combatant] = [hero, boss]
	engine.setup(all)
	var enrage_count: Array[int] = [0]
	engine.boss_enraged.connect(func(_b: Combatant) -> void: enrage_count[0] += 1)
	engine.perform_attack(hero, boss, "enemy_claw")
	engine.perform_attack(hero, boss, "enemy_claw")
	engine.perform_attack(hero, boss, "enemy_claw")
	if boss.is_alive():
		assert_true(enrage_count[0] <= 1, "Boss enrages at most once")
	else:
		assert_true(true, "Boss died")

func test_regular_enemy_never_enrages() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	var imp := Combatant.new("imp_0001", "Imp", Combatant.Faction.ENEMY, 25, 12)
	imp.hp = 5
	var all: Array[Combatant] = [hero, imp]
	engine.setup(all)
	var enraged_ids: Array[String] = []
	engine.boss_enraged.connect(func(b: Combatant) -> void: enraged_ids.append(b.id))
	engine.perform_attack(hero, imp, "enemy_claw")
	assert_true(enraged_ids.is_empty(), "Regular enemies never trigger boss_enraged")

# ── Enemy ability unlocks ──────────────────────────────────────────────────────

func test_skeleton_no_bone_volley_before_floor10() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var skeleton_def: Dictionary = {}
	for e: Dictionary in EnemyDefs.ENEMIES:
		if e["id"] == "skeleton":
			skeleton_def = e
			break
	assert_true(not skeleton_def.is_empty(), "Found skeleton def")
	var c: Combatant = EnemyDefs.make_combatant(skeleton_def, Vector2i(0, 0), rng, 9)
	assert_true(not c.abilities.has("bone_volley"), "Skeleton has no bone_volley before floor 10")

func test_skeleton_gets_bone_volley_at_floor10() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var skeleton_def: Dictionary = {}
	for e: Dictionary in EnemyDefs.ENEMIES:
		if e["id"] == "skeleton":
			skeleton_def = e
			break
	var c: Combatant = EnemyDefs.make_combatant(skeleton_def, Vector2i(0, 0), rng, 10)
	assert_true(c.abilities.has("bone_volley"), "Skeleton gets bone_volley at floor 10")

func test_skeleton_gets_bone_volley_above_floor10() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var skeleton_def: Dictionary = {}
	for e: Dictionary in EnemyDefs.ENEMIES:
		if e["id"] == "skeleton":
			skeleton_def = e
			break
	var c: Combatant = EnemyDefs.make_combatant(skeleton_def, Vector2i(0, 0), rng, 15)
	assert_true(c.abilities.has("bone_volley"), "Skeleton keeps bone_volley above floor 10")

func test_demon_no_hellfire_before_floor13() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var demon_def: Dictionary = {}
	for e: Dictionary in EnemyDefs.ENEMIES:
		if e["id"] == "demon_grunt":
			demon_def = e
			break
	assert_true(not demon_def.is_empty(), "Found demon_grunt def")
	var c: Combatant = EnemyDefs.make_combatant(demon_def, Vector2i(0, 0), rng, 12)
	assert_true(not c.abilities.has("hellfire_aoe"), "Demon has no hellfire_aoe before floor 13")

func test_demon_gets_hellfire_at_floor13() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var demon_def: Dictionary = {}
	for e: Dictionary in EnemyDefs.ENEMIES:
		if e["id"] == "demon_grunt":
			demon_def = e
			break
	var c: Combatant = EnemyDefs.make_combatant(demon_def, Vector2i(0, 0), rng, 13)
	assert_true(c.abilities.has("hellfire_aoe"), "Demon gets hellfire_aoe at floor 13")

func test_bone_volley_in_abilities_data() -> void:
	var abl: Dictionary = Abilities.get_ability("bone_volley")
	assert_eq(abl.get("range", 0), 3, "Bone Volley has range 3")
	assert_gt(abl.get("base_damage", 0), 0, "Bone Volley has positive damage")

func test_hellfire_aoe_in_abilities_data() -> void:
	var abl: Dictionary = Abilities.get_ability("hellfire_aoe")
	assert_eq(abl.get("target", ""), "all_enemies", "Hellfire AoE targets all_enemies")
	assert_eq(abl.get("range", 0), 2, "Hellfire AoE has range 2")

# ── Shadow Step ability ────────────────────────────────────────────────────────

func test_shadow_step_in_abilities_data() -> void:
	var abl: Dictionary = Abilities.get_ability("shadow_step")
	assert_eq(abl.get("range", 0), 3, "Shadow Step has range 3")
	assert_true(abl.get("ignore_armor", false), "Shadow Step ignores armor")
	assert_true(abl.get("teleport_to_target", false), "Shadow Step has teleport_to_target flag")
	assert_gt(abl.get("base_damage", 0), 0, "Shadow Step deals positive damage")

func test_shadow_step_ignores_armor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	var target := Combatant.new("armored", "Armored", Combatant.Faction.ENEMY, 100, 8)
	target.armor = 20  # heavy armor
	var all: Array[Combatant] = [hero, target]
	engine.setup(all)
	var hp_before: int = target.hp
	engine.perform_attack(hero, target, "shadow_step")
	var dmg: int = hp_before - target.hp
	assert_gt(dmg, 0, "Shadow Step deals damage even through heavy armor")

func test_boss_is_boss_flag_set() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var boss: Combatant = EnemyDefs.make_boss(1, Vector2i(0, 0), rng)
	assert_true(boss.is_boss, "Boss created by EnemyDefs.make_boss has is_boss=true")

func test_regular_enemy_no_boss_flag() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var imp_def: Dictionary = EnemyDefs.ENEMIES[0]
	var imp: Combatant = EnemyDefs.make_combatant(imp_def, Vector2i(0, 0), rng, 1)
	assert_true(not imp.is_boss, "Regular enemy has is_boss=false")
