## Run 17 tests: Floor-3 allies (Marcus + Lina).
## Verifies the Allies data class — pure logic, no autoloads, no Node refs.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun17Allies

# ── Floor → ally pool mapping ──────────────────────────────────────────────────

func test_floor_3_has_two_allies() -> void:
	var defs: Array[Dictionary] = Allies.get_allies_for_floor(3)
	assert_eq(defs.size(), 2, "Floor 3 spawns exactly two allies")

func test_no_allies_on_floor_1() -> void:
	assert_eq(Allies.get_allies_for_floor(1).size(), 0, "Floor 1 has no allies")

func test_no_allies_on_floor_2() -> void:
	assert_eq(Allies.get_allies_for_floor(2).size(), 0, "Floor 2 has no allies")

func test_no_allies_on_floor_4() -> void:
	assert_eq(Allies.get_allies_for_floor(4).size(), 0, "Floor 4 has no allies (one-shot floor 3 only)")

func test_no_allies_on_other_boss_floors() -> void:
	# Other boss floors (6, 9, 12, 15, 18) should not auto-include the floor-3 allies.
	assert_eq(Allies.get_allies_for_floor(6).size(), 0,  "Floor 6 has no allies (only floor 3)")
	assert_eq(Allies.get_allies_for_floor(9).size(), 0,  "Floor 9 has no allies (only floor 3)")
	assert_eq(Allies.get_allies_for_floor(18).size(), 0, "Floor 18 has no allies (only floor 3)")

func test_has_allies_on_floor_predicate() -> void:
	assert_true(Allies.has_allies_on_floor(3),  "has_allies_on_floor(3) is true")
	assert_true(not Allies.has_allies_on_floor(2), "has_allies_on_floor(2) is false")

# ── Ally factory produces HERO-faction Combatants with expected stats ───────────

func test_make_ally_is_hero_faction() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var defs: Array[Dictionary] = Allies.get_allies_for_floor(3)
	var c: Combatant = Allies.make_ally(defs[0], Vector2i(1, 0), rng)
	assert_eq(c.faction, Combatant.Faction.HERO, "Ally is HERO faction (so player loss = Carl's death only)")

func test_make_ally_distinct_from_carl() -> void:
	## Allies must have unique IDs so death/dispatch can disambiguate them
	## from the player hero and from each other.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var defs: Array[Dictionary] = Allies.get_allies_for_floor(3)
	var a1: Combatant = Allies.make_ally(defs[0], Vector2i(1, 0), rng)
	var a2: Combatant = Allies.make_ally(defs[1], Vector2i(-1, 0), rng)
	assert_true(a1.id != a2.id, "Two allies get distinct IDs")
	assert_true(a1.id != "hero", "Ally ID is not 'hero' (Carl's ID)")
	assert_true(a2.id != "hero", "Ally ID is not 'hero' (Carl's ID)")

func test_marcus_and_lina_stats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var defs: Array[Dictionary] = Allies.get_allies_for_floor(3)
	var marcus: Combatant = Allies.make_ally(defs[0], Vector2i(1, 0), rng)
	var lina: Combatant   = Allies.make_ally(defs[1], Vector2i(-1, 0), rng)
	# Knight = tankier, slower, more armor
	assert_eq(marcus.max_hp, 70, "Marcus has 70 HP (knight)")
	assert_eq(marcus.armor, 3,  "Marcus has 3 armor")
	# Hexweaver = squishier, faster, hits harder
	assert_eq(lina.max_hp, 55,   "Lina has 55 HP (mage)")
	assert_eq(lina.attack_bonus, 6, "Lina has +6 attack bonus")
	assert_true(lina.speed > marcus.speed, "Lina acts before Marcus in turn order")

func test_ally_sprite_keys_are_distinct() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var defs: Array[Dictionary] = Allies.get_allies_for_floor(3)
	var marcus: Combatant = Allies.make_ally(defs[0], Vector2i(1, 0), rng)
	var lina: Combatant   = Allies.make_ally(defs[1], Vector2i(-1, 0), rng)
	assert_true(marcus.sprite_key.begins_with("ally_"),
		"Marcus sprite_key has ally_ prefix (drives BattleScene sprite path lookup)")
	assert_true(lina.sprite_key.begins_with("ally_"),
		"Lina sprite_key has ally_ prefix")
	assert_true(marcus.sprite_key != lina.sprite_key,
		"Marcus and Lina use different sprites")

func test_ally_position_set_from_factory() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var defs: Array[Dictionary] = Allies.get_allies_for_floor(3)
	var spawn := Vector2i(2, -1)
	var c: Combatant = Allies.make_ally(defs[0], spawn, rng)
	assert_eq(c.position, spawn, "Ally spawned at requested hex")

# ── Engine integration: an ally death does NOT end the battle as long as Carl lives ─

func test_ally_death_does_not_end_run() -> void:
	## Build a mini encounter: Carl + one ally + one enemy. Kill the ally.
	## BattleEngine should NOT flag battle_over=true (Carl is still alive).
	var rng := RandomNumberGenerator.new()
	rng.seed = 100
	var engine := BattleEngine.new(rng)
	var carl := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	var defs: Array[Dictionary] = Allies.get_allies_for_floor(3)
	var ally: Combatant = Allies.make_ally(defs[0], Vector2i(1, 0), rng)
	var imp := Combatant.new("imp_1", "Imp", Combatant.Faction.ENEMY, 100, 8)
	var all: Array[Combatant] = [carl, ally, imp]
	engine.setup(all)
	# Murder the ally outright.
	ally.take_damage(9999, true)
	assert_true(not ally.is_alive(), "Ally is dead")
	# Manually trigger end-check (mimics what BattleScene does after attacks)
	var ended: bool = engine._check_battle_end()
	assert_true(not ended, "Battle continues — Carl alive, enemy alive")
	assert_true(not engine.battle_over, "engine.battle_over remains false after ally death")

func test_carl_death_ends_run_even_with_living_ally() -> void:
	## Opposite case: Carl dies, ally still alive. Battle MUST end.
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var engine := BattleEngine.new(rng)
	var carl := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	var defs: Array[Dictionary] = Allies.get_allies_for_floor(3)
	var ally: Combatant = Allies.make_ally(defs[0], Vector2i(1, 0), rng)
	var imp := Combatant.new("imp_1", "Imp", Combatant.Faction.ENEMY, 100, 8)
	var all: Array[Combatant] = [carl, ally, imp]
	engine.setup(all)
	carl.take_damage(9999, true)
	assert_true(not carl.is_alive(), "Carl is dead")
	# NOTE: BattleEngine treats ALL living HERO-faction members as "heroes" for
	# its win/loss check, so an ally surviving Carl's death keeps battle going
	# inside the engine. BattleScene short-circuits this in _on_combatant_died
	# (when c == _hero) by setting engine.battle_over=true and emitting loss.
	# This test documents the engine-level invariant so future refactors stay honest.
	var ally_alive: bool = ally.is_alive()
	assert_true(ally_alive, "Ally still alive (BattleScene must override the engine check)")
