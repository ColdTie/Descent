extends Control
## Victory screen shown after clearing a floor.
## Run 11: styled stone panel, shadow title, stat cards with borders.

signal floor_cleared

var xp_earned: int = 0
var enemies_killed: int = 0

func prepare(data: Dictionary) -> void:
	xp_earned      = data.get("xp", 0)
	enemies_killed = data.get("kills", 0)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# ── Background ────────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color(0.40, 0.05, 0.0, 0.14)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glow)

	# ── Stone panel ───────────────────────────────────────────────────────────
	var outer := PanelContainer.new()
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.offset_left   = -510.0
	outer.offset_top    = -288.0
	outer.offset_right  =  510.0
	outer.offset_bottom =  288.0
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.10, 0.98)
	s.border_color = Color(0.54, 0.41, 0.09)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(30.0)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.80)
	s.shadow_size  = 14
	outer.add_theme_stylebox_override("panel", s)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	outer.add_child(vbox)

	# ── Floor label ───────────────────────────────────────────────────────────
	var floor_lbl := Label.new()
	floor_lbl.text = "▶  FLOOR %d / %d  ◀" % [GameState.floor_num, GameState.TOTAL_FLOORS]
	floor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_lbl.add_theme_font_size_override("font_size", 20)
	floor_lbl.add_theme_color_override("font_color", Color(0.60, 0.48, 0.18))
	vbox.add_child(floor_lbl)

	# ── Progress bar ──────────────────────────────────────────────────────────
	var prog_row := HBoxContainer.new()
	prog_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(prog_row)

	var prog_bg := ColorRect.new()
	prog_bg.custom_minimum_size = Vector2(940.0, 8.0)
	prog_bg.color = Color(0.10, 0.08, 0.15)
	prog_bg.mouse_filter = MOUSE_FILTER_IGNORE
	prog_row.add_child(prog_bg)

	var prog_fill := ColorRect.new()
	prog_fill.color = Color(0.60, 0.45, 0.08)
	prog_fill.custom_minimum_size = Vector2(0.0, 8.0)
	prog_fill.mouse_filter = MOUSE_FILTER_IGNORE
	prog_bg.add_child(prog_fill)
	var fill_w: float = 940.0 * clampf(
		float(GameState.floor_num) / float(GameState.TOTAL_FLOORS), 0.0, 1.0)
	var tw_prog: Tween = create_tween()
	tw_prog.tween_property(prog_fill, "custom_minimum_size:x", fill_w, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# ── "CLEARED!" title with shadow ──────────────────────────────────────────
	var title_wrap := Control.new()
	title_wrap.custom_minimum_size = Vector2(0.0, 104.0)
	vbox.add_child(title_wrap)

	var shadow_lbl := Label.new()
	shadow_lbl.text = "CLEARED!"
	shadow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shadow_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow_lbl.offset_left = 3.0; shadow_lbl.offset_top = 4.0
	shadow_lbl.add_theme_font_size_override("font_size", 90)
	shadow_lbl.add_theme_color_override("font_color", Color(0.28, 0.12, 0.0, 0.65))
	title_wrap.add_child(shadow_lbl)

	var title := Label.new()
	title.text = "CLEARED!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_theme_font_size_override("font_size", 90)
	title.add_theme_color_override("font_color", Color(0.97, 0.79, 0.10))
	title.modulate.a = 0.0
	title_wrap.add_child(title)
	var tw_title: Tween = create_tween()
	tw_title.tween_property(title, "modulate:a", 1.0, 0.55)

	# ── Gold divider ──────────────────────────────────────────────────────────
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(940.0, 2.0)
	divider.color = Color(0.50, 0.38, 0.08, 0.65)
	divider.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	# ── System quip ───────────────────────────────────────────────────────────
	var quip := Label.new()
	quip.text = SystemVoice.pick("victory")
	quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip.add_theme_font_size_override("font_size", 17)
	quip.add_theme_color_override("font_color", Color(0.76, 0.74, 0.62))
	quip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip.custom_minimum_size = Vector2(900.0, 0.0)
	vbox.add_child(quip)

	# ── Stat cards ────────────────────────────────────────────────────────────
	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 18)
	vbox.add_child(stats_row)

	_stat_card(stats_row, "⚔", "ENEMIES",   str(enemies_killed),
		Color(0.90, 0.28, 0.16))
	_stat_card(stats_row, "✦", "XP EARNED", str(xp_earned),
		Color(0.28, 0.82, 0.38))
	_stat_card(stats_row, "◆", "LEVEL",     str(GameState.hero_level),
		Color(0.38, 0.60, 1.00))
	var hp_ratio: float = float(GameState.hero_hp) / float(max(1, GameState.hero_max_hp))
	_stat_card(stats_row, "❤", "HP",
		"%d / %d" % [GameState.hero_hp, GameState.hero_max_hp],
		Color(0.18, 0.90, 0.22) if hp_ratio > 0.50 else Color(1.0, 0.38, 0.08))

	# ── Button ────────────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn := Button.new()
	btn.text = "▼  DESCEND DEEPER  ▼"
	btn.custom_minimum_size = Vector2(300.0, 58.0)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.96, 0.76, 0.10))
	btn.pressed.connect(_on_descend_pressed)
	btn_row.add_child(btn)


func _stat_card(parent: Node, icon: String, label_text: String,
		value_text: String, val_color: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200.0, 90.0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.09, 0.07, 0.13, 0.96)
	ps.border_color = val_color.darkened(0.42)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(4)
	ps.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)

	var ico := Label.new()
	ico.text = icon
	ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ico.add_theme_font_size_override("font_size", 22)
	ico.add_theme_color_override("font_color", val_color)
	col.add_child(ico)

	var val := Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 26)
	val.add_theme_color_override("font_color", val_color)
	col.add_child(val)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.48, 0.46, 0.50))
	col.add_child(lbl)


func _on_descend_pressed() -> void:
	floor_cleared.emit()
