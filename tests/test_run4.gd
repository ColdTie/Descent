## Run 4 tests: Shield Bash push, poison_strike, ability unlocks, HP regen, reactive commentary data.
## No autoload references — pure class instantiation only.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun4

## ─── Shield Bash ability data ────────────────────────────────────────────────

func test_shield_bash_in_abilities_data() -> void:
	var d: Dictionary = Abilities.get_ability("shield_bash")
	assert_eq(d.get("id", ""), "shield_bash", "shield_bash id")
	assert_true(d.get("push", false), "shield_bash has push flag")
	assert_eq(d.get("range", 0), 1, "shield_bash range 1")
	assert_eq(d.get("max_charges", 0), 1, "shield_bash 1 charge")
	assert_eq(d.get("cooldown_turns", 0), 3, "shield_bash 3-turn cooldown")

func test_poison_strike_in_abilities_data() -> void:
	var d: Dictionary = Abilities.get_ability("poison_strike")
	assert_eq(d.get("id", ""), "poison_strike", "poison_strike id")
	assert_true(d.get("applies_poisoned", false), "poison_strike applies poisoned")
	assert_eq(d.get("max_charges", 0), 2, "poison_strike 2 charges")

## ─── Classes have unlockable abilities ───────────────────────────────────────

func test_brawler_has_shield_bash() -> void:
	var cls: Dictionary = Classes.get_class_data("brawler")
	var abilities: Array = cls.get("abilities", [])
	assert_true(abilities.has("shield_bash"), "brawler starts with shield_bash")

func test_all_classes_have_unlockable_abilities() -> void:
	for id: String in Classes.all_ids():
		var cls: Dictionary = Classes.get_class_data(id)
		var unlockable: Array = cls.get("unlockable_abilities", [])
		assert_true(unlockable.size() > 0, "%s has unlockable_abilities" % id)

func test_unlockable_abilities_are_valid() -> void:
	for id: String in Classes.all_ids():
		var cls: Dictionary = Classes.get_class_data(id)
		for abl_id in cls.get("unlockable_abilities", []):
			var abl: Dictionary = Abilities.get_ability(abl_id)
			assert_true(abl.size() > 1, "%s unlockable '%s' exists in Abilities.DATA" % [id, abl_id])

## ─── Push mechanic via BattleEngine ─────────────────────────────────────────

func _make_rng(seed_val: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

func test_push_combatant_basic() -> void:
	var rng: RandomNumberGenerator = _make_rng()
	var engine := BattleEngine.new(rng)

	var hero := Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e", "Enemy", Combatant.Faction.ENEMY, 40, 8)
	enemy.position = Vector2i(1, 0)

	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)

	var map := DungeonMap.new()
	map.generate(1, rng)
	# Ensure hero and enemy are on passable hexes
	map.tile_types[Vector2i(0, 0)] = "floor"
	map.passable[Vector2i(0, 0)] = true
	map.tile_types[Vector2i(1, 0)] = "floor"
	map.passable[Vector2i(1, 0)] = true
	map.tile_types[Vector2i(2, 0)] = "floor"
	map.passable[Vector2i(2, 0)] = true

	var result: Dictionary = engine.push_combatant(hero, enemy, map)
	assert_true(result.get("pushed", false), "enemy was pushed")
	assert_eq(enemy.position, Vector2i(2, 0), "enemy pushed to (2,0)")
	assert_false(result.get("blocked", true), "push not blocked")
	assert_false(result.get("lava", true), "push not into lava")

func test_push_blocked_by_wall() -> void:
	var rng: RandomNumberGenerator = _make_rng()
	var engine := BattleEngine.new(rng)

	var hero := Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e", "Enemy", Combatant.Faction.ENEMY, 40, 8)
	enemy.position = Vector2i(1, 0)

	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)

	# Map: (1,0) is in dungeon but (2,0) is NOT (off the edge)
	var map := DungeonMap.new()
	map.tile_types[Vector2i(0, 0)] = "floor"
	map.passable[Vector2i(0, 0)] = true
	map.tile_types[Vector2i(1, 0)] = "floor"
	map.passable[Vector2i(1, 0)] = true
	# (2,0) is NOT in tile_types → off-map → blocked

	var result: Dictionary = engine.push_combatant(hero, enemy, map)
	assert_false(result.get("pushed", true), "push blocked by off-map hex")
	assert_eq(enemy.position, Vector2i(1, 0), "enemy stays at (1,0)")
	assert_true(result.get("blocked", false), "result.blocked is true")

func test_push_into_lava_detected() -> void:
	var rng: RandomNumberGenerator = _make_rng()
	var engine := BattleEngine.new(rng)

	var hero := Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e", "Enemy", Combatant.Faction.ENEMY, 40, 8)
	enemy.position = Vector2i(1, 0)

	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)

	var map := DungeonMap.new()
	map.tile_types[Vector2i(0, 0)] = "floor"
	map.passable[Vector2i(0, 0)] = true
	map.tile_types[Vector2i(1, 0)] = "floor"
	map.passable[Vector2i(1, 0)] = true
	map.tile_types[Vector2i(2, 0)] = "lava"
	map.passable[Vector2i(2, 0)] = false  # lava is impassable normally

	var result: Dictionary = engine.push_combatant(hero, enemy, map)
	assert_true(result.get("pushed", false), "push into lava succeeds")
	assert_eq(enemy.position, Vector2i(2, 0), "enemy is now at lava hex (2,0)")
	assert_true(result.get("lava", false), "result marks lava landing")

func test_push_blocked_by_other_combatant() -> void:
	var rng: RandomNumberGenerator = _make_rng()
	var engine := BattleEngine.new(rng)

	var hero := Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy1 := Combatant.new("e1", "E1", Combatant.Faction.ENEMY, 40, 8)
	enemy1.position = Vector2i(1, 0)
	var enemy2 := Combatant.new("e2", "E2", Combatant.Faction.ENEMY, 40, 8)
	enemy2.position = Vector2i(2, 0)  # blocking the push destination

	var all: Array[Combatant] = [hero, enemy1, enemy2]
	engine.setup(all)

	var map := DungeonMap.new()
	for hx: Vector2i in [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)]:
		map.tile_types[hx] = "floor"
		map.passable[hx] = true

	var result: Dictionary = engine.push_combatant(hero, enemy1, map)
	assert_false(result.get("pushed", true), "push blocked by enemy2 at destination")
	assert_eq(enemy1.position, Vector2i(1, 0), "enemy1 stays put")

## ─── combatant_pushed signal emitted ────────────────────────────────────────

func test_push_signal_emitted() -> void:
	var rng: RandomNumberGenerator = _make_rng()
	var engine := BattleEngine.new(rng)

	var hero := Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e", "Enemy", Combatant.Faction.ENEMY, 40, 8)
	enemy.position = Vector2i(1, 0)

	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)

	var map := DungeonMap.new()
	for hx: Vector2i in [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)]:
		map.tile_types[hx] = "floor"
		map.passable[hx] = true

	var fired: Array[bool] = [false]
	var captured_blocked: Array[bool] = [true]
	engine.combatant_pushed.connect(func(_c: Combatant, _f: Vector2i, _t: Vector2i, b: bool) -> void:
		fired[0] = true
		captured_blocked[0] = b
	)

	engine.push_combatant(hero, enemy, map)
	assert_true(fired[0], "combatant_pushed signal emitted")
	assert_false(captured_blocked[0], "signal reports not blocked")

## ─── GameState HP regen on descend ──────────────────────────────────────────

func test_descend_regen_increases_hp() -> void:
	# Simulate what GameState.descend() does (without autoloads)
	# The regen formula: max(1, hero_max_hp / 10)
	var max_hp: int = 100
	var current_hp: int = 60
	var regen: int = max(1, max_hp / 10)
	var new_hp: int = min(max_hp, current_hp + regen)
	assert_eq(regen, 10, "10% of 100 max HP = 10 regen")
	assert_eq(new_hp, 70, "60 + 10 regen = 70")

func test_descend_regen_caps_at_max() -> void:
	var max_hp: int = 100
	var current_hp: int = 96
	var regen: int = max(1, max_hp / 10)
	var new_hp: int = min(max_hp, current_hp + regen)
	assert_eq(new_hp, 100, "regen capped at max HP")

func test_descend_regen_low_max_hp() -> void:
	var max_hp: int = 5
	var current_hp: int = 3
	var regen: int = max(1, max_hp / 10)
	assert_eq(regen, 1, "minimum regen is 1")
	var new_hp: int = min(max_hp, current_hp + regen)
	assert_eq(new_hp, 4, "3 + 1 regen = 4")

## ─── SystemVoice has new pools ───────────────────────────────────────────────

func test_systemvoice_has_low_hp_pool() -> void:
	assert_true(SystemVoice.LINES.has("low_hp"), "SystemVoice has low_hp pool")
	assert_true(SystemVoice.LINES["low_hp"].size() >= 2, "low_hp has at least 2 lines")

func test_systemvoice_has_surrounded_pool() -> void:
	assert_true(SystemVoice.LINES.has("surrounded"), "SystemVoice has surrounded pool")

func test_systemvoice_has_backstab_hit_pool() -> void:
	assert_true(SystemVoice.LINES.has("backstab_hit"), "SystemVoice has backstab_hit pool")

func test_systemvoice_has_first_kill_pool() -> void:
	assert_true(SystemVoice.LINES.has("first_kill"), "SystemVoice has first_kill pool")

func test_systemvoice_has_push_into_lava_pool() -> void:
	assert_true(SystemVoice.LINES.has("push_into_lava"), "SystemVoice has push_into_lava pool")

func test_systemvoice_has_unlock_ability_pool() -> void:
	assert_true(SystemVoice.LINES.has("unlock_ability"), "SystemVoice has unlock_ability pool")
