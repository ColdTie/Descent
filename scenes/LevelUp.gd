extends Control
## Level-up upgrade screen. Shown when hero gains a level.
## Presents 3 upgrade choices; hero picks one then continues.

signal upgrade_chosen(upgrade_id: String)

@onready var _title_label: Label = $VBox/TitleLabel
@onready var _subtitle_label: Label = $VBox/SubtitleLabel
@onready var _cards_container: HBoxContainer = $VBox/Cards
@onready var _system_label: Label = $VBox/SystemLabel
@onready var _continue_button: Button = $VBox/ContinueButton

var _chosen: String = ""

# Upgrade pool: each entry has id, name, desc, and an apply() callable-compatible dict
const UPGRADES: Array[Dictionary] = [
	{"id": "atk_up", "name": "Savage Strike", "desc": "+8 Attack. Your strikes land harder. The dungeon is unimpressed."},
	{"id": "spd_up", "name": "Quick Reflexes", "desc": "+4 Speed. Act before they do. Simple math."},
	{"id": "hp_up", "name": "Iron Constitution", "desc": "+30 Max HP and heal 30. Your body becomes slightly less breakable."},
	{"id": "def_up", "name": "Thick Skin", "desc": "+4 Armor. You've learned to absorb punishment. Professionally."},
	{"id": "xp_bonus", "name": "Combat Instincts", "desc": "Next floor grants +50% XP. The System upgrades your XP farm."},
	{"id": "heal_big", "name": "Second Wind", "desc": "Restore 50 HP now. The dungeon sighs and patches you up."},
]

func _ready() -> void:
	_title_label.text = "LEVEL %d" % GameState.hero_level
	_subtitle_label.text = "Choose an upgrade. Or don't. Actually, please do."
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue)
	SystemVoice.speak("level_up")
	SystemVoice.line_spoken.connect(func(text: String, _d: float) -> void: _system_label.text = text)
	_generate_choices()

func _generate_choices() -> void:
	var pool: Array[Dictionary] = UPGRADES.duplicate()
	GameRng.shuffle(pool)
	var choices: Array[Dictionary] = pool.slice(0, min(3, pool.size()))
	for item: Dictionary in choices:
		_cards_container.add_child(_make_card(item))

func _make_card(item: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240.0, 200.0)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = item["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.1))
	vbox.add_child(name_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var desc_lbl := Label.new()
	desc_lbl.text = item["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.custom_minimum_size = Vector2(220.0, 0.0)
	vbox.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "TAKE IT"
	btn.pressed.connect(_on_upgrade_selected.bind(item["id"], item, panel))
	vbox.add_child(btn)

	return panel

func _on_upgrade_selected(upgrade_id: String, item: Dictionary, panel: PanelContainer) -> void:
	_chosen = upgrade_id
	_apply_upgrade(item)
	for child: Node in _cards_container.get_children():
		child.modulate = Color(0.45, 0.45, 0.45)
	panel.modulate = Color(1.0, 1.0, 1.0)
	_continue_button.visible = true

func _apply_upgrade(item: Dictionary) -> void:
	match item["id"]:
		"atk_up":
			GameState.hero_base_stats["attack"] = GameState.hero_base_stats.get("attack", 0) + 8
			SystemVoice.speak_direct(["Attack increased. The dungeon feels the difference.",
				"Damage output elevated. The enemies will notice. That's the point.",
				"Attack up. The dungeon adjusts its projections. Upward, for you.",
			][randi() % 3])
		"spd_up":
			GameState.hero_base_stats["speed"] = GameState.hero_base_stats.get("speed", 10) + 4
			SystemVoice.speak_direct(["Speed increased. You are now slightly less slow.",
				"Faster. The dungeon's turn-order calculations have been updated.",
				"Speed up. You move before more things. Use that.",
			][randi() % 3])
		"hp_up":
			GameState.hero_max_hp += 30
			GameState.heal(30)
			SystemVoice.speak_direct(["Max HP increased. You're harder to kill. Noted.",
				"HP ceiling raised. You can survive more mistakes. Try not to make them.",
				"More HP. The dungeon finds this irritating. Good.",
			][randi() % 3])
		"def_up":
			GameState.hero_base_stats["defense"] = GameState.hero_base_stats.get("defense", 0) + 4
			SystemVoice.speak_direct(["Armor increased. Pain is now less painful.",
				"Defense up. The dungeon's attacks will hurt slightly less. Slightly.",
				"More armor. The dungeon recalculates required hits to kill you. It does not look pleased.",
			][randi() % 3])
		"xp_bonus":
			GameState.hero_base_stats["xp_bonus"] = GameState.hero_base_stats.get("xp_bonus", 0) + 50
			SystemVoice.speak_direct(["XP bonus applied. Efficient. Grind on, Hero.",
				"XP multiplier active. You will level faster. The dungeon will respond in kind.",
				"Bonus XP unlocked. The System rewards your commitment to violence.",
			][randi() % 3])
		"heal_big":
			GameState.heal(50)
			SystemVoice.speak_direct(["Healed 50 HP. The dungeon is briefly generous.",
				"50 HP restored. The dungeon notes your survival with mild displeasure.",
				"Healing applied. You are less dead than you were. This is good.",
			][randi() % 3])

func _on_continue() -> void:
	upgrade_chosen.emit(_chosen)
