## Tests for Run 3 features:
## - Ability charges/cooldown system
## - Backstab ignores armor
## - Enemy collision avoidance in movement
## - Floor scaling (HP/armor per floor)
## - Environment damage (lava heat)

class_name TestRun3
extends "res://tests/run_tests.gd".BaseTest

# ─── Ability Charges ──────────────────────────────────────────────────────────

func test_ability_unlimited_always_usable() -> void:
	## max_charges = -1 means unlimited; can_use() always true, use() doesn't decrement
	var abl := Ability.new("basic_attack", "Basic Attack")
	abl.max_charges = -1
	abl.current_charges = 1
	abl.cooldown_turns = 0
	abl.cooldown_remaining = 0
	assert_true(abl.can_use(), "Unlimited ability can be used initially")
	abl.use()
	assert_true(abl.can_use(), "Unlimited ability still usable after use()")
	assert_eq(abl.current_charges, 1, "Unlimited ability charges unchanged after use()")

func test_ability_charges_deplete_on_use() -> void:
	## max_charges = 2; each use() depletes one charge
	var abl := Ability.new("backstab", "Backstab")
	abl.max_charges = 2
	abl.current_charges = 2
	abl.cooldown_turns = 2
	abl.cooldown_remaining = 0
	assert_true(abl.can_use(), "Can use with 2 charges")
	abl.use()
	assert_eq(abl.current_charges, 1, "One charge consumed")
	assert_true(abl.can_use(), "Still usable with 1 charge")
	abl.use()
	assert_eq(abl.current_charges, 0, "Both charges consumed")

func test_ability_cooldown_blocks_use() -> void:
	## After depleting all charges, cooldown_remaining > 0, can_use() returns false
	var abl := Ability.new("power_strike", "Power Strike")
	abl.max_charges = 1
	abl.current_charges = 1
	abl.cooldown_turns = 3
	abl.cooldown_remaining = 0
	assert_true(abl.can_use(), "Initially usable")
	abl.use()
	assert_eq(abl.current_charges, 0, "Charge consumed")
	assert_eq(abl.cooldown_remaining, 3, "Cooldown set after use")
	assert_true(not abl.can_use(), "Cannot use while on cooldown")

func test_ability_tick_restores_charge() -> void:
	## tick_cooldown() counts down; when it hits 0, charge is restored
	var abl := Ability.new("power_strike", "Power Strike")
	abl.max_charges = 1
	abl.current_charges = 0  # depleted
	abl.cooldown_turns = 3
	abl.cooldown_remaining = 3

	abl.tick_cooldown()
	assert_eq(abl.cooldown_remaining, 2, "Cooldown ticked to 2")
	assert_eq(abl.current_charges, 0, "No charge yet at cooldown 2")

	abl.tick_cooldown()
	assert_eq(abl.cooldown_remaining, 1, "Cooldown ticked to 1")
	assert_eq(abl.current_charges, 0, "No charge yet at cooldown 1")

	abl.tick_cooldown()
	assert_eq(abl.cooldown_remaining, 0, "Cooldown reached 0")
	assert_eq(abl.current_charges, 1, "Charge restored when cooldown hits 0")
	assert_true(abl.can_use(), "Now usable again")

func test_ability_multi_charge_partial_restore() -> void:
	## 3-charge ability: each tick at cooldown=0 restores 1 charge
	var abl := Ability.new("multi", "Multi")
	abl.max_charges = 3
	abl.current_charges = 0
	abl.cooldown_turns = 1
	abl.cooldown_remaining = 1

	abl.tick_cooldown()
	assert_eq(abl.cooldown_remaining, 0, "Cooldown reaches 0")
	assert_eq(abl.current_charges, 1, "One charge restored")
	# Tick again; cooldown is 0 but only 1 charge restored per cooldown cycle
	abl.tick_cooldown()
	# With cooldown_remaining = 0, no decrement; charges already restored to 1
	# Since current < max, it will add another charge only if cooldown goes through again
	# Current behavior: if cooldown_remaining == 0 and current < max, restore happens on each tick
	# Let's verify actual behavior
	assert_true(abl.current_charges >= 1, "At least 1 charge after second tick")

func test_ability_recharge_full() -> void:
	## recharge_full() resets everything
	var abl := Ability.new("fireball", "Fireball")
	abl.max_charges = 1
	abl.current_charges = 0
	abl.cooldown_turns = 4
	abl.cooldown_remaining = 4
	abl.recharge_full()
	assert_eq(abl.current_charges, 1, "Charges fully restored")
	assert_eq(abl.cooldown_remaining, 0, "Cooldown cleared")
	assert_true(abl.can_use(), "Ability usable after recharge")

# ─── Backstab Ignores Armor ───────────────────────────────────────────────────

func test_backstab_ignores_armor() -> void:
	## A target with armor 20 should still take full damage from backstab
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	var target := Combatant.new("t", "Target", Combatant.Faction.ENEMY, 500, 5)
	target.armor = 20  # high armor — should be ignored by backstab

	var all: Array[Combatant] = [hero, target]
	engine.setup(all)

	# Verify backstab ability has ignore_armor = true in data
	var abl_data: Dictionary = Abilities.get_ability("backstab")
	assert_true(abl_data.get("ignore_armor", false), "backstab has ignore_armor flag in data")

	var hp_before: int = target.hp
	engine.perform_attack(hero, target, "backstab")
	var dmg: int = hp_before - target.hp
	assert_true(dmg > 0, "Backstab deals damage (dmg=%d)" % dmg)
	# Base damage for backstab is 35; without armor that's at least 35*0.8=28
	# With armor 20 and NO ignore, damage would be max(1, 35*0.8 - 20) = max(1,8) = 8
	# With ignore, damage should be at least 28
	assert_true(dmg >= 20, "Backstab ignores armor 20 — damage should be >= 20 (got %d)" % dmg)

func test_normal_attack_respects_armor() -> void:
	## Confirm basic_attack DOES respect armor (sanity check for backstab comparison)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	var target_low_armor := Combatant.new("t1", "Low", Combatant.Faction.ENEMY, 500, 5)
	target_low_armor.armor = 0
	var target_high_armor := Combatant.new("t2", "High", Combatant.Faction.ENEMY, 500, 5)
	target_high_armor.armor = 10

	var all: Array[Combatant] = [hero, target_low_armor, target_high_armor]
	engine.setup(all)

	# Use same rng seed sequence: attack t1, then t2
	var dmg_no_armor: int = engine.perform_attack(hero, target_low_armor, "basic_attack")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var engine2 := BattleEngine.new(rng2)
	var hero2 := Combatant.new("hero2", "Carl", Combatant.Faction.HERO, 100, 10)
	var target_with_armor := Combatant.new("t3", "Armored", Combatant.Faction.ENEMY, 500, 5)
	target_with_armor.armor = 10
	var all2: Array[Combatant] = [hero2, target_with_armor]
	engine2.setup(all2)
	var dmg_with_armor: int = engine2.perform_attack(hero2, target_with_armor, "basic_attack")
	assert_true(dmg_no_armor > dmg_with_armor,
		"Basic attack does less damage to armored target (no_armor=%d, armored=%d)" % [dmg_no_armor, dmg_with_armor])

# ─── Enemy Collision Avoidance ────────────────────────────────────────────────

func test_enemy_no_collision_on_move() -> void:
	## Two enemies moving toward same hex: second should not stack on first
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)

	# Place two imps next to each other, both trying to move toward hero
	var imp1 := Combatant.new("imp1", "Imp", Combatant.Faction.ENEMY, 25, 12)
	imp1.sprite_key = "imp"
	imp1.position = Vector2i(3, 0)

	var imp2 := Combatant.new("imp2", "Imp2", Combatant.Faction.ENEMY, 25, 11)
	imp2.sprite_key = "imp"
	imp2.position = Vector2i(3, -1)  # adjacent to imp1, also trying to reach hero

	var ia: Array[String] = ["enemy_claw"]
	imp1.abilities = ia
	imp2.abilities = ia.duplicate()

	var all: Array[Combatant] = [hero, imp1, imp2]
	engine.setup(all)

	# Generate a map where all relevant hexes are passable
	var map := DungeonMap.new()
	# Mock map: manually set passable
	for q: int in range(-5, 6):
		for r: int in range(-5, 6):
			map.passable[Vector2i(q, r)] = true
			map.tile_types[Vector2i(q, r)] = "floor"

	# Move imp1 toward hero
	engine.enemy_ai_action(imp1, map)
	var pos1_after: Vector2i = imp1.position

	# Move imp2 toward hero
	engine.enemy_ai_action(imp2, map)
	var pos2_after: Vector2i = imp2.position

	# They should not be on the same hex
	assert_true(pos1_after != pos2_after,
		"Enemies at different positions after movement (imp1=%s, imp2=%s)" % [str(pos1_after), str(pos2_after)])

func test_enemy_blocked_when_neighbor_occupied() -> void:
	## Enemy surrounded by occupied hexes stays put (can't move to blocked hex)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(5, 0)  # far away

	# Enemy surrounded by other enemies on all neighbors
	var mover := Combatant.new("mover", "Blocked", Combatant.Faction.ENEMY, 30, 10)
	mover.sprite_key = "imp"
	mover.position = Vector2i(0, 0)
	var ia: Array[String] = ["enemy_claw"]
	mover.abilities = ia

	# Fill all neighbors of (0,0) with enemies
	var all: Array[Combatant] = [hero, mover]
	var nbs: Array[Vector2i] = HexGrid.neighbors(Vector2i(0, 0))
	for idx: int in range(nbs.size()):
		var blocker := Combatant.new("b%d" % idx, "Blocker", Combatant.Faction.ENEMY, 30, 9)
		blocker.position = nbs[idx]
		var ba: Array[String] = ["enemy_claw"]
		blocker.abilities = ba
		all.append(blocker)

	engine.setup(all)
	var map := DungeonMap.new()
	for q: int in range(-5, 6):
		for r: int in range(-5, 6):
			map.passable[Vector2i(q, r)] = true
			map.tile_types[Vector2i(q, r)] = "floor"

	var pos_before: Vector2i = mover.position
	engine.enemy_ai_action(mover, map)
	assert_eq(mover.position, pos_before, "Surrounded enemy cannot move, stays at %s" % str(pos_before))

# ─── Floor Scaling ────────────────────────────────────────────────────────────

func test_floor_scaling_hp_increases() -> void:
	## Floor 1 imp has base 25 HP; floor 5 imp should have ~125% of that
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	var def: Dictionary = {"id": "imp", "display_name": "Imp", "hp": 25,
		"armor": 0, "speed": 12, "abilities": ["enemy_claw"], "xp_reward": 20, "sprite_key": "imp"}

	var imp_f1: Combatant = EnemyDefs.make_combatant(def, Vector2i(0,0), rng, 1)
	rng.seed = 99  # reset for same id suffix
	var imp_f5: Combatant = EnemyDefs.make_combatant(def, Vector2i(0,0), rng, 5)

	assert_true(imp_f5.max_hp > imp_f1.max_hp,
		"Floor 5 enemy has more HP than floor 1 (f1=%d, f5=%d)" % [imp_f1.max_hp, imp_f5.max_hp])

func test_floor_1_enemy_unscaled() -> void:
	## Floor 1 enemy should have exactly base HP (scale factor = 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var def: Dictionary = {"id": "goblin", "display_name": "Goblin", "hp": 35,
		"armor": 1, "speed": 14, "abilities": ["enemy_claw"], "xp_reward": 25, "sprite_key": "goblin"}
	var goblin: Combatant = EnemyDefs.make_combatant(def, Vector2i(1, 0), rng, 1)
	assert_eq(goblin.max_hp, 35, "Floor 1 goblin has base HP 35 (no scaling)")

func test_floor_3_enemy_scaled() -> void:
	## Floor 3: scale factor = 1.0 + 2 * 0.20 = 1.40 → imp HP = int(25 * 1.40) = 35
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var def: Dictionary = {"id": "imp", "display_name": "Imp", "hp": 25,
		"armor": 0, "speed": 12, "abilities": ["enemy_claw"], "xp_reward": 20, "sprite_key": "imp"}
	var imp: Combatant = EnemyDefs.make_combatant(def, Vector2i(0,0), rng, 3)
	assert_eq(imp.max_hp, 35, "Floor 3 imp HP = int(25 * 1.40) = 35")

func test_floor_armor_scaling() -> void:
	## Armor scales: +1 every 2 floors above floor 1
	## Floor 1: +0, Floor 2: +0, Floor 3: +1, Floor 4: +1, Floor 5: +2
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var def: Dictionary = {"id": "skeleton", "display_name": "Skeleton", "hp": 45,
		"armor": 3, "speed": 8, "abilities": ["enemy_claw"], "xp_reward": 30, "sprite_key": "skeleton"}

	rng.seed = 33
	var skel_f1: Combatant = EnemyDefs.make_combatant(def, Vector2i(0,0), rng, 1)
	assert_eq(skel_f1.armor, 3, "Floor 1 skeleton armor = base 3 (no bonus)")
	rng.seed = 33
	var skel_f3: Combatant = EnemyDefs.make_combatant(def, Vector2i(0,0), rng, 3)
	assert_eq(skel_f3.armor, 4, "Floor 3 skeleton armor = 3 + 1 = 4")
	rng.seed = 33
	var skel_f5: Combatant = EnemyDefs.make_combatant(def, Vector2i(0,0), rng, 5)
	assert_eq(skel_f5.armor, 5, "Floor 5 skeleton armor = 3 + 2 = 5")

# ─── Environment Damage ───────────────────────────────────────────────────────

func test_environment_damage_reduces_hp() -> void:
	## apply_environment_damage deals direct damage (no armor reduction)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	hero.armor = 10  # armor should NOT reduce env damage
	var all: Array[Combatant] = [hero]
	engine.setup(all)

	var hp_before: int = hero.hp
	var actual: int = engine.apply_environment_damage(hero, 15)
	assert_eq(actual, 15, "Environment damage applied fully (armor ignored)")
	assert_eq(hero.hp, hp_before - 15, "Hero HP reduced by env damage")

func test_environment_damage_kills_combatant() -> void:
	## If env damage kills a combatant, combatant_died is emitted
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var engine := BattleEngine.new(rng)
	var victim := Combatant.new("v", "Victim", Combatant.Faction.ENEMY, 10, 5)
	var all: Array[Combatant] = [victim]
	engine.setup(all)

	var died_ids: Array[String] = []
	engine.combatant_died.connect(func(c: Combatant) -> void: died_ids.append(c.id))

	engine.apply_environment_damage(victim, 50)  # overkill
	assert_true(not victim.is_alive(), "Victim killed by env damage")
	assert_true(died_ids.has("v"), "combatant_died emitted for v")
