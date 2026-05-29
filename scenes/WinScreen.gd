extends Control
## Shown when the hero clears all 18 floors — a true victory.

signal play_again

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Triumphant gold glow
	var glow := ColorRect.new()
	glow.color = Color(0.6, 0.45, 0.0, 0.12)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glow)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -500.0
	center.offset_top = -300.0
	center.offset_right = 500.0
	center.offset_bottom = 300.0
	center.add_theme_constant_override("separation", 18)
	add_child(center)

	var floor_lbl := Label.new()
	floor_lbl.text = "ALL %d FLOORS CONQUERED" % GameState.TOTAL_FLOORS
	floor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_lbl.add_theme_font_size_override("font_size", 20)
	floor_lbl.add_theme_color_override("font_color", Color(0.65, 0.52, 0.2))
	center.add_child(floor_lbl)

	var title := Label.new()
	title.text = "YOU WIN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	title.modulate.a = 0.0
	center.add_child(title)
	var tw: Tween = create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.8)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.6, 0.48, 0.1, 0.7))
	center.add_child(sep)

	# System voice — reluctant praise, from the SystemVoice "win" pool
	var quip_lbl := Label.new()
	quip_lbl.text = SystemVoice.pick("win")
	quip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip_lbl.add_theme_font_size_override("font_size", 18)
	quip_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.65))
	quip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip_lbl.custom_minimum_size = Vector2(960.0, 0.0)
	center.add_child(quip_lbl)

	# Stats grid
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 60)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(stats)
	_stat_card(stats, "◆ LEVEL", str(GameState.hero_level), Color(0.4, 0.6, 1.0))
	_stat_card(stats, "❤ HP", "%d/%d" % [GameState.hero_hp, GameState.hero_max_hp], Color(0.2, 0.9, 0.2))
	_stat_card(stats, "✦ XP", str(GameState.hero_xp), Color(0.3, 0.8, 0.4))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 12.0)
	center.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(btn_row)

	var btn := Button.new()
	btn.text = "PLAY AGAIN"
	btn.custom_minimum_size = Vector2(260.0, 58.0)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_on_play_again)
	btn_row.add_child(btn)

func _stat_card(parent: Node, label_text: String, value_text: String, color: Color) -> void:
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
	val.add_theme_color_override("font_color", color)
	card.add_child(val)

	parent.add_child(card)

func _on_play_again() -> void:
	play_again.emit()
