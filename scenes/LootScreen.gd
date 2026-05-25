extends Control
## Post-battle loot choice screen: "Choose One" trade-off items.

signal loot_chosen(loot_id: String)

const LOOT_POOL: Array[Dictionary] = [
	{"id": "heal_small", "name": "Field Dressing", "desc": "Restore 30 HP. Simple. Effective. Boring.", "type": "heal", "value": 30},
	{"id": "heal_large", "name": "Elixir of Life", "desc": "Restore 60 HP. The dungeon begrudgingly provides this.", "type": "heal", "value": 60},
	{"id": "atk_boost", "name": "Berserker Salve", "desc": "+10 Attack. You become marginally scarier.", "type": "stat", "stat": "attack", "value": 10},
	{"id": "def_boost", "name": "Chitin Plate Shard", "desc": "+3 Armor. Every bit helps. Or doesn't.", "type": "stat", "stat": "defense", "value": 3},
	{"id": "hp_boost", "name": "Heart of Stone", "desc": "+25 Max HP. The dungeon grows a piece of you.", "type": "stat", "stat": "max_hp", "value": 25},
	{"id": "recharge_all", "name": "Chrono Shard", "desc": "Recharge all abilities right now. Use them wisely.", "type": "recharge"},
	{"id": "floor_skip", "name": "Teleport Shard", "desc": "Skip the next floor entirely. Cowardly but effective.", "type": "skip"},
	{"id": "spd_boost", "name": "Quicksilver Vial", "desc": "+3 Speed. Act earlier, die later.", "type": "stat", "stat": "speed", "value": 3},
]

@onready var _loot_cards: HBoxContainer = $VBox/LootCards
@onready var _system_label: Label = $VBox/SystemLabel
@onready var _continue_button: Button = $VBox/ContinueButton

var _chosen: String = ""

func _ready() -> void:
	SystemVoice.speak("loot")
	SystemVoice.line_spoken.connect(func(text: String, _d: float) -> void: _system_label.text = text)
	_continue_button.pressed.connect(_on_continue)
	_generate_choices()

func _generate_choices() -> void:
	var pool: Array[Dictionary] = LOOT_POOL.duplicate()
	GameRng.shuffle(pool)
	var choices: Array[Dictionary] = pool.slice(0, 3)
	for item: Dictionary in choices:
		var card: PanelContainer = _make_loot_card(item)
		_loot_cards.add_child(card)

func _make_loot_card(item: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220.0, 180.0)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = item["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.custom_minimum_size = Vector2(200.0, 0.0)
	vbox.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "TAKE IT"
	btn.pressed.connect(_on_loot_selected.bind(item["id"], item, panel))
	vbox.add_child(btn)

	return panel

func _on_loot_selected(loot_id: String, item: Dictionary, panel: PanelContainer) -> void:
	_chosen = loot_id
	_apply_loot(item)
	for child: Node in _loot_cards.get_children():
		child.modulate = Color(0.45, 0.45, 0.45)
	panel.modulate = Color(1.0, 1.0, 1.0)
	_continue_button.visible = true

func _apply_loot(item: Dictionary) -> void:
	match item["type"]:
		"heal":
			GameState.heal(item.get("value", 30))
			SystemVoice.speak_direct("You've healed %d HP. Try not to need it again." % item.get("value", 30))
		"stat":
			var stat: String = item.get("stat", "attack")
			var val: int = item.get("value", 5)
			match stat:
				"attack":
					GameState.hero_base_stats["attack"] = GameState.hero_base_stats.get("attack", 0) + val
				"defense":
					GameState.hero_base_stats["defense"] = GameState.hero_base_stats.get("defense", 0) + val
				"max_hp":
					GameState.hero_max_hp += val
					GameState.hero_hp = min(GameState.hero_hp + val, GameState.hero_max_hp)
				"speed":
					GameState.hero_base_stats["speed"] = GameState.hero_base_stats.get("speed", 10) + val
			SystemVoice.speak_direct("Stat upgraded. You remain, somehow, alive.")
		"recharge":
			SystemVoice.speak_direct("All abilities recharged. Don't waste them.")
		"skip":
			GameState.floor_num += 1
			SystemVoice.speak_direct("Skipped a floor. The System judges you silently.")

func _on_continue() -> void:
	loot_chosen.emit(_chosen)
