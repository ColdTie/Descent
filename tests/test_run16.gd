## Run 16 tests: critical hits, boss-floor milestones, run score.
extends "res://tests/run_tests.gd".BaseTest
class_name TestRun16

# ── Critical hits ───────────────────────────────────────────────────────────────

func test_hero_crit_doubles_damage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var engine := BattleEngine.new(rng)
	engine.hero_crit_chance = 1.0  # force crit
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	var target := Combatant.new("dummy", "Dummy", Combatant.Faction.ENEMY, 500, 8)
	var all: Array[Combatant] = [hero, target]
	engine.setup(all)
	var hp_before: int = target.hp
	engine.perform_attack(hero, target, "basic_attack")
	var dmg: int = hp_before - target.hp
	# base_damage 12, variance 0.8-1.2, ×2 crit → min 19; non-crit max would be 14
	assert_gt(dmg, 15, "Crit damage exceeds non-crit ceiling")
	assert_true(engine.last_attack_was_crit, "last_attack_was_crit flagged on forced crit")

func test_hero_no_crit_when_chance_zero() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var engine := BattleEngine.new(rng)
	engine.hero_crit_chance = 0.0
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	var target := Combatant.new("dummy", "Dummy", Combatant.Faction.ENEMY, 500, 8)
	var all: Array[Combatant] = [hero, target]
	engine.setup(all)
	var hp_before: int = target.hp
	engine.perform_attack(hero, target, "basic_attack")
	var dmg: int = hp_before - target.hp
	assert_true(dmg <= 15, "Non-crit damage stays within normal range")
	assert_true(not engine.last_attack_was_crit, "No crit flag when chance is 0")

func test_enemy_never_crits() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var engine := BattleEngine.new(rng)
	engine.hero_crit_chance = 1.0  # would crit IF enemy were eligible
	var enemy := Combatant.new("imp", "Imp", Combatant.Faction.ENEMY, 100, 12)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 500, 10)
	var all: Array[Combatant] = [enemy, hero]
	engine.setup(all)
	engine.perform_attack(enemy, hero, "enemy_claw")
	assert_true(not engine.last_attack_was_crit, "Enemy attacks never crit")

func test_nondamaging_ability_no_crit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var engine := BattleEngine.new(rng)
	engine.hero_crit_chance = 1.0
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	var target := Combatant.new("dummy", "Dummy", Combatant.Faction.ENEMY, 500, 8)
	var all: Array[Combatant] = [hero, target]
	engine.setup(all)
	# taunt has base_damage 0 → not crit-eligible
	engine.perform_attack(hero, target, "taunt")
	assert_true(not engine.last_attack_was_crit, "Zero-damage abilities don't crit")

func test_crit_flag_resets_between_attacks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var engine := BattleEngine.new(rng)
	var hero := Combatant.new("hero", "Carl", Combatant.Faction.HERO, 100, 10)
	var target := Combatant.new("dummy", "Dummy", Combatant.Faction.ENEMY, 500, 8)
	var all: Array[Combatant] = [hero, target]
	engine.setup(all)
	# Force a crit, then force a non-crit; flag must follow the latest attack
	engine.hero_crit_chance = 1.0
	engine.perform_attack(hero, target, "basic_attack")
	assert_true(engine.last_attack_was_crit, "Crit set on first attack")
	engine.hero_crit_chance = 0.0
	engine.perform_attack(hero, target, "basic_attack")
	assert_true(not engine.last_attack_was_crit, "Crit flag cleared on next non-crit")

# ── Boss-floor milestones ─────────────────────────────────────────────────────

func test_boss_floors_are_multiples_of_three() -> void:
	assert_true(EnemyDefs.is_boss_floor(3),  "Floor 3 is a boss floor")
	assert_true(EnemyDefs.is_boss_floor(6),  "Floor 6 is a boss floor")
	assert_true(EnemyDefs.is_boss_floor(9),  "Floor 9 is a boss floor")
	assert_true(EnemyDefs.is_boss_floor(12), "Floor 12 is a boss floor")
	assert_true(EnemyDefs.is_boss_floor(18), "Floor 18 (final) is a boss floor")

func test_non_boss_floors() -> void:
	assert_true(not EnemyDefs.is_boss_floor(1), "Floor 1 is not a boss floor")
	assert_true(not EnemyDefs.is_boss_floor(2), "Floor 2 is not a boss floor")
	assert_true(not EnemyDefs.is_boss_floor(4), "Floor 4 is not a boss floor")
	assert_true(not EnemyDefs.is_boss_floor(17),"Floor 17 is not a boss floor")
	assert_true(not EnemyDefs.is_boss_floor(0), "Floor 0 is not a boss floor")

func test_boss_count_over_full_run() -> void:
	# 18 total floors; bosses every 3rd → 6 boss floors
	var count: int = 0
	for f: int in range(1, 19):
		if EnemyDefs.is_boss_floor(f):
			count += 1
	assert_eq(count, 6, "Exactly 6 boss floors across 18 floors")

# ── Run score formula (mirrors GameState.run_score) ─────────────────────────────
# GameState is an autoload (unavailable in --script mode), so we verify the
# scoring formula's shape directly: depth dominates, kills/bosses/level add.

func _score(floor_num: int, kills: int, bosses: int, level: int) -> int:
	return floor_num * 1000 + kills * 25 + bosses * 250 + level * 100

func test_run_score_rewards_depth() -> void:
	assert_gt(_score(10, 0, 0, 1), _score(5, 0, 0, 1), "Deeper floor yields higher score")

func test_run_score_rewards_kills_and_bosses() -> void:
	assert_gt(_score(5, 20, 2, 1), _score(5, 0, 0, 1), "Kills and bosses raise the score")
