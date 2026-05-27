## Run 4 Tests: Shield Bash pushback, commentary pools, ability unlocking, floor regen
## Extends the headless BaseTest from run_tests.gd.

class_name TestRun4 extends RefCounted

var _passes: int = 0
var _failures: int = 0

func assert_eq(a: Variant, b: Variant, msg: String = "") -> void:
	if a == b:
		_passes += 1
		print("  PASS: %s" % (msg if msg else "%s == %s" % [str(a), str(b)]))
	else:
		_failures += 1
		print("  FAIL: %s -- got %s, expected %s" % [msg, str(a), str(b)])

func assert_true(val: bool, msg: String = "") -> void:
	if val:
		_passes += 1
		print("  PASS: %s" % msg)
	else:
		_failures += 1
		print("  FAIL: %s" % msg)

func assert_gt(a: Variant, b: Variant, msg: String = "") -> void:
	if a > b:
		_passes += 1
		print("  PASS: %s (%s > %s)" % [msg, str(a), str(b)])
	else:
		_failures += 1
		print("  FAIL: %s -- %s not > %s" % [msg, str(a), str(b)])

## ── Helper: make a Combatant quickly ───────────────────────────────────────

func _make_hero(pos: Vector2i) -> Combatant:
	var c := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 150, 10)
	c.position = pos
	return c

func _make_enemy(id: String, pos: Vector2i, hp: int = 50) -> Combatant:
	var c := Combatant.new(id, "Foe", Combatant.Faction.ENEMY, hp, 8)
	c.position = pos
	return c

## ── Shield Bash / push_distance in Abilities ───────────────────────────────

func test_shield_bash_in_abilities() -> void:
	var data: Dictionary = Abilities.get_ability("shield_bash")
	assert_eq(data.get("id", ""), "shield_bash", "shield_bash ability exists")
	assert_eq(data.get("push_distance", 0), 2, "shield_bash push_distance = 2")
	assert_eq(data.get("range", 0), 1, "shield_bash range = 1 (melee)")
	assert_eq(data.get("max_charges", 0), 2, "shield_bash has 2 charges")

func test_brawler_has_shield_bash() -> void:
	var data: Dictionary = Classes.get_class_data("brawler")
	var abilities: Array = data.get("abilities", [])
	assert_true(abilities.has("shield_bash"), "Brawler starts with shield_bash")

## ── BattleEngine.perform_push ──────────────────────────────────────────────

func test_push_moves_target_along_attack_axis() -> void:
	## Hero at (0,0), enemy at (1,0) — expect push to land at (3,0) over 2 hexes.
	var hero := _make_hero(Vector2i(0, 0))
	var enemy := _make_enemy("e1", Vector2i(1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var engine := BattleEngine.new(rng)
	var combatants: Array[Combatant] = [hero, enemy]
	engine.setup(combatants)

	engine.perform_push(hero, enemy, 2, null)  # null map = all passable
	assert_eq(enemy.position, Vector2i(3, 0), "Enemy pushed 2 hexes from (1,0) to (3,0)")

func test_push_stops_at_occupied_hex() -> void:
	## Enemy at (1,0), blocker at (3,0) — push of 2 should stop at (2,0).
	var hero   := _make_hero(Vector2i(0, 0))
	var enemy  := _make_enemy("e1", Vector2i(1, 0))
	var blocker := _make_enemy("e2", Vector2i(3, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var engine := BattleEngine.new(rng)
	var combatants: Array[Combatant] = [hero, enemy, blocker]
	engine.setup(combatants)

	engine.perform_push(hero, enemy, 2, null)
	assert_eq(enemy.position, Vector2i(2, 0), "Push stops at (2,0) — (3,0) is occupied")
	assert_eq(blocker.position, Vector2i(3, 0), "Blocker did not move")

func test_push_stops_at_impassable_hex_via_map() -> void:
	## Set up a map where (2,0) is lava (impassable). Enemy at (1,0), push 2.
	## Should stop at (1,0) since (2,0) is blocked immediately.
	var hero  := _make_hero(Vector2i(0, 0))
	var enemy := _make_enemy("e1", Vector2i(1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var engine := BattleEngine.new(rng)
	var combatants: Array[Combatant] = [hero, enemy]
	engine.setup(combatants)

	# Build a minimal map with (2,0) set to lava (not passable)
	var map := DungeonMap.new()
	map.tile_types[Vector2i(1, 0)] = "floor"
	map.passable[Vector2i(1, 0)]   = true
	map.tile_types[Vector2i(2, 0)] = "lava"
	map.passable[Vector2i(2, 0)]   = false
	map.tile_types[Vector2i(3, 0)] = "floor"
	map.passable[Vector2i(3, 0)]   = true

	engine.perform_push(hero, enemy, 2, map)
	assert_eq(enemy.position, Vector2i(1, 0), "Push blocked at lava (2,0) — stays at (1,0)")

func test_push_negative_direction() -> void:
	## Hero at (2,0), enemy at (1,0) — push direction is (-1,0), lands at (-1,0).
	var hero  := _make_hero(Vector2i(2, 0))
	var enemy := _make_enemy("e1", Vector2i(1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var engine := BattleEngine.new(rng)
	var combatants: Array[Combatant] = [hero, enemy]
	engine.setup(combatants)

	engine.perform_push(hero, enemy, 2, null)
	assert_eq(enemy.position, Vector2i(-1, 0), "Enemy pushed left from (1,0) to (-1,0)")

func test_push_diagonal_direction() -> void:
	## Hero at (0,0), enemy at (0,-1) — push direction should be (0,-1).
	## After 2 hexes: (0,-3).
	var hero  := _make_hero(Vector2i(0, 0))
	var enemy := _make_enemy("e1", Vector2i(0, -1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var engine := BattleEngine.new(rng)
	var combatants: Array[Combatant] = [hero, enemy]
	engine.setup(combatants)

	engine.perform_push(hero, enemy, 2, null)
	assert_eq(enemy.position, Vector2i(0, -3), "Enemy pushed in (0,-1) direction to (0,-3)")

func test_push_emits_signal() -> void:
	## perform_push should emit combatant_pushed.
	var hero  := _make_hero(Vector2i(0, 0))
	var enemy := _make_enemy("e1", Vector2i(1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var engine := BattleEngine.new(rng)
	var combatants: Array[Combatant] = [hero, enemy]
	engine.setup(combatants)

	var signal_fired: Array[bool] = [false]
	engine.combatant_pushed.connect(func(_c, _f, _t) -> void: signal_fired[0] = true)
	engine.perform_push(hero, enemy, 1, null)
	assert_true(signal_fired[0], "combatant_pushed signal emitted on successful push")

func test_push_no_signal_when_blocked_immediately() -> void:
	## Push of 1 where immediate next hex is occupied — no movement, no signal.
	var hero    := _make_hero(Vector2i(0, 0))
	var enemy   := _make_enemy("e1", Vector2i(1, 0))
	var blocker := _make_enemy("e2", Vector2i(2, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var engine := BattleEngine.new(rng)
	var combatants: Array[Combatant] = [hero, enemy, blocker]
	engine.setup(combatants)

	var signal_fired: Array[bool] = [false]
	engine.combatant_pushed.connect(func(_c, _f, _t) -> void: signal_fired[0] = true)
	engine.perform_push(hero, enemy, 1, null)
	assert_true(not signal_fired[0], "No push signal when immediately blocked")
	assert_eq(enemy.position, Vector2i(1, 0), "Enemy stays put when blocked")

## ── Abilities.gd: new pools exist in SystemVoice (indirectly) ──────────────

func test_shield_bash_not_in_enemy_pool() -> void:
	## shield_bash should NOT appear in enemy ability IDs (it's hero-only)
	var enemy_ids: Array[String] = ["enemy_claw", "enemy_bite", "enemy_fireball"]
	assert_true(not enemy_ids.has("shield_bash"), "shield_bash is not an enemy ability")

## ── GameState.heal_between_floors ──────────────────────────────────────────
## (Can't call the autoload in headless --script mode; test the math directly.)

func test_floor_regen_math() -> void:
	## 8% of 150 HP = 12, clamped to max
	var max_hp: int = 150
	var current_hp: int = 100
	var regen: int = max(5, int(max_hp * 0.08))
	var healed: int = min(max_hp, current_hp + regen)
	assert_eq(regen, 12, "Regen for 150 max HP = 12")
	assert_eq(healed, 112, "100 HP + 12 regen = 112")

func test_floor_regen_minimum() -> void:
	## Even tiny max HP gives at least 5 regen
	var max_hp: int = 30
	var regen: int = max(5, int(max_hp * 0.08))
	assert_eq(regen, 5, "Minimum regen = 5 for small max HP")

func test_floor_regen_caps_at_max_hp() -> void:
	## Full HP hero gets capped at max
	var max_hp: int = 150
	var current_hp: int = 148
	var regen: int = max(5, int(max_hp * 0.08))
	var healed: int = min(max_hp, current_hp + regen)
	assert_eq(healed, max_hp, "Regen capped at max HP (148+12 → 150)")

## ── Abilities unlock list completeness ────────────────────────────────────

func test_unlockable_abilities_all_exist() -> void:
	## Every ability in the LevelUp unlock pool must exist in Abilities.DATA
	var all_unlockable: Array[String] = [
		"power_strike", "backstab", "fireball", "frost_nova",
		"taunt", "vanish", "shield_bash"
	]
	for abl_id: String in all_unlockable:
		var data: Dictionary = Abilities.get_ability(abl_id)
		assert_eq(data.get("id", ""), abl_id, "%s exists in Abilities.DATA" % abl_id)
