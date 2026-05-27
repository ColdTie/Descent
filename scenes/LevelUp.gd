extends Control
## Level-up upgrade screen. Shown when hero gains a level.
## Presents 3 upgrade choices; hero picks one then continues.
## Run 4: dynamic ability unlock options added to the pool.

signal upgrade_chosen(upgrade_id: String)

@onready var _title_label: Label = $VBox/TitleLabel
@onready var _subtitle_label: Label = $VBox/SubtitleLabel
@onready var _cards_container: HBoxContainer = $VBox/Cards
@onready var _system_label: Label = $VBox/SystemLabel
@onready var _continue_button: Button = $VBox/ContinueButton

var _chosen: String = ""

# Stat upgrade pool
const STAT_UPGRADES: Array[Dictionary] = [
	{"id": "atk_up",    "type": "stat", "name": "Savage Strike",     "desc": "+8 Attack. Your strikes land harder. The dungeon is unimpressed."},
	{"id": "spd_up",    "type": "stat", "name": "Quick Reflexes",    "desc": "+4 Speed. Act before they do. Simple math."},
	{"id": "hp_up",     "type": "stat", "name": "Iron Constitution", "desc": "+30 Max HP and heal 30. Your body becomes slightly less breakable."},
	{"id": "def_up",    "type": "stat", "name": "Thick Skin",        "desc": "+4 Armor. You've learned to absorb punishment. Professionally."},
	{"id": "xp_bonus",  "type": "stat", "name": "Combat Instincts",  "desc": "Next floor grants +50% XP. The System upgrades your XP farm."},
	{"id": "heal_big",  "type": "stat", "name": "Second Wind",       "desc": "Restore 50 HP now. The dungeon sighs and patches you up."},
]

# Abilities that can be unlocked via level-up
const UNLOCKABLE_ABILITIES: Array[String] = [
	"fireball", "frost_nova", "backstab", "power_strike",
	"taunt", "vanish", "shield_bash", "whirlwind",
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
	var pool: Array[Dictionary] = []
	# Always include the stat upgrades
	for u: Dictionary in STAT_UPGRADES:
		pool.append(u)
	# Add ability unlocks for abilities the hero doesn't have yet
	for ability_id: String in UNLOCKABLE_ABILITIES:
		if not GameState.hero_abilities.has(ability_id):
			var abl_data: Dictionary = Abilities.get_ability(ability_id)
			pool.append({
				"id": "unlock_" + ability_id,
				"type": "ability_unlock",
				"ability_id": ability_id,
				"name": abl_data.get("display_name", ability_id),
				"desc": abl_data.get("description", ""),
			})
	GameRng.shuffle(pool)
	var choices: Array[Dictionary] = pool.slice(0, min(3, pool.size()))
	for item: Dictionary in choices:
		_cards_container.add_child(_make_card(item))

func _make_card(item: Dictionary) -> PanelContainer:
	var is_ability: bool = item.get("type", "stat") == "ability_unlock"
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240.0, 220.0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# "NEW ABILITY" tag for unlocks
	if is_ability:
		var tag := Label.new()
		tag.text = "✦ NEW ABILITY ✦"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		vbox.add_child(tag)

	var name_lbl := Label.new()
	name_lbl.text = item["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	if is_ability:
		name_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	else:
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

	# Ability cooldown / charges info for ability unlocks
	if is_ability:
		var ability_id: String = item.get("ability_id", "")
		var abl_data: Dictionary = Abilities.get_ability(ability_id)
		var charges: int = abl_data.get("max_charges", 1)
		var cooldown: int = abl_data.get("cooldown_turns", 0)
		var meta_text: String = ""
		if charges == -1:
			meta_text = "Charges: ∞"
		else:
			meta_text = "Charges: %d" % charges
		if cooldown > 0:
			meta_text += "  ·  Cooldown: %d turns" % cooldown
		var meta_lbl := Label.new()
		meta_lbl.text = meta_text
		meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		meta_lbl.add_theme_font_size_override("font_size", 10)
		meta_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
		vbox.add_child(meta_lbl)

	var btn := Button.new()
	btn.text = "UNLOCK" if is_ability else "TAKE IT"
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
	# Ability unlock
	if item.get("type", "stat") == "ability_unlock":
		var ability_id: String = item.get("ability_id", "")
		if not ability_id.is_empty() and not GameState.hero_abilities.has(ability_id):
			GameState.hero_abilities.append(ability_id)
			SystemVoice.speak("ability_unlock")
		return
	# Stat upgrades
	match item["id"]:
		"atk_up":
			GameState.hero_base_stats["attack"] = GameState.hero_base_stats.get("attack", 0) + 8
			SystemVoice.speak_direct("Attack increased. The dungeon feels the difference.")
		"spd_up":
			GameState.hero_base_stats["speed"] = GameState.hero_base_stats.get("speed", 10) + 4
			SystemVoice.speak_direct("Speed increased. You are now slightly less slow.")
		"hp_up":
			GameState.hero_max_hp += 30
			GameState.heal(30)
			SystemVoice.speak_direct("Max HP increased. You're harder to kill. Noted.")
		"def_up":
			GameState.hero_base_stats["defense"] = GameState.hero_base_stats.get("defense", 0) + 4
			SystemVoice.speak_direct("Armor increased. Pain is now less painful.")
		"xp_bonus":
			GameState.hero_base_stats["xp_bonus"] = GameState.hero_base_stats.get("xp_bonus", 0) + 50
			SystemVoice.speak_direct("XP bonus applied. Efficient. Grind on, Hero.")
		"heal_big":
			GameState.heal(50)
			SystemVoice.speak_direct("Healed 50 HP. The dungeon is briefly generous.")

func _on_continue() -> void:
	upgrade_chosen.emit(_chosen)
