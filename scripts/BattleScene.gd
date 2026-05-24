## BattleScene — root controller for the combat encounter.
## Owns Grid, UnitsContainer, TurnManager, and UI.
extends Node2D

# ── Preloads ──────────────────────────────────────────────────────────────────

const UnitScene: PackedScene = preload("res://scenes/Unit.tscn")

const W_RUSTY_SHIV:  Weapon = preload("res://resources/weapon_rusty_shiv.tres")
const W_BANDAGE:     Weapon = preload("res://resources/weapon_bandage.tres")
const W_GOBLIN_CLAW: Weapon = preload("res://resources/weapon_goblin_claw.tres")

# ── Spawn positions ───────────────────────────────────────────────────────────

const CARL_CELL: Vector2i = Vector2i(1, 4)
const GOBLIN_CELLS: Array[Vector2i] = [
	Vector2i(10, 1),
	Vector2i(10, 5),
	Vector2i(10, 8),
]

# ── Node references ───────────────────────────────────────────────────────────

@onready var grid: Grid              = $Grid
@onready var units_container: Node2D = $UnitsContainer

var all_units: Array[Unit] = []

# ── UI (built in _ready) ──────────────────────────────────────────────────────

var _status_label: Label
var _end_turn_btn: Button
var _turn_manager: TurnManager

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_spawn_units()
	_build_ui()
	_start_turn_manager()

# ── Spawning ──────────────────────────────────────────────────────────────────

func _spawn_units() -> void:
	var carl: Unit = UnitScene.instantiate() as Unit
	carl.unit_name  = "Carl"
	carl.max_hp     = 12
	carl.move_range = 5
	carl.defense    = 12
	carl.is_player  = true
	carl.body_color = Color(0.35, 0.55, 0.90)
	carl.weapons    = [W_RUSTY_SHIV.duplicate(), W_BANDAGE.duplicate()]
	_place_unit(carl, CARL_CELL)
	all_units.append(carl)

	for i: int in range(GOBLIN_CELLS.size()):
		var g: Unit = UnitScene.instantiate() as Unit
		g.unit_name  = "Goblin %d" % (i + 1)
		g.max_hp     = 5
		g.move_range = 4
		g.defense    = 11
		g.is_player  = false
		g.body_color = Color(0.30, 0.65, 0.30)
		g.weapons    = [W_GOBLIN_CLAW.duplicate()]
		_place_unit(g, GOBLIN_CELLS[i])
		all_units.append(g)


func _place_unit(unit: Unit, cell: Vector2i) -> void:
	unit.grid_cell = cell
	unit.position  = grid.position + grid.cell_to_world(cell)
	units_container.add_child(unit)
	grid.set_occupied(cell, unit)

# ── UI ────────────────────────────────────────────────────────────────────────

## Builds the right-side panel: status label + End Turn button.
## All UI goes into a CanvasLayer so it draws over the 2D scene and
## isn't affected by any future camera transforms.
func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	# ── Right panel background ────────────────────────────────────────────────
	var panel_bg := ColorRect.new()
	panel_bg.color = Color(0.10, 0.08, 0.14)
	# Grid ends at x=20+768=788; panel starts at 796
	panel_bg.set_position(Vector2(796, 0))
	panel_bg.set_size(Vector2(484, 720))
	ui_layer.add_child(panel_bg)

	# ── Status label ──────────────────────────────────────────────────────────
	_status_label = Label.new()
	_status_label.position = Vector2(806, 20)
	_status_label.size     = Vector2(464, 100)
	_status_label.text     = "Rolling initiative…"
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_layer.add_child(_status_label)

	# ── End Turn button ───────────────────────────────────────────────────────
	_end_turn_btn = Button.new()
	_end_turn_btn.position = Vector2(806, 130)
	_end_turn_btn.size     = Vector2(200, 48)
	_end_turn_btn.text     = "End Turn"
	_end_turn_btn.add_theme_font_size_override("font_size", 16)
	ui_layer.add_child(_end_turn_btn)

	# ── Initiative legend (static) ────────────────────────────────────────────
	var legend := Label.new()
	legend.position = Vector2(806, 640)
	legend.size     = Vector2(464, 70)
	legend.text     = "[Blue] = reachable cells\n[Red]  = attackable enemies"
	legend.add_theme_font_size_override("font_size", 13)
	legend.modulate  = Color(0.7, 0.7, 0.7)
	ui_layer.add_child(legend)

# ── TurnManager ───────────────────────────────────────────────────────────────

func _start_turn_manager() -> void:
	_turn_manager = TurnManager.new()
	_turn_manager.name = "TurnManager"
	add_child(_turn_manager)
	_turn_manager.setup(grid, all_units, _status_label)
	_end_turn_btn.pressed.connect(_turn_manager.end_player_turn)
