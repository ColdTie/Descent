extends Control
## Class selection screen — the front end of each run.

const CARD_WIDTH: float = 190.0
const CARD_HEIGHT: float = 270.0

var _selected_class: String = ""

@onready var _class_cards: HBoxContainer = $VBox/ClassCards
@onready var _start_button: Button = $VBox/StartButton
@onready var _system_label: Label = $VBox/SystemLabel

func _ready() -> void:
	SystemVoice.speak("class_select")
	SystemVoice.line_spoken.connect(_on_system_line)
	_build_class_cards()
	_start_button.pressed.connect(_on_start_pressed)

func _on_system_line(text: String, _dur: float) -> void:
	_system_label.text = text

func _build_class_cards() -> void:
	for class_id: String in Classes.all_ids():
		var card: PanelContainer = _make_class_card(class_id)
		_class_cards.add_child(card)

func _make_class_card(class_id: String) -> PanelContainer:
	var cls: Dictionary = Classes.get_class_data(class_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	# Hero portrait — PNG loads reliably in headless/web export without editor import.
	var portrait_path: String = "res://assets/sprites/hero_%s.png" % class_id
	var portrait_tex: Texture2D = null
	if ResourceLoader.exists(portrait_path):
		portrait_tex = load(portrait_path) as Texture2D
	if portrait_tex != null:
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(CARD_WIDTH - 10.0, 160.0)
		portrait.texture = portrait_tex
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		vbox.add_child(portrait)
	else:
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(CARD_WIDTH - 10.0, 80.0)
		swatch.color = cls.get("icon_color", Color.GRAY)
		vbox.add_child(swatch)

	# Class name
	var name_label := Label.new()
	name_label.text = cls.get("display_name", class_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)

	# HP
	var hp_label := Label.new()
	hp_label.text = "HP: %d" % cls.get("hp", 100)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	vbox.add_child(hp_label)

	# Description
	var desc_label := Label.new()
	desc_label.text = cls.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(desc_label)

	# Abilities list
	var abilities: Array = cls.get("abilities", [])
	var abl_label := Label.new()
	abl_label.text = "Abilities: " + ", ".join(abilities)
	abl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abl_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
	abl_label.add_theme_font_size_override("font_size", 10)
	abl_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(abl_label)

	# Select button
	var btn := Button.new()
	btn.text = "SELECT"
	btn.pressed.connect(_on_class_selected.bind(class_id, panel))
	vbox.add_child(btn)

	return panel

func _on_class_selected(class_id: String, panel: PanelContainer) -> void:
	_selected_class = class_id
	for child: Node in _class_cards.get_children():
		child.modulate = Color(0.55, 0.55, 0.55)
	panel.modulate = Color(1.0, 1.0, 1.0)
	_start_button.visible = true
	var cls_name: String = Classes.get_class_data(class_id).get("display_name", class_id)
	SystemVoice.speak_direct(SystemVoice.pick("class_chosen") % cls_name)

func _on_start_pressed() -> void:
	if _selected_class.is_empty():
		return
	GameState.start_run(_selected_class)
