extends "res://tests/run_tests.gd".BaseTest
class_name TestMovement
## Tests for movement, frozen skip-turn, vanish multiplier, and AI behaviour.

func _make_rng(seed_val: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

## ─── Movement validation ──────────────────────────────────────────────────────

func test_can_move_to_adjacent_empty() -> void:
	var rng := _make_rng()
	var engine := BattleEngine.new(rng)
	var hero  := Combatant.new("h",  "Hero", Combatant.Faction.HERO,  100, 10)
	var enemy := Combatant.new("e1", "Imp",  Combatant.Faction.ENEMY,  25, 12)
	hero.position  = Vector2i(0, 0)
	enemy.position = Vector2i(3, 0)
	engine.setup([hero, enemy])
	assert_true(engine.can_move_to(hero, Vector2i(1, 0)),
		"Adjacent empty hex is moveable")

func test_cannot_move_to_nonadjacent() -> void:
	var rng := _make_rng()
	var engine := BattleEngine.new(rng)
	var hero  := Combatant.new("h",  "Hero", Combatant.Faction.HERO,  100, 10)
	var enemy := Combatant.new("e1", "Imp",  Combatant.Faction.ENEMY,  25, 12)
	hero.position  = Vector2i(0, 0)
	enemy.position = Vector2i(3, 0)
	engine.setup([hero, enemy])
	assert_true(not engine.can_move_to(hero, Vector2i(2, 0)),
		"Non-adjacent hex (distance 2) not moveable")

func test_cannot_move_to_occupied_hex() -> void:
	var rng := _make_rng()
	var engine := BattleEngine.new(rng)
	var hero  := Combatant.new("h",  "Hero", Combatant.Faction.HERO, 100, 10)
	var enemy := Combatant.new("e1", "Imp",  Combatant.Faction.ENEMY,  25, 12)
	hero.position  = Vector2i(0, 0)
	enemy.position = Vector2i(1, 0)  # Adjacent to hero
	engine.setup([hero, enemy])
	assert_true(not engine.can_move_to(hero, Vector2i(1, 0)),
		"Occupied adjacent hex not moveable")

func test_perform_move_updates_position() -> void:
	var rng := _make_rng()
	var engine := BattleEngine.new(rng)
	var hero  := Combatant.new("h",  "Hero", Combatant.Faction.HERO, 100, 10)
	var enemy := Combatant.new("e1", "Imp",  Combatant.Faction.ENEMY,  25, 12)
	hero.position  = Vector2i(0, 0)
	enemy.position = Vector2i(3, 0)
	engine.setup([hero, enemy])
	var ok: bool = engine.perform_move(hero, Vector2i(1, 0))
	assert_true(ok, "perform_move returns true on valid move")
	assert_eq(hero.position, Vector2i(1, 0), "Hero position updated after move")

func test_perform_move_rejects_illegal() -> void:
	var rng := _make_rng()
	var engine := BattleEngine.new(rng)
	var hero  := Combatant.new("h",  "Hero", Combatant.Faction.HERO, 100, 10)
	var enemy := Combatant.new("e1", "Imp",  Combatant.Faction.ENEMY,  25, 12)
	hero.position  = Vector2i(0, 0)
	enemy.position = Vector2i(1, 0)
	engine.setup([hero, enemy])
	var ok: bool = engine.perform_move(hero, Vector2i(1, 0))
	assert_true(not ok, "perform_move returns false when hex is occupied")
	assert_eq(hero.position, Vector2i(0, 0), "Hero position unchanged after failed move")

## ─── Status helpers ───────────────────────────────────────────────────────────

func test_has_status_true() -> void:
	var c := Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	c.apply_status(StatusEffect.burning())
	assert_true(c.has_status("burning"), "has_status returns true for applied status")

func test_has_status_false() -> void:
	var c := Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	assert_true(not c.has_status("burning"), "has_status returns false for absent status")

func test_consume_status_removes() -> void:
	var c := Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	c.apply_status(StatusEffect.burning())
	var removed: bool = c.consume_status("burning")
	assert_true(removed, "consume_status returns true when found")
	assert_true(not c.has_status("burning"), "Status gone after consume")

func test_consume_status_missing_returns_false() -> void:
	var c := Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	var removed: bool = c.consume_status("burning")
	assert_true(not removed, "consume_status returns false when not present")

## ─── Vanish ───────────────────────────────────────────────────────────────────

func test_vanish_persists_through_tick() -> void:
	var c := Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	c.apply_status(StatusEffect.vanish())
	c.tick_statuses()
	assert_true(c.has_status("vanish"), "Vanish (no_tick=true) persists through tick_statuses")

func test_vanish_consumed_by_attack() -> void:
	var rng := _make_rng(100)
	var engine := BattleEngine.new(rng)
	var hero  := Combatant.new("h",  "Hero",  Combatant.Faction.HERO,  100, 10)
	var enemy := Combatant.new("e1", "Enemy", Combatant.Faction.ENEMY, 500, 8)
	hero.position  = Vector2i(0, 0)
	enemy.position = Vector2i(1, 0)
	enemy.armor    = 0
	engine.setup([hero, enemy])
	hero.apply_status(StatusEffect.vanish())
	assert_true(hero.has_status("vanish"), "Vanish present before attack")
	engine.perform_attack(hero, enemy, "basic_attack")
	assert_true(not hero.has_status("vanish"), "Vanish consumed after attack")

func test_vanish_triples_damage() -> void:
	## Compare damage with and without vanish (same RNG seed, high-HP enemy).
	var rng_base := _make_rng(999)
	var engine_base := BattleEngine.new(rng_base)
	var hero_base  := Combatant.new("h",  "Hero",  Combatant.Faction.HERO,  100, 10)
	var enemy_base := Combatant.new("e1", "Enemy", Combatant.Faction.ENEMY, 1000, 8)
	hero_base.position  = Vector2i(0, 0)
	enemy_base.position = Vector2i(1, 0)
	hero_base.attack_bonus = 0
	enemy_base.armor       = 0
	engine_base.setup([hero_base, enemy_base])
	var normal_dmg: int = engine_base.perform_attack(hero_base, enemy_base, "basic_attack")

	var rng_van := _make_rng(999)
	var engine_van := BattleEngine.new(rng_van)
	var hero_van  := Combatant.new("h2", "Hero",  Combatant.Faction.HERO,  100, 10)
	var enemy_van := Combatant.new("e2", "Enemy", Combatant.Faction.ENEMY, 1000, 8)
	hero_van.position  = Vector2i(0, 0)
	enemy_van.position = Vector2i(1, 0)
	hero_van.attack_bonus = 0
	enemy_van.armor       = 0
	engine_van.setup([hero_van, enemy_van])
	hero_van.apply_status(StatusEffect.vanish())
	var vanish_dmg: int = engine_van.perform_attack(hero_van, enemy_van, "basic_attack")

	assert_true(vanish_dmg > normal_dmg * 2,
		"Vanish deals significantly more damage (%d vs %d)" % [vanish_dmg, normal_dmg])

## ─── Frozen skip-turn ─────────────────────────────────────────────────────────

func test_frozen_enemy_skips_turn() -> void:
	var rng := _make_rng()
	var engine := BattleEngine.new(rng)
	var hero  := Combatant.new("h",  "Hero", Combatant.Faction.HERO,  100, 5)
	var enemy := Combatant.new("e1", "Imp",  Combatant.Faction.ENEMY,  50, 15)
	hero.position  = Vector2i(0, 0)
	enemy.position = Vector2i(1, 0)
	enemy.speed    = 15  # Enemy would normally go first
	hero.speed     = 5
	enemy.apply_status(StatusEffect.frozen(2))
	engine.setup([hero, enemy])

	var active := engine.begin_turn()
	assert_true(active != null, "Got an active combatant")
	assert_true(active.faction == Combatant.Faction.HERO,
		"Frozen enemy skipped; hero gets the turn (speed 5 < enemy 15)")

func test_frozen_status_decrements_on_skip() -> void:
	var rng := _make_rng()
	var engine := BattleEngine.new(rng)
	var hero  := Combatant.new("h",  "Hero", Combatant.Faction.HERO,  100, 5)
	var enemy := Combatant.new("e1", "Imp",  Combatant.Faction.ENEMY,  50, 15)
	hero.position  = Vector2i(0, 0)
	enemy.position = Vector2i(1, 0)
	enemy.apply_status(StatusEffect.frozen(1))
	engine.setup([hero, enemy])

	engine.begin_turn()  # hero gets turn (enemy skipped)
	# Frozen duration was 1; after skip-tick it should be gone
	assert_true(not enemy.has_skip_turn(),
		"Frozen status expired after one skip (duration=1)")

## ─── AI movement ──────────────────────────────────────────────────────────────

func test_enemy_moves_toward_hero() -> void:
	var rng := _make_rng()
	var engine := BattleEngine.new(rng)
	var hero  := Combatant.new("h",  "Hero", Combatant.Faction.HERO,  100, 5)
	var enemy := Combatant.new("e1", "Imp",  Combatant.Faction.ENEMY,  50, 15)
	hero.position  = Vector2i(0, 0)
	enemy.position = Vector2i(4, 0)  # Far from hero — beyond attack range
	enemy.ai_behavior = "rush"
	engine.setup([hero, enemy])

	var dist_before: int = HexGrid.hex_distance(enemy.position, hero.position)
	engine.enemy_ai_action(enemy)
	var dist_after: int = HexGrid.hex_distance(enemy.position, hero.position)
	assert_true(dist_after < dist_before,
		"Rush enemy moved closer to hero (%d → %d)" % [dist_before, dist_after])

func test_ranged_enemy_retreats_when_adjacent() -> void:
	var rng := _make_rng(77)
	var engine := BattleEngine.new(rng)
	var hero  := Combatant.new("h",  "Hero",      Combatant.Faction.HERO,  100, 5)
	var enemy := Combatant.new("e1", "Lava Golem", Combatant.Faction.ENEMY, 90,  5)
	hero.position  = Vector2i(0, 0)
	enemy.position = Vector2i(1, 0)  # Adjacent — golem should retreat
	enemy.ai_behavior = "ranged"
	var raw: Array[String] = ["enemy_fireball"]
	enemy.abilities = raw
	engine.setup([hero, enemy])

	var before: Vector2i = enemy.position
	engine.enemy_ai_action(enemy)
	var dist_after: int = HexGrid.hex_distance(enemy.position, hero.position)
	assert_true(dist_after > 1 or enemy.position != before,
		"Ranged enemy tried to retreat from adjacent hero")

## ─── Ignore-armor flag ────────────────────────────────────────────────────────

func test_backstab_ignores_armor() -> void:
	var rng := _make_rng(55)
	var engine := BattleEngine.new(rng)
	var hero  := Combatant.new("h",  "Hero",  Combatant.Faction.HERO,  100, 10)
	var enemy := Combatant.new("e1", "Enemy", Combatant.Faction.ENEMY, 200, 8)
	hero.position  = Vector2i(0, 0)
	enemy.position = Vector2i(1, 0)
	enemy.armor    = 20  # High armor
	engine.setup([hero, enemy])
	var dmg: int = engine.perform_attack(hero, enemy, "backstab")
	## backstab base_damage = 35; with armor 20 it should still deal > 1 via ignore_armor
	assert_true(dmg > 10,
		"Backstab ignores armor; dealt %d to armor-20 enemy" % dmg)
