extends Control
## Run 20: Sponsor offer screen — DCC-style "audience-funded gift" picker.
## Triggered between floors when the audience score crosses a multiple of
## `Sponsors.SPONSOR_THRESHOLD`. Modeled on LevelUp / LootScreen: three
## randomized cards, click one, apply effects, descend.
##
## Run 29: cards are drawn through `Sponsors.slate()` so rarity (Common /
## Rare / Legendary) shifts toward rarer offers as the player accepts more
## sponsors, and "return engagement" sponsors only appear once their setup
## sponsor has been taken. Card chrome now shows rarity label + colored
## border + Legendary screen flash, matching the Loot/Shop idiom.

signal sponsor_chosen(sponsor_id: String)

@onready var _title_label:  Label  = $VBox/TitleLabel
@onready var _subtitle_label: Label  = $VBox/SubtitleLabel
@onready var _system_label:  Label  = $VBox/SystemLabel
@onready var _cards_container:HBoxContainer = $VBox/Cards
@onready var _continue_button:Button  = $VBox/ContinueButton

var _chosen: String = ""

func _ready() -> void:
	_title_label.text = "* SPONSOR INTERLUDE *"
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
	## Run 29: draw through Sponsors.slate(). RNG is seeded from the run seed
	## XOR'd with the current taken-count so consecutive pop-ups within a run
	## roll different slates AND a saved-and-resumed run sees the same slate
	## it would have seen pre-resume.
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run_seed ^ (GameState.sponsor_offers_taken + 1) * 7919
	var picks: Array[Dictionary] = Sponsors.slate(
		rng,
		GameState.sponsor_offers_taken,
		GameState.sponsor_offers_taken_ids)
	# Defensive: if slate() returns nothing (e.g. empty pool, never expected),
	# fall back to the legacy shuffle so the screen always shows something.
	if picks.is_empty():
		var legacy: Array[Dictionary] = Sponsors.POOL.duplicate()
		GameRng.shuffle(legacy)
		picks = legacy.slice(0, Sponsors.SLATE_SIZE)
	var any_legendary: bool = false
	for item: Dictionary in picks:
		_cards_container.add_child(_make_card(item))
		if String(item.get("rarity", Sponsors.RARITY_COMMON)) == Sponsors.RARITY_LEGENDARY:
			any_legendary = true
	if any_legendary:
		_flash_legendary_aura()
		SystemVoice.speak("sponsor_legendary")

func _make_card(item: Dictionary) -> PanelContainer:
	var brand_col: Color = item.get("color", Color(0.95, 0.78, 0.10))
	var rarity: String = String(item.get("rarity", Sponsors.RARITY_COMMON))
	var rarity_col: Color = Sponsors.RARITY_COLORS.get(rarity, brand_col)
	var border_w: int = 4 if rarity == Sponsors.RARITY_LEGENDARY else 2
	var is_return: bool = String(item.get("requires_taken", "")) != ""

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280.0, 270.0)
	var ps := StyleBoxFlat.new()
	ps.bg_color  = Color(0.08, 0.06, 0.12, 0.97)
	ps.border_color = rarity_col
	ps.set_border_width_all(border_w)
	ps.set_corner_radius_all(5)
	ps.set_content_margin_all(16.0)
	ps.shadow_color = Color(rarity_col.r * 0.4, rarity_col.g * 0.4, rarity_col.b * 0.4, 0.65)
	ps.shadow_size = 10 if rarity == Sponsors.RARITY_LEGENDARY else 6
	panel.add_theme_stylebox_override("panel", ps)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Rarity strip — same idiom as Loot/Shop. A "return engagement" sponsor
	# gets a small chevron prefix so the player notices it's a callback.
	var rarity_lbl := Label.new()
	var rarity_text: String = Sponsors.RARITY_LABELS.get(rarity, "")
	if is_return:
		rarity_text = "▸ %s · ENCORE" % rarity_text
	rarity_lbl.text = rarity_text
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	rarity_lbl.add_theme_color_override("font_color", rarity_col)
	vbox.add_child(rarity_lbl)

	# Sponsor brand row (smaller, italic-feeling)
	var sponsor_lbl := Label.new()
	sponsor_lbl.text = "▌ %s" % item.get("sponsor", "SPONSOR")
	sponsor_lbl.add_theme_font_size_override("font_size", 11)
	sponsor_lbl.add_theme_color_override("font_color", brand_col.lightened(0.25))
	vbox.add_child(sponsor_lbl)

	# Icon + name row
	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(header_row)

	var icon_lbl := Label.new()
	icon_lbl.text = item.get("icon", "*")
	icon_lbl.add_theme_font_size_override("font_size", 26)
	icon_lbl.add_theme_color_override("font_color", brand_col)
	header_row.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "Sponsorship")
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", brand_col.lightened(0.15))
	header_row.add_child(name_lbl)

	# Thin divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(246.0, 1.0)
	div.color = rarity_col.darkened(0.42)
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
	btn.add_theme_color_override("font_color", rarity_col)
	btn.pressed.connect(_on_card_selected.bind(item, panel, ps))
	vbox.add_child(btn)

	# Pulsing shadow on Legendary so the eye finds it without reading.
	if rarity == Sponsors.RARITY_LEGENDARY:
		var tw: Tween = create_tween()
		tw.set_loops()
		tw.tween_property(ps, "shadow_size", 16, 1.1) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(ps, "shadow_size", 8, 1.1) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	return panel

func _flash_legendary_aura() -> void:
	## Soft orange screen flash so a Legendary sponsor slate feels special.
	## Same idiom as LootScreen / Shop.
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.55, 0.10, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	move_child(flash, get_child_count() - 1)
	var tw: Tween = create_tween()
	tw.tween_property(flash, "color:a", 0.42, 0.20)
	tw.tween_property(flash, "color:a", 0.0, 0.85)
	tw.tween_callback(flash.queue_free)

func _on_card_selected(item: Dictionary, panel: PanelContainer, ps: StyleBoxFlat) -> void:
	if _chosen != "":
		return
	_chosen = String(item.get("id", ""))
	var rarity: String = String(item.get("rarity", Sponsors.RARITY_COMMON))
	# Legendary picks get the victory sting + special quip; return-engagement
	# picks get their own line so the callback gag lands.
	if rarity == Sponsors.RARITY_LEGENDARY:
		AudioManager.play("victory", 0.0, -4.0)
		_flash_legendary_aura()
		SystemVoice.speak_direct(
			"A LEGENDARY endorsement. The audience screams. The sponsor's stock spikes. Everyone wins. Mostly the sponsor.")
	elif String(item.get("requires_taken", "")) != "":
		AudioManager.play("select")
		SystemVoice.speak("sponsor_return")
	else:
		AudioManager.play("select")
	_apply_effects(item)
	for child: Node in _cards_container.get_children():
		child.modulate = Color(0.42, 0.42, 0.42)
	panel.modulate = Color(1.0, 1.0, 1.0)
	ps.border_color = Sponsors.RARITY_COLORS.get(rarity, item.get("color", Color(0.95, 0.78, 0.10)))
	ps.set_border_width_all(4)
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
	# Run 29: record the accepted id so story-arc prereqs can unlock for the
	# next pop-up. Defensive empty-id guard so a malformed card can't push a
	# blank string into the prereq set.
	if _chosen != "":
		GameState.sponsor_offers_taken_ids.append(_chosen)
	sponsor_chosen.emit(_chosen)
