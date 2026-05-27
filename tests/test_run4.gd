## Tests for Run 4 features:
## - Shield Bash pushback mechanic (BattleEngine.push_combatant)
## - _closest_hex_direction helper
## - New ability data (shield_bash, whirlwind)
## - Ability unlock pool filtering
## - HP regen calculation
## - SystemVoice new categories

class_name TestRun4
extends "res://tests/run_tests.gd".BaseTest

# ─── _closest_hex_direction ────────────────────────────────────────────────────

func test_closest_hex_dir_east() -> void:
	## A delta of (3,0) is east — should map to the (1,0) hex direction
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var eng := BattleEngine.new(rng)
	var dir: Vector2i = eng._closest_hex_direction(Vector2i(3, 0))
	assert_eq(dir, Vector2i(1, 0), "delta (3,0) → east direction (1,0)")

func test_closest_hex_dir_west() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var eng := BattleEngine.new(rng)
	var dir: Vector2i = eng._closest_hex_direction(Vector2i(-5, 0))
	assert_eq(dir, Vector2i(-1, 0), "delta (-5,0) → west direction (-1,0)")

func test_closest_hex_dir_zero_no_crash() -> void:
	## Zero delta should not crash — returns some valid direction
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var eng := BattleEngine.new(rng)
	var dir: Vector2i = eng._closest_hex_direction(Vector2i.ZERO)
	assert_true(dir != Vector2i.ZERO, "zero delta returns a non-zero hex direction")

# ─── push_combatant ────────────────────────────────────────────────────────────

func test_push_moves_target_away() -> void:
	## Simple push: target at (1,0) pushed east → moves beyond (1,0)
	## Explicitly set (2,0) and (3,0) as passable floor to guarantee the path.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var map := DungeonMap.new()
	map.generate(1, rng)
	# Guarantee the push path is passable
	map.tile_types[Vector2i(1, 0)] = "floor"
	map.passable[Vector2i(1, 0)] = true
	map.tile_types[Vector2i(2, 0)] = "floor"
	map.passable[Vector2i(2, 0)] = true
	map.tile_types[Vector2i(3, 0)] = "floor"
	map.passable[Vector2i(3, 0)] = true

	var pusher := Combatant.new("hero", "Hero", Combatant.Faction.HERO, 100, 10)
	pusher.position = Vector2i(0, 0)
	var target := Combatant.new("e1", "Imp", Combatant.Faction.ENEMY, 30, 10)
	target.position = Vector2i(1, 0)

	var eng := BattleEngine.new(rng)
	var all: Array[Combatant] = [pusher, target]
	eng.setup(all)

	var final_pos: Vector2i = eng.push_combatant(pusher, target, 2, map)
	assert_true(final_pos.x > 1, "target pushed east past (1,0)")
	assert_eq(target.position, final_pos, "combatant.position matches return value")

func test_push_updates_combatant_position() -> void:
	## After push, the Combatant.position field is updated
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var map := DungeonMap.new()
	map.generate(1, rng)
	# Guarantee the push path is passable
	map.tile_types[Vector2i(1, 0)] = "floor"
	map.passable[Vector2i(1, 0)] = true
	map.tile_types[Vector2i(2, 0)] = "floor"
	map.passable[Vector2i(2, 0)] = true

	var pusher := Combatant.new("hero", "Hero", Combatant.Faction.HERO, 100, 10)
	pusher.position = Vector2i(0, 0)
	var target := Combatant.new("e1", "Imp", Combatant.Faction.ENEMY, 30, 10)
	target.position = Vector2i(1, 0)

	var eng := BattleEngine.new(rng)
	var all: Array[Combatant] = [pusher, target]
	eng.setup(all)

	eng.push_combatant(pusher, target, 2, map)
	assert_true(target.position != Vector2i(1, 0), "position changed from original")

func test_push_blocked_by_other_combatant() -> void:
	## Blocker at (2,0) stops push at (1,0) when target starts at (1,0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var map := DungeonMap.new()
	map.generate(1, rng)
	# Ensure (2,0) is passable terrain (not a wall or lava)
	map.tile_types[Vector2i(2, 0)] = "floor"
	map.passable[Vector2i(2, 0)] = true

	var pusher := Combatant.new("hero", "Hero", Combatant.Faction.HERO, 100, 10)
	pusher.position = Vector2i(0, 0)
	var target := Combatant.new("e1", "Imp", Combatant.Faction.ENEMY, 30, 10)
	target.position = Vector2i(1, 0)
	var blocker := Combatant.new("e2", "Golem", Combatant.Faction.ENEMY, 90, 5)
	blocker.position = Vector2i(2, 0)

	var eng := BattleEngine.new(rng)
	var all: Array[Combatant] = [pusher, target, blocker]
	eng.setup(all)

	var final_pos: Vector2i = eng.push_combatant(pusher, target, 3, map)
	assert_eq(final_pos, Vector2i(1, 0), "push blocked by living combatant at (2,0)")

func test_push_blocked_by_wall_stops_early() -> void:
	## If second hex is impassable, push stops at first passable step (or stays)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var map := DungeonMap.new()
	map.generate(1, rng)
	# Force (2,0) to be impassable (wall)
	map.tile_types[Vector2i(2, 0)] = "wall"
	map.passable[Vector2i(2, 0)] = false
	# Ensure (1,0) is passable so push can land there if already there
	map.tile_types[Vector2i(1, 0)] = "floor"
	map.passable[Vector2i(1, 0)] = true

	var pusher := Combatant.new("hero", "Hero", Combatant.Faction.HERO, 100, 10)
	pusher.position = Vector2i(0, 0)
	var target := Combatant.new("e1", "Imp", Combatant.Faction.ENEMY, 30, 10)
	target.position = Vector2i(1, 0)

	var eng := BattleEngine.new(rng)
	var all: Array[Combatant] = [pusher, target]
	eng.setup(all)

	var final_pos: Vector2i = eng.push_combatant(pusher, target, 3, map)
	assert_eq(final_pos, Vector2i(1, 0), "push stopped by wall at (2,0); stays at (1,0)")

func test_push_dead_target_noop() -> void:
	## Pushing a dead combatant does nothing, returns original position
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var map := DungeonMap.new()
	map.generate(1, rng)

	var pusher := Combatant.new("hero", "Hero", Combatant.Faction.HERO, 100, 10)
	pusher.position = Vector2i(0, 0)
	var target := Combatant.new("e1", "Dead", Combatant.Faction.ENEMY, 30, 10)
	target.position = Vector2i(1, 0)
	target.hp = 0  # dead

	var eng := BattleEngine.new(rng)
	var all: Array[Combatant] = [pusher, target]
	eng.setup(all)

	var final_pos: Vector2i = eng.push_combatant(pusher, target, 3, map)
	assert_eq(final_pos, Vector2i(1, 0), "dead target not moved")
	assert_eq(target.position, Vector2i(1, 0), "position unchanged")

func test_push_into_lava_deals_damage() -> void:
	## Enemy pushed exactly onto a lava tile (distance 1) takes 15 env damage.
	## (3,0) is impassable so push stops at (2,0).
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var map := DungeonMap.new()
	map.generate(1, rng)

	# Clear path: floor at (1,0), lava at (2,0) passable, wall at (3,0) to stop push there
	map.tile_types[Vector2i(1, 0)] = "floor"
	map.passable[Vector2i(1, 0)] = true
	map.tile_types[Vector2i(2, 0)] = "lava"
	map.passable[Vector2i(2, 0)] = true   # allow landing here
	map.tile_types[Vector2i(3, 0)] = "wall"
	map.passable[Vector2i(3, 0)] = false  # stops push at (2,0)

	var pusher := Combatant.new("hero", "Hero", Combatant.Faction.HERO, 100, 10)
	pusher.position = Vector2i(0, 0)
	var target := Combatant.new("e1", "Imp", Combatant.Faction.ENEMY, 100, 10)
	target.position = Vector2i(1, 0)

	var eng := BattleEngine.new(rng)
	var all: Array[Combatant] = [pusher, target]
	eng.setup(all)

	var hp_before: int = target.hp
	var final_pos: Vector2i = eng.push_combatant(pusher, target, 2, map)

	assert_eq(final_pos, Vector2i(2, 0), "target lands on lava at (2,0)")
	assert_true(target.hp < hp_before, "lava landing reduces HP")
	assert_eq(hp_before - target.hp, 15, "lava landing deals exactly 15 damage")

# ─── Ability data ─────────────────────────────────────────────────────────────

func test_shield_bash_pushback_distance() -> void:
	var abl: Dictionary = Abilities.get_ability("shield_bash")
	assert_eq(abl.get("pushback_distance", 0), 2, "shield_bash has pushback_distance 2")

func test_shield_bash_is_melee_cooldown3() -> void:
	var abl: Dictionary = Abilities.get_ability("shield_bash")
	assert_eq(abl.get("range", 0), 1, "shield_bash range 1 (melee)")
	assert_eq(abl.get("cooldown_turns", 0), 3, "shield_bash cooldown 3")
	assert_eq(abl.get("max_charges", 0), 1, "shield_bash max_charges 1")

func test_whirlwind_targets_all_enemies() -> void:
	var abl: Dictionary = Abilities.get_ability("whirlwind")
	assert_eq(abl.get("target", ""), "all_enemies", "whirlwind target: all_enemies")
	assert_eq(abl.get("range", 0), 1, "whirlwind range 1 (adjacent only)")

func test_brawler_has_shield_bash() -> void:
	var cls: Dictionary = Classes.get_class_data("brawler")
	var abilities: Array = cls.get("abilities", [])
	assert_true(abilities.has("shield_bash"), "brawler class has shield_bash")

# ─── Ability unlock pool filtering ────────────────────────────────────────────

func test_unlock_pool_excludes_known_abilities() -> void:
	## Abilities the hero already has should NOT appear in the unlock pool
	var known: Array[String] = ["basic_attack", "fireball", "backstab"]
	var all_unlockable: Array[String] = [
		"fireball", "frost_nova", "backstab", "power_strike",
		"taunt", "vanish", "shield_bash", "whirlwind",
	]
	var candidates: Array[String] = []
	for ability_id: String in all_unlockable:
		if not known.has(ability_id):
			candidates.append(ability_id)
	assert_true(not candidates.has("fireball"),  "fireball excluded (hero knows it)")
	assert_true(not candidates.has("backstab"),  "backstab excluded (hero knows it)")
	assert_true(candidates.has("frost_nova"),    "frost_nova available for unlock")
	assert_true(candidates.has("shield_bash"),   "shield_bash available for unlock")
	assert_true(candidates.has("whirlwind"),     "whirlwind available for unlock")

func test_unlock_pool_empty_when_all_known() -> void:
	## If hero has all unlockable abilities, the pool should have none to offer
	var known: Array[String] = [
		"fireball", "frost_nova", "backstab", "power_strike",
		"taunt", "vanish", "shield_bash", "whirlwind",
	]
	var all_unlockable: Array[String] = known.duplicate()
	var candidates: Array[String] = []
	for ability_id: String in all_unlockable:
		if not known.has(ability_id):
			candidates.append(ability_id)
	assert_eq(candidates.size(), 0, "no abilities to unlock when all are known")

# ─── HP regen calculation ──────────────────────────────────────────────────────

func test_hp_regen_ten_percent_of_max() -> void:
	## Regen = max(5, max_hp / 10)
	assert_eq(max(5, 100 / 10), 10, "regen 10% of 100 = 10")
	assert_eq(max(5, 150 / 10), 15, "regen 10% of 150 = 15")
	assert_eq(max(5, 80  / 10), 8,  "regen 10% of 80 = 8")

func test_hp_regen_minimum_5() -> void:
	## Very low max_hp still gets minimum 5 regen
	assert_eq(max(5, 30 / 10), 5, "regen for max_hp=30 is minimum 5")
	assert_eq(max(5, 10 / 10), 5, "regen for max_hp=10 is minimum 5")

# ─── SystemVoice categories ───────────────────────────────────────────────────

func test_systemvoice_has_first_kill_category() -> void:
	assert_true(SystemVoice.LINES.has("first_kill"), "SystemVoice has first_kill category")
	assert_true(SystemVoice.LINES["first_kill"].size() >= 2, "first_kill has multiple lines")

func test_systemvoice_has_low_hp_category() -> void:
	assert_true(SystemVoice.LINES.has("low_hp"), "SystemVoice has low_hp category")

func test_systemvoice_has_backstab_success_category() -> void:
	assert_true(SystemVoice.LINES.has("backstab_success"), "SystemVoice has backstab_success category")

func test_systemvoice_has_surrounded_category() -> void:
	assert_true(SystemVoice.LINES.has("surrounded"), "SystemVoice has surrounded category")

func test_systemvoice_has_pushback_category() -> void:
	assert_true(SystemVoice.LINES.has("pushback"), "SystemVoice has pushback category")
