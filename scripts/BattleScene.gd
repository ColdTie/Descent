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

# ── UI nodes ──────────────────────────────────────────────────────────────────

var _status_label:  Label
var _end_turn_btn:  Button
var _log_rtl:       RichTextLabel   ## Combat narrative log
var _banner_bg:     ColorRect       ## Dark overlay behind result text
var _result_banner: Label           ## VICTORY / DEFEAT overlay
var _turn_manager:  TurnManager

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

## Builds the right-side panel (status, End Turn, combat log) plus the
## center-screen result banner (hidden until battle ends).
func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	# ── Right panel background ────────────────────────────────────────────────
	var panel_bg := ColorRect.new()
	panel_bg.color        = Color(0.08, 0.06, 0.12, 1.0)
	panel_bg.position     = Vector2(796, 0)
	panel_bg.size         = Vector2(484, 720)
	ui_layer.add_child(panel_bg)

	# ── Status label (whose turn, last action) ────────────────────────────────
	_status_label = Label.new()
	_status_label.position      = Vector2(806, 14)
	_status_label.size          = Vector2(464, 80)
	_status_label.text          = "Rolling initiative…"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 15)
	ui_layer.add_child(_status_label)

	# ── End Turn button ───────────────────────────────────────────────────────
	_end_turn_btn          = Button.new()
	_end_turn_btn.position = Vector2(806, 100)
	_end_turn_btn.size     = Vector2(200, 44)
	_end_turn_btn.text     = "End Turn"
	_end_turn_btn.add_theme_font_size_override("font_size", 15)
	ui_layer.add_child(_end_turn_btn)

	# ── "Combat Log" section header ───────────────────────────────────────────
	var log_hdr := Label.new()
	log_hdr.position = Vector2(806, 156)
	log_hdr.size     = Vector2(464, 22)
	log_hdr.text     = "— Combat Log —"
	log_hdr.add_theme_font_size_override("font_size", 13)
	log_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_hdr.modulate             = Color(0.65, 0.60, 0.80)
	ui_layer.add_child(log_hdr)

	# ── Combat log RichTextLabel ──────────────────────────────────────────────
	_log_rtl                     = RichTextLabel.new()
	_log_rtl.position            = Vector2(806, 182)
	_log_rtl.size                = Vector2(464, 490)
	_log_rtl.bbcode_enabled      = true
	_log_rtl.scroll_active       = true
	_log_rtl.scroll_following    = true
	_log_rtl.add_theme_font_size_override("font_size", 13)
	ui_layer.add_child(_log_rtl)

	# Wire the log to System so all announce() calls appear here.
	System.set_log_label(_log_rtl)

	# ── Legend ────────────────────────────────────────────────────────────────
	var legend := Label.new()
	legend.position      = Vector2(806, 682)
	legend.size          = Vector2(464, 34)
	legend.text          = "Blue = move range    Red = attack range"
	legend.add_theme_font_size_override("font_size", 11)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.modulate             = Color(0.55, 0.55, 0.65)
	ui_layer.add_child(legend)

	# ── Result banner (hidden until battle ends) ──────────────────────────────
	_banner_bg          = ColorRect.new()
	_banner_bg.color    = Color(0.02, 0.02, 0.05, 0.82)
	_banner_bg.position = Vector2(0, 0)
	_banner_bg.size     = Vector2(796, 720)
	_banner_bg.visible  = false
	ui_layer.add_child(_banner_bg)

	_result_banner                    = Label.new()
	_result_banner.position           = Vector2(0, 280)
	_result_banner.size               = Vector2(796, 160)
	_result_banner.text               = ""
	_result_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_banner.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_result_banner.add_theme_font_size_override("font_size", 54)
	_result_banner.visible            = false
	_result_banner.name               = "ResultBanner"
	ui_layer.add_child(_result_banner)

# ── TurnManager ───────────────────────────────────────────────────────────────

func _start_turn_manager() -> void:
	_turn_manager = TurnManager.new()
	_turn_manager.name = "TurnManager"
	add_child(_turn_manager)
	_turn_manager.setup(grid, all_units, _status_label)
	_end_turn_btn.pressed.connect(_turn_manager.end_player_turn)
	_turn_manager.battle_ended.connect(_on_battle_ended)


func _on_battle_ended(player_won: bool) -> void:
	_banner_bg.visible     = true
	_result_banner.text    = "✦  VICTORY  ✦" if player_won else "✦  DEFEAT  ✦"
	_result_banner.modulate = Color(0.95, 0.90, 0.40) if player_won \
		else Color(0.90, 0.30, 0.25)
	_result_banner.visible = true
	_end_turn_btn.disabled = true
