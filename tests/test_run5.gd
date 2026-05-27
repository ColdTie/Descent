## Run 5 Tests: BossDefs, boss floor detection, GameState.run_length,
## Golem Shove (enemy push mechanic), boss AI ability selection.

class_name TestRun5 extends RefCounted

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

## ─── Helpers ──────────────────────────────────────────────────────────────────

func _make_hero(pos: Vector2i) -> Combatant:
	var c := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 150, 10)
	c.position = pos
	return c

func _make_golem(pos: Vector2i) -> Combatant:
	var c := Combatant.new("golem_1234", "Lava Golem", Combatant.Faction.ENEMY, 90, 5)
	c.armor = 8
	c.sprite_key = "golem"
	c.position = pos
	var abilities: Array[String] = ["enemy_fireball", "enemy_shove"]
	c.abilities = abilities
	return c

## ─── Boss Floor Detection ─────────────────────────────────────────────────────

func test_boss_floor_5() -> void:
	assert_true(BossDefs.is_boss_floor(5), "Floor 5 is a boss floor")

func test_boss_floor_10() -> void:
	assert_true(BossDefs.is_boss_floor(10), "Floor 10 is a boss floor")

func test_boss_floor_15() -> void:
	assert_true(BossDefs.is_boss_floor(15), "Floor 15 is a boss floor")

func test_not_boss_floor_4() -> void:
	assert_true(not BossDefs.is_boss_floor(4), "Floor 4 is not a boss floor")

func test_not_boss_floor_6() -> void:
	assert_true(not BossDefs.is_boss_floor(6), "Floor 6 is not a boss floor")

func test_not_boss_floor_0() -> void:
	assert_true(not BossDefs.is_boss_floor(0), "Floor 0 is not a boss floor")

func test_not_boss_floor_1() -> void:
	assert_true(not BossDefs.is_boss_floor(1), "Floor 1 is not a boss floor")

## ─── Boss Definitions ─────────────────────────────────────────────────────────

func test_boss_def_floor5_is_herald() -> void:
	var def: Dictionary = BossDefs.get_boss_for_floor(5)
	assert_eq(def.get("id", ""), "stone_herald", "Floor 5 boss = stone_herald")

func test_boss_def_floor10_cycles() -> void:
	var def: Dictionary = BossDefs.get_boss_for_floor(10)
	assert_eq(def.get("id", ""), "wrathful_champion", "Floor 10 boss = wrathful_champion")

func test_boss_def_floor15_cycles() -> void:
	var def: Dictionary = BossDefs.get_boss_for_floor(15)
	assert_eq(def.get("id", ""), "demon_overlord", "Floor 15 boss = demon_overlord")

func test_boss_def_floor20_wraps() -> void:
	var def: Dictionary = BossDefs.get_boss_for_floor(20)
	# Tier 3 (floor 20), 3 % 3 = 0 = stone_herald again
	assert_eq(def.get("id", ""), "stone_herald", "Floor 20 boss wraps back to stone_herald")

## ─── make_boss Combatant ──────────────────────────────────────────────────────

func test_boss_make_floor5_hp() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var boss: Combatant = BossDefs.make_boss(5, Vector2i(3, 0), rng)
	# Tier 0, stone_herald base HP=280, hp_scale=1.0 → 280
	assert_eq(boss.max_hp, 280, "Floor 5 boss HP = 280 (tier 0, no scaling)")

func test_boss_make_floor10_hp_scaled() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var boss: Combatant = BossDefs.make_boss(10, Vector2i(3, 0), rng)
	# Tier 1, wrathful_champion base HP=320, hp_scale=1.5 → 480
	assert_eq(boss.max_hp, 480, "Floor 10 boss HP = 480 (tier 1, 1.5x scaling)")

func test_boss_make_floor5_name() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var boss: Combatant = BossDefs.make_boss(5, Vector2i(0, 0), rng)
	assert_eq(boss.display_name, "Stone Herald", "Floor 5 boss name = Stone Herald")

func test_boss_make_sprite_key() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var boss: Combatant = BossDefs.make_boss(5, Vector2i(0, 0), rng)
	assert_eq(boss.sprite_key, "boss", "Boss sprite_key = 'boss'")

func test_boss_make_faction() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var boss: Combatant = BossDefs.make_boss(5, Vector2i(0, 0), rng)
	assert_eq(boss.faction, Combatant.Faction.ENEMY, "Boss faction = ENEMY")

func test_boss_make_abilities_not_empty() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var boss: Combatant = BossDefs.make_boss(5, Vector2i(0, 0), rng)
	assert_true(not boss.abilities.is_empty(), "Boss has abilities")

func test_boss_armor_tier0() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var boss: Combatant = BossDefs.make_boss(5, Vector2i(0, 0), rng)
	# stone_herald base armor=12, tier=0, bonus=0 → 12
	assert_eq(boss.armor, 12, "Floor 5 boss (herald) armor = 12")

func test_boss_armor_tier1() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var boss: Combatant = BossDefs.make_boss(10, Vector2i(0, 0), rng)
	# wrathful_champion base armor=8, tier=1, bonus=2 → 10
	assert_eq(boss.armor, 10, "Floor 10 boss (champion) armor = 10 (8+2)")

func test_boss_xp_tier0() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var boss: Combatant = BossDefs.make_boss(5, Vector2i(0, 0), rng)
	assert_eq(boss.xp_reward, 200, "Floor 5 boss XP = 200")

func test_boss_xp_tier1() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var boss: Combatant = BossDefs.make_boss(10, Vector2i(0, 0), rng)
	# wrathful_champion xp=250 + 50*1 = 300
	assert_eq(boss.xp_reward, 300, "Floor 10 boss XP = 300 (250+50)")

func test_boss_position_set() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var spawn: Vector2i = Vector2i(4, -2)
	var boss: Combatant = BossDefs.make_boss(5, spawn, rng)
	assert_eq(boss.position, spawn, "Boss spawns at given position")

## ─── Golem Shove / Enemy Push ─────────────────────────────────────────────────

func test_enemy_shove_exists() -> void:
	var abl: Dictionary = Abilities.get_ability("enemy_shove")
	assert_eq(abl.get("id", ""), "enemy_shove", "enemy_shove in Abilities.DATA")

func test_enemy_shove_push_distance() -> void:
	var abl: Dictionary = Abilities.get_ability("enemy_shove")
	assert_eq(abl.get("push_distance", 0), 2, "enemy_shove push_distance = 2")

func test_enemy_shove_base_damage() -> void:
	var abl: Dictionary = Abilities.get_ability("enemy_shove")
	assert_true(abl.get("base_damage", 0) > 0, "enemy_shove has positive base damage")

func test_golem_has_shove_ability() -> void:
	## EnemyDefs golem definition should include enemy_shove.
	var pool: Array[Dictionary] = EnemyDefs.get_enemies_for_floor(5)
	var found_golem: bool = false
	var golem_has_shove: bool = false
	for def: Dictionary in pool:
		if def.get("sprite_key", "") == "golem":
			found_golem = true
			var abilities: Array = def.get("abilities", [])
			if abilities.has("enemy_shove"):
				golem_has_shove = true
	assert_true(found_golem, "Lava Golem is in floor-5 pool")
	assert_true(golem_has_shove, "Lava Golem has enemy_shove ability")

func test_golem_shove_damages_hero() -> void:
	## Uses Array[int] container for lambda capture (GDScript captures primitives by value).
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var hero := _make_hero(Vector2i(0, 0))
	var golem := _make_golem(Vector2i(1, 0))

	var engine := BattleEngine.new(rng)
	engine.setup([hero, golem])

	var damage_dealt: Array[int] = [0]
	engine.action_taken.connect(func(_a: Combatant, _t: Combatant, dmg: int, _id: String) -> void:
		damage_dealt[0] += dmg
	)

	engine.enemy_ai_action(golem)
	assert_gt(damage_dealt[0], 0, "Golem shove deals damage to hero when adjacent")

func test_golem_shove_pushes_hero_away() -> void:
	## Golem at (1,0), hero at (0,0): push direction = away from golem = (-1,0).
	## Hero should end up at (-1,0) or (-2,0).
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var hero := _make_hero(Vector2i(0, 0))
	var golem := _make_golem(Vector2i(1, 0))

	var engine := BattleEngine.new(rng)
	engine.setup([hero, golem])
	engine.enemy_ai_action(golem)

	assert_true(hero.position.x < 0, "Hero pushed in -x direction (away from golem at x=1)")

func test_golem_shove_signal_emitted() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 333
	var hero := _make_hero(Vector2i(0, 0))
	var golem := _make_golem(Vector2i(1, 0))

	var engine := BattleEngine.new(rng)
	engine.setup([hero, golem])

	var push_fired: Array[bool] = [false]
	engine.combatant_pushed.connect(func(_c: Combatant, _f: Vector2i, _t: Vector2i) -> void:
		push_fired[0] = true
	)

	engine.enemy_ai_action(golem)
	assert_true(push_fired[0], "combatant_pushed signal fires when golem shoves hero")

func test_golem_no_shove_when_far() -> void:
	## Golem at (4,0), hero at (0,0): distance=4, golem should NOT shove.
	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	var hero := _make_hero(Vector2i(0, 0))
	var golem := _make_golem(Vector2i(4, 0))

	var engine := BattleEngine.new(rng)
	engine.setup([hero, golem])

	var push_fired: Array[bool] = [false]
	engine.combatant_pushed.connect(func(_c: Combatant, _f: Vector2i, _t: Vector2i) -> void:
		push_fired[0] = true
	)

	engine.enemy_ai_action(golem)
	assert_true(not push_fired[0], "Golem does not shove when not adjacent")

## ─── Boss AI ──────────────────────────────────────────────────────────────────

func test_boss_ai_picks_highest_damage() -> void:
	## stone_herald has enemy_claw(8), enemy_shove(10), boss_slam(32).
	## At distance 1 all are in range; boss_slam should be picked.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var boss: Combatant = BossDefs.make_boss(5, Vector2i(1, 0), rng)
	var hero := _make_hero(Vector2i(0, 0))
	var engine := BattleEngine.new(rng)
	engine.setup([hero, boss])

	var picked: String = engine._pick_boss_ability(boss, 1)
	assert_eq(picked, "boss_slam", "Boss picks boss_slam (highest dmg=32) at range 1")

func test_boss_ai_cooldown_blocks_ability() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var boss: Combatant = BossDefs.make_boss(5, Vector2i(1, 0), rng)
	var hero := _make_hero(Vector2i(0, 0))
	var engine := BattleEngine.new(rng)
	engine.setup([hero, boss])

	engine._enemy_use_ability(boss, "boss_slam")
	var picked: String = engine._pick_boss_ability(boss, 1)
	assert_true(picked != "boss_slam", "boss_slam blocked after use; picks different ability")

func test_boss_ai_no_ability_out_of_range() -> void:
	## stone_herald: all abilities range=1. At dist=3, nothing should be picked.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var boss: Combatant = BossDefs.make_boss(5, Vector2i(0, 0), rng)
	var engine := BattleEngine.new(rng)
	var hero := _make_hero(Vector2i(3, 0))
	engine.setup([hero, boss])

	var picked: String = engine._pick_boss_ability(boss, 3)
	assert_eq(picked, "", "stone_herald has no range-3 ability → empty pick")

func test_enemy_ability_cooldown_ticks() -> void:
	## After using an ability with cooldown 4, after 4 turns it should be ready.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var boss: Combatant = BossDefs.make_boss(5, Vector2i(0, 0), rng)
	var engine := BattleEngine.new(rng)
	var hero := _make_hero(Vector2i(1, 0))
	engine.setup([hero, boss])

	engine._enemy_use_ability(boss, "boss_slam")  # cooldown = 4
	assert_true(not engine._enemy_ability_ready(boss, "boss_slam"), "boss_slam not ready after use")

	# Tick 4 times
	for _i: int in range(4):
		engine._tick_enemy_cooldowns(boss)

	assert_true(engine._enemy_ability_ready(boss, "boss_slam"), "boss_slam ready after 4 ticks")

## ─── Boss abilities existence ─────────────────────────────────────────────────

func test_boss_slam_exists() -> void:
	var abl: Dictionary = Abilities.get_ability("boss_slam")
	assert_eq(abl.get("id", ""), "boss_slam", "boss_slam in Abilities.DATA")

func test_boss_cleave_exists() -> void:
	var abl: Dictionary = Abilities.get_ability("boss_cleave")
	assert_eq(abl.get("id", ""), "boss_cleave", "boss_cleave in Abilities.DATA")

func test_boss_inferno_exists() -> void:
	var abl: Dictionary = Abilities.get_ability("boss_inferno")
	assert_eq(abl.get("id", ""), "boss_inferno", "boss_inferno in Abilities.DATA")
