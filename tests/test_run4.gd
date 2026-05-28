## Tests for Run 4 features:
## - Shield Bash push mechanic (HexGrid push direction + BattleEngine perform_push_attack)
## - Rallied status effect (attack_mod in _calculate_damage)
## - New abilities present in Abilities.DATA
## - War cry / poison blade / chain lightning ability data
## - LevelUp unlock pool logic (pure function test via direct class reference)

class_name TestRun4
extends "res://tests/run_tests.gd".BaseTest

# ─── HexGrid.get_push_direction ──────────────────────────────────────────────

func test_push_direction_adjacent_east() -> void:
	## From (0,0) to (1,0) — east direction (1,0)
	var dir: Vector2i = HexGrid.get_push_direction(Vector2i(0, 0), Vector2i(1, 0))
	assert_eq(dir, Vector2i(1, 0), "East push direction")

func test_push_direction_adjacent_nw() -> void:
	## From (0,0) to (-1,1) — SW direction in axial coords
	var dir: Vector2i = HexGrid.get_push_direction(Vector2i(0, 0), Vector2i(-1, 1))
	assert_eq(dir, Vector2i(-1, 1), "SW push direction")

func test_push_direction_same_hex_zero() -> void:
	## From (0,0) to (0,0) — zero vector (no push)
	var dir: Vector2i = HexGrid.get_push_direction(Vector2i(0, 0), Vector2i(0, 0))
	assert_eq(dir, Vector2i.ZERO, "Same hex = zero push direction")

func test_push_direction_non_adjacent_projects() -> void:
	## From (0,0) to (3,0) — should still return (1,0)
	var dir: Vector2i = HexGrid.get_push_direction(Vector2i(0, 0), Vector2i(3, 0))
	assert_eq(dir, Vector2i(1, 0), "Non-adjacent: projects to east direction")

# ─── BattleEngine.perform_push_attack ────────────────────────────────────────

func _make_push_setup() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var map := DungeonMap.new()
	map.generate(1, rng)

	var attacker := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 150, 10)
	attacker.position = Vector2i(0, 0)
	attacker.attack_bonus = 0

	var target := Combatant.new("e1", "Goblin", Combatant.Faction.ENEMY, 100, 8)
	target.position = Vector2i(1, 0)

	# Place them on passable floor tiles in our test map
	map.tile_types[Vector2i(0, 0)] = "floor"
	map.passable[Vector2i(0, 0)] = true
	map.tile_types[Vector2i(1, 0)] = "floor"
	map.passable[Vector2i(1, 0)] = true
	map.tile_types[Vector2i(2, 0)] = "floor"
	map.passable[Vector2i(2, 0)] = true
	map.tile_types[Vector2i(3, 0)] = "floor"
	map.passable[Vector2i(3, 0)] = true

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var engine := BattleEngine.new(rng2)
	var all: Array[Combatant] = [attacker, target]
	engine.setup(all)

	return {"engine": engine, "attacker": attacker, "target": target, "map": map}

func test_push_moves_target() -> void:
	var s: Dictionary = _make_push_setup()
	var engine: BattleEngine = s["engine"]
	var attacker: Combatant = s["attacker"]
	var target: Combatant = s["target"]
	var map: DungeonMap = s["map"]

	var result: Dictionary = engine.perform_push_attack(attacker, target, "shield_bash", map)
	assert_true(result["pushed_to"].x >= 1, "Target pushed east (x >= 1)")
	assert_eq(target.position, result["pushed_to"], "target.position matches pushed_to")

func test_push_damage_dealt() -> void:
	var s: Dictionary = _make_push_setup()
	var engine: BattleEngine = s["engine"]
	var result: Dictionary = engine.perform_push_attack(
		s["attacker"], s["target"], "shield_bash", s["map"]
	)
	assert_true(result["damage"] > 0, "Push attack dealt positive damage (got %d)" % result["damage"])
	assert_true(s["target"].hp < 100, "Target HP reduced")

func test_push_blocked_by_combatant() -> void:
	## Put a second enemy at (2,0) — target at (1,0) cannot be pushed past it.
	var s: Dictionary = _make_push_setup()
	var engine: BattleEngine = s["engine"]
	var blocker := Combatant.new("e2", "Blocker", Combatant.Faction.ENEMY, 50, 8)
	blocker.position = Vector2i(2, 0)
	engine.combatants.append(blocker)

	var result: Dictionary = engine.perform_push_attack(
		s["attacker"], s["target"], "shield_bash", s["map"]
	)
	## Target stays at (1,0) because (2,0) is occupied
	assert_eq(result["pushed_to"], Vector2i(1, 0), "Blocked by combatant at (2,0)")

func test_push_lava_bounce_damages() -> void:
	## Put lava at (2,0) — target bounces off, takes fire damage.
	var s: Dictionary = _make_push_setup()
	var engine: BattleEngine = s["engine"]
	var map: DungeonMap = s["map"]
	map.tile_types[Vector2i(2, 0)] = "lava"
	map.passable[Vector2i(2, 0)] = false

	var target_hp_before: int = s["target"].hp
	var result: Dictionary = engine.perform_push_attack(
		s["attacker"], s["target"], "shield_bash", map
	)
	assert_true(result["lava_bounce"], "lava_bounce should be true")
	assert_true(result["lava_damage"] > 0, "lava_damage > 0 (got %d)" % result["lava_damage"])
	# Target should have taken push damage + lava damage
	var total_damage: int = target_hp_before - s["target"].hp
	assert_true(total_damage > result["damage"], "Total damage > push damage (lava applied)")

# ─── Rallied status effect ────────────────────────────────────────────────────

func test_rallied_boosts_attack_damage() -> void:
	## Hero with rallied status should deal more damage than without.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 150, 10)
	hero.attack_bonus = 0
	var target := Combatant.new("e1", "Dummy", Combatant.Faction.ENEMY, 500, 5)
	target.armor = 0

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 77  # same seed for fair comparison
	var engine := BattleEngine.new(rng2)
	var all: Array[Combatant] = [hero, target]
	engine.setup(all)

	# Damage without rallied
	var dmg_base: int = engine.perform_attack(hero, target, "basic_attack")

	# Reset and apply rallied
	target.hp = 500
	hero.apply_status(StatusEffect.rallied(3, 8))
	# Reset rng to same seed for fair comparison
	rng2.seed = 77
	var dmg_rallied: int = engine.perform_attack(hero, target, "basic_attack")

	assert_true(dmg_rallied > dmg_base, "Rallied boosts damage: %d > %d" % [dmg_rallied, dmg_base])

func test_rallied_expires_after_duration() -> void:
	var c := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	c.apply_status(StatusEffect.rallied(2, 8))
	assert_true(c.status_effects.size() == 1, "Rallied applied")
	c.tick_statuses()
	assert_true(c.status_effects.size() == 1, "Rallied still active after 1 tick")
	c.tick_statuses()
	assert_true(c.status_effects.is_empty(), "Rallied expired after 2 ticks")

# ─── New ability data ─────────────────────────────────────────────────────────

func test_shield_bash_in_data() -> void:
	var abl: Dictionary = Abilities.get_ability("shield_bash")
	assert_eq(abl["id"], "shield_bash", "shield_bash exists")
	assert_true(abl.get("pushback", 0) > 0, "shield_bash has pushback > 0")
	assert_eq(abl["range"], 1, "shield_bash is melee range")

func test_war_cry_in_data() -> void:
	var abl: Dictionary = Abilities.get_ability("war_cry")
	assert_eq(abl["id"], "war_cry", "war_cry exists")
	assert_eq(abl.get("target", ""), "self", "war_cry targets self")

func test_poison_blade_in_data() -> void:
	var abl: Dictionary = Abilities.get_ability("poison_blade")
	assert_eq(abl["id"], "poison_blade", "poison_blade exists")
	assert_true(abl.get("applies_poisoned", false), "poison_blade applies poisoned")
	assert_true(abl.get("poison_dpt", 0) > 0, "poison_blade has positive DPT")

func test_chain_lightning_in_data() -> void:
	var abl: Dictionary = Abilities.get_ability("chain_lightning")
	assert_eq(abl["id"], "chain_lightning", "chain_lightning exists")
	assert_true(abl.get("chain_jumps", 0) > 0, "chain_lightning has chain_jumps")
	assert_true(abl["range"] >= 3, "chain_lightning has long range")

# ─── Poison blade status application ─────────────────────────────────────────

func test_poison_blade_applies_poisoned_status() -> void:
	## Simulate what BattleScene does: attack + apply poisoned
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	var target := Combatant.new("e1", "Imp", Combatant.Faction.ENEMY, 100, 8)
	var engine := BattleEngine.new(rng)
	var all: Array[Combatant] = [hero, target]
	engine.setup(all)

	engine.perform_attack(hero, target, "poison_blade")
	var abl_data: Dictionary = Abilities.get_ability("poison_blade")
	if target.is_alive():
		target.apply_status(StatusEffect.poisoned(
			abl_data.get("poison_duration", 5),
			abl_data.get("poison_dpt", 3)
		))
	assert_true(target.status_effects.size() > 0, "Poison status applied")
	var has_poison: bool = false
	for eff: Dictionary in target.status_effects:
		if eff.get("id", "") == "poisoned":
			has_poison = true
	assert_true(has_poison, "Target has 'poisoned' status")
