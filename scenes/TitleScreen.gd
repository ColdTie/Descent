extends Control
## Title / main menu — the first thing the player sees.
## Branding, a System intro quip, how-to-play, an SFX toggle, and BEGIN DESCENT.

signal start_game

func _ready() -> void:
	AudioManager.play_music("music_title", 2.0)
	_build_ui()

func _build_ui() -> void:
	# ── Background ────────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Subtle warm glow from "below" — the dungeon beneath
	var glow := ColorRect.new()
	glow.color = Color(0.55, 0.18, 0.0, 0.07)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glow)

	# ── Center panel ──────────────────────────────────────────────────────────
	var outer := PanelContainer.new()
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.offset_left   = -440.0
	outer.offset_top    = -280.0
	outer.offset_right  =  440.0
	outer.offset_bottom =  280.0
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.10, 0.98)
	s.border_color = Color(0.72, 0.56, 0.10)
	s.set_border_width_all(3)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(34.0)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	s.shadow_size  = 18
	outer.add_theme_stylebox_override("panel", s)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	outer.add_child(vbox)

	# ── Title with drop shadow ────────────────────────────────────────────────
	var title_wrap := Control.new()
	title_wrap.custom_minimum_size = Vector2(0.0, 120.0)
	vbox.add_child(title_wrap)

	var shadow_lbl := Label.new()
	shadow_lbl.text = "DESCENT"
	shadow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shadow_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow_lbl.offset_left = 4.0; shadow_lbl.offset_top = 5.0
	shadow_lbl.add_theme_font_size_override("font_size", 92)
	shadow_lbl.add_theme_color_override("font_color", Color(0.30, 0.05, 0.0, 0.72))
	title_wrap.add_child(shadow_lbl)

	var title := Label.new()
	title.text = "DESCENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_theme_font_size_override("font_size", 92)
	title.add_theme_color_override("font_color", Color(0.92, 0.20, 0.12))
	title_wrap.add_child(title)
	var tw: Tween = create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.7).from(0.0)

	# ── Tagline ───────────────────────────────────────────────────────────────
	var tagline := Label.new()
	tagline.text = "18 floors down. The dungeon is watching. So is everyone else."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 16)
	tagline.add_theme_color_override("font_color", Color(0.78, 0.74, 0.62))
	vbox.add_child(tagline)

	# ── Divider ───────────────────────────────────────────────────────────────
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(800.0, 2.0)
	divider.color = Color(0.60, 0.20, 0.08, 0.6)
	divider.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	# ── How to play ───────────────────────────────────────────────────────────
	var howto := Label.new()
	howto.text = "Click a glowing tile to move.  Click an enemy to attack.\n" \
		+ "Select abilities from the bar, then click a target.\n" \
		+ "Survive each floor, choose your loot, and descend deeper."
	howto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	howto.add_theme_font_size_override("font_size", 14)
	howto.add_theme_color_override("font_color", Color(0.62, 0.62, 0.66))
	vbox.add_child(howto)

	# ── System quip ───────────────────────────────────────────────────────────
	var quip := Label.new()
	quip.text = SystemVoice.pick("title")
	quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip.add_theme_font_size_override("font_size", 15)
	quip.add_theme_color_override("font_color", Color(0.70, 0.66, 0.78))
	quip.custom_minimum_size = Vector2(800.0, 0.0)
	vbox.add_child(quip)

	# ── Buttons ───────────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	vbox.add_child(btn_row)

	var begin_btn := Button.new()
	begin_btn.text = "BEGIN DESCENT"
	begin_btn.custom_minimum_size = Vector2(320.0, 60.0)
	begin_btn.add_theme_font_size_override("font_size", 22)
	begin_btn.add_theme_color_override("font_color", Color(1.0, 0.86, 0.12))
	begin_btn.pressed.connect(_on_begin)
	btn_row.add_child(begin_btn)

	var sfx_btn := Button.new()
	sfx_btn.text = "SFX: ON" if AudioManager.sfx_enabled else "SFX: OFF"
	sfx_btn.custom_minimum_size = Vector2(130.0, 60.0)
	sfx_btn.add_theme_font_size_override("font_size", 16)
	sfx_btn.pressed.connect(_on_toggle_sfx.bind(sfx_btn))
	btn_row.add_child(sfx_btn)

	var music_btn := Button.new()
	music_btn.text = "MUSIC: ON" if AudioManager.music_enabled else "MUSIC: OFF"
	music_btn.custom_minimum_size = Vector2(150.0, 60.0)
	music_btn.add_theme_font_size_override("font_size", 16)
	music_btn.pressed.connect(_on_toggle_music.bind(music_btn))
	btn_row.add_child(music_btn)

func _on_begin() -> void:
	AudioManager.play("select")
	start_game.emit()

func _on_toggle_sfx(btn: Button) -> void:
	var on: bool = AudioManager.toggle_enabled()
	btn.text = "SFX: ON" if on else "SFX: OFF"
	if on:
		AudioManager.play("select")

func _on_toggle_music(btn: Button) -> void:
	var on: bool = AudioManager.toggle_music_enabled()
	btn.text = "MUSIC: ON" if on else "MUSIC: OFF"
	AudioManager.play("select")
