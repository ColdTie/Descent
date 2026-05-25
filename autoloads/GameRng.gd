extends Node
## Seeded RNG autoload. All gameplay randomness routes through here.
## Pure logic functions accept an explicit rng: RandomNumberGenerator param for testability.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0

func _ready() -> void:
	reseed(randi())

func reseed(s: int) -> void:
	_seed = s
	_rng.seed = s

func get_seed() -> int:
	return _seed

## Returns int in [0, n)
func randi_range(lo: int, hi: int) -> int:
	return _rng.randi_range(lo, hi)

func randf() -> float:
	return _rng.randf()

func randf_range(lo: float, hi: float) -> float:
	return _rng.randf_range(lo, hi)

## Pick a random element from an array
func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]

## Shuffle array in place using seeded Fisher-Yates
func shuffle(arr: Array) -> void:
	var n: int = arr.size()
	for i: int in range(n - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
