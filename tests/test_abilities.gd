extends "res://tests/run_tests.gd".BaseTest
class_name TestAbilities
## Tests for ability effects, status mechanics, and enemy movement.

func _make_rng(seed_val: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

func _make_engine(seed_val: int = 42) -> BattleEngine:
	return BattleEngine.new(_make_rng(seed_val))

# ─── Combatant helpers ────────────────────────────────────────────────────────

func test_combatant_has_status() -> void:
	var c := Combatant.new("e", "E", Combatant.Faction.ENEMY, 100, 10)
	c.apply_status(StatusEffect.burning(3))
	assert_true(c.has_status("burning"), "has_status finds burning")
	assert_true(not c.has_status("frozen"), "has_status negative for missing")

func test_combatant_remove_status() -> void:
	var c := Combatant.new("e", "E", Combatant.Faction.ENEMY, 100, 10)
	c.apply_status(StatusEffect.burning(3))
	c.apply_status(StatusEffect.frozen(2))
	c.remove_status("burning")
	assert_true(not c.has_status("burning"), "burning removed")
	assert_true(c.has_status("frozen"), "frozen still present")

func test_take_damage_respects_armor() -> void:
	var c := Combatant.new("t", "T", Combatant.Faction.ENEMY, 100, 10)
	c.armor = 5
	var dealt: int = c.take_damage(12)
	assert_eq(dealt, 7, "12 damage - 5 armor = 7 dealt")

func test_take_damage_ignore_armor() -> void:
	var c := Combatant.new("t", "T", Combatant.Faction.ENEMY, 100, 10)
	c.armor = 10
	var dealt: int = c.take_damage(15, true)
	assert_eq(dealt, 15, "Ignore armor: full 15 dealt")

func test_combatant_stats_field() -> void:
	var c := Combatant.new("h", "H", Combatant.Faction.HERO, 100, 10)
	c.stats = {"attack": 20}
	assert_eq(c.stats.get("attack", 0), 20, "Stats dict accessible")

# ─── Status: Vanish ───────────────────────────────────────────────────────────

func test_vanish_status_created() -> void:
	var eff := StatusEffect.vanished()
	assert_eq(eff.get("id", ""), "vanished", "vanished id")
	assert_eq(eff.get("damage_multiplier", 0.0), 3.0, "3x multiplier")
	assert_true(eff.get("consume_on_hit", false), "consume_on_hit flag")

func test_vanish_triples_damage() -> void:
	var rng := _make_rng(99)
	rng.seed = 99
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 200, 10)
	hero.abilities = ["basic_attack"]
	hero.stats = {"attack": 0}
	var enemy := Combatant.new("e", "Imp", Combatant.Faction.ENEMY, 500, 5)
	enemy.abilities = ["enemy_claw"]
	engine.setup([hero, enemy])
	# Get baseline damage (without vanish) — reset rng
	var rng2 := _make_rng(99)
	var engine2 := BattleEngine.new(rng2)
	var hero2 := Combatant.new("hero2", "Carl", Combatant.Faction.HERO, 200, 10)
	hero2.abilities = ["basic_attack"]
	hero2.stats = {"attack": 0}
	var enemy2 := Combatant.new("e2", "Imp", Combatant.Faction.ENEMY, 500, 5)
	enemy2.abilities = ["enemy_claw"]
	engine2.setup([hero2, enemy2])
	# Normal hit
	engine2.begin_turn()
	var normal_hp_before: int = enemy2.hp
	engine2.perform_attack(hero2, enemy2, "basic_attack")
	var normal_dmg: int = normal_hp_before - enemy2.hp
	# Vanish hit (same seed)
	engine.begin_turn()
	hero.apply_status(StatusEffect.vanished())
	var vanish_hp_before: int = enemy.hp
	engine.perform_attack(hero, enemy, "basic_attack")
	var vanish_dmg: int = vanish_hp_before - enemy.hp
	# Vanished should deal ~3x
	assert_true(vanish_dmg >= normal_dmg * 2, "Vanish deals >= 2x normal damage (%d vs %d)" % [vanish_dmg, normal_dmg])

func test_vanish_consumed_after_hit() -> void:
	var engine := _make_engine(5)
	var hero := Combatant.new("h", "H", Combatant.Faction.HERO, 200, 10)
	hero.stats = {}
	hero.abilities = ["basic_attack"]
	var enemy := Combatant.new("e", "E", Combatant.Faction.ENEMY, 500, 5)
	enemy.abilities = ["enemy_claw"]
	engine.setup([hero, enemy])
	engine.begin_turn()
	hero.apply_status(StatusEffect.vanished())
	engine.perform_attack(hero, enemy, "basic_attack")
	assert_true(not hero.has_status("vanished"), "Vanish consumed after hit")

# ─── Status: Frozen ──────────────────────────────────────────────────────────

func test_frozen_detected_in_begin_turn() -> void:
	var engine := _make_engine(1)
	var hero := Combatant.new("h", "H", Combatant.Faction.HERO, 100, 15)  # fast: goes first
	hero.abilities = ["basic_attack"]
	hero.stats = {}
	var enemy := Combatant.new("e", "E", Combatant.Faction.ENEMY, 100, 5)
	enemy.abilities = ["enemy_claw"]
	enemy.apply_status(StatusEffect.frozen(2))
	engine.setup([hero, enemy])
	# Hero goes first
	var first: Combatant = engine.begin_turn()
	assert_eq(first.id, "h", "Hero goes first")
	assert_true(not engine.active_turn_skipped, "Hero turn not skipped")
	engine.end_turn()
	# Enemy's turn — frozen
	var second: Combatant = engine.begin_turn()
	assert_eq(second.id, "e", "Enemy's turn next")
	assert_true(engine.active_turn_skipped, "Enemy turn skipped (frozen)")

func test_frozen_lasts_correct_turns() -> void:
	## duration=2 frozen → skipped 2 turns then acts on 3rd
	var engine := _make_engine(2)
	var hero := Combatant.new("h", "H", Combatant.Faction.HERO, 200, 15)
	hero.abilities = ["basic_attack"]
	hero.stats = {}
	var enemy := Combatant.new("e", "E", Combatant.Faction.ENEMY, 200, 5)
	enemy.abilities = ["enemy_claw"]
	enemy.apply_status(StatusEffect.frozen(2))
	engine.setup([hero, enemy])
	var skip_count: int = 0
	# Run enough rounds to see skip and then act
	for _i: int in range(8):
		if engine.battle_over:
			break
		var active: Combatant = engine.begin_turn()
		if active == null:
			break
		if engine.active_turn_skipped:
			skip_count += 1
		engine.end_turn()
	assert_eq(skip_count, 2, "Frozen for duration=2 → 2 skipped turns")

# ─── Status: Fortified ───────────────────────────────────────────────────────

func test_fortified_adds_armor() -> void:
	var c := Combatant.new("h", "H", Combatant.Faction.HERO, 100, 10)
	c.armor = 3
	c.apply_status(StatusEffect.fortified(3, 5))
	assert_eq(c.get_effective_armor(), 8, "3 base + 5 fortified = 8 effective armor")

# ─── AOE: Fireball ───────────────────────────────────────────────────────────

func test_fireball_hits_nearby_enemies() -> void:
	var engine := _make_engine(10)
	var hero := Combatant.new("h", "Carl", Combatant.Faction.HERO, 200, 10)
	hero.abilities = ["fireball"]
	hero.stats = {"attack": 0}
	# Two enemies: one at distance 1 from target, one at distance 3
	var e1 := Combatant.new("e1", "Imp1", Combatant.Faction.ENEMY, 500, 5)
	e1.position = Vector2i(1, 0)
	var e2 := Combatant.new("e2", "Imp2", Combatant.Faction.ENEMY, 500, 5)
	e2.position = Vector2i(4, 0)
	engine.setup([hero, e1, e2])
	engine.begin_turn()
	var hp1_before: int = e1.hp
	var hp2_before: int = e2.hp
	# Fire at center = e1's position; radius 2 hits e1 but not e2 (dist=3)
	engine.perform_ability(hero, "fireball", e1)
	assert_true(e1.hp < hp1_before, "e1 hit by fireball (dist=0 from center)")
	assert_eq(e2.hp, hp2_before, "e2 not hit (dist=3 from center > radius 2)")

func test_fireball_hits_all_in_radius() -> void:
	var engine := _make_engine(11)
	var hero := Combatant.new("h", "Carl", Combatant.Faction.HERO, 200, 10)
	hero.abilities = ["fireball"]
	hero.stats = {"attack": 0}
	# Three enemies within radius 2 of (2,0)
	var e1 := Combatant.new("e1", "E1", Combatant.Faction.ENEMY, 500, 5)
	e1.position = Vector2i(2, 0)
	var e2 := Combatant.new("e2", "E2", Combatant.Faction.ENEMY, 500, 5)
	e2.position = Vector2i(3, 0)  # dist 1 from e1
	var e3 := Combatant.new("e3", "E3", Combatant.Faction.ENEMY, 500, 5)
	e3.position = Vector2i(4, 0)  # dist 2 from e1
	engine.setup([hero, e1, e2, e3])
	engine.begin_turn()
	engine.perform_ability(hero, "fireball", e1)
	assert_true(e1.hp < 500, "e1 hit")
	assert_true(e2.hp < 500, "e2 hit (dist 1)")
	assert_true(e3.hp < 500, "e3 hit (dist 2)")

# ─── AOE: Frost Nova ─────────────────────────────────────────────────────────

func test_frost_nova_freezes_adjacent() -> void:
	var engine := _make_engine(20)
	var hero := Combatant.new("h", "Carl", Combatant.Faction.HERO, 200, 10)
	hero.position = Vector2i(0, 0)
	hero.abilities = ["frost_nova"]
	hero.stats = {"attack": 0}
	var e1 := Combatant.new("e1", "E1", Combatant.Faction.ENEMY, 500, 5)
	e1.position = Vector2i(1, 0)  # adjacent
	var e2 := Combatant.new("e2", "E2", Combatant.Faction.ENEMY, 500, 5)
	e2.position = Vector2i(3, 0)  # not adjacent
	engine.setup([hero, e1, e2])
	engine.begin_turn()
	engine.perform_ability(hero, "frost_nova", null)
	assert_true(e1.has_status("frozen"), "Adjacent enemy frozen")
	assert_true(not e2.has_status("frozen"), "Non-adjacent enemy not frozen")

# ─── Buff: Taunt ─────────────────────────────────────────────────────────────

func test_taunt_applies_fortified() -> void:
	var engine := _make_engine(30)
	var hero := Combatant.new("h", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.abilities = ["taunt"]
	hero.stats = {}
	engine.setup([hero])
	engine.begin_turn()
	engine.perform_ability(hero, "taunt", null)
	assert_true(hero.has_status("fortified"), "Taunt applies fortified to hero")
	assert_gt(hero.get_effective_armor(), 0, "Fortified adds armor")

# ─── Buff: Vanish (through perform_ability) ───────────────────────────────────

func test_vanish_ability_applies_status() -> void:
	var engine := _make_engine(40)
	var hero := Combatant.new("h", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.abilities = ["vanish"]
	hero.stats = {}
	engine.setup([hero])
	engine.begin_turn()
	engine.perform_ability(hero, "vanish", null)
	assert_true(hero.has_status("vanished"), "Vanish ability applies vanished status")

# ─── Enemy Movement ──────────────────────────────────────────────────────────

func test_enemy_moves_toward_hero() -> void:
	var engine := _make_engine(50)
	var hero := Combatant.new("h", "H", Combatant.Faction.HERO, 200, 15)
	hero.position = Vector2i(0, 0)
	hero.abilities = ["basic_attack"]
	hero.stats = {}
	var enemy := Combatant.new("e", "E", Combatant.Faction.ENEMY, 200, 5)
	enemy.position = Vector2i(4, 0)  # 4 hexes away
	enemy.abilities = ["basic_attack"]
	# Set up a minimal map
	var map := DungeonMap.new()
	map.generate(1, _make_rng(50))
	# Override positions to known coords
	hero.position = Vector2i(0, 0)
	enemy.position = Vector2i(4, 0)
	engine.setup([hero, enemy])
	engine.setup_map(map)
	# Force the engine to process enemy's turn
	engine.begin_turn()  # hero turn
	engine.end_turn()
	var old_pos: Vector2i = enemy.position
	engine.begin_turn()  # enemy turn
	engine.enemy_ai_action(enemy)
	assert_true(HexGrid.hex_distance(enemy.position, hero.position) < HexGrid.hex_distance(old_pos, hero.position),
		"Enemy moved closer to hero")

func test_backstab_ignores_armor() -> void:
	## Backstab should deal more damage against armored target than basic_attack
	var rng := _make_rng(77)
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("h", "H", Combatant.Faction.HERO, 200, 10)
	hero.stats = {"attack": 0}
	hero.abilities = ["backstab", "basic_attack"]
	var enemy := Combatant.new("e", "E", Combatant.Faction.ENEMY, 500, 5)
	enemy.armor = 15  # Heavy armor — basic attack barely scratches
	engine.setup([hero, enemy])
	engine.begin_turn()
	var hp_before: int = enemy.hp
	engine.perform_attack(hero, enemy, "backstab")
	var backstab_dmg: int = hp_before - enemy.hp
	assert_gt(backstab_dmg, 0, "Backstab ignores armor, deals damage")
	# Reset and compare with normal attack
	enemy.hp = 500
	var rng2 := _make_rng(77)
	var engine2 := BattleEngine.new(rng2)
	engine2.setup([hero, enemy])
	engine2.begin_turn()
	engine2.perform_attack(hero, enemy, "basic_attack")
	var basic_dmg: int = 500 - enemy.hp
	assert_true(backstab_dmg > basic_dmg, "Backstab deals more than basic vs high-armor enemy (backstab=%d basic=%d)" % [backstab_dmg, basic_dmg])
