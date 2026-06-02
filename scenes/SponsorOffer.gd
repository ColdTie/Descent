extends Control
## Run 20: Sponsor offer screen — DCC-style "audience-funded gift" picker.
## Triggered between floors when the audience score crosses a multiple of
## `Sponsors.SPONSOR_THRESHOLD`. Modeled on LevelUp / LootScreen: three
## randomized cards, click one, apply effects, descend.

signal sponsor_chosen(sponsor_id: String)

@onready var _title_label:    Label         = $VBox/TitleLabel
@onready var _subtitle_label: Label         = $VBox/SubtitleLabel
@onready var _system_label:   Label         = $VBox/SystemLabel
@onready var _cards_container:HBoxContainer = $VBox/Cards
@onready var _continue_button:Button        = $VBox/ContinueButton

var _chosen: String = ""

func _ready() -> void:
	_title_label.text = "★ SPONSOR INTERLUDE ★"
	_subtitle_label.text = "Audience favor: %d. A sponsor would like a word." \
		% GameState.audience_score
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue)
	AudioManager.play("select")
	SystemVoice.speak("sponsor_offer")
	SystemVoice.line_spoken.connect(func(text: String, _d: float) -> void:
		_system_label.text = text)
	_generate_choices()

func _generate_choices() -> void:
	var pool: Array[Dictionary] = Sponsors.POOL.duplicate()
	GameRng.shuffle(pool)
	for item: Dictionary in pool.slice(0, 3):
		_cards_container.add_child(_make_card(item))

func _make_card(item: Dictionary) -> PanelContainer:
	var col: Color = item.get("color", Color(0.95, 0.78, 0.10))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280.0, 240.0)
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.08, 0.06, 0.12, 0.97)
	ps.border_color = col.darkened(0.28)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(5)
	ps.set_content_margin_all(16.0)
	ps.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	ps.shadow_size  = 6
	panel.add_theme_stylebox_override("panel", ps)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Sponsor brand row (smaller, italic-feeling)
	var sponsor_lbl := Label.new()
	sponsor_lbl.text = "▌ %s" % item.get("sponsor", "SPONSOR")
	sponsor_lbl.add_theme_font_size_override("font_size", 11)
	sponsor_lbl.add_theme_color_override("font_color", col.lightened(0.25))
	vbox.add_child(sponsor_lbl)

	# Icon + name row
	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(header_row)

	var icon_lbl := Label.new()
	icon_lbl.text = item.get("icon", "★")
	icon_lbl.add_theme_font_size_override("font_size", 26)
	icon_lbl.add_theme_color_override("font_color", col)
	header_row.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "Sponsorship")
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", col.lightened(0.15))
	header_row.add_child(name_lbl)

	# Thin divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(246.0, 1.0)
	div.color = col.darkened(0.42)
	div.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(div)

	var desc_lbl := Label.new()
	desc_lbl.text = item.get("desc", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.80, 0.70))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.custom_minimum_size = Vector2(246.0, 0.0)
	vbox.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "ACCEPT"
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", col)
	btn.pressed.connect(_on_card_selected.bind(item, panel, ps))
	vbox.add_child(btn)

	return panel

func _on_card_selected(item: Dictionary, panel: PanelContainer, ps: StyleBoxFlat) -> void:
	if _chosen != "":
		return
	_chosen = String(item.get("id", ""))
	AudioManager.play("select")
	_apply_effects(item)
	for child: Node in _cards_container.get_children():
		child.modulate = Color(0.42, 0.42, 0.42)
	panel.modulate = Color(1.0, 1.0, 1.0)
	ps.border_color = item.get("color", Color(0.95, 0.78, 0.10))
	ps.set_border_width_all(3)
	_continue_button.visible = true

func _apply_effects(item: Dictionary) -> void:
	var fx: Dictionary = item.get("effects", {})
	var name: String = String(item.get("name", "sponsorship"))

	var atk_delta: int = int(fx.get("attack", 0))
	if atk_delta != 0:
		GameState.hero_base_stats["attack"] = GameState.hero_base_stats.get("attack", 0) + atk_delta

	var spd_delta: int = int(fx.get("speed", 0))
	if spd_delta != 0:
		GameState.hero_base_stats["speed"] = GameState.hero_base_stats.get("speed", 10) + spd_delta

	var def_delta: int = int(fx.get("defense", 0))
	if def_delta != 0:
		GameState.hero_base_stats["defense"] = GameState.hero_base_stats.get("defense", 0) + def_delta

	var hp_delta: int = int(fx.get("max_hp", 0))
	if hp_delta != 0:
		GameState.hero_max_hp = max(1, GameState.hero_max_hp + hp_delta)
		GameState.hero_hp = clamp(GameState.hero_hp + hp_delta, 1, GameState.hero_max_hp)

	var heal_amt: int = int(fx.get("heal", 0))
	if heal_amt > 0:
		GameState.heal(heal_amt)

	var aud_bonus: int = int(fx.get("audience", 0))
	if aud_bonus > 0:
		GameState.award_audience(aud_bonus, "sponsor")

	SystemVoice.speak_direct(
		"%s applied. The audience approves. Loudly." % name)

func _on_continue() -> void:
	GameState.sponsor_offers_taken += 1
	sponsor_chosen.emit(_chosen)
