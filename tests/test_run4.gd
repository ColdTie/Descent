## Tests for Run 4 features:
## - Shield Bash push mechanic
## - Shield Bash into wall (slam damage)
## - New abilities data integrity
## - Ability unlock filtering in LevelUp pool
## - Class has unlockable_abilities defined

class_name TestRun4
extends "res://tests/run_tests.gd".BaseTest

# ─── Shield Bash Push ─────────────────────────────────────────────────────────

func test_shield_bash_push_clear_path() -> void:
	## Target adjacent to attacker on clear path gets pushed one hex away
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var map := DungeonMap.new()
	map.generate(1, rng)

	var attacker := Combatant.new("att", "Hero", Combatant.Faction.HERO, 100, 10)
	attacker.position = Vector2i(0, 0)
	var target := Combatant.new("tgt", "Enemy", Combatant.Faction.ENEMY, 30, 8)
	target.position = Vector2i(1, 0)

	var engine := BattleEngine.new(rng)
	var all: Array[Combatant] = [attacker, target]
	engine.setup(all)

	# Ensure center hexes are passable (center is always floor)
	map.passable[Vector2i(2, 0)] = true
	map.tile_types[Vector2i(2, 0)] = "floor"

	var slammed: bool = engine.apply_push(attacker, target, map)
	assert_true(not slammed, "Push into clear hex should not slam")
	assert_eq(target.position, Vector2i(2, 0), "Target pushed from (1,0) to (2,0)")

func test_shield_bash_push_blocked_slam() -> void:
	## Target adjacent to impassable hex gets slam-blocked (returns true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var map := DungeonMap.new()
	map.generate(1, rng)

	var attacker := Combatant.new("att", "Hero", Combatant.Faction.HERO, 100, 10)
	attacker.position = Vector2i(0, 0)
	var target := Combatant.new("tgt", "Enemy", Combatant.Faction.ENEMY, 30, 8)
	target.position = Vector2i(1, 0)

	var engine := BattleEngine.new(rng)
	var all: Array[Combatant] = [attacker, target]
	engine.setup(all)

	# Make push destination impassable (wall)
	map.passable[Vector2i(2, 0)] = false
	map.tile_types[Vector2i(2, 0)] = "wall"

	var slammed: bool = engine.apply_push(attacker, target, map)
	assert_true(slammed, "Push into impassable hex should return slam=true")
	assert_eq(target.position, Vector2i(1, 0), "Target stays in place on slam")

func test_shield_bash_push_occupied_slam() -> void:
	## Target can't be pushed into hex occupied by another living combatant
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var map := DungeonMap.new()
	map.generate(1, rng)

	var attacker := Combatant.new("att", "Hero", Combatant.Faction.HERO, 100, 10)
	attacker.position = Vector2i(0, 0)
	var target := Combatant.new("tgt", "Enemy", Combatant.Faction.ENEMY, 30, 8)
	target.position = Vector2i(1, 0)
	var blocker := Combatant.new("blk", "Blocker", Combatant.Faction.ENEMY, 30, 8)
	blocker.position = Vector2i(2, 0)

	var engine := BattleEngine.new(rng)
	var all: Array[Combatant] = [attacker, target, blocker]
	engine.setup(all)
	map.passable[Vector2i(2, 0)] = true

	var slammed: bool = engine.apply_push(attacker, target, map)
	assert_true(slammed, "Push into occupied hex should return slam=true")
	assert_eq(target.position, Vector2i(1, 0), "Target stays in place when push blocked by occupant")

func test_shield_bash_push_direction_is_away() -> void:
	## Push direction: target moves further from attacker, not toward
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var map := DungeonMap.new()
	map.generate(1, rng)

	var attacker := Combatant.new("att", "Hero", Combatant.Faction.HERO, 100, 10)
	attacker.position = Vector2i(0, 0)
	var target := Combatant.new("tgt", "Enemy", Combatant.Faction.ENEMY, 30, 8)
	target.position = Vector2i(0, -1)  # directly above

	var engine := BattleEngine.new(rng)
	var all: Array[Combatant] = [attacker, target]
	engine.setup(all)
	map.passable[Vector2i(0, -2)] = true
	map.tile_types[Vector2i(0, -2)] = "floor"

	var slammed: bool = engine.apply_push(attacker, target, map)
	assert_true(not slammed, "Push (0,-1) away from (0,0) should not slam if (0,-2) is passable")
	assert_eq(target.position, Vector2i(0, -2), "Target pushed from (0,-1) to (0,-2)")

# ─── Shield Bash Signal ───────────────────────────────────────────────────────

func test_shield_bash_emits_pushed_signal() -> void:
	## apply_push emits combatant_pushed signal with correct slammed flag
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var map := DungeonMap.new()
	map.generate(1, rng)
	map.passable[Vector2i(2, 0)] = true
	map.tile_types[Vector2i(2, 0)] = "floor"

	var attacker := Combatant.new("att", "Hero", Combatant.Faction.HERO, 100, 10)
	attacker.position = Vector2i(0, 0)
	var target := Combatant.new("tgt", "Enemy", Combatant.Faction.ENEMY, 30, 8)
	target.position = Vector2i(1, 0)

	var engine := BattleEngine.new(rng)
	var all: Array[Combatant] = [attacker, target]
	engine.setup(all)

	var signal_fired: Array[bool] = [false]
	var signal_slammed: Array[bool] = [false]
	engine.combatant_pushed.connect(func(_c: Combatant, _f: Vector2i, _t: Vector2i, slammed: bool) -> void:
		signal_fired[0] = true
		signal_slammed[0] = slammed
	)

	engine.apply_push(attacker, target, map)
	assert_true(signal_fired[0], "combatant_pushed signal should fire")
	assert_true(not signal_slammed[0], "Signal slammed flag should be false for clear push")

# ─── New Ability Data ─────────────────────────────────────────────────────────

func test_shield_bash_ability_data_exists() -> void:
	var abl: Dictionary = Abilities.get_ability("shield_bash")
	assert_eq(abl.get("id", ""), "shield_bash", "shield_bash ability should exist")
	assert_true(abl.get("push_back", false), "shield_bash should have push_back flag")
	assert_eq(abl.get("range", 0), 1, "shield_bash range should be 1")
	assert_eq(abl.get("max_charges", 0), 2, "shield_bash should have 2 charges")

func test_whirlwind_ability_data_exists() -> void:
	var abl: Dictionary = Abilities.get_ability("whirlwind")
	assert_eq(abl.get("id", ""), "whirlwind", "whirlwind ability should exist")
	assert_eq(abl.get("target", ""), "all_enemies", "whirlwind targets all_enemies")
	assert_eq(abl.get("aoe_radius", 0), 1, "whirlwind aoe_radius should be 1")

func test_smoke_bomb_ability_data_exists() -> void:
	var abl: Dictionary = Abilities.get_ability("smoke_bomb")
	assert_eq(abl.get("id", ""), "smoke_bomb", "smoke_bomb ability should exist")
	assert_true(abl.get("applies_frozen", false), "smoke_bomb should apply frozen")
	assert_eq(abl.get("aoe_radius", 0), 2, "smoke_bomb aoe_radius should be 2")

func test_lightning_bolt_ability_data_exists() -> void:
	var abl: Dictionary = Abilities.get_ability("lightning_bolt")
	assert_eq(abl.get("id", ""), "lightning_bolt", "lightning_bolt should exist")
	assert_eq(abl.get("base_damage", 0), 45, "lightning_bolt base_damage should be 45")
	assert_eq(abl.get("range", 0), 4, "lightning_bolt range should be 4")

func test_fireball_has_aoe_radius() -> void:
	var abl: Dictionary = Abilities.get_ability("fireball")
	assert_eq(abl.get("aoe_radius", 0), 2, "fireball should have aoe_radius 2")

func test_frost_nova_has_aoe_radius() -> void:
	var abl: Dictionary = Abilities.get_ability("frost_nova")
	assert_eq(abl.get("aoe_radius", 0), 1, "frost_nova should have aoe_radius 1")

# ─── Class Data ───────────────────────────────────────────────────────────────

func test_brawler_has_shield_bash() -> void:
	var cls: Dictionary = Classes.get_class_data("brawler")
	var abilities: Array = cls.get("abilities", [])
	assert_true("shield_bash" in abilities, "Brawler should start with shield_bash")

func test_brawler_unlockable_whirlwind() -> void:
	var cls: Dictionary = Classes.get_class_data("brawler")
	var unlockable: Array = cls.get("unlockable_abilities", [])
	assert_true("whirlwind" in unlockable, "Brawler unlockable_abilities should include whirlwind")

func test_rogue_unlockable_smoke_bomb() -> void:
	var cls: Dictionary = Classes.get_class_data("rogue")
	var unlockable: Array = cls.get("unlockable_abilities", [])
	assert_true("smoke_bomb" in unlockable, "Rogue unlockable_abilities should include smoke_bomb")

func test_arcanist_unlockable_lightning_bolt() -> void:
	var cls: Dictionary = Classes.get_class_data("arcanist")
	var unlockable: Array = cls.get("unlockable_abilities", [])
	assert_true("lightning_bolt" in unlockable, "Arcanist unlockable_abilities should include lightning_bolt")

# ─── System Voice Commentary Pools ───────────────────────────────────────────

func test_system_voice_has_low_hp_pool() -> void:
	assert_true(SystemVoice.LINES.has("low_hp"), "SystemVoice should have low_hp pool")
	assert_true(SystemVoice.LINES["low_hp"].size() >= 3, "low_hp pool should have at least 3 lines")

func test_system_voice_has_surrounded_pool() -> void:
	assert_true(SystemVoice.LINES.has("surrounded"), "SystemVoice should have surrounded pool")

func test_system_voice_has_backstab_hit_pool() -> void:
	assert_true(SystemVoice.LINES.has("backstab_hit"), "SystemVoice should have backstab_hit pool")

func test_system_voice_has_push_slam_pool() -> void:
	assert_true(SystemVoice.LINES.has("push_slam"), "SystemVoice should have push_slam pool")

func test_system_voice_has_first_kill_pool() -> void:
	assert_true(SystemVoice.LINES.has("first_kill"), "SystemVoice should have first_kill pool")
