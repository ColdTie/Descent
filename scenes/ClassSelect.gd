extends Control
## Class selection screen — the front end of each run.
## Run 6: portrait images from assets/portraits/, styled cards with class colors.

const CARD_WIDTH:  float = 240.0
const CARD_HEIGHT: float = 420.0

var _selected_class: String = ""

@onready var _class_cards: HBoxContainer = $VBox/ClassCards
@onready var _start_button: Button       = $VBox/StartButton
@onready var _system_label: Label        = $VBox/SystemLabel

func _ready() -> void:
	SystemVoice.speak("class_select")
	SystemVoice.line_spoken.connect(_on_system_line)
	_draw_bg_decoration()
	_build_class_cards()
	_start_button.pressed.connect(_on_start_pressed)

func _on_system_line(text: String, _dur: float) -> void:
	_system_label.text = text

# ── Background torch-flicker decoration ───────────────────────────────────────

func _draw_bg_decoration() -> void:
	# Subtle vignette corners — MOUSE_FILTER_IGNORE so they don't eat clicks
	for cfg: Array in [
		[0, 0, 420, 720],      # left
		[860, 0, 420, 720],    # right
	]:
		var cr := ColorRect.new()
		cr.position     = Vector2(cfg[0], cfg[1])
		cr.size         = Vector2(cfg[2], cfg[3])
		cr.color        = Color(0.0, 0.0, 0.0, 0.35)
		cr.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(cr)
		move_child(cr, 0)   # push behind the VBox

	# Three class-color column tints
	var glow_colors: Array[Color] = [
		Color(0.7, 0.15, 0.05, 0.14),   # brawler red
		Color(0.12, 0.72, 0.28, 0.10),  # rogue green
		Color(0.18, 0.28, 0.88, 0.12),  # arcanist blue
	]
	var glow_xs: Array[float] = [320.0, 640.0, 960.0]
	for i: int in range(3):
		var cr2 := ColorRect.new()
		cr2.size         = Vector2(320.0, 720.0)
		cr2.position     = Vector2(glow_xs[i] - 160.0, 0.0)
		cr2.color        = glow_colors[i]
		cr2.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(cr2)
		move_child(cr2, 0)   # push behind the VBox

# ── Class cards ────────────────────────────────────────────────────────────────

func _build_class_cards() -> void:
	for class_id: String in Classes.all_ids():
		_class_cards.add_child(_make_class_card(class_id))

func _make_class_card(class_id: String) -> PanelContainer:
	var cls:       Dictionary = Classes.get_class_data(class_id)
	var cls_color: Color      = cls.get("icon_color", Color.WHITE)
	var stats:     Dictionary = cls.get("stats", {})

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	# Tinted background for this class
	var bg := StyleBoxFlat.new()
	bg.bg_color           = Color(0.07, 0.05, 0.10, 1.0)
	bg.border_color       = cls_color.darkened(0.35)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.theme_override_constants_separation = 4
	panel.add_child(vbox)

	# ── Portrait image ──────────────────────────────────────────────────────
	# Try 200×190 portrait first, fall back to battle sprite, then color swatch.
	var portrait_tex: Texture2D = _try_load_tex(
		"res://assets/portraits/%s.png" % class_id,
		"res://assets/sprites/hero_%s.png" % class_id
	)
	if portrait_tex != null:
		var portrait := TextureRect.new()
		# 200×220 DCSS pixel-art portraits — keep pixel aspect, use NEAREST filter
		portrait.custom_minimum_size = Vector2(CARD_WIDTH - 4.0, 248.0)
		portrait.texture       = portrait_tex
		portrait.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
		portrait.texture_filter= CanvasItem.TEXTURE_FILTER_NEAREST
		vbox.add_child(portrait)
	else:
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(CARD_WIDTH - 4.0, 120.0)
		swatch.color        = cls_color.darkened(0.3)
		swatch.mouse_filter = MOUSE_FILTER_IGNORE
		vbox.add_child(swatch)

	# Class color strip — ignore mouse so it doesn't block the card's button
	var strip := ColorRect.new()
	strip.custom_minimum_size = Vector2(CARD_WIDTH - 4.0, 3.0)
	strip.color        = cls_color
	strip.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(strip)

	# ── Class name ──────────────────────────────────────────────────────────
	var name_lbl := Label.new()
	name_lbl.text = cls.get("display_name", class_id).to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", cls_color.lightened(0.15))
	vbox.add_child(name_lbl)

	# ── Stats ───────────────────────────────────────────────────────────────
	var stats_lbl := Label.new()
	stats_lbl.text = "HP %d  ·  ATK %d  ·  DEF %d  ·  SPD %d" % [
		cls.get("hp", 0),
		stats.get("attack", 0),
		stats.get("defense", 0),
		stats.get("speed", 0),
	]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.65))
	vbox.add_child(stats_lbl)

	# ── Description ─────────────────────────────────────────────────────────
	var desc_lbl := Label.new()
	desc_lbl.text = cls.get("description", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.58))
	desc_lbl.custom_minimum_size = Vector2(CARD_WIDTH - 18.0, 0.0)
	vbox.add_child(desc_lbl)

	# ── Abilities ───────────────────────────────────────────────────────────
	var abilities: Array = cls.get("abilities", [])
	var abl_lbl := Label.new()
	abl_lbl.text = "✦ " + "   ✦ ".join(abilities)
	abl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abl_lbl.add_theme_font_size_override("font_size", 10)
	abl_lbl.add_theme_color_override("font_color", cls_color.lightened(0.25))
	abl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(abl_lbl)

	# ── Select button ────────────────────────────────────────────────────────
	var btn := Button.new()
	btn.text = "▶  SELECT"
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", cls_color.lightened(0.2))
	btn.pressed.connect(_on_class_selected.bind(class_id, panel))
	vbox.add_child(btn)

	return panel

func _try_load_tex(primary: String, fallback: String) -> Texture2D:
	for path: String in [primary, fallback]:
		if ResourceLoader.exists(path):
			var t: Texture2D = load(path) as Texture2D
			if t != null:
				return t
	return null

# ── Selection / Start ──────────────────────────────────────────────────────────

func _on_class_selected(class_id: String, panel: PanelContainer) -> void:
	_selected_class = class_id
	# Dim all cards then brighten the chosen one
	for child: Node in _class_cards.get_children():
		child.modulate = Color(0.45, 0.45, 0.45)
	panel.modulate = Color(1.0, 1.0, 1.0)

	# Pulse the chosen card
	var tw: Tween = panel.create_tween()
	tw.tween_property(panel, "scale", Vector2(1.04, 1.04), 0.08)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0),   0.10)

	_start_button.visible = true
	var cls_name: String = Classes.get_class_data(class_id).get("display_name", class_id)
	SystemVoice.speak_direct(SystemVoice.pick("class_chosen") % cls_name)

func _on_start_pressed() -> void:
	if _selected_class.is_empty():
		return
	GameState.start_run(_selected_class)
