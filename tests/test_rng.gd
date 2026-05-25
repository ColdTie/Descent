extends "res://tests/run_tests.gd".BaseTest
class_name TestRng

func test_seeded_reproducibility() -> void:
	var rng1 := RandomNumberGenerator.new()
	var rng2 := RandomNumberGenerator.new()
	rng1.seed = 42
	rng2.seed = 42
	var results_match: bool = true
	for _i: int in range(100):
		if rng1.randi() != rng2.randi():
			results_match = false
			break
	assert_true(results_match, "Same seed produces same sequence")

func test_range_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var all_in_bounds: bool = true
	for _i: int in range(1000):
		var v: int = rng.randi_range(0, 9)
		if v < 0 or v > 9:
			all_in_bounds = false
			break
	assert_true(all_in_bounds, "randi_range stays in [0,9]")

func test_shuffle_preserves_elements() -> void:
	## Array.shuffle() uses global RNG; test that sum is preserved
	var arr: Array[int] = [1, 2, 3, 4, 5]
	var original_sum: int = 0
	for v: int in arr:
		original_sum += v
	arr.shuffle()
	var shuffled_sum: int = 0
	for v: int in arr:
		shuffled_sum += v
	assert_eq(original_sum, shuffled_sum, "Shuffle preserves elements (sum check)")

func test_seeded_fisher_yates() -> void:
	## Test our own Fisher-Yates shuffle via RandomNumberGenerator
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var arr: Array[int] = [10, 20, 30, 40, 50]
	var expected_sum: int = 150
	# Manual Fisher-Yates with seeded RNG
	var n: int = arr.size()
	for i: int in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	var actual_sum: int = 0
	for v: int in arr:
		actual_sum += v
	assert_eq(actual_sum, expected_sum, "Seeded Fisher-Yates preserves element sum")

func test_randf_range_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var all_ok: bool = true
	for _i: int in range(500):
		var v: float = rng.randf_range(0.8, 1.2)
		if v < 0.8 or v > 1.2:
			all_ok = false
			break
	assert_true(all_ok, "randf_range stays within [0.8, 1.2]")
