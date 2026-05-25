extends Control
## XP-driven ability upgrade screen shown after leveling up.
## Run 2: first implementation — Recharge / Primary / Special tabs.

signal upgrade_chosen(upgrade_type: String, value: String)

const UPGRADES: Array[Dictionary] = [
	{
		"id": "recharge_all",
		"tab": "Recharge",
		"display_name": "Full Recharge",
		"description": "Reset all ability cooldowns and restore all charges. Get back in the fight.",
		"type": "recharge",
		"value": "all",
		"icon": "⟳",
	},
	{
		"id": "upgrade_attack",
		"tab": "Primary",
		"display_name": "+5 Attack",
		"description": "Sharpen the edge. Every hit deals 5 more damage.",
		"type": "stat",
		"value": "attack",
		"amount": 5,
		"icon": "⚔",
	},
	{
		"id": "upgrade_defense",
		"tab": "Primary",
		"display_name": "+3 Defense",
		"description": "Toughen up. Reduce all incoming damage by 3.",
		"type": "stat",
		"value": "defense",
		"amount": 3,
		"icon": "🛡",
	},
	{
		"id": "upgrade_hp",
		"tab": "Primary",
		"display_name": "+25 Max HP",
		"description": "More meat for the grinder. Maximum health increased by 25.",
		"type": "stat",
		"value": "max_hp",
		"amount": 25,
		"icon": "❤",
	},
	{
		"id": "upgrade_speed",
		"tab": "Special",
		"display_name": "+3 Speed",
		"description": "Move before they can think. Speed increased by 3.",
		"type": "stat",
		"value": "speed",
		"amount": 3,
		"icon": "⚡",
	},
	{
		"id": "upgrade_heal",
		"tab": "Special",
		"display_name": "Emergency Heal",
		"description": "Patch up right now. Restore 40 HP immediately.",
		"type": "heal",
		"value": "40",
		"amount": 40,
		"icon": "+",
	},
]

## Shown as 3 random choices, one per tab (Recharge / Primary / Special)
var _choices: Array[Dictionary] = []

func _ready() -> void:
	SystemVoice.speak("level_up")
	_pick_choices()
	_build_ui()

func _pick_choices() -> void:
	## Pick one from each tab category
	_choices.clear()
	var tabs: Array[String] = ["Recharge", "Primary", "Special"]
	for tab: String in tabs:
		var pool: Array[Dictionary] = []
		for u: Dictionary in UPGRADES:
			if u.get("tab", "") == tab:
				pool.append(u)
		if pool.is_empty():
			continue
		_choices.append(pool[GameRng.randi_range(0, pool.size() - 1)])

func _build_ui() -> void:
	## Root panel covering the full screen
	var canvas := CanvasLayer.new()
	canvas.layer = 64
	add_child(canvas)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.08, 0.92)
	canvas.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	canvas.add_child(vbox)

	## Header
	var header := Label.new()
	header.text = "LEVEL %d — CHOOSE AN UPGRADE" % GameState.hero_level
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	vbox.add_child(header)

	var sub := Label.new()
	sub.text = "The System has deemed you minimally worthy of improvement."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
	vbox.add_child(sub)

	## Card row
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 24)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(cards)

	for choice: Dictionary in _choices:
		var card: PanelContainer = _make_card(choice)
		cards.add_child(card)

func _make_card(upgrade: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220.0, 280.0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	## Tab badge
	var tab_lbl := Label.new()
	tab_lbl.text = upgrade.get("tab", "")
	tab_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab_lbl.add_theme_font_size_override("font_size", 11)
	var tab_color: Color = _tab_color(upgrade.get("tab", ""))
	tab_lbl.add_theme_color_override("font_color", tab_color)
	vbox.add_child(tab_lbl)

	## Icon
	var icon_lbl := Label.new()
	icon_lbl.text = upgrade.get("icon", "?")
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 36)
	vbox.add_child(icon_lbl)

	## Name
	var name_lbl := Label.new()
	name_lbl.text = upgrade.get("display_name", "")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	## Description
	var desc_lbl := Label.new()
	desc_lbl.text = upgrade.get("description", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.62))
	desc_lbl.custom_minimum_size = Vector2(200.0, 0.0)
	vbox.add_child(desc_lbl)

	## Take it button
	var btn := Button.new()
	btn.text = "TAKE IT"
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_on_upgrade_chosen.bind(upgrade))
	vbox.add_child(btn)

	return panel

func _tab_color(tab: String) -> Color:
	match tab:
		"Recharge": return Color(0.4, 0.9, 0.5)
		"Primary":  return Color(0.9, 0.7, 0.2)
		"Special":  return Color(0.7, 0.4, 1.0)
	return Color.WHITE

func _on_upgrade_chosen(upgrade: Dictionary) -> void:
	_apply_upgrade(upgrade)
	upgrade_chosen.emit(upgrade.get("type", ""), upgrade.get("value", ""))

func _apply_upgrade(upgrade: Dictionary) -> void:
	var up_type: String = upgrade.get("type", "")
	match up_type:
		"recharge":
			## Tell BattleScene/GameState that we want a recharge next battle
			## (actual recharge handled via LootScreen-style; here we just record it)
			pass  ## Handled by Main after emit
		"stat":
			var key: String = upgrade.get("value", "")
			var amount: int = upgrade.get("amount", 0)
			match key:
				"attack":
					GameState.hero_base_stats["attack"] = GameState.hero_base_stats.get("attack", 0) + amount
				"defense":
					GameState.hero_base_stats["defense"] = GameState.hero_base_stats.get("defense", 0) + amount
				"max_hp":
					GameState.hero_max_hp += amount
					GameState.hero_hp = min(GameState.hero_hp + amount, GameState.hero_max_hp)
				"speed":
					GameState.hero_base_stats["speed"] = GameState.hero_base_stats.get("speed", 10) + amount
		"heal":
			var amount: int = upgrade.get("amount", 40)
			GameState.heal(amount)
