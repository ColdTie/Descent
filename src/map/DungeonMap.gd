class_name DungeonMap
## Procedural map for one dungeon floor.
## Pure logic — no Node dependency.

var floor_num: int = 0
var radius: int = 5  # hex grid radius
var passable: Dictionary = {}   # Vector2i -> bool
var tile_types: Dictionary = {} # Vector2i -> String ("floor","lava","wall")
var spawn_points: Array[Vector2i] = []
var hero_start: Vector2i = Vector2i.ZERO
var exit_pos: Vector2i = Vector2i.ZERO
var boss_spawn: Vector2i = Vector2i.ZERO

func generate(p_floor: int, rng: RandomNumberGenerator) -> void:
	floor_num = p_floor
	passable.clear()
	tile_types.clear()
	spawn_points.clear()
	
	# Fill disk with floor tiles
	var all_hexes: Array[Vector2i] = HexGrid.disk(Vector2i.ZERO, radius)
	for h: Vector2i in all_hexes:
		tile_types[h] = "floor"
		passable[h] = true
	
	# Place some lava tiles (10-15% of tiles)
	var lava_count: int = rng.randi_range(int(all_hexes.size() * 0.10), int(all_hexes.size() * 0.15))
	var shuffled: Array[Vector2i] = all_hexes.duplicate()
	_shuffle_vec2i(shuffled, rng)
	for i: int in range(lava_count):
		var h: Vector2i = shuffled[i]
		if h != Vector2i.ZERO:  # never lava on center
			tile_types[h] = "lava"
			passable[h] = false

	# Hero starts at center
	hero_start = Vector2i.ZERO

	# Enemy spawns on outer ring, not lava
	var outer: Array[Vector2i] = HexGrid.ring(Vector2i.ZERO, radius - 1)
	_shuffle_vec2i(outer, rng)
	var enemy_count: int = 3 + floor_num  # more enemies per floor
	var placed: int = 0
	for h: Vector2i in outer:
		if tile_types.get(h, "lava") == "floor":
			spawn_points.append(h)
			placed += 1
			if placed >= enemy_count:
				break
	
	# Exit at far end
	exit_pos = Vector2i(0, -(radius - 1))
	if tile_types.get(exit_pos, "lava") == "lava":
		exit_pos = Vector2i(radius - 1, 0)

	# Boss spawn at the southern ring position (opposite the exit)
	var boss_candidates: Array[Vector2i] = [
		Vector2i(0, radius - 1),
		Vector2i(-(radius - 1), radius - 1),
		Vector2i(radius - 1, 0),
	]
	boss_spawn = boss_candidates[0]
	for candidate: Vector2i in boss_candidates:
		if tile_types.get(candidate, "lava") == "floor":
			boss_spawn = candidate
			break

## Fisher-Yates shuffle for typed Array[Vector2i] using a seeded rng
func _shuffle_vec2i(arr: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	var n: int = arr.size()
	for i: int in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func is_passable(h: Vector2i) -> bool:
	return passable.get(h, false)

func get_tile_type(h: Vector2i) -> String:
	return tile_types.get(h, "wall")
