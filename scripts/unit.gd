## unit.gd — stats, weapons, HP, signals, and placeholder rendering for a unit.
##
## Rendering note: Milestone 3 uses _draw() for placeholder art (coloured square
## + HP bar).  Milestone 8 will replace this with a proper Sprite2D + animation.
class_name Unit
extends Node2D

# ── Signals ───────────────────────────────────────────────────────────────────

signal damaged(amount: int)
signal died

# ── Exported configuration (set at spawn time by BattleScene) ─────────────────

@export var unit_name: String = "Unknown"
@export var max_hp: int = 10
@export var move_range: int = 4
@export var defense: int = 10

## true = player-controlled, false = enemy AI.
@export var is_player: bool = false

## Loadout.  Index order: attack weapons first, consumables last.
@export var weapons: Array[Weapon] = []

## Colour of the placeholder body rectangle.
@export var body_color: Color = Color(0.5, 0.5, 0.5)

# ── Runtime state ─────────────────────────────────────────────────────────────

## Current HP.  Initialised from max_hp in _ready().
var hp: int = 0

## Current grid cell (updated by TurnManager on move).
var grid_cell: Vector2i = Vector2i.ZERO

## True while the unit is alive and participating in the encounter.
var is_alive: bool = true

# ── Visual constants ──────────────────────────────────────────────────────────

const SPRITE_SIZE: int = 48
const HALF_SPRITE: float = SPRITE_SIZE * 0.5
const HP_BAR_W: int = 48
const HP_BAR_H: int = 6
# HP bar sits 4 px above the top edge of the body square.
const HP_BAR_Y: float = -HALF_SPRITE - HP_BAR_H - 4.0

const C_OUTLINE: Color = Color(0.0,  0.0,  0.0,  0.85)
const C_HP_BG:   Color = Color(0.15, 0.15, 0.15, 1.0)
const C_HP_OK:   Color = Color(0.25, 0.85, 0.30, 1.0)   # green
const C_HP_LOW:  Color = Color(0.85, 0.25, 0.20, 1.0)   # red (≤33 %)

# Active-turn indicator: bright outline when it is this unit's turn.
var _is_active_turn: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	hp = max_hp

# ── Public API ────────────────────────────────────────────────────────────────

## Reduce HP by [param amount].  Emits damaged; emits died if hp reaches 0.
func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	queue_redraw()
	damaged.emit(amount)
	if hp <= 0 and is_alive:
		is_alive = false
		died.emit()


## Restore HP by [param amount], capped at max_hp.
func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	queue_redraw()


## Returns the primary attack weapon (first non-consumable), or null.
func get_attack_weapon() -> Weapon:
	for w: Weapon in weapons:
		if not w.is_consumable:
			return w
	return null


## Returns the first consumable heal item, or null.
func get_heal_item() -> Weapon:
	for w: Weapon in weapons:
		if w.is_consumable:
			return w
	return null


## Called by TurnManager to visually highlight the active unit.
func set_active(active: bool) -> void:
	_is_active_turn = active
	queue_redraw()

# ── Rendering ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	# ── Body square ──────────────────────────────────────────────────────────
	var body_rect := Rect2(
		Vector2(-HALF_SPRITE, -HALF_SPRITE),
		Vector2(SPRITE_SIZE,  SPRITE_SIZE)
	)
	draw_rect(body_rect, body_color)

	# Active-turn highlight: bright white outline
	var outline_color := Color.WHITE if _is_active_turn else C_OUTLINE
	var outline_width: float = 2.5 if _is_active_turn else 1.5
	draw_rect(body_rect, outline_color, false, outline_width)

	# ── HP bar ────────────────────────────────────────────────────────────────
	var bar_pos := Vector2(-HP_BAR_W * 0.5, HP_BAR_Y)
	var bar_bg_rect := Rect2(bar_pos, Vector2(HP_BAR_W, HP_BAR_H))
	draw_rect(bar_bg_rect, C_HP_BG)

	var ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	if ratio > 0.0:
		var fill_color := C_HP_OK if ratio > 0.33 else C_HP_LOW
		var fill_rect := Rect2(bar_pos, Vector2(HP_BAR_W * ratio, HP_BAR_H))
		draw_rect(fill_rect, fill_color)
