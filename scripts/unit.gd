## unit.gd — stats, weapons, HP, signals, and visual placeholder rendering.
##
## Drawing uses _draw() with distinctive silhouettes:
##   • Carl:   tall rectangle with bathrobe collar lines + head circle.
##   • Goblins: shorter hunched shape with ear bumps and red eyes.
## Milestone 8 adds: damage-flash overlay, name label via draw_string.
## Milestone 8+ will replace _draw with a proper Sprite2D + animation sheet.
class_name Unit
extends Node2D

# ── Signals ───────────────────────────────────────────────────────────────────

signal damaged(amount: int)
signal died

# ── Exported configuration ────────────────────────────────────────────────────

@export var unit_name: String = "Unknown"
@export var max_hp: int = 10
@export var move_range: int = 4
@export var defense: int = 10
@export var is_player: bool = false
@export var weapons: Array[Weapon] = []

## Primary body colour (blue for Carl, green for goblins).
@export var body_color: Color = Color(0.5, 0.5, 0.5)

# ── Runtime state ─────────────────────────────────────────────────────────────

var hp: int = 0
var grid_cell: Vector2i = Vector2i.ZERO
var is_alive: bool = true

# ── Visual constants ──────────────────────────────────────────────────────────

const BODY_W: int   = 40   ## Sprite body width
const BODY_H: int   = 44   ## Sprite body height
const HALF_W: float = BODY_W * 0.5
const HALF_H: float = BODY_H * 0.5

const HP_BAR_W: int   = 48
const HP_BAR_H: int   = 6
const HP_BAR_Y: float = -HALF_H - 12.0  ## above the body

const C_HEAD:    Color = Color(0.92, 0.78, 0.64)   ## skin tone
const C_OUTLINE: Color = Color(0.0,  0.0,  0.0,  0.85)
const C_ACTIVE:  Color = Color(1.0,  1.0,  1.0,  1.0)
const C_HP_BG:   Color = Color(0.12, 0.12, 0.12)
const C_HP_OK:   Color = Color(0.25, 0.85, 0.30)
const C_HP_LOW:  Color = Color(0.85, 0.25, 0.20)
const C_NAME:    Color = Color(0.88, 0.88, 0.88)
const C_FLASH:   Color = Color(1.0,  0.2,  0.2,  0.55)

# ── Damage-flash state ────────────────────────────────────────────────────────

var _flash_t: float = 0.0     ## Counts down; red overlay while > 0
var _is_active_turn: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	hp = max_hp


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta)
		queue_redraw()

# ── Public API ────────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	_flash_t = 0.42        # Trigger red-flash overlay
	queue_redraw()
	damaged.emit(amount)
	if hp <= 0 and is_alive:
		is_alive = false
		died.emit()


func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	queue_redraw()


func get_attack_weapon() -> Weapon:
	for w: Weapon in weapons:
		if not w.is_consumable:
			return w
	return null


func get_heal_item() -> Weapon:
	for w: Weapon in weapons:
		if w.is_consumable:
			return w
	return null


func set_active(active: bool) -> void:
	_is_active_turn = active
	queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if is_player:
		_draw_carl()
	else:
		_draw_goblin()
	_draw_hp_bar()
	_draw_name_label()
	if _flash_t > 0.0:
		_draw_damage_flash()


func _draw_carl() -> void:
	# ── Bathrobe body ─────────────────────────────────────────────────────────
	var body := Rect2(Vector2(-HALF_W, -HALF_H), Vector2(BODY_W, BODY_H))
	draw_rect(body, body_color)

	# Bathrobe collar: two diagonal lines forming a V
	var neck_top  := Vector2(0.0, -HALF_H + 4)
	var left_hip  := Vector2(-HALF_W + 5, HALF_H - 8)
	var right_hip := Vector2( HALF_W - 5, HALF_H - 8)
	var collar_col: Color = body_color.darkened(0.30)
	draw_line(neck_top, left_hip,  collar_col, 2.0)
	draw_line(neck_top, right_hip, collar_col, 2.0)

	# Belt line (boxer waistband)
	draw_line(
		Vector2(-HALF_W, 4), Vector2(HALF_W, 4),
		body_color.darkened(0.25), 1.5
	)

	# Head
	draw_circle(Vector2(0, -HALF_H - 9), 9.0, C_HEAD)

	# Outline (bright white when active)
	var oc: Color = C_ACTIVE if _is_active_turn else C_OUTLINE
	var ow: float = 2.5 if _is_active_turn else 1.5
	draw_rect(body, oc, false, ow)


func _draw_goblin() -> void:
	# ── Hunched green body ────────────────────────────────────────────────────
	# Slightly offset downward and shorter than Carl — goblin posture.
	var body := Rect2(Vector2(-HALF_W + 3, -HALF_H + 5), Vector2(BODY_W - 6, BODY_H - 5))
	draw_rect(body, body_color)

	# Ear bumps (small rectangles poking out)
	var ear_h: int = 14
	var ear_w: int = 8
	draw_rect(Rect2(Vector2(-HALF_W + 3 - ear_w, -HALF_H + 8), Vector2(ear_w, ear_h)),
			body_color.lightened(0.12))
	draw_rect(Rect2(Vector2(HALF_W - 3,            -HALF_H + 8), Vector2(ear_w, ear_h)),
			body_color.lightened(0.12))

	# Eyes (two glowing red dots)
	draw_circle(Vector2(-8, -HALF_H + 16), 3.5, Color(0.90, 0.10, 0.10))
	draw_circle(Vector2( 8, -HALF_H + 16), 3.5, Color(0.90, 0.10, 0.10))
	# Eye gleam
	draw_circle(Vector2(-7, -HALF_H + 15), 1.2, Color(1.0, 0.6, 0.6))
	draw_circle(Vector2( 9, -HALF_H + 15), 1.2, Color(1.0, 0.6, 0.6))

	# Tusk marks below eyes
	draw_line(Vector2(-6, -HALF_H + 22), Vector2(-4, -HALF_H + 28),
			Color(0.95, 0.90, 0.80), 1.5)
	draw_line(Vector2( 6, -HALF_H + 22), Vector2( 4, -HALF_H + 28),
			Color(0.95, 0.90, 0.80), 1.5)

	# Outline
	var oc: Color = C_ACTIVE if _is_active_turn else C_OUTLINE
	var ow: float = 2.5 if _is_active_turn else 1.5
	draw_rect(body, oc, false, ow)


func _draw_hp_bar() -> void:
	var bar_pos := Vector2(-HP_BAR_W * 0.5, HP_BAR_Y)
	# Background
	draw_rect(Rect2(bar_pos, Vector2(HP_BAR_W, HP_BAR_H)), C_HP_BG)
	# Fill
	var ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	if ratio > 0.0:
		var fill_col := C_HP_OK if ratio > 0.33 else C_HP_LOW
		draw_rect(Rect2(bar_pos, Vector2(HP_BAR_W * ratio, HP_BAR_H)), fill_col)
	# Border
	draw_rect(Rect2(bar_pos, Vector2(HP_BAR_W, HP_BAR_H)), C_OUTLINE, false, 1.0)


func _draw_name_label() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var y_pos: float = HP_BAR_Y - 4.0
	draw_string(font, Vector2(-HP_BAR_W * 0.5, y_pos),
		unit_name, HORIZONTAL_ALIGNMENT_LEFT, HP_BAR_W, 11, C_NAME)


func _draw_damage_flash() -> void:
	# Red flash fades out as _flash_t decays.
	var alpha: float = (_flash_t / 0.42) * C_FLASH.a
	var flash := Rect2(Vector2(-HALF_W - 2, -HALF_H - 2),
		Vector2(BODY_W + 4, BODY_H + 4))
	draw_rect(flash, Color(C_FLASH.r, C_FLASH.g, C_FLASH.b, alpha))
