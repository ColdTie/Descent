## Grid — 12×10 dungeon room, AStarGrid2D, cell highlighting, and
## world↔cell coordinate helpers.  Pure rendering + data; no game logic.
extends Node2D
class_name Grid

# ── Constants ────────────────────────────────────────────────────────────────

const COLS: int = 12
const ROWS: int = 10
const CELL_SIZE: int = 64  # pixels per cell edge

## Hand-authored wall / rock cells for the v1 dungeon room.
## Arranged to create cover and tactical positioning without blocking paths.
const WALL_CELLS: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(2, 3),        # Left column of rocks
	Vector2i(6, 4), Vector2i(6, 5),        # Central obstruction
	Vector2i(9, 2), Vector2i(10, 2),       # Right-side rocks
	Vector2i(4, 7), Vector2i(5, 7),        # Bottom-centre rocks
	Vector2i(1, 7),                        # Isolated bottom-left rock
]

# ── Visual colours ───────────────────────────────────────────────────────────

const C_FLOOR:       Color = Color(0.18, 0.15, 0.22, 1.0)
const C_WALL:        Color = Color(0.10, 0.08, 0.12, 1.0)
const C_WALL_CRACK:  Color = Color(0.40, 0.35, 0.50, 1.0)
const C_LINE:        Color = Color(0.30, 0.25, 0.40, 0.40)
const C_HOVER:       Color = Color(0.95, 0.95, 0.55, 0.30)
const C_MOVE:        Color = Color(0.25, 0.65, 1.00, 0.28)
const C_ATTACK:      Color = Color(1.00, 0.35, 0.25, 0.35)

# ── State ────────────────────────────────────────────────────────────────────

var _astar: AStarGrid2D

## Current cell under the mouse cursor.  (-1,-1) = off-grid.
var _hovered_cell: Vector2i = Vector2i(-1, -1)

## Cells tinted blue (movement range).
var _move_cells: Array[Vector2i] = []

## Cells tinted red (attackable enemies).
var _attack_cells: Array[Vector2i] = []

## Occupancy map: Vector2i → Node.  Updated by TurnManager.
var _occupied: Dictionary = {}

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_astar()


func _build_astar() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, COLS, ROWS)
	_astar.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	# IMPORTANT: call update() BEFORE set_point_solid.
	# Calling update() after solid points are set clears them.
	_astar.update()
	for wall: Vector2i in WALL_CELLS:
		_astar.set_point_solid(wall, true)

# ── Coordinate helpers ────────────────────────────────────────────────────────

## Convert a local-space position to a grid cell.  May be out-of-bounds.
func world_to_cell(local_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(local_pos.x / CELL_SIZE),
		int(local_pos.y / CELL_SIZE)
	)


## Convert a grid cell to its centre in local space.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * CELL_SIZE + CELL_SIZE * 0.5,
		cell.y * CELL_SIZE + CELL_SIZE * 0.5
	)

# ── Queries ───────────────────────────────────────────────────────────────────

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS \
		and cell.y >= 0 and cell.y < ROWS


func is_wall(cell: Vector2i) -> bool:
	return cell in WALL_CELLS


func is_walkable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and not is_wall(cell)


func is_occupied(cell: Vector2i) -> bool:
	return _occupied.has(cell)


func get_occupant(cell: Vector2i) -> Node:
	return _occupied.get(cell, null)


func set_occupied(cell: Vector2i, unit: Node) -> void:
	_occupied[cell] = unit


func clear_occupied(cell: Vector2i) -> void:
	_occupied.erase(cell)


## Manhattan distance — matches 4-directional movement cost.
func manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Chebyshev distance — used for weapon range checks (8-directional reach).
func cell_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

# ── Pathfinding ───────────────────────────────────────────────────────────────

## Returns all cells reachable from [param origin] within [param max_steps]
## via BFS, skipping walls and occupied cells.
## Pass [param moving_unit] to allow movement through that unit's own cell.
func get_reachable_cells(
		origin: Vector2i,
		max_steps: int,
		moving_unit: Node = null) -> Array[Vector2i]:

	var result: Array[Vector2i] = []
	var visited: Dictionary = { origin: true }
	# queue entry: [cell: Vector2i, steps_taken: int]
	var queue: Array = [[origin, 0]]

	while not queue.is_empty():
		var entry: Array = queue.pop_front()
		var cell: Vector2i = entry[0]
		var steps: int = entry[1]
		if steps > 0:
			result.append(cell)
		if steps >= max_steps:
			continue
		for nb: Vector2i in _four_neighbors(cell):
			if visited.has(nb):
				continue
			if not is_walkable(nb):
				continue
			# Block on occupied cells unless it's the moving unit itself.
			var occ: Node = get_occupant(nb)
			if occ != null and occ != moving_unit:
				continue
			visited[nb] = true
			queue.append([nb, steps + 1])

	return result


## Returns an A* path (wall-only blocking) from [param from_cell] to
## [param to_cell] as an ordered array of Vector2i cells.
## Empty if no path exists or destination is a wall.
## Named find_path (not get_path) to avoid shadowing Node.get_path()->NodePath.
func find_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	if not is_walkable(to_cell):
		return []
	var path: Array[Vector2i] = []
	# get_id_path returns Array[Vector2i] in Godot 4.0+; assign() handles
	# the typed-array conversion safely even if the runtime type differs.
	path.assign(_astar.get_id_path(from_cell, to_cell))
	return path


func _four_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x,     cell.y - 1),
		Vector2i(cell.x,     cell.y + 1),
	]

# ── Highlight API (called by TurnManager) ────────────────────────────────────

func set_move_highlights(cells: Array[Vector2i]) -> void:
	_move_cells = cells
	queue_redraw()


func set_attack_highlights(cells: Array[Vector2i]) -> void:
	_attack_cells = cells
	queue_redraw()


func clear_highlights() -> void:
	_move_cells   = []
	_attack_cells = []
	queue_redraw()

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# get_local_mouse_position() returns position in this node's local space.
		var cell: Vector2i = world_to_cell(get_local_mouse_position())
		if cell != _hovered_cell:
			_hovered_cell = cell
			queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	# 1. Floor / wall tiles
	for row: int in range(ROWS):
		for col: int in range(COLS):
			var cell: Vector2i = Vector2i(col, row)
			var rect: Rect2 = _cell_rect(cell)
			if is_wall(cell):
				_draw_wall_tile(rect)
			else:
				draw_rect(rect, C_FLOOR)
			draw_rect(rect, C_LINE, false, 1.0)

	# 2. Movement highlights
	for cell: Vector2i in _move_cells:
		if is_in_bounds(cell):
			draw_rect(_cell_rect(cell), C_MOVE)

	# 3. Attack highlights
	for cell: Vector2i in _attack_cells:
		if is_in_bounds(cell):
			draw_rect(_cell_rect(cell), C_ATTACK)

	# 4. Hover overlay (on top of highlights)
	if is_in_bounds(_hovered_cell):
		draw_rect(_cell_rect(_hovered_cell), C_HOVER)


func _draw_wall_tile(rect: Rect2) -> void:
	draw_rect(rect, C_WALL)
	# Simple decorative crack marks to distinguish walls from floor.
	var tl: Vector2 = rect.position + Vector2(6, 6)
	var br: Vector2 = rect.position + rect.size - Vector2(6, 6)
	var mid: Vector2 = rect.get_center()
	draw_line(tl,              mid - Vector2(4, 4), C_WALL_CRACK, 1.0)
	draw_line(mid + Vector2(4, 4), br,              C_WALL_CRACK, 1.0)
	draw_line(Vector2(tl.x, br.y), mid + Vector2(-4, 4), C_WALL_CRACK, 1.0)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE),
		Vector2(CELL_SIZE, CELL_SIZE)
	)
