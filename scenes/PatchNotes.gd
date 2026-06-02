extends Control
## Run 20: DCC-style "patch notes" overlay shown at tier transitions.
##
## When the player is about to descend into floor 7 (Obsidian) or floor 13
## (Void), the System dumps a mocking dev-blog patch list. Pure flavor —
## no gameplay effect — narrating the difficulty spike that already happens
## via per-floor scaling and floor-gated enemy abilities.

signal patch_notes_dismissed

var _target_floor: int = 0

func prepare(data: Dictionary) -> void:
	_target_floor = int(data.get("floor", 0))

func _ready() -> void:
	# If `prepare` wasn't called (defensive), pull from GameState.
	if _target_floor == 0:
		_target_floor = GameState.floor_num + 1
	_build_ui()
	AudioManager.play("descend")
	var category: String = "patch_notes_v2" if _target_floor == 7 else "patch_notes_v3"
	SystemVoice.speak(category)

func _build_ui() -> void:
	var notes: Dictionary = PatchNotes.notes_for(_target_floor)

	# ── Background ────────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.02, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color(0.55, 0.18, 0.0, 0.10) if _target_floor == 7 \
		else Color(0.42, 0.12, 0.62, 0.12)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glow)

	# ── Stone panel ───────────────────────────────────────────────────────────
	var border_col: Color = Color(0.62, 0.38, 0.10) if _target_floor == 7 \
		else Color(0.58, 0.28, 0.82)

	var outer := PanelContainer.new()
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.offset_left  = -440.0
	outer.offset_top  = -260.0
	outer.offset_right  =  440.0
	outer.offset_bottom =  260.0
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.10, 0.98)
	s.border_color = border_col
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(28.0)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.80)
	s.shadow_size  = 14
	outer.add_theme_stylebox_override("panel", s)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	outer.add_child(vbox)

	# ── Header: SYSTEM // PATCH NOTES ────────────────────────────────────────
	var sys_tag := Label.new()
	sys_tag.text = "[ SYSTEM // PATCH NOTES ]"
	sys_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sys_tag.add_theme_font_size_override("font_size", 14)
	sys_tag.add_theme_color_override("font_color", border_col.lightened(0.20))
	vbox.add_child(sys_tag)

	# ── Version line ──────────────────────────────────────────────────────────
	var ver := Label.new()
	ver.text = String(notes.get("version", "v?.?"))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 34)
	ver.add_theme_color_override("font_color", border_col.lightened(0.40))
	vbox.add_child(ver)

	# ── Subtitle ──────────────────────────────────────────────────────────────
	var subtitle := Label.new()
	subtitle.text = String(notes.get("subtitle", ""))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.80, 0.78, 0.68))
	subtitle.custom_minimum_size = Vector2(820.0, 0.0)
	vbox.add_child(subtitle)

	# ── Divider ───────────────────────────────────────────────────────────────
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(820.0, 1.0)
	div.color = border_col.darkened(0.30)
	div.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(div)

	# ── Notes block ───────────────────────────────────────────────────────────
	var notes_vbox := VBoxContainer.new()
	notes_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(notes_vbox)

	var lines: Array = notes.get("lines", [])
	for line: String in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", _line_color(line, border_col))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(820.0, 0.0)
		notes_vbox.add_child(lbl)

	# ── Closing line ──────────────────────────────────────────────────────────
	var closing := Label.new()
	closing.text = String(notes.get("closing", ""))
	closing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	closing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	closing.add_theme_font_size_override("font_size", 13)
	closing.add_theme_color_override("font_color", Color(0.62, 0.58, 0.52))
	closing.custom_minimum_size = Vector2(820.0, 0.0)
	vbox.add_child(closing)

	# ── Continue button ───────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn := Button.new()
	btn.text = "  ACKNOWLEDGE & DESCEND  "
	btn.custom_minimum_size = Vector2(320.0, 52.0)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", border_col.lightened(0.40))
	btn.pressed.connect(_on_continue)
	btn_row.add_child(btn)

func _line_color(line: String, accent: Color) -> Color:
	if line.begins_with("+"):
		return Color(0.40, 0.86, 0.46)
	if line.begins_with("-"):
		return Color(0.96, 0.42, 0.38)
	if line.begins_with("#"):
		return accent.lightened(0.20)
	return Color(0.82, 0.80, 0.70)

func _on_continue() -> void:
	AudioManager.play("descend")
	patch_notes_dismissed.emit()
