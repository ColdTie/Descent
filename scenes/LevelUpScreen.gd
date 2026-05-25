extends Control
## Level-up upgrade picker: shown when hero gains a new level.
## Offers 3 upgrade choices across Recharge / Ability / Stat tabs.

signal upgrade_chosen(upgrade_id: String)

const UPGRADE_POOLS: Array[Dictionary] = [
	# Recharge
	{
		"id": "recharge_all",
		"tab": "RECHARGE",
		"name": "Full Recharge",
		"desc": "All ability charges restored. The System is briefly generous.",
		"type": "recharge",
	},
	{
		"id": "recharge_single_fast",
		"tab": "RECHARGE",
		"name": "Quick Reset",
		"desc": "One random ability fully recharged. Take what you can get.",
		"type": "recharge_one",
	},
	# Stat boosts
	{
		"id": "boost_atk_big",
		"tab": "STAT",
		"name": "Berserker Rush",
		"desc": "+15 Attack. You are now statistically more dangerous.",
		"type": "stat",
		"stat": "attack",
		"value": 15,
	},
	{
		"id": "boost_def",
		"tab": "STAT",
		"name": "Iron Skin",
		"desc": "+4 Armor. Marginally harder to kill.",
		"type": "stat",
		"stat": "defense",
		"value": 4,
	},
	{
		"id": "boost_hp",
		"tab": "STAT",
		"name": "Extra Vitality",
		"desc": "+30 Max HP. The dungeon grows you a spare heart.",
		"type": "stat",
		"stat": "max_hp",
		"value": 30,
	},
	{
		"id": "boost_spd",
		"tab": "STAT",
		"name": "Quickening",
		"desc": "+2 Speed. Act sooner. Survive longer. Maybe.",
		"type": "stat",
		"stat": "speed",
		"value": 2,
	},
	# New abilities
	{
		"id": "gain_power_strike",
		"tab": "ABILITY",
		"name": "Learn: Power Strike",
		"desc": "Brutal overhead blow. 2× damage with cooldown.",
		"type": "add_ability",
		"ability": "power_strike",
	},
	{
		"id": "gain_backstab",
		"tab": "ABILITY",
		"name": "Learn: Backstab",
		"desc": "Strike from shadows. Ignores armor entirely.",
		"type": "add_ability",
		"ability": "backstab",
	},
	{
		"id": "gain_fireball",
		"tab": "ABILITY",
		"name": "Learn: Fireball",
		"desc": "Explosive AOE. Hits everything in radius 2.",
		"type": "add_ability",
		"ability": "fireball",
	},
	{
		"id": "gain_frost_nova",
		"tab": "ABILITY",
		"name": "Learn: Frost Nova",
		"desc": "Freeze all adjacent enemies for 2 turns.",
		"type": "add_ability",
		"ability": "frost_nova",
	},
	{
		"id": "gain_taunt",
		"tab": "ABILITY",
		"name": "Learn: Taunt",
		"desc": "Draw aggro, gain +5 armor for 3 turns.",
		"type": "add_ability",
		"ability": "taunt",
	},
	{
		"id": "gain_vanish",
		"tab": "ABILITY",
		"name": "Learn: Vanish",
		"desc": "Disappear. Next attack deals 3× damage.",
		"type": "add_ability",
		"ability": "vanish",
	},
]

@onready var _header_label: Label = $VBox/HeaderLabel
@onready var _system_label: Label = $VBox/SystemLabel
@onready var _card_row: HBoxContainer = $VBox/CardRow
@onready var _continue_btn: Button = $VBox/ContinueButton

var _chosen_id: String = ""

func _ready() -> void:
	_header_label.text = "LEVEL %d — CHOOSE AN UPGRADE" % GameState.hero_level
	SystemVoice.speak("level_up")
	SystemVoice.line_spoken.connect(func(text: String, _d: float) -> void: _system_label.text = text)
	_continue_btn.pressed.connect(_on_continue)
	_generate_cards()

func _generate_cards() -> void:
	## Pick 3 distinct upgrades, filtering out abilities the hero already has.
	var pool: Array[Dictionary] = []
	for u: Dictionary in UPGRADE_POOLS:
		if u.get("type", "") == "add_ability":
			if GameState.hero_abilities.has(u.get("ability", "")):
				continue  # skip already-known abilities
		pool.append(u)

	GameRng.shuffle(pool)
	var count: int = 0
	for item: Dictionary in pool:
		if count >= 3:
			break
		_card_row.add_child(_make_card(item))
		count += 1

func _make_card(item: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(230.0, 200.0)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	# Tab badge
	var tab_lbl := Label.new()
	tab_lbl.text = "[%s]" % item.get("tab", "?")
	tab_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tab_color: Color = Color.GRAY
	match item.get("tab", ""):
		"RECHARGE": tab_color = Color(0.4, 0.9, 0.4)
		"STAT":     tab_color = Color(1.0, 0.75, 0.1)
		"ABILITY":  tab_color = Color(0.5, 0.55, 1.0)
	tab_lbl.add_theme_color_override("font_color", tab_color)
	tab_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(tab_lbl)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "?")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.get("desc", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.custom_minimum_size = Vector2(210.0, 60.0)
	vbox.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "TAKE IT"
	btn.pressed.connect(_on_card_chosen.bind(item.get("id", ""), item, panel))
	vbox.add_child(btn)

	return panel

func _on_card_chosen(upg_id: String, item: Dictionary, panel: PanelContainer) -> void:
	_chosen_id = upg_id
	_apply_upgrade(item)
	for child: Node in _card_row.get_children():
		child.modulate = Color(0.4, 0.4, 0.4)
	panel.modulate = Color.WHITE
	_continue_btn.visible = true

func _apply_upgrade(item: Dictionary) -> void:
	match item.get("type", ""):
		"recharge":
			# Will take effect at start of next battle (charges tracked per-combat)
			SystemVoice.speak_direct("All charges restored. Don't squander them.")
		"recharge_one":
			SystemVoice.speak_direct("One ability recharged. Specifically, the useful one. Probably.")
		"stat":
			var stat: String = item.get("stat", "attack")
			var val: int = item.get("value", 5)
			match stat:
				"attack":
					GameState.hero_base_stats["attack"] = GameState.hero_base_stats.get("attack", 0) + val
					SystemVoice.speak_direct("Attack +%d. The enemies are, as yet, unaware." % val)
				"defense":
					GameState.hero_base_stats["defense"] = GameState.hero_base_stats.get("defense", 0) + val
					SystemVoice.speak_direct("Armor +%d. You are now marginally less squishy." % val)
				"max_hp":
					GameState.hero_max_hp += val
					GameState.hero_hp = min(GameState.hero_hp + val, GameState.hero_max_hp)
					SystemVoice.speak_direct("Max HP +%d. The dungeon gifts you a sliver of hope." % val)
				"speed":
					GameState.hero_base_stats["speed"] = GameState.hero_base_stats.get("speed", 10) + val
					SystemVoice.speak_direct("Speed +%d. You are now marginally faster. Marginally." % val)
		"add_ability":
			var ability_id: String = item.get("ability", "")
			if not GameState.hero_abilities.has(ability_id):
				GameState.hero_abilities.append(ability_id)
			var abl: Dictionary = Abilities.get_ability(ability_id)
			SystemVoice.speak_direct("Learned: %s. Try not to misuse it. You will." % abl.get("display_name", ability_id))

func _on_continue() -> void:
	upgrade_chosen.emit(_chosen_id)
