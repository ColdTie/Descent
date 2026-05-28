class_name HexGrid
## Offset-coordinate hex grid utilities (axial coords internally).
## All static — no instance needed.

## Axial hex directions (q, r)
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

## Convert axial hex (q,r) to world pixel position (pointy-top)
static func hex_to_pixel(hex: Vector2i, size: float) -> Vector2:
	var x: float = size * (sqrt(3.0) * float(hex.x) + sqrt(3.0) / 2.0 * float(hex.y))
	var y: float = size * (3.0 / 2.0 * float(hex.y))
	return Vector2(x, y)

## Convert world pixel to nearest hex (axial)
static func pixel_to_hex(pixel: Vector2, size: float) -> Vector2i:
	var q: float = (sqrt(3.0) / 3.0 * pixel.x - 1.0 / 3.0 * pixel.y) / size
	var r: float = (2.0 / 3.0 * pixel.y) / size
	return _hex_round(Vector2(q, r))

static func _hex_round(frac: Vector2) -> Vector2i:
	var s: float = -frac.x - frac.y
	var rx: int = roundi(frac.x)
	var ry: int = roundi(frac.y)
	var rs: int = roundi(s)
	var x_diff: float = abs(float(rx) - frac.x)
	var y_diff: float = abs(float(ry) - frac.y)
	var s_diff: float = abs(float(rs) - s)
	if x_diff > y_diff and x_diff > s_diff:
		rx = -ry - rs
	elif y_diff > s_diff:
		ry = -rx - rs
	return Vector2i(rx, ry)

static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2

static func neighbors(hex: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in DIRECTIONS:
		result.append(hex + d)
	return result

static func is_in_range(center: Vector2i, target: Vector2i, range_val: int) -> bool:
	return hex_distance(center, target) <= range_val

## Generate a ring of hexes at given radius
static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius == 0:
		return [center]
	var results: Array[Vector2i] = []
	var h: Vector2i = center + DIRECTIONS[4] * radius
	for i in range(6):
		for _j in range(radius):
			results.append(h)
			h = h + DIRECTIONS[i]
	return results

## Return the canonical hex direction that best matches the vector from_hex → to_hex.
## If from_hex == to_hex, returns Vector2i.ZERO.
static func get_push_direction(from_hex: Vector2i, to_hex: Vector2i) -> Vector2i:
	var diff: Vector2i = to_hex - from_hex
	if diff == Vector2i.ZERO:
		return Vector2i.ZERO
	# If diff is already a unit direction (adjacent hexes), return it directly.
	for d: Vector2i in DIRECTIONS:
		if d == diff:
			return d
	# Otherwise project onto the six directions via dot product.
	var diff_f: Vector2 = Vector2(float(diff.x), float(diff.y))
	var best_dir: Vector2i = DIRECTIONS[0]
	var best_dot: float = -999.0
	for d: Vector2i in DIRECTIONS:
		var df: Vector2 = Vector2(float(d.x), float(d.y))
		var dot: float = diff_f.dot(df) / (df.length() * diff_f.length())
		if dot > best_dot:
			best_dot = dot
			best_dir = d
	return best_dir

## Generate filled disk of hexes
static func disk(center: Vector2i, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		var r1: int = max(-radius, -q - radius)
		var r2: int = min(radius, -q + radius)
		for r in range(r1, r2 + 1):
			results.append(center + Vector2i(q, r))
	return results
