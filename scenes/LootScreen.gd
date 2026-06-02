extends Control
## Post-battle loot choice screen: "Choose One" trade-off items.
## Run 11: styled cards with type-based icon + border colors.

signal loot_chosen(loot_id: String)

const LOOT_POOL: Array[Dictionary] = [
	{"id": "heal_small", "type": "heal",  "icon": "+",
	 "name": "Field Dressing",  "value": 30,
	 "desc": "Restore 30 HP. Simple. Effective. Boring."},
	{"id": "heal_large", "type": "heal",  "icon": "+",
	 "name": "Elixir of Life",  "value": 60,
	 "desc": "Restore 60 HP. The dungeon begrudgingly provides this."},
	{"id": "atk_boost",  "type": "stat",  "icon": "ATK",  "stat": "attack",  "value": 10,
	 "name": "Berserker Salve",
	 "desc": "+10 Attack. You become marginally scarier."},
	{"id": "def_boost",  "type": "stat",  "icon": "DEF",  "stat": "defense", "value": 3,
	 "name": "Chitin Plate Shard",
	 "desc": "+3 Armor. Every bit helps. Or doesn't."},
	{"id": "hp_boost",  "type": "stat",  "icon": "HP",  "stat": "max_hp",  "value": 25,
	 "name": "Heart of Stone",
	 "desc": "+25 Max HP. The dungeon grows a piece of you."},
	{"id": "warlords_brand","type":"multi","icon": "*",
	 "attack": 6, "max_hp": 15,
	 "name": "Warlord's Brand",
	 "desc": "+6 Attack and +15 Max HP. The dungeon brands its survivors."},
	{"id": "floor_skip", "type": "skip",  "icon": "^",
	 "name": "Teleport Shard",
	 "desc": "Skip the next floor entirely. Cowardly but effective."},
	{"id": "spd_boost",  "type": "stat",  "icon": "SPD", "stat": "speed",  "value": 3,
	 "name": "Quicksilver Vial",
	 "desc": "+3 Speed. Act earlier, die later."},
]

# Border/accent colors per item type
const TYPE_COLORS: Dictionary = {
	"heal":  Color(0.18, 0.88, 0.28),
	"stat":  Color(0.92, 0.76, 0.10),
	"multi":  Color(0.95, 0.55, 0.12),
	"skip":  Color(0.62, 0.32, 0.92),
}

@onready var _loot_cards:  HBoxContainer = $VBox/LootCards
@onready var _system_label:  Label  = $VBox/SystemLabel
@onready var _continue_button: Button  = $VBox/ContinueButton

var _chosen: String = ""

func _ready() -> void:
	SystemVoice.speak("loot")
	SystemVoice.line_spoken.connect(func(text: String, _d: float) -> void:
		_system_label.text = text)
	_continue_button.pressed.connect(_on_continue)
	_generate_choices()

func _generate_choices() -> void:
	var pool: Array[Dictionary] = LOOT_POOL.duplicate()
	GameRng.shuffle(pool)
	for item: Dictionary in pool.slice(0, 3):
		_loot_cards.add_child(_make_loot_card(item))

func _make_loot_card(item: Dictionary) -> PanelContainer:
	var item_type: String = item.get("type", "stat")
	var col: Color = TYPE_COLORS.get(item_type, Color(0.9, 0.7, 0.1))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250.0, 200.0)
	var ps := StyleBoxFlat.new()
	ps.bg_color  = Color(0.07, 0.05, 0.11, 0.97)
	ps.border_color = col.darkened(0.32)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(5)
	ps.set_content_margin_all(16.0)
	ps.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	ps.shadow_size  = 6
	panel.add_theme_stylebox_override("panel", ps)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Icon + name row
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var icon_lbl := Label.new()
	icon_lbl.text = item.get("icon", "*")
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.add_theme_color_override("font_color", col)
	header.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = item["name"]
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", col.lightened(0.15))
	header.add_child(name_lbl)

	# Thin divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(218.0, 1.0)
	div.color = col.darkened(0.42)
	div.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(div)

	var desc_lbl := Label.new()
	desc_lbl.text = item["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.80, 0.70))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.custom_minimum_size = Vector2(218.0, 0.0)
	vbox.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "TAKE IT"
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", col)
	btn.pressed.connect(_on_loot_selected.bind(item["id"], item, panel, ps))
	vbox.add_child(btn)

	return panel

func _on_loot_selected(loot_id: String, item: Dictionary,
		panel: PanelContainer, ps: StyleBoxFlat) -> void:
	_chosen = loot_id
	AudioManager.play("heal" if item.get("type", "") == "heal" else "select")
	_apply_loot(item)
	for child: Node in _loot_cards.get_children():
		child.modulate = Color(0.42, 0.42, 0.42)
	panel.modulate = Color(1.0, 1.0, 1.0)
	var col: Color = TYPE_COLORS.get(item.get("type", "stat"), Color(0.9, 0.7, 0.1))
	ps.border_color = col
	ps.set_border_width_all(3)
	_continue_button.visible = true

func _apply_loot(item: Dictionary) -> void:
	match item["type"]:
		"heal":
			GameState.heal(item.get("value", 30))
			SystemVoice.speak_direct(
				"You've healed %d HP. Try not to need it again." % item.get("value", 30))
		"stat":
			var stat: String = item.get("stat", "attack")
			var val: int = item.get("value", 5)
			match stat:
				"attack":
					GameState.hero_base_stats["attack"] = \
						GameState.hero_base_stats.get("attack", 0) + val
				"defense":
					GameState.hero_base_stats["defense"] = \
						GameState.hero_base_stats.get("defense", 0) + val
				"max_hp":
					GameState.hero_max_hp += val
					GameState.hero_hp = min(GameState.hero_hp + val, GameState.hero_max_hp)
				"speed":
					GameState.hero_base_stats["speed"] = \
						GameState.hero_base_stats.get("speed", 10) + val
			SystemVoice.speak_direct("Stat upgraded. You remain, somehow, alive.")
		"multi":
			GameState.hero_base_stats["attack"] = \
				GameState.hero_base_stats.get("attack", 0) + item.get("attack", 0)
			var hp_gain: int = item.get("max_hp", 0)
			GameState.hero_max_hp += hp_gain
			GameState.hero_hp = min(GameState.hero_hp + hp_gain, GameState.hero_max_hp)
			SystemVoice.speak_direct("Branded. Stronger and harder to kill. The dungeon notices.")
		"skip":
			GameState.floor_num += 1
			SystemVoice.speak_direct("Skipped a floor. The System judges you silently.")

func _on_continue() -> void:
	loot_chosen.emit(_chosen)
