## BattleScene — root controller for the combat encounter.
## Owns Grid, UnitsContainer, TurnManager (added in M5), and UI (added in M7).
extends Node2D

# ── Preloads ──────────────────────────────────────────────────────────────────

const UnitScene: PackedScene = preload("res://scenes/Unit.tscn")

const W_RUSTY_SHIV:  Weapon = preload("res://resources/weapon_rusty_shiv.tres")
const W_BANDAGE:     Weapon = preload("res://resources/weapon_bandage.tres")
const W_GOBLIN_CLAW: Weapon = preload("res://resources/weapon_goblin_claw.tres")

# ── Spawn positions ───────────────────────────────────────────────────────────

## Carl starts on the left, mid-height.
const CARL_CELL: Vector2i = Vector2i(1, 4)

## Three goblins spread across the right side of the map.
const GOBLIN_CELLS: Array[Vector2i] = [
	Vector2i(10, 1),
	Vector2i(10, 5),
	Vector2i(10, 8),
]

# ── Node references ───────────────────────────────────────────────────────────

@onready var grid: Grid              = $Grid
@onready var units_container: Node2D = $UnitsContainer

## All units alive at start; used by TurnManager later.
var all_units: Array[Unit] = []

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_spawn_units()
	System.announce(&"battle_start", {})


# ── Spawning ──────────────────────────────────────────────────────────────────

func _spawn_units() -> void:
	# ── Carl ──────────────────────────────────────────────────────────────────
	var carl: Unit = UnitScene.instantiate() as Unit
	carl.unit_name  = "Carl"
	carl.max_hp     = 12
	carl.move_range = 5
	carl.defense    = 12
	carl.is_player  = true
	carl.body_color = Color(0.35, 0.55, 0.90)   # cornflower blue
	carl.weapons    = [W_RUSTY_SHIV.duplicate(), W_BANDAGE.duplicate()]
	_place_unit(carl, CARL_CELL)
	all_units.append(carl)

	# ── Goblins ───────────────────────────────────────────────────────────────
	for i: int in range(GOBLIN_CELLS.size()):
		var g: Unit = UnitScene.instantiate() as Unit
		g.unit_name  = "Goblin %d" % (i + 1)
		g.max_hp     = 5
		g.move_range = 4
		g.defense    = 11
		g.is_player  = false
		g.body_color = Color(0.30, 0.65, 0.30)  # goblin green
		g.weapons    = [W_GOBLIN_CLAW.duplicate()]
		_place_unit(g, GOBLIN_CELLS[i])
		all_units.append(g)


## Position [param unit] on [param cell], register it on the grid, and add
## it to the UnitsContainer.
func _place_unit(unit: Unit, cell: Vector2i) -> void:
	unit.grid_cell = cell
	# grid.position offsets the Grid node inside BattleScene; cell_to_world
	# returns the cell centre in Grid-local space.
	unit.position  = grid.position + grid.cell_to_world(cell)
	units_container.add_child(unit)
	grid.set_occupied(cell, unit)
	print("Spawned [%s] at cell %s  hp=%d/%d" % [
		unit.unit_name, cell, unit.max_hp, unit.max_hp])
