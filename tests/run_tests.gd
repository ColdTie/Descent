extends SceneTree
## Headless test runner. Exit code 0 = all pass, 1 = any failure.

var _failures: int = 0
var _passes: int = 0

func _init() -> void:
	print("=== DESCENT Test Runner ===")
	_run_all()
	print("\nResults: %d passed, %d failed" % [_passes, _failures])
	quit(_failures)

func _run_all() -> void:
	_run_suite("RNG", TestRng.new())
	_run_suite("Hex", TestHex.new())
	_run_suite("Combat", TestCombat.new())
	_run_suite("Movement+Abilities", TestMovement.new())
	_run_suite("Run3 (Charges+Scaling+Collision)", TestRun3.new())
	_run_suite("Run15 (BossPhase2+EnemyUnlocks+ShadowStep)", TestRun15.new())
	_run_suite("Run16 (Crits+BossFloors+Score)", TestRun16.new())
	_run_suite("Run17 (Floor-3 Allies)", TestRun17Allies.new())
	_run_suite("Run19 (Achievements+Audience)", TestRun19.new())
	_run_suite("Run20 (Sponsors+PatchNotes)", TestRun20.new())
	_run_suite("Run21 (Shop+Gold+ManaShield)", TestRun21.new())
	_run_suite("Run24 (LootRarity+Music)", TestRun24.new())

func _run_suite(name: String, suite: Object) -> void:
	print("\n--- %s ---" % name)
	for method: Dictionary in suite.get_method_list():
		var mname: String = method["name"]
		if not mname.begins_with("test_"):
			continue
		suite.call(mname)
		# Collect results from suite
	var s_pass: int = suite.get("_passes") if suite.get("_passes") != null else 0
	var s_fail: int = suite.get("_failures") if suite.get("_failures") != null else 0
	_passes += s_pass
	_failures += s_fail

class BaseTest:
	var _passes: int = 0
	var _failures: int = 0
	
	func assert_eq(a: Variant, b: Variant, msg: String = "") -> void:
		if a == b:
			_passes += 1
			print("  PASS: %s" % (msg if msg else "%s == %s" % [str(a), str(b)]))
		else:
			_failures += 1
			print("  FAIL: %s -- got %s, expected %s" % [msg, str(a), str(b)])
	
	func assert_true(val: bool, msg: String = "") -> void:
		if val:
			_passes += 1
			print("  PASS: %s" % msg)
		else:
			_failures += 1
			print("  FAIL: %s" % msg)
	
	func assert_gt(a: Variant, b: Variant, msg: String = "") -> void:
		if a > b:
			_passes += 1
			print("  PASS: %s (%s > %s)" % [msg, str(a), str(b)])
		else:
			_failures += 1
			print("  FAIL: %s -- %s not > %s" % [msg, str(a), str(b)])
