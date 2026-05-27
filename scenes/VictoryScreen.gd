extends Control
## Victory screen shown after clearing a floor.
## Displays floor stats, System quip, then lets player descend deeper.
## Run 5: Boss-defeated variant, floor progress bar.

signal floor_cleared

# Set these before adding to the scene tree (Main.gd calls prepare()).
var xp_earned: int = 0
var enemies_killed: int = 0
var was_boss_floor: bool = false

const QUIPS: Array[String] = [
	"Floor cleared. The dungeon is mildly impressed. That's as good as it gets.",
	"All hostiles eliminated. The System awards a grudging nod.",
	"You survived. Statistically, this was improbable.",
	"Victory. The dungeon recalibrates. You should be concerned.",
	"Enemies defeated. You remain alive. For now.",
	"Floor complete. Something worse waits below.",
]

const BOSS_QUIPS: Array[String] = [
	"Boss defeated. The dungeon registers this as a critical system error.",
	"Named entity eliminated. The System is... recalculating.",
	"Boss dead. You weren't supposed to be able to do that.",
	"Champion slain. The dungeon files a formal complaint with HR.",
	"Boss floor cleared. The dungeon's middle management has been decimated.",
]

func prepare(data: Dictionary) -> void:
	## Called by Main before adding to scene tree.
	xp_earned = data.get("xp", 0)
	enemies_killed = data.get("kills", 0)
	was_boss_floor = data.get("was_boss_floor", false)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Cave atmosphere overlay — faint red glow from below
	var glow := ColorRect.new()
	glow.color = Color(0.45, 0.06, 0.0, 0.18)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glow)

	# Center container
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -480.0
	center.offset_top = -260.0
	center.offset_right = 480.0
	center.offset_bottom = 260.0
	center.add_theme_constant_override("separation", 20)
	add_child(center)

	# Floor progress bar row
	var progress_row := HBoxContainer.new()
	progress_row.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_row.add_theme_constant_override("separation", 8)
	center.add_child(progress_row)

	var prog_prefix := Label.new()
	prog_prefix.text = "FLOOR %d / %d" % [GameState.floor_num, GameState.run_length]
	prog_prefix.add_theme_font_size_override("font_size", 16)
	if was_boss_floor:
		prog_prefix.add_theme_color_override("font_color", Color(0.95, 0.5, 0.1))
	else:
		prog_prefix.add_theme_color_override("font_color", Color(0.6, 0.5, 0.3))
	progress_row.add_child(prog_prefix)

	# Progress bar track
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(320.0, 14.0)
	bar_bg.color = Color(0.15, 0.12, 0.08)
	progress_row.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	var fill_ratio: float = float(GameState.floor_num) / float(max(1, GameState.run_length))
	bar_fill.size = Vector2(320.0 * fill_ratio, 14.0)
	bar_fill.color = Color(0.95, 0.55, 0.1) if was_boss_floor else Color(0.3, 0.7, 0.95)
	bar_bg.add_child(bar_fill)

	# Boss marker dots at every 5th floor
	for bfl: int in range(5, GameState.run_length + 1, 5):
		var marker_x: float = 320.0 * float(bfl) / float(max(1, GameState.run_length))
		var marker := ColorRect.new()
		marker.size = Vector2(3.0, 14.0)
		marker.position = Vector2(marker_x - 1.5, 0.0)
		marker.color = Color(0.9, 0.2, 0.1, 0.8)
		bar_bg.add_child(marker)

	# "CLEARED!" or "BOSS DEFEATED!" title
	var title := Label.new()
	if was_boss_floor:
		title.text = "BOSS DEFEATED!"
		title.add_theme_color_override("font_color", Color(0.95, 0.4, 0.05))
	else:
		title.text = "CLEARED!"
		title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", was_boss_floor ? 72 : 88)
	title.modulate.a = 0.0
	center.add_child(title)
	# Fade in animation
	var tw_title: Tween = create_tween()
	tw_title.tween_property(title, "modulate:a", 1.0, 0.55)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.4, 0.3, 0.1, 0.6))
	center.add_child(sep)

	# System quip
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run_seed + GameState.floor_num * 1337
	var quip_pool: Array[String] = BOSS_QUIPS if was_boss_floor else QUIPS
	var quip_idx: int = rng.randi_range(0, quip_pool.size() - 1)
	var quip_lbl := Label.new()
	quip_lbl.text = quip_pool[quip_idx]
	quip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip_lbl.add_theme_font_size_override("font_size", 18)
	quip_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.65))
	quip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip_lbl.custom_minimum_size = Vector2(900.0, 0.0)
	center.add_child(quip_lbl)

	# Stats row
	var stats_container := HBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 60)
	stats_container.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(stats_container)

	_add_stat_card(stats_container, "⚔ ENEMIES", str(enemies_killed), Color(0.9, 0.3, 0.2))
	_add_stat_card(stats_container, "✦ XP EARNED", str(xp_earned), Color(0.3, 0.8, 0.4))
	_add_stat_card(stats_container, "◆ LEVEL", str(GameState.hero_level), Color(0.4, 0.6, 1.0))
	_add_stat_card(stats_container, "❤ HP", "%d/%d" % [GameState.hero_hp, GameState.hero_max_hp],
		Color(0.2, 0.9, 0.2) if float(GameState.hero_hp) / float(max(1, GameState.hero_max_hp)) > 0.5 else Color(1.0, 0.4, 0.1))

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 10.0)
	center.add_child(spacer)

	# "DESCEND DEEPER" button
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(btn_container)

	var btn := Button.new()
	btn.text = "DESCEND DEEPER ▼"
	btn.custom_minimum_size = Vector2(280.0, 58.0)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_on_descend_pressed)
	btn_container.add_child(btn)

func _add_stat_card(parent: Node, label_text: String, value_text: String, value_color: Color) -> void:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	card.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 28)
	val.add_theme_color_override("font_color", value_color)
	card.add_child(val)

	parent.add_child(card)

func _on_descend_pressed() -> void:
	floor_cleared.emit()
