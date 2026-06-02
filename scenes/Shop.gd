extends Control
## Run 21: between-floor merchant — "the dungeon's storefront".
##
## Triggered by Main.gd after the loot pick (and after PatchNotes if a tier
## transition is happening). Cadence is gated by Shop.should_show_shop() so
## the very first floor doesn't surface an empty wallet.
##
## Unlike LootScreen / SponsorOffer (pick-one), the shop is multi-purchase:
## the player may buy any items they can afford, then click LEAVE to descend.

signal shop_left

var _slate: Array[Dictionary] = []
var _purchased: Dictionary = {}  # id -> true once bought (greys the card)
var _gold_label: Label = null
var _system_label: Label = null
var _cards_container: HBoxContainer = null
var _leave_button: Button = null


func _ready() -> void:
	GameState.shop_visits += 1
	_build_ui()
	AudioManager.play("select")
	SystemVoice.speak("shop_enter")
	SystemVoice.line_spoken.connect(func(text: String, _d: float) -> void:
		if _system_label != null:
			_system_label.text = text)
	GameState.gold_spent.connect(_on_gold_spent)


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Subtle warm-coin glow overlay so the shop feels distinct from sponsor/loot.
	var glow := ColorRect.new()
	glow.color = Color(0.55, 0.42, 0.10, 0.10)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glow)

	# Stone panel
	var outer := PanelContainer.new()
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.offset_left  = -560.0
	outer.offset_top  = -290.0
	outer.offset_right  =  560.0
	outer.offset_bottom =  290.0
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.10, 0.98)
	s.border_color = Color(0.76, 0.58, 0.12)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(26.0)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.80)
	s.shadow_size = 14
	outer.add_theme_stylebox_override("panel", s)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	outer.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "*  MERCHANT INTERLUDE  *"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.20))
	vbox.add_child(title)

	# Subtitle + Gold balance row
	var subtitle := Label.new()
	subtitle.text = "The dungeon's vending licence is, regrettably, valid."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.74, 0.62))
	vbox.add_child(subtitle)

	_gold_label = Label.new()
	_gold_label.text = _gold_text()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.18))
	vbox.add_child(_gold_label)

	_system_label = Label.new()
	_system_label.text = "..."
	_system_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_system_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_system_label.add_theme_font_size_override("font_size", 13)
	_system_label.add_theme_color_override("font_color", Color(0.66, 0.66, 0.58))
	_system_label.custom_minimum_size = Vector2(1000.0, 0.0)
	vbox.add_child(_system_label)

	# Card row
	_cards_container = HBoxContainer.new()
	_cards_container.add_theme_constant_override("separation", 16)
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_cards_container)

	# Match the LootScreen / SponsorOffer pattern: duplicate, shuffle via the
	# seeded GameRng autoload, take the slate-size prefix. (Shop.slate(rng)
	# exists for headless tests where we need a private rng.)
	var pool: Array[Dictionary] = Shop.INVENTORY.duplicate()
	GameRng.shuffle(pool)
	for item: Dictionary in pool.slice(0, Shop.SLATE_SIZE):
		_slate.append(item)
	for item2: Dictionary in _slate:
		_cards_container.add_child(_make_card(item2))

	# Leave button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_leave_button = Button.new()
	_leave_button.text = "  LEAVE & DESCEND  "
	_leave_button.custom_minimum_size = Vector2(300.0, 52.0)
	_leave_button.add_theme_font_size_override("font_size", 17)
	_leave_button.add_theme_color_override("font_color", Color(0.96, 0.80, 0.18))
	_leave_button.pressed.connect(_on_leave_pressed)
	btn_row.add_child(_leave_button)


func _gold_text() -> String:
	return "$  GOLD: %d" % GameState.hero_gold


func _make_card(item: Dictionary) -> PanelContainer:
	var col: Color = item.get("color", Color(0.95, 0.78, 0.10))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(244.0, 220.0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.06, 0.12, 0.97)
	ps.border_color = col.darkened(0.30)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(5)
	ps.set_content_margin_all(14.0)
	ps.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	ps.shadow_size = 6
	panel.add_theme_stylebox_override("panel", ps)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	# Icon + name row
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 8)
	vb.add_child(header)

	var icon_lbl := Label.new()
	icon_lbl.text = item.get("icon", "*")
	icon_lbl.add_theme_font_size_override("font_size", 26)
	icon_lbl.add_theme_color_override("font_color", col)
	header.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "Item")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", col.lightened(0.15))
	header.add_child(name_lbl)

	# Divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(210.0, 1.0)
	div.color = col.darkened(0.42)
	div.mouse_filter = MOUSE_FILTER_IGNORE
	vb.add_child(div)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = item.get("desc", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.80, 0.70))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.custom_minimum_size = Vector2(210.0, 0.0)
	vb.add_child(desc_lbl)

	# Cost label
	var cost: int = int(item.get("cost", 0))
	var cost_lbl := Label.new()
	cost_lbl.text = "$ %d gold" % cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.18))
	vb.add_child(cost_lbl)

	# Buy button
	var btn := Button.new()
	btn.text = "BUY"
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", col)
	btn.pressed.connect(_on_buy_pressed.bind(item, panel, ps, btn))
	vb.add_child(btn)

	_refresh_card_state(item, panel, ps, btn)
	return panel


func _refresh_card_state(item: Dictionary, panel: PanelContainer,
		ps: StyleBoxFlat, btn: Button) -> void:
	## Disable when bought or unaffordable; bought cards grey out.
	var id: String = String(item.get("id", ""))
	var cost: int = int(item.get("cost", 0))
	if _purchased.get(id, false):
		btn.disabled = true
		btn.text = "PURCHASED"
		panel.modulate = Color(0.42, 0.42, 0.42)
		return
	if GameState.hero_gold < cost:
		btn.disabled = true
		btn.text = "TOO POOR"
		ps.border_color = Color(0.30, 0.28, 0.36)
		panel.modulate = Color(0.78, 0.78, 0.78)
	else:
		btn.disabled = false
		btn.text = "BUY"
		var col: Color = item.get("color", Color(0.95, 0.78, 0.10))
		ps.border_color = col.darkened(0.30)
		panel.modulate = Color(1.0, 1.0, 1.0)


func _on_buy_pressed(item: Dictionary, panel: PanelContainer,
		ps: StyleBoxFlat, btn: Button) -> void:
	var id: String = String(item.get("id", ""))
	var cost: int = int(item.get("cost", 0))
	if _purchased.get(id, false):
		return
	if not GameState.spend_gold(cost, id):
		return
	_purchased[id] = true
	AudioManager.play("select", 0.05)
	_apply_effects(item)
	SystemVoice.speak("shop_purchase")
	_refresh_all_cards()


func _refresh_all_cards() -> void:
	## After any purchase, redraw every card (affordability may have changed)
	## and re-run the disable rules.
	for i: int in range(_slate.size()):
		var item: Dictionary = _slate[i]
		var panel: PanelContainer = _cards_container.get_child(i) as PanelContainer
		if panel == null:
			continue
		var ps: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		var vb: VBoxContainer = panel.get_child(0) as VBoxContainer
		if vb == null:
			continue
		# Buy button is the last child of the card's vbox.
		var btn: Button = vb.get_child(vb.get_child_count() - 1) as Button
		if btn == null or ps == null:
			continue
		_refresh_card_state(item, panel, ps, btn)


func _apply_effects(item: Dictionary) -> void:
	var fx: Dictionary = item.get("effects", {})
	var name_s: String = String(item.get("name", "item"))

	var atk: int = int(fx.get("attack", 0))
	if atk != 0:
		GameState.hero_base_stats["attack"] = GameState.hero_base_stats.get("attack", 0) + atk

	var def: int = int(fx.get("defense", 0))
	if def != 0:
		GameState.hero_base_stats["defense"] = GameState.hero_base_stats.get("defense", 0) + def

	var spd: int = int(fx.get("speed", 0))
	if spd != 0:
		GameState.hero_base_stats["speed"] = GameState.hero_base_stats.get("speed", 10) + spd

	var hp: int = int(fx.get("max_hp", 0))
	if hp != 0:
		GameState.hero_max_hp = max(1, GameState.hero_max_hp + hp)
		GameState.hero_hp = clamp(GameState.hero_hp + hp, 1, GameState.hero_max_hp)

	var heal: int = int(fx.get("heal", 0))
	if heal > 0:
		GameState.heal(heal)

	if int(fx.get("full_heal", 0)) > 0:
		GameState.hero_hp = GameState.hero_max_hp

	var aud: int = int(fx.get("audience", 0))
	if aud > 0:
		GameState.award_audience(aud, "shop")

	SystemVoice.speak_direct(
		"%s purchased. The merchant offers no refunds. Or guarantees." % name_s)


func _on_gold_spent(_amount: int, _item_id: String) -> void:
	if _gold_label != null:
		_gold_label.text = _gold_text()


func _on_leave_pressed() -> void:
	AudioManager.play("descend")
	shop_left.emit()
