extends Control
## Run 3: Victory screen shown after clearing a floor.
## Displays floor number, kills, XP; player confirms to descend.
## Reads GameState.last_battle_kills / last_battle_xp set by BattleScene.

signal victory_confirmed

const QUIPS: Array[String] = [
	"Floor cleared. The System is... marginally impressed.",
	"All enemies neutralized. Statistically, you should be dead.",
	"You survived. The dungeon is taking notes.",
	"Enemies eliminated. Efficiency: debatable. Result: acceptable.",
	"They fell. As things in dungeons do. Descend further.",
	"Floor complete. The System reluctantly tallies your score.",
]

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.06, 1.0)
	add_child(bg)

	# Outer CanvasLayer to keep UI above everything
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root_vbox.custom_minimum_size = Vector2(700.0, 480.0)
	root_vbox.offset_left = -350.0
	root_vbox.offset_top = -240.0
	root_vbox.offset_right = 350.0
	root_vbox.offset_bottom = 240.0
	root_vbox.add_theme_constant_override("separation", 18)
	add_child(root_vbox)

	# "FLOOR N CLEARED" title
	var title := Label.new()
	title.text = "FLOOR %d CLEARED" % GameState.floor_num
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
	title.modulate.a = 0.0
	root_vbox.add_child(title)

	# Fade in title
	var tw: Tween = create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.5)

	# The System quip
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run_seed + GameState.floor_num * 173
	var quip_lbl := Label.new()
	quip_lbl.text = QUIPS[rng.randi_range(0, QUIPS.size() - 1)]
	quip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip_lbl.add_theme_font_size_override("font_size", 17)
	quip_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.60))
	quip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip_lbl.custom_minimum_size = Vector2(600.0, 0.0)
	root_vbox.add_child(quip_lbl)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.35, 0.28, 0.45))
	root_vbox.add_child(sep)

	# Stats panel
	var stats_panel := PanelContainer.new()
	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 10)
	stats_panel.add_child(stats_vbox)
	root_vbox.add_child(stats_panel)

	var stat_rows: Array[Dictionary] = [
		{"label": "Enemies Slain", "value": str(GameState.last_battle_kills), "color": Color(0.9, 0.35, 0.1)},
		{"label": "XP Earned",     "value": str(GameState.last_battle_xp),    "color": Color(0.3, 0.85, 0.3)},
		{"label": "Current Level", "value": str(GameState.hero_level),         "color": Color(0.55, 0.75, 1.0)},
		{"label": "HP Remaining",  "value": "%d / %d" % [GameState.hero_hp, GameState.hero_max_hp], "color": Color(0.85, 0.25, 0.25)},
	]
	for row: Dictionary in stat_rows:
		var row_hbox := HBoxContainer.new()
		row_hbox.custom_minimum_size = Vector2(500.0, 0.0)
		var k_lbl := Label.new()
		k_lbl.text = row["label"]
		k_lbl.add_theme_font_size_override("font_size", 18)
		k_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_child(k_lbl)
		var v_lbl := Label.new()
		v_lbl.text = row["value"]
		v_lbl.add_theme_font_size_override("font_size", 20)
		v_lbl.add_theme_color_override("font_color", row["color"])
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row_hbox.add_child(v_lbl)
		stats_vbox.add_child(row_hbox)

	# Second separator
	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.35, 0.28, 0.45))
	root_vbox.add_child(sep2)

	# "DESCEND" button
	var btn := Button.new()
	btn.text = "DESCEND ↓"
	btn.custom_minimum_size = Vector2(280.0, 58.0)
	btn.add_theme_font_size_override("font_size", 24)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_descend)
	root_vbox.add_child(btn)

func _on_descend() -> void:
	victory_confirmed.emit()
