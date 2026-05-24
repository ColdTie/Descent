## TestCombatResolver — unit tests for CombatResolver and GameRng.roll_dice().
##
## How to run:
##   Godot editor → open tests/TestRunner.tscn → press F6 (Run Current Scene).
##   Results print to the Output panel.  Non-zero failures are printed as errors.
##
## The test node prints a PASS/FAIL summary and signals the runner via
## `all_done(failed_count: int)` so a CI wrapper can check the exit code.
extends Node

signal all_done(failed_count: int)

var _passed: int = 0
var _failed: int = 0

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Tiny deferred call so the scene tree is fully stable before we run.
	call_deferred("_run_all")


func _run_all() -> void:
	print("\n=== CombatResolver + Dice Tests ===\n")

	# Dice tests
	_test_dice_basic_range()
	_test_dice_determinism()
	_test_dice_multi_range()

	# CombatResolver tests
	_test_guaranteed_hit()
	_test_guaranteed_miss()
	_test_lethal()
	_test_miss_no_damage_no_kill()
	_test_full_determinism()
	_test_resolve_heal()

	# Summary
	var total: int = _passed + _failed
	print("\n=== Results: %d / %d passed ===" % [_passed, total])
	if _failed > 0:
		printerr("=== %d test(s) FAILED ===" % _failed)

	all_done.emit(_failed)


# ── Assertion helper ──────────────────────────────────────────────────────────

func _assert(label: String, condition: bool) -> void:
	if condition:
		print("  [PASS] %s" % label)
		_passed += 1
	else:
		printerr("  [FAIL] %s" % label)
		_failed += 1

# ── Dice tests ─────────────────────────────────────────────────────────────────

func _test_dice_basic_range() -> void:
	print("[dice] 1d6 always in [1, 6]")
	GameRng.reset(1)
	var ok := true
	for _i: int in range(500):
		var v: int = GameRng.roll(6)
		if v < 1 or v > 6:
			ok = false
			break
	_assert("roll(6) ∈ [1, 6]  (500 rolls, seed=1)", ok)


func _test_dice_determinism() -> void:
	print("[dice] roll_dice determinism")
	GameRng.reset(999)
	var seq_a: Array[int] = []
	for _i: int in range(20):
		seq_a.append(GameRng.roll_dice("2d6"))

	GameRng.reset(999)
	var seq_b: Array[int] = []
	for _i: int in range(20):
		seq_b.append(GameRng.roll_dice("2d6"))

	_assert("same seed → identical 2d6 sequence (20 rolls)", seq_a == seq_b)


func _test_dice_multi_range() -> void:
	print("[dice] 2d6 always in [2, 12]")
	GameRng.reset(7)
	var ok := true
	for _i: int in range(500):
		var v: int = GameRng.roll_dice("2d6")
		if v < 2 or v > 12:
			ok = false
			break
	_assert("roll_dice('2d6') ∈ [2, 12]  (500 rolls, seed=7)", ok)

# ── CombatResolver tests ──────────────────────────────────────────────────────

func _test_guaranteed_hit() -> void:
	print("[resolver] guaranteed hit")
	# to_hit_bonus=19: d20 min=1 → total=20 ≥ defense=20 → always hits.
	GameRng.reset(42)
	var r: Dictionary = CombatResolver.resolve_attack(19, "1d4", 20, 5, GameRng)
	_assert("hit == true   (to_hit=19, def=20, any seed)", r.hit == true)
	_assert("damage >= 1   on confirmed hit",              r.damage >= 1)
	_assert("roll == d20+19 (roll-19 in [1,20])",
			r.roll >= 20 and r.roll <= 39)


func _test_guaranteed_miss() -> void:
	print("[resolver] guaranteed miss")
	# defense=21: d20 max=20, to_hit=0 → max possible roll=20 < 21 → always misses.
	GameRng.reset(42)
	var r: Dictionary = CombatResolver.resolve_attack(0, "1d4", 21, 5, GameRng)
	_assert("hit == false  (to_hit=0, def=21, any seed)", r.hit == false)
	_assert("damage == 0   on miss",                      r.damage == 0)


func _test_lethal() -> void:
	print("[resolver] lethal damage")
	# Guaranteed hit (to_hit=19, def=20), defender at 1 HP.
	# d6 min=1 → damage ≥ 1 → (1 - damage) ≤ 0 → killed=true always.
	GameRng.reset(42)
	var r: Dictionary = CombatResolver.resolve_attack(19, "1d6", 20, 1, GameRng)
	_assert("killed == true  (1 HP, guaranteed hit, d6 ≥ 1)", r.killed == true)


func _test_miss_no_damage_no_kill() -> void:
	print("[resolver] miss → no damage, no kill")
	GameRng.reset(42)
	var r: Dictionary = CombatResolver.resolve_attack(0, "1d6", 21, 1, GameRng)
	_assert("killed == false on miss", r.killed == false)
	_assert("damage == 0    on miss",  r.damage == 0)


func _test_full_determinism() -> void:
	print("[resolver] full-result determinism")
	var seed_val: int = 31337
	GameRng.reset(seed_val)
	var r1: Dictionary = CombatResolver.resolve_attack(2, "1d4", 11, 5, GameRng)

	GameRng.reset(seed_val)
	var r2: Dictionary = CombatResolver.resolve_attack(2, "1d4", 11, 5, GameRng)

	_assert("hit    same on equal seed", r1.hit    == r2.hit)
	_assert("roll   same on equal seed", r1.roll   == r2.roll)
	_assert("damage same on equal seed", r1.damage == r2.damage)
	_assert("killed same on equal seed", r1.killed == r2.killed)


func _test_resolve_heal() -> void:
	print("[resolver] heal resolution")
	GameRng.reset(5)
	var h1: int = CombatResolver.resolve_heal("1d6", GameRng)
	_assert("heal ∈ [1, 6]", h1 >= 1 and h1 <= 6)

	GameRng.reset(5)
	var h2: int = CombatResolver.resolve_heal("1d6", GameRng)
	_assert("heal deterministic on same seed", h1 == h2)

	var zero: int = CombatResolver.resolve_heal("", GameRng)
	_assert("empty heal_dice → 0", zero == 0)
