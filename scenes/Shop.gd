extends Control
## Run 21: between-floor merchant — "the dungeon's storefront".
##
## Triggered by Main.gd after the loot pick (and after PatchNotes if a tier
## transition is happening). Cadence is gated by Shop.should_show_shop() so
## the very first floor doesn't surface an empty wallet.
##
## Unlike LootScreen / SponsorOffer (pick-one), the shop is multi-purchase:
## the player may buy any items they can afford, then click LEAVE to descend.
##
## Run 25: rarity tiers (Common/Rare/Legendary) + REROLL button. Each card
## now renders with a rarity label, rarity-colored border (4px for Legendary),
## and a tinted shadow. Legendary cards pulse + trigger a soft orange screen
## flash on entry. The REROLL button below the cards spends an escalating
## amount of gold to redraw the entire slate.

signal shop_left

const RARITY_COLORS: Dictionary = {
	"common":  Color(0.72, 0.72, 0.74),
	"rare":  Color(0.42, 0.72, 1.00),
	"legendary": Color(1.00, 0.55, 0.10),
}

const RARITY_LABELS: Dictionary = {
	"common":  "COMMON",
	"rare":  "RARE",
	"legendary": "LEGENDARY",
}

var _slate: Array[Dictionary] = []
var _purchased: Dictionary = {}  # id -> true once bought (greys the card)
var _reroll_count: int = 0       # Run 25: number of rerolls used this visit
var _gold_label: Label = null
var _system_label: Label = null
var _cards_container: HBoxContainer = null
var _leave_button: Button = null
var _reroll_button: Button = null


func _ready() -> void:
	GameState.shop_visits += 1
	_build_ui()
	_roll_initial_slate()
	_rebuild_cards()
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
	outer.offset_top  = -310.0
	outer.offset_right  =  560.0
	outer.offset_bottom =  310.0
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

	# Reroll + Leave button row (Run 25)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	_reroll_button = Button.new()
	_reroll_button.custom_minimum_size = Vector2(220.0, 52.0)
	_reroll_button.add_theme_font_size_override("font_size", 15)
	_reroll_button.add_theme_color_override("font_color", Color(0.82, 0.92, 1.00))
	_reroll_button.pressed.connect(_on_reroll_pressed)
	btn_row.add_child(_reroll_button)

	_leave_button = Button.new()
	_leave_button.text = "  LEAVE & DESCEND  "
	_leave_button.custom_minimum_size = Vector2(300.0, 52.0)
	_leave_button.add_theme_font_size_override("font_size", 17)
	_leave_button.add_theme_color_override("font_color", Color(0.96, 0.80, 0.18))
	_leave_button.pressed.connect(_on_leave_pressed)
	btn_row.add_child(_leave_button)


func _gold_text() -> String:
	return "$  GOLD: %d" % GameState.hero_gold


func _roll_initial_slate() -> void:
	## Use a deterministic per-floor rng so the slate is reproducible per seed,
	## mirroring how LootScreen rolls. Mixing in shop_visits ensures consecutive
	## visits aren't identical. floor_num is the floor the player CLEARED.
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run_seed ^ (GameState.floor_num * 7919) ^ (GameState.shop_visits * 1543)
	_slate = Shop.slate(rng, GameState.floor_num)
	_check_legendary_aura()


func _reroll_slate() -> void:
	## Run 25: redraw the slate with a fresh seed that includes the reroll
	## count so repeated rerolls within one visit don't loop the same items.
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run_seed ^ (GameState.floor_num * 7919) \
		^ (GameState.shop_visits * 1543) ^ (_reroll_count * 6151)
	_slate = Shop.slate(rng, GameState.floor_num)
	# Reset purchased state — a reroll is a fresh slate so previous "PURCHASED"
	# greys don't carry over. Items already bought are gone from inventory of
	# THIS slate anyway; if the same id rolls again it's a new card.
	_purchased.clear()
	_check_legendary_aura()


func _check_legendary_aura() -> void:
	## Run 25: flash the screen when at least one Legendary item is on offer.
	for it: Dictionary in _slate:
		if String(it.get("rarity", "common")) == "legendary":
			_flash_legendary_aura()
			return


func _rebuild_cards() -> void:
	if _cards_container == null:
		return
	for child: Node in _cards_container.get_children():
		_cards_container.remove_child(child)
		child.queue_free()
	for item: Dictionary in _slate:
		_cards_container.add_child(_make_card(item))
	_refresh_reroll_button()


func _make_card(item: Dictionary) -> PanelContainer:
	var col: Color = item.get("color", Color(0.95, 0.78, 0.10))
	var rarity: String = String(item.get("rarity", "common"))
	var border_col: Color = RARITY_COLORS.get(rarity, col)
	var border_w: int = 4 if rarity == "legendary" else 2

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(244.0, 240.0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.06, 0.12, 0.97)
	ps.border_color = border_col
	ps.set_border_width_all(border_w)
	ps.set_corner_radius_all(5)
	ps.set_content_margin_all(14.0)
	ps.shadow_color = Color(border_col.r * 0.45, border_col.g * 0.45, border_col.b * 0.45, 0.70)
	ps.shadow_size = 10 if rarity == "legendary" else 6
	panel.add_theme_stylebox_override("panel", ps)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	# Rarity label (Run 25)
	var rarity_lbl := Label.new()
	rarity_lbl.text = RARITY_LABELS.get(rarity, "COMMON")
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	rarity_lbl.add_theme_color_override("font_color", border_col)
	vb.add_child(rarity_lbl)

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
	name_lbl.add_theme_color_override("font_color", border_col.lightened(0.15))
	header.add_child(name_lbl)

	# Divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(210.0, 1.0)
	div.color = border_col.darkened(0.42)
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

	# Pulsing shadow for Legendary cards — same idiom as LootScreen.
	if rarity == "legendary":
		var tw: Tween = create_tween()
		tw.set_loops()
		tw.tween_property(ps, "shadow_size", 16, 1.1) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(ps, "shadow_size", 8, 1.1) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	_refresh_card_state(item, panel, ps, btn)
	return panel


func _refresh_card_state(item: Dictionary, panel: PanelContainer,
		ps: StyleBoxFlat, btn: Button) -> void:
	## Disable when bought or unaffordable; bought cards grey out.
	var id: String = String(item.get("id", ""))
	var cost: int = int(item.get("cost", 0))
	var rarity: String = String(item.get("rarity", "common"))
	var border_col: Color = RARITY_COLORS.get(rarity, item.get("color",
		Color(0.95, 0.78, 0.10)))
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
		ps.border_color = border_col
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
	var rarity: String = String(item.get("rarity", "common"))
	if rarity == "legendary":
		AudioManager.play("victory", 0.0, -4.0)
		_flash_legendary_aura()
		SystemVoice.speak_direct("Legendary purchase. The merchant's smile is, regrettably, sincere.")
	else:
		AudioManager.play("select", 0.05)
	_apply_effects(item)
	if rarity != "legendary":
		SystemVoice.speak("shop_purchase")
	_refresh_all_cards()


func _on_reroll_pressed() -> void:
	## Run 25: spend escalating gold to redraw the slate.
	var cost: int = Shop.reroll_cost(_reroll_count)
	if GameState.hero_gold < cost:
		return
	if not GameState.spend_gold(cost, "shop_reroll"):
		return
	_reroll_count += 1
	AudioManager.play("ability", 0.08)
	SystemVoice.speak("shop_reroll")
	_reroll_slate()
	_rebuild_cards()


func _refresh_reroll_button() -> void:
	if _reroll_button == null:
		return
	var cost: int = Shop.reroll_cost(_reroll_count)
	_reroll_button.text = "  REROLL  ($ %d)  " % cost
	if GameState.hero_gold < cost:
		_reroll_button.disabled = true
		_reroll_button.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	else:
		_reroll_button.disabled = false
		_reroll_button.add_theme_color_override("font_color", Color(0.82, 0.92, 1.00))


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
	_refresh_reroll_button()


func _flash_legendary_aura() -> void:
	## Soft orange screen flash so a Legendary slate feels special.
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.55, 0.10, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	move_child(flash, get_child_count() - 1)
	var tw: Tween = create_tween()
	tw.tween_property(flash, "color:a", 0.36, 0.20)
	tw.tween_property(flash, "color:a", 0.0, 0.85)
	tw.tween_callback(flash.queue_free)


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
	_refresh_reroll_button()


func _on_leave_pressed() -> void:
	AudioManager.play("descend")
	shop_left.emit()
