extends Control
## Level-up upgrade screen.
## Run 12: added class-specific ability unlock cards alongside stat upgrades.

signal upgrade_chosen(upgrade_id: String)

@onready var _title_label:    Label        = $VBox/TitleLabel
@onready var _subtitle_label: Label        = $VBox/SubtitleLabel
@onready var _cards_container:HBoxContainer= $VBox/Cards
@onready var _system_label:   Label        = $VBox/SystemLabel
@onready var _continue_button:Button       = $VBox/ContinueButton

var _chosen: String = ""

# Abilities each class can unlock (abilities NOT in their starting kit)
const CLASS_UNLOCKS: Dictionary = {
	"brawler":  ["shield_bash"],
	"rogue":    ["power_strike", "frost_nova"],
	"arcanist": ["backstab", "taunt"],
}

const UPGRADES: Array[Dictionary] = [
	{"id": "atk_up",   "name": "Savage Strike",    "icon": "⚔",
	 "color": Color(0.90, 0.28, 0.16),
	 "desc": "+8 Attack. Your strikes land harder. The dungeon is unimpressed."},
	{"id": "spd_up",   "name": "Quick Reflexes",   "icon": "⚡",
	 "color": Color(0.95, 0.80, 0.10),
	 "desc": "+4 Speed. Act before they do. Simple math."},
	{"id": "hp_up",    "name": "Iron Constitution","icon": "❤",
	 "color": Color(0.18, 0.88, 0.28),
	 "desc": "+30 Max HP and heal 30. Your body becomes slightly less breakable."},
	{"id": "def_up",   "name": "Thick Skin",       "icon": "🛡",
	 "color": Color(0.38, 0.62, 1.00),
	 "desc": "+4 Armor. You've learned to absorb punishment. Professionally."},
	{"id": "xp_bonus", "name": "Combat Instincts", "icon": "✦",
	 "color": Color(0.55, 0.38, 0.90),
	 "desc": "Next floor grants +50% XP. The System upgrades your XP farm."},
	{"id": "heal_big", "name": "Second Wind",      "icon": "✚",
	 "color": Color(0.20, 0.92, 0.42),
	 "desc": "Restore 50 HP now. The dungeon sighs and patches you up."},
]

func _ready() -> void:
	_title_label.text = "LEVEL  %d" % GameState.hero_level
	_subtitle_label.text = "Choose an upgrade, Hero. The dungeon waits."
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue)
	SystemVoice.speak("level_up")
	SystemVoice.line_spoken.connect(func(text: String, _d: float) -> void:
		_system_label.text = text)
	_generate_choices()

func _generate_choices() -> void:
	# Build the pool of available ability unlocks for this class/run state
	var unlock_card: Dictionary = {}
	var class_unlocks: Array = CLASS_UNLOCKS.get(GameState.hero_class, [])
	for ability_id: String in class_unlocks:
		if not GameState.hero_abilities.has(ability_id):
			# Found an ability the hero can unlock — use the first one
			var abl: Dictionary = Abilities.get_ability(ability_id)
			unlock_card = {
				"id": "ability_unlock_%s" % ability_id,
				"type": "ability",
				"ability_id": ability_id,
				"name": "Learn: %s" % abl.get("display_name", ability_id),
				"icon": "✦",
				"color": Color(0.95, 0.72, 0.10),
				"desc": abl.get("description", ""),
			}
			break

	var pool: Array[Dictionary] = UPGRADES.duplicate()
	GameRng.shuffle(pool)
	var choices: Array[Dictionary] = []
	# If there's an ability to unlock, replace one stat card with it (~60% chance per level-up)
	if not unlock_card.is_empty() and GameRng.randf() < 0.60:
		choices.append(unlock_card)
		for item: Dictionary in pool.slice(0, 2):
			choices.append(item)
	else:
		for item: Dictionary in pool.slice(0, 3):
			choices.append(item)

	for item: Dictionary in choices:
		_cards_container.add_child(_make_card(item))

func _make_card(item: Dictionary) -> PanelContainer:
	var col: Color = item.get("color", Color(0.9, 0.7, 0.1))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(270.0, 220.0)
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.07, 0.05, 0.11, 0.97)
	ps.border_color = col.darkened(0.30)
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
	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(header_row)

	var icon_lbl := Label.new()
	icon_lbl.text = item.get("icon", "✦")
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.add_theme_color_override("font_color", col)
	header_row.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = item["name"]
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", col.lightened(0.18))
	header_row.add_child(name_lbl)

	# Thin color divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(236.0, 1.0)
	div.color = col.darkened(0.42)
	div.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(div)

	var desc_lbl := Label.new()
	desc_lbl.text = item["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.80, 0.70))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.custom_minimum_size = Vector2(238.0, 0.0)
	vbox.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "TAKE IT"
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", col)
	btn.pressed.connect(_on_upgrade_selected.bind(item["id"], item, panel, ps))
	vbox.add_child(btn)

	return panel

func _on_upgrade_selected(upgrade_id: String, item: Dictionary,
		panel: PanelContainer, ps: StyleBoxFlat) -> void:
	_chosen = upgrade_id
	_apply_upgrade(item)
	for child: Node in _cards_container.get_children():
		child.modulate = Color(0.42, 0.42, 0.42)
	panel.modulate = Color(1.0, 1.0, 1.0)
	# Brighten the chosen card's border
	ps.border_color = item.get("color", Color(0.9, 0.7, 0.1))
	ps.set_border_width_all(3)
	_continue_button.visible = true

func _apply_upgrade(item: Dictionary) -> void:
	# Handle ability unlocks first
	if item.get("type", "") == "ability":
		var ability_id: String = item.get("ability_id", "")
		if ability_id != "" and not GameState.hero_abilities.has(ability_id):
			GameState.hero_abilities.append(ability_id)
			var abl: Dictionary = Abilities.get_ability(ability_id)
			SystemVoice.speak_direct(
				"New ability acquired: %s. The dungeon updates its threat model." \
				% abl.get("display_name", ability_id))
		return
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
				"More armor. The dungeon recalculates required hits to kill you.",
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
