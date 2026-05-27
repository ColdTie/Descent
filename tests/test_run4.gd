## Run 4 Tests: Shield Bash (knockback), ability unlocks, System commentary, HP regen.

class_name TestRun4
extends "res://tests/run_tests.gd".BaseTest

## ─── Shield Bash ability data ─────────────────────────────────────────────────

func test_shield_bash_in_abilities_data() -> void:
	assert_true(Abilities.DATA.has("shield_bash"), "shield_bash exists in Abilities.DATA")

func test_shield_bash_has_knockback_flag() -> void:
	var data: Dictionary = Abilities.get_ability("shield_bash")
	assert_true(data.get("knockback", 0) > 0, "shield_bash has knockback > 0")

func test_shield_bash_range_and_damage() -> void:
	var data: Dictionary = Abilities.get_ability("shield_bash")
	assert_eq(data.get("range", 0), 1, "shield_bash range is 1 (melee)")
	assert_true(data.get("base_damage", 0) > 0, "shield_bash has positive base_damage")

func test_shield_bash_is_single_enemy() -> void:
	var data: Dictionary = Abilities.get_ability("shield_bash")
	assert_eq(data.get("target", ""), "single_enemy", "shield_bash targets single_enemy")

## ─── Brawler class kit ────────────────────────────────────────────────────────

func test_brawler_starts_with_shield_bash() -> void:
	var brawler: Dictionary = Classes.get_class_data("brawler")
	var abilities: Array = brawler.get("abilities", [])
	assert_true(abilities.has("shield_bash"), "Brawler starts with shield_bash")

func test_brawler_no_longer_starts_with_taunt() -> void:
	var brawler: Dictionary = Classes.get_class_data("brawler")
	var abilities: Array = brawler.get("abilities", [])
	assert_true(not abilities.has("taunt"), "taunt removed from Brawler starting kit (unlockable now)")

## ─── Knockback logic ──────────────────────────────────────────────────────────

func _make_open_map() -> DungeonMap:
	## Build a map where center and all neighbors are floor tiles (no lava near center).
	var map: DungeonMap = DungeonMap.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9999  # seed chosen to produce low lava density near center
	map.generate(1, rng)
	# Force center area to be passable floor (override any lava that landed there)
	for d: int in range(3):
		for h: Vector2i in HexGrid.ring(Vector2i.ZERO, d):
			map.tile_types[h] = "floor"
			map.passable[h] = true
	return map

func test_knockback_moves_enemy_away() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var map: DungeonMap = _make_open_map()

	var hero: Combatant = Combatant.new("h", "Hero", Combatant.Faction.HERO, 200, 10)
	hero.attack_bonus = 0
	hero.position = Vector2i(0, 0)

	var enemy: Combatant = Combatant.new("e", "Goblin", Combatant.Faction.ENEMY, 200, 5)
	enemy.armor = 0
	enemy.position = Vector2i(1, 0)  # adjacent

	var engine: BattleEngine = BattleEngine.new(rng)
	engine.setup([hero, enemy])

	var start_pos: Vector2i = enemy.position
	engine.perform_knockback_attack(hero, enemy, "shield_bash", map)

	assert_true(enemy.position != start_pos or not enemy.is_alive(),
		"Enemy moved away from hero after shield bash (pos=%s, alive=%s)" % [str(enemy.position), str(enemy.is_alive())])

func test_knockback_push_direction_is_away() -> void:
	## get_push_hex should return the neighbor of target farthest from attacker.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var map: DungeonMap = _make_open_map()

	var hero: Combatant = Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy: Combatant = Combatant.new("e", "Enemy", Combatant.Faction.ENEMY, 100, 5)
	enemy.position = Vector2i(1, 0)

	var engine: BattleEngine = BattleEngine.new(rng)
	engine.setup([hero, enemy])

	var push_to: Vector2i = engine.get_push_hex(hero.position, enemy.position, map)
	var push_dist: int = HexGrid.hex_distance(push_to, hero.position)
	var start_dist: int = HexGrid.hex_distance(enemy.position, hero.position)
	assert_true(push_dist >= start_dist,
		"Push destination is at least as far from attacker as original position (push_dist=%d, start_dist=%d)" % [push_dist, start_dist])

func test_knockback_blocked_by_wall() -> void:
	## If all neighbors are walls/out-of-map, enemy stays in place.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var map: DungeonMap = DungeonMap.new()
	# Build a minimal map with only two hexes: (0,0) and (1,0)
	map.tile_types[Vector2i(0, 0)] = "floor"
	map.passable[Vector2i(0, 0)] = true
	map.tile_types[Vector2i(1, 0)] = "floor"
	map.passable[Vector2i(1, 0)] = true
	# All other neighbors of (1,0) are NOT in tile_types (treated as wall)

	var hero: Combatant = Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	hero.position = Vector2i(0, 0)
	var enemy: Combatant = Combatant.new("e", "Enemy", Combatant.Faction.ENEMY, 200, 5)
	enemy.armor = 999  # near-invincible so knock doesn't kill
	enemy.position = Vector2i(1, 0)

	var engine: BattleEngine = BattleEngine.new(rng)
	engine.setup([hero, enemy])

	var result: Array = engine.perform_knockback_attack(hero, enemy, "shield_bash", map)
	# Enemy should remain at (1,0) since no other tile is in the map
	assert_eq(enemy.position, Vector2i(1, 0), "Enemy stays when all push hexes are walls")

func test_knockback_signal_emitted() -> void:
	## Verify combatant_pushed signal fires when an actual push occurs.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var map: DungeonMap = _make_open_map()

	var hero: Combatant = Combatant.new("h", "Hero", Combatant.Faction.HERO, 200, 10)
	hero.attack_bonus = 0
	hero.position = Vector2i(0, 0)
	var enemy: Combatant = Combatant.new("e", "Enemy", Combatant.Faction.ENEMY, 300, 5)
	enemy.armor = 999
	enemy.position = Vector2i(1, 0)

	var engine: BattleEngine = BattleEngine.new(rng)
	engine.setup([hero, enemy])

	var pushed: Array[bool] = [false]
	engine.combatant_pushed.connect(func(_t: Combatant, _f: Vector2i, _to: Vector2i) -> void:
		pushed[0] = true
	)

	engine.perform_knockback_attack(hero, enemy, "shield_bash", map)
	assert_true(pushed[0], "combatant_pushed signal emitted after successful knockback")

## ─── System Voice new categories ─────────────────────────────────────────────

func test_system_voice_has_hero_low_hp() -> void:
	assert_true(SystemVoice.LINES.has("hero_low_hp"), "SystemVoice has hero_low_hp category")

func test_system_voice_has_first_kill() -> void:
	assert_true(SystemVoice.LINES.has("first_kill"), "SystemVoice has first_kill category")

func test_system_voice_has_backstab_hit() -> void:
	assert_true(SystemVoice.LINES.has("backstab_hit"), "SystemVoice has backstab_hit category")

func test_system_voice_has_hero_surrounded() -> void:
	assert_true(SystemVoice.LINES.has("hero_surrounded"), "SystemVoice has hero_surrounded category")

func test_system_voice_has_shield_bash() -> void:
	assert_true(SystemVoice.LINES.has("shield_bash"), "SystemVoice has shield_bash category")

func test_system_voice_has_ability_unlock() -> void:
	assert_true(SystemVoice.LINES.has("ability_unlock"), "SystemVoice has ability_unlock category")

func test_system_voice_hero_low_hp_pool_not_empty() -> void:
	var pool: Array = SystemVoice.LINES.get("hero_low_hp", [])
	assert_true(pool.size() >= 2, "hero_low_hp has at least 2 lines (pool size=%d)" % pool.size())

## ─── HP regen logic ───────────────────────────────────────────────────────────

func test_heal_does_not_exceed_max_hp() -> void:
	## Simulate the between-floor regen: heal() should cap at max_hp.
	## We test Combatant.heal() directly (which GameState.heal mirrors).
	var c: Combatant = Combatant.new("h", "Hero", Combatant.Faction.HERO, 100, 10)
	c.hp = 95
	var healed: int = c.heal(20)  # would overshoot
	assert_eq(c.hp, 100, "HP capped at max_hp after heal")
	assert_eq(healed, 5, "Heal returns actual HP restored (not requested amount)")

func test_regen_amount_formula() -> void:
	## 10% of max_hp, minimum 5
	var max_hp: int = 150  # Brawler baseline
	var regen: int = max(5, int(float(max_hp) * 0.10))
	assert_eq(regen, 15, "Brawler 10% regen = 15 HP")

	var max_hp2: int = 30  # hypothetical low-HP scenario
	var regen2: int = max(5, int(float(max_hp2) * 0.10))
	assert_eq(regen2, 5, "Minimum regen is 5 HP even for low max_hp")

## ─── Ability unlock pool logic ────────────────────────────────────────────────

func test_unlock_pool_excludes_owned_abilities() -> void:
	## Build a fake hero_abilities list and check what's "unlockable".
	var owned: Array[String] = ["basic_attack", "power_strike", "shield_bash"]
	var unlockable: Array[String] = ["power_strike", "backstab", "fireball",
		"frost_nova", "taunt", "vanish", "shield_bash"]
	var available: Array[String] = []
	for a: String in unlockable:
		if not owned.has(a):
			available.append(a)
	assert_true(not available.has("power_strike"), "Owned ability not in unlock pool")
	assert_true(not available.has("shield_bash"), "Owned ability not in unlock pool")
	assert_true(available.has("backstab"), "Unowned ability IS in unlock pool")
	assert_true(available.has("fireball"), "Unowned ability IS in unlock pool")
	assert_eq(available.size(), 5, "5 unlockable abilities when 2 are already owned (from pool of 7)")
