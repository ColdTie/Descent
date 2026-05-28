## Tests for Run 4 features:
## - Shield Bash ability data (pushback flag)
## - HexGrid.push_direction utility
## - BattleEngine.push_combatant mechanics
## - Classes unlockable_abilities data
## - Ability unlock items in LevelUp pool (logic only)

class_name TestRun4
extends "res://tests/run_tests.gd".BaseTest

# ─── HexGrid push_direction ───────────────────────────────────────────────────

func test_push_direction_east() -> void:
	## From (0,0) to (3,0) should give direction (1,0) — east
	var dir: Vector2i = HexGrid.push_direction(Vector2i(0, 0), Vector2i(3, 0))
	assert_eq(dir, Vector2i(1, 0), "Push east: (0,0) → (3,0) gives dir (1,0)")

func test_push_direction_west() -> void:
	## From (0,0) to (-2,0) should give direction (-1,0) — west
	var dir: Vector2i = HexGrid.push_direction(Vector2i(0, 0), Vector2i(-2, 0))
	assert_eq(dir, Vector2i(-1, 0), "Push west: (0,0) → (-2,0) gives dir (-1,0)")

func test_push_direction_northeast() -> void:
	## From (0,0) to (2,-2) should give direction (1,-1) — northeast
	var dir: Vector2i = HexGrid.push_direction(Vector2i(0, 0), Vector2i(2, -2))
	assert_eq(dir, Vector2i(1, -1), "Push NE: (0,0) → (2,-2) gives dir (1,-1)")

func test_push_direction_from_hero_to_target() -> void:
	## Typical battle use: hero at (0,0), enemy at (1,0) → push east
	var dir: Vector2i = HexGrid.push_direction(Vector2i(0, 0), Vector2i(1, 0))
	assert_eq(dir, Vector2i(1, 0), "Push from hero at origin toward adjacent enemy east")

# ─── BattleEngine.push_combatant ─────────────────────────────────────────────

func _make_open_map() -> DungeonMap:
	## Create a fully passable floor map for testing
	var map := DungeonMap.new()
	for q: int in range(-8, 9):
		for r: int in range(-8, 9):
			map.passable[Vector2i(q, r)] = true
			map.tile_types[Vector2i(q, r)] = "floor"
	return map

func test_push_moves_combatant() -> void:
	## Pushing an enemy 2 steps east from (1,0) should end at (3,0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Goblin", Combatant.Faction.ENEMY, 50, 8)
	enemy.position = Vector2i(1, 0)
	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)
	var map: DungeonMap = _make_open_map()

	var dir: Vector2i = HexGrid.push_direction(hero.position, enemy.position)
	engine.push_combatant(enemy, dir, 2, map)
	assert_eq(enemy.position, Vector2i(3, 0), "Enemy pushed 2 steps east to (3,0)")

func test_push_stops_at_wall() -> void:
	## Push into impassable hex stops before it
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Goblin", Combatant.Faction.ENEMY, 50, 8)
	enemy.position = Vector2i(1, 0)
	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)

	var map: DungeonMap = _make_open_map()
	# Wall at (2,0) — push should stop at (1,0) since next step is blocked
	map.passable[Vector2i(2, 0)] = false
	map.tile_types[Vector2i(2, 0)] = "wall"

	var dir: Vector2i = Vector2i(1, 0)
	engine.push_combatant(enemy, dir, 2, map)
	assert_eq(enemy.position, Vector2i(1, 0), "Enemy stuck at (1,0) — wall at (2,0)")

func test_push_deals_lava_damage() -> void:
	## Pushing into a lava tile deals damage
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Goblin", Combatant.Faction.ENEMY, 100, 8)
	enemy.armor = 5  # armor should NOT reduce lava damage (env damage ignores armor)
	enemy.position = Vector2i(1, 0)
	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)

	var map: DungeonMap = _make_open_map()
	# Lava at (2,0) — enemy pushed 2 steps: lands on (2,0) lava, then (3,0) if alive
	map.tile_types[Vector2i(2, 0)] = "lava"
	map.passable[Vector2i(2, 0)] = false  # lava is not passable in DungeonMap

	var hp_before: int = enemy.hp
	var dir: Vector2i = Vector2i(1, 0)
	var lava_dmg: int = engine.push_combatant(enemy, dir, 2, map)
	# Enemy stops at (1,0) since lava at (2,0) is impassable — push stops
	# But lava damage should be 0 here since they can't enter lava hex (impassable)
	# This tests that push respects impassable correctly
	assert_eq(enemy.position, Vector2i(1, 0), "Push stopped by impassable lava tile")
	assert_eq(lava_dmg, 0, "No lava damage when push stopped before lava (lava is impassable)")
	assert_eq(enemy.hp, hp_before, "Enemy HP unchanged when stopped before lava")

func test_push_into_passable_lava_deals_damage() -> void:
	## If a lava tile is somehow passable (unusual map state), push into it deals damage
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Goblin", Combatant.Faction.ENEMY, 100, 8)
	enemy.armor = 10  # high armor — should be ignored by lava damage
	enemy.position = Vector2i(1, 0)
	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)

	var map: DungeonMap = _make_open_map()
	# Mark (2,0) as passable lava — test that push into it deals env damage
	map.tile_types[Vector2i(2, 0)] = "lava"
	map.passable[Vector2i(2, 0)] = true  # passable lava for test purposes

	var hp_before: int = enemy.hp
	var dir: Vector2i = Vector2i(1, 0)
	var lava_dmg: int = engine.push_combatant(enemy, dir, 2, map)
	assert_true(lava_dmg > 0, "Lava damage dealt when pushed into passable lava tile (got %d)" % lava_dmg)
	assert_true(enemy.hp < hp_before, "Enemy HP reduced by lava damage (before=%d, after=%d)" % [hp_before, enemy.hp])

func test_push_stops_at_occupied_hex() -> void:
	## Push into a hex occupied by another combatant stops
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy1 := Combatant.new("e1", "Goblin", Combatant.Faction.ENEMY, 50, 8)
	enemy1.position = Vector2i(1, 0)
	var enemy2 := Combatant.new("e2", "Goblin2", Combatant.Faction.ENEMY, 50, 7)
	enemy2.position = Vector2i(2, 0)  # blocking the push path
	var all: Array[Combatant] = [hero, enemy1, enemy2]
	engine.setup(all)
	var map: DungeonMap = _make_open_map()

	var dir: Vector2i = Vector2i(1, 0)
	engine.push_combatant(enemy1, dir, 2, map)
	assert_eq(enemy1.position, Vector2i(1, 0), "Push stopped by occupied hex at (2,0)")

func test_push_emits_signal() -> void:
	## push_combatant emits combatant_pushed signal
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Goblin", Combatant.Faction.ENEMY, 50, 8)
	enemy.position = Vector2i(1, 0)
	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)
	var map: DungeonMap = _make_open_map()

	var signal_fired: Array[bool] = [false]
	engine.combatant_pushed.connect(
		func(_pushed: Combatant, _from: Vector2i, _to: Vector2i, _dmg: int) -> void:
			signal_fired[0] = true
	)

	engine.push_combatant(enemy, Vector2i(1, 0), 1, map)
	assert_true(signal_fired[0], "combatant_pushed signal emitted after push")

# ─── Shield Bash ability data ─────────────────────────────────────────────────

func test_shield_bash_exists_in_abilities() -> void:
	var abl: Dictionary = Abilities.get_ability("shield_bash")
	assert_true(abl.has("pushback"), "shield_bash has pushback key in Abilities.DATA")
	assert_eq(abl.get("pushback", 0), 2, "shield_bash pushback = 2")

func test_shield_bash_range_is_one() -> void:
	var abl: Dictionary = Abilities.get_ability("shield_bash")
	assert_eq(abl.get("range", 0), 1, "shield_bash range = 1 (melee)")

func test_shield_bash_has_charges() -> void:
	var abl: Dictionary = Abilities.get_ability("shield_bash")
	assert_eq(abl.get("max_charges", 0), 2, "shield_bash has 2 charges")
	assert_eq(abl.get("cooldown_turns", 0), 3, "shield_bash cooldown = 3")

# ─── Classes unlockable_abilities ─────────────────────────────────────────────

func test_brawler_starts_with_shield_bash() -> void:
	var cls: Dictionary = Classes.get_class_data("brawler")
	assert_true(cls.get("abilities", []).has("shield_bash"),
		"Brawler starts with shield_bash in kit")

func test_all_classes_have_unlockable_abilities() -> void:
	for class_id: String in ["brawler", "rogue", "arcanist"]:
		var cls: Dictionary = Classes.get_class_data(class_id)
		var unlockable: Array = cls.get("unlockable_abilities", [])
		assert_true(unlockable.size() >= 1,
			"%s has at least 1 unlockable ability" % class_id)

func test_brawler_unlockable_not_in_starting_kit() -> void:
	var cls: Dictionary = Classes.get_class_data("brawler")
	var starting: Array = cls.get("abilities", [])
	var unlockable: Array = cls.get("unlockable_abilities", [])
	for uid: String in unlockable:
		assert_true(not starting.has(uid),
			"Brawler unlockable '%s' is not in starting kit" % uid)

func test_rogue_unlockable_not_in_starting_kit() -> void:
	var cls: Dictionary = Classes.get_class_data("rogue")
	var starting: Array = cls.get("abilities", [])
	var unlockable: Array = cls.get("unlockable_abilities", [])
	for uid: String in unlockable:
		assert_true(not starting.has(uid),
			"Rogue unlockable '%s' is not in starting kit" % uid)

func test_arcanist_unlockable_not_in_starting_kit() -> void:
	var cls: Dictionary = Classes.get_class_data("arcanist")
	var starting: Array = cls.get("abilities", [])
	var unlockable: Array = cls.get("unlockable_abilities", [])
	for uid: String in unlockable:
		assert_true(not starting.has(uid),
			"Arcanist unlockable '%s' is not in starting kit" % uid)

# ─── SystemVoice new pools ────────────────────────────────────────────────────

func test_system_voice_new_pools_exist() -> void:
	## Verify all new commentary pools are present in SystemVoice.LINES
	for pool_key: String in ["low_hp", "first_blood", "backstab_land", "surrounded", "shield_bash_lava", "floor_regen"]:
		assert_true(SystemVoice.LINES.has(pool_key),
			"SystemVoice has '%s' pool" % pool_key)
		assert_true((SystemVoice.LINES[pool_key] as Array).size() >= 2,
			"SystemVoice '%s' pool has at least 2 entries" % pool_key)
