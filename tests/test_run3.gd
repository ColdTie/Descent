## Run 3 feature tests:
## - Ability charges / cooldown (Ability.gd)
## - Enemy collision avoidance (BattleEngine._move_toward)
## - Floor-based enemy stat scaling (EnemyDefs.make_combatant)
## - Ability.charge_display() formatting

class_name TestRun3
extends "res://tests/run_tests.gd".BaseTest

# ── Ability: unlimited charges ────────────────────────────────────────────────

func test_ability_unlimited_always_usable() -> void:
	var a := Ability.new("basic_attack", "Basic Attack")
	a.max_charges = -1
	a.cooldown_turns = 0
	assert_true(a.can_use(), "Unlimited ability always usable")

func test_ability_unlimited_use_returns_true() -> void:
	var a := Ability.new("basic_attack", "Basic Attack")
	a.max_charges = -1
	assert_true(a.use(), "Unlimited ability use() returns true")

func test_ability_unlimited_charges_unchanged_after_use() -> void:
	var a := Ability.new("basic_attack", "Basic Attack")
	a.max_charges = -1
	a.current_charges = -1  # sentinel
	a.use()
	assert_eq(a.current_charges, -1, "Unlimited: current_charges unchanged after use")

# ── Ability: finite charges ────────────────────────────────────────────────────

func test_ability_one_charge_usable() -> void:
	var a := Ability.new("fireball", "Fireball")
	a.max_charges = 1
	a.current_charges = 1
	a.cooldown_turns = 4
	assert_true(a.can_use(), "1-charge ability can use when charge available")

func test_ability_zero_charges_not_usable() -> void:
	var a := Ability.new("fireball", "Fireball")
	a.max_charges = 1
	a.current_charges = 0
	a.cooldown_remaining = 4
	assert_true(not a.can_use(), "0-charge ability cannot be used")

func test_ability_use_decrements_charge() -> void:
	var a := Ability.new("power_strike", "Power Strike")
	a.max_charges = 2
	a.current_charges = 2
	a.cooldown_turns = 3
	a.use()
	assert_eq(a.current_charges, 1, "Charge decremented after use")

func test_ability_use_triggers_cooldown_on_empty() -> void:
	var a := Ability.new("fireball", "Fireball")
	a.max_charges = 1
	a.current_charges = 1
	a.cooldown_turns = 4
	a.cooldown_remaining = 0
	a.use()
	assert_eq(a.current_charges, 0, "Charge is 0 after use")
	assert_eq(a.cooldown_remaining, 4, "Cooldown set after charge depleted")

func test_ability_use_fails_when_depleted() -> void:
	var a := Ability.new("fireball", "Fireball")
	a.max_charges = 1
	a.current_charges = 0
	a.cooldown_remaining = 3
	assert_true(not a.use(), "use() returns false when depleted")

# ── Ability: cooldown ticking ─────────────────────────────────────────────────

func test_ability_cooldown_ticks_down() -> void:
	var a := Ability.new("fireball", "Fireball")
	a.max_charges = 1
	a.current_charges = 0
	a.cooldown_turns = 4
	a.cooldown_remaining = 3
	a.tick_cooldown()
	assert_eq(a.cooldown_remaining, 2, "Cooldown decrements each tick")

func test_ability_recharges_when_cooldown_hits_zero() -> void:
	var a := Ability.new("fireball", "Fireball")
	a.max_charges = 1
	a.current_charges = 0
	a.cooldown_remaining = 1
	a.tick_cooldown()
	assert_eq(a.cooldown_remaining, 0, "Cooldown hits 0")
	assert_eq(a.current_charges, 1, "Charge restored when cooldown expires")

func test_ability_recharge_full() -> void:
	var a := Ability.new("power_strike", "Power Strike")
	a.max_charges = 2
	a.current_charges = 0
	a.cooldown_remaining = 5
	a.recharge_full()
	assert_eq(a.current_charges, 2, "recharge_full restores all charges")
	assert_eq(a.cooldown_remaining, 0, "recharge_full clears cooldown")

func test_ability_unlimited_recharge_full_safe() -> void:
	var a := Ability.new("basic_attack", "Basic Attack")
	a.max_charges = -1
	a.recharge_full()
	assert_eq(a.cooldown_remaining, 0, "Unlimited: recharge_full clears cooldown safely")

# ── Ability: charge_display ───────────────────────────────────────────────────

func test_charge_display_unlimited() -> void:
	var a := Ability.new("basic_attack", "Basic")
	a.max_charges = -1
	assert_eq(a.charge_display(), "∞", "Unlimited shows ∞")

func test_charge_display_on_cooldown() -> void:
	var a := Ability.new("fireball", "Fireball")
	a.max_charges = 1
	a.current_charges = 0
	a.cooldown_remaining = 3
	assert_eq(a.charge_display(), "⏳3", "Cooldown shows ⏳N")

func test_charge_display_full_charge() -> void:
	var a := Ability.new("power_strike", "Power")
	a.max_charges = 2
	a.current_charges = 2
	a.cooldown_remaining = 0
	assert_eq(a.charge_display(), "●●", "Full charges shows filled dots")

func test_charge_display_partial_charge() -> void:
	var a := Ability.new("power_strike", "Power")
	a.max_charges = 2
	a.current_charges = 1
	a.cooldown_remaining = 0
	assert_eq(a.charge_display(), "●○", "Partial charges shows mixed dots")

# ── Enemy collision avoidance ─────────────────────────────────────────────────

func test_enemy_no_stack_on_occupied_hex() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)

	# Two enemies: one blocking the path
	var blocker := Combatant.new("e_block", "Blocker", Combatant.Faction.ENEMY, 50, 8)
	blocker.sprite_key = "goblin"
	blocker.position = Vector2i(1, 0)  # directly between mover and hero

	var mover := Combatant.new("e_move", "Mover", Combatant.Faction.ENEMY, 50, 6)
	mover.sprite_key = "goblin"
	mover.position = Vector2i(2, 0)  # wants to move to (1,0) but it's occupied

	var ea: Array[String] = ["basic_attack"]
	blocker.abilities = ea
	mover.abilities = ea

	var all: Array[Combatant] = [hero, blocker, mover]
	engine.setup(all)

	# Generate a map that makes (1,0) passable
	var map := DungeonMap.new()
	var map_rng := RandomNumberGenerator.new()
	map_rng.seed = 1
	map.generate(1, map_rng)
	# Force (1,0) to be passable (it's within the disk)
	map.passable[Vector2i(1, 0)] = true
	map.tile_types[Vector2i(1, 0)] = "floor"
	map.passable[Vector2i(2, 0)] = true
	map.tile_types[Vector2i(2, 0)] = "floor"

	var pos_before: Vector2i = mover.position
	engine.enemy_ai_action(mover, map)

	# Mover should NOT be at (1,0) — it's occupied by blocker
	assert_true(mover.position != blocker.position,
		"Mover did not stack on blocker's hex (was %s, blocker at %s)" % [str(mover.position), str(blocker.position)])

func test_enemy_moves_when_path_clear() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 10
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy := Combatant.new("e1", "Imp", Combatant.Faction.ENEMY, 50, 8)
	enemy.sprite_key = "imp"
	enemy.position = Vector2i(3, 0)
	var ea: Array[String] = ["enemy_claw"]
	enemy.abilities = ea
	var all: Array[Combatant] = [hero, enemy]
	engine.setup(all)

	var map := DungeonMap.new()
	var map_rng := RandomNumberGenerator.new()
	map_rng.seed = 2
	map.generate(1, map_rng)
	# Ensure the path is clear
	for hx: int in range(-1, 4):
		map.passable[Vector2i(hx, 0)] = true
		map.tile_types[Vector2i(hx, 0)] = "floor"

	var pos_before: Vector2i = enemy.position
	engine.enemy_ai_action(enemy, map)

	assert_true(enemy.position != pos_before, "Imp moves when path is clear")
	assert_true(HexGrid.hex_distance(enemy.position, hero.position) <
		HexGrid.hex_distance(pos_before, hero.position),
		"Imp moved closer to hero")

# ── Floor-based enemy scaling ─────────────────────────────────────────────────

func test_enemy_scales_hp_by_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var imp_def: Dictionary = {
		"id": "imp", "display_name": "Imp",
		"hp": 25, "armor": 0, "speed": 12,
		"abilities": ["enemy_claw"],
		"xp_reward": 20, "sprite_key": "imp", "min_floor": 1
	}
	var imp_floor1: Combatant = EnemyDefs.make_combatant(imp_def, Vector2i.ZERO, rng, 1)
	var imp_floor4: Combatant = EnemyDefs.make_combatant(imp_def, Vector2i.ZERO, rng, 4)
	assert_true(imp_floor4.max_hp > imp_floor1.max_hp,
		"Floor 4 imp has more HP than floor 1 imp (%d > %d)" % [imp_floor4.max_hp, imp_floor1.max_hp])

func test_enemy_scales_xp_by_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var goblin_def: Dictionary = {
		"id": "goblin", "display_name": "Goblin",
		"hp": 35, "armor": 1, "speed": 14,
		"abilities": ["enemy_claw"], "xp_reward": 25, "sprite_key": "goblin", "min_floor": 1
	}
	var g1: Combatant = EnemyDefs.make_combatant(goblin_def, Vector2i.ZERO, rng, 1)
	var g5: Combatant = EnemyDefs.make_combatant(goblin_def, Vector2i.ZERO, rng, 5)
	assert_true(g5.xp_reward > g1.xp_reward,
		"Floor 5 goblin gives more XP than floor 1 (%d > %d)" % [g5.xp_reward, g1.xp_reward])

func test_enemy_scales_attack_by_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var def: Dictionary = {
		"id": "skeleton", "display_name": "Skeleton",
		"hp": 45, "armor": 3, "speed": 8,
		"abilities": ["enemy_claw"], "xp_reward": 30, "sprite_key": "skeleton", "min_floor": 2
	}
	var s2: Combatant = EnemyDefs.make_combatant(def, Vector2i.ZERO, rng, 2)
	var s6: Combatant = EnemyDefs.make_combatant(def, Vector2i.ZERO, rng, 6)
	assert_true(s6.attack_bonus > s2.attack_bonus,
		"Floor 6 skeleton has higher attack_bonus than floor 2 (%d > %d)" % [s6.attack_bonus, s2.attack_bonus])

func test_enemy_floor1_equals_base_hp() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var def: Dictionary = {
		"id": "imp", "display_name": "Imp",
		"hp": 25, "armor": 0, "speed": 12,
		"abilities": ["enemy_claw"], "xp_reward": 20, "sprite_key": "imp", "min_floor": 1
	}
	var imp: Combatant = EnemyDefs.make_combatant(def, Vector2i.ZERO, rng, 1)
	assert_eq(imp.max_hp, 25, "Floor 1 imp spawns with base HP (scale = 0)")
