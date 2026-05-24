## GameRng — seeded RNG autoload.
## All game randomness routes through here so runs are deterministic.
## Seed is fixed in v1; later milestones can expose a UI seed or timestamp seed.
extends Node

const DEFAULT_SEED: int = 42

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	reset(DEFAULT_SEED)


## Reset the RNG to a known seed. Call before each test or new encounter.
func reset(seed_value: int = DEFAULT_SEED) -> void:
	_rng.seed = seed_value


## Roll a single die with [param sides] faces. Returns 1..sides.
func roll(sides: int) -> int:
	assert(sides >= 1, "GameRng.roll: sides must be >= 1")
	return _rng.randi_range(1, sides)


## Parse and roll standard dice notation, e.g. "2d6" or "1d4".
## Returns the sum of all dice.
func roll_dice(notation: String) -> int:
	var parts: PackedStringArray = notation.to_lower().split("d")
	if parts.size() != 2:
		push_error("GameRng.roll_dice: invalid notation '%s'" % notation)
		return 0
	var count: int = int(parts[0])
	var sides: int = int(parts[1])
	if count < 1 or sides < 1:
		push_error("GameRng.roll_dice: invalid notation '%s'" % notation)
		return 0
	var total: int = 0
	for _i: int in range(count):
		total += roll(sides)
	return total


## Convenience: roll a d20.
func d20() -> int:
	return roll(20)
