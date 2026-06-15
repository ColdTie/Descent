extends Control
## Run 36: meta-progression screen.
##
## Reached from TitleScreen → META. Shows the player's shard balance, a
## grid of every perk in `Perks.DEFS`, and a back button. Each perk card
## flips between three states:
##   - LOCKED — unpurchased. Cost + BUY button (disabled when shards < cost).
##   - OWNED — bought but not in the active loadout. EQUIP button.
##   - EQUIPPED — active for the next run. UNEQUIP button.
##
## The MAX_EQUIPPED cap (currently 2) is surfaced both as a header line and
## inline (EQUIP buttons grey out when the loadout is full).
##
## Pure scene logic — no game-state mutation here; every action goes
## through MetaProgress, which persists on every change.

signal meta_closed

const CARD_WIDTH: float = 250.0
const CARD_HEIGHT: float = 200.0
# Run 37: two-tab view — PERKS (the original Run-36 grid) and ACHIEVEMENTS
# (the new lifetime gallery). The tabs share the same outer panel + header
# row, only the body grid swaps. Mirrors the toggle idiom used in BattleScene's
# pause menu so the affordance reads consistently.
const TAB_PERKS: String = "perks"
const TAB_ACHIEVEMENTS: String = "achievements"

var _shard_label: Label
var _equipped_label: Label
var _stats_label: Label
var _cards_container: GridContainer
var _tab_perks_btn: Button
var _tab_achievements_btn: Button
var _active_tab: String = TAB_PERKS


func _ready() -> void:
	# Run 36: signal the autoload directly so a purchase/equip elsewhere in
	# the scene tree (none today, but future async refresh paths) would
	# still keep the UI in sync.
	MetaProgress.shards_changed.connect(_on_shards_changed)
	MetaProgress.perks_equipped_changed.connect(_on_equipped_changed)
	_build_ui()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color(0.32, 0.12, 0.50, 0.10)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glow)

	# Outer panel
	var outer := PanelContainer.new()
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.offset_left = -560.0
	outer.offset_top = -320.0
	outer.offset_right = 560.0
	outer.offset_bottom = 320.0
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.10, 0.98)
	s.border_color = Color(0.55, 0.36, 0.78)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(24.0)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	s.shadow_size = 16
	outer.add_theme_stylebox_override("panel", s)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	outer.add_child(vbox)

	# Header
	var title := Label.new()
	title.text = "META PROGRESSION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.86, 0.66, 1.0))
	vbox.add_child(title)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(1040.0, 2.0)
	divider.color = Color(0.55, 0.36, 0.78, 0.55)
	divider.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	# Shard + stats header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 28)
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header_row)

	_shard_label = Label.new()
	_shard_label.add_theme_font_size_override("font_size", 18)
	_shard_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	header_row.add_child(_shard_label)

	_equipped_label = Label.new()
	_equipped_label.add_theme_font_size_override("font_size", 14)
	_equipped_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.84))
	header_row.add_child(_equipped_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70))
	header_row.add_child(_stats_label)

	# Run 37: tab toggle row — PERKS / ACHIEVEMENTS. The active tab pops with
	# a brighter accent so the player always knows which body grid is showing.
	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 8)
	vbox.add_child(tab_row)

	_tab_perks_btn = Button.new()
	_tab_perks_btn.custom_minimum_size = Vector2(180.0, 32.0)
	_tab_perks_btn.add_theme_font_size_override("font_size", 14)
	_tab_perks_btn.pressed.connect(_on_tab_pressed.bind(TAB_PERKS))
	tab_row.add_child(_tab_perks_btn)

	_tab_achievements_btn = Button.new()
	_tab_achievements_btn.custom_minimum_size = Vector2(220.0, 32.0)
	_tab_achievements_btn.add_theme_font_size_override("font_size", 14)
	_tab_achievements_btn.pressed.connect(_on_tab_pressed.bind(TAB_ACHIEVEMENTS))
	tab_row.add_child(_tab_achievements_btn)

	# Body grid — repopulated per tab. Perks use 4 cols (cards are wide);
	# achievements use 4 cols of smaller cards (more entries to display).
	# Wrapped in a ScrollContainer so the achievements tab can overflow the
	# fixed-height outer panel cleanly without truncating cards.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1060.0, 380.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_cards_container = GridContainer.new()
	_cards_container.columns = 4
	_cards_container.add_theme_constant_override("h_separation", 14)
	_cards_container.add_theme_constant_override("v_separation", 14)
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards_container)

	# Back button
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.text = "BACK TO TITLE"
	back_btn.custom_minimum_size = Vector2(260.0, 50.0)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.add_theme_color_override("font_color", Color(0.96, 0.76, 0.10))
	back_btn.pressed.connect(_on_back)
	btn_row.add_child(back_btn)

	_refresh()


func _refresh() -> void:
	_shard_label.text = "$  %d shards" % MetaProgress.shards
	_equipped_label.text = "Equipped: %d / %d" % [
		MetaProgress.equipped_perks.size(), Perks.MAX_EQUIPPED]
	var win_pct: int = 0
	if MetaProgress.total_runs > 0:
		win_pct = MetaProgress.total_wins * 100 / MetaProgress.total_runs
	# Run 37: header gains a lifetime-achievements counter so a player who's
	# never opened the gallery tab still gets a hint there's progress to view.
	var ach_count: int = MetaProgress.total_achievements_unlocked_lifetime()
	var ach_total: int = Achievements.DEFS.size()
	_stats_label.text = "Runs: %d  ·  Wins: %d (%d%%)  ·  Best floor: %d  ·  Achievements: %d/%d" % [
		MetaProgress.total_runs, MetaProgress.total_wins, win_pct,
		MetaProgress.best_floor, ach_count, ach_total]
	_refresh_tab_buttons()
	_rebuild_cards()


func _refresh_tab_buttons() -> void:
	## Run 37: highlight the active tab. PERKS is the default-on landing tab
	## so existing players don't see a behavior change on entry.
	var ach_count: int = MetaProgress.total_achievements_unlocked_lifetime()
	var ach_total: int = Achievements.DEFS.size()
	_tab_perks_btn.text = "PERKS  (%d / %d)" % [
		MetaProgress.owned_perks.size(), Perks.DEFS.size()]
	_tab_achievements_btn.text = "ACHIEVEMENTS  (%d / %d)" % [ach_count, ach_total]
	if _active_tab == TAB_PERKS:
		_tab_perks_btn.add_theme_color_override("font_color", Color(0.96, 0.76, 0.10))
		_tab_achievements_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	else:
		_tab_perks_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		_tab_achievements_btn.add_theme_color_override("font_color", Color(0.96, 0.76, 0.10))


func _rebuild_cards() -> void:
	for child: Node in _cards_container.get_children():
		child.queue_free()
	if _active_tab == TAB_ACHIEVEMENTS:
		_cards_container.columns = 4
		for aid: String in Achievements.DEFS.keys():
			_cards_container.add_child(_make_achievement_card(aid))
	else:
		_cards_container.columns = 4
		for pid: String in Perks.all_ids():
			_cards_container.add_child(_make_perk_card(pid))


func _on_tab_pressed(tab: String) -> void:
	if tab == _active_tab:
		return
	_active_tab = tab
	AudioManager.play("select")
	_refresh()


func _make_achievement_card(achievement_id: String) -> PanelContainer:
	## Locked = grey card with name hidden behind "??? — Hidden" if the
	## achievement def itself sets `hidden: true` AND it's still locked.
	## Unlocked = full info + green border + UNLOCKED tag.
	var def: Dictionary = Achievements.DEFS.get(achievement_id, {})
	var unlocked: bool = MetaProgress.is_achievement_unlocked_lifetime(achievement_id)
	var hidden: bool = bool(def.get("hidden", false)) and not unlocked

	var border_color: Color = Color(0.32, 0.30, 0.40)
	if unlocked:
		border_color = Color(0.30, 0.92, 0.42)

	var panel := PanelContainer.new()
	# Sized to fit 4 columns inside the 1060-wide scroll viewport.
	panel.custom_minimum_size = Vector2(250.0, 130.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.07, 0.13, 0.96)
	bg.border_color = border_color
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	bg.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", bg)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	# Header row: name + status tag
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	col.add_child(header)

	var name_lbl := Label.new()
	if hidden:
		name_lbl.text = "??? — HIDDEN"
		name_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	else:
		name_lbl.text = String(def.get("name", achievement_id)).to_upper()
		name_lbl.add_theme_color_override("font_color", border_color.lightened(0.20))
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	var status := Label.new()
	if unlocked:
		status.text = "UNLOCKED"
		status.add_theme_color_override("font_color", Color(0.30, 0.92, 0.42))
	else:
		status.text = "LOCKED"
		status.add_theme_color_override("font_color", Color(0.62, 0.55, 0.30))
	status.add_theme_font_size_override("font_size", 11)
	header.add_child(status)

	# Description
	var desc := Label.new()
	if hidden:
		desc.text = "A hidden achievement. Earn it to read the entry."
		desc.add_theme_color_override("font_color", Color(0.52, 0.52, 0.58))
	else:
		desc.text = String(def.get("desc", ""))
		desc.add_theme_color_override("font_color", Color(0.68, 0.68, 0.74))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.custom_minimum_size = Vector2(226.0, 0.0)
	col.add_child(desc)

	# Reward line — show the audience-score / lifetime-shard reward so the
	# player understands why pursuing locked achievements matters.
	var reward := Label.new()
	var aud: int = int(def.get("audience", 10))
	if unlocked:
		reward.text = "+%d audience  ·  paid %d shards" % [
			aud, MetaProgress.SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK]
		reward.add_theme_color_override("font_color", Color(0.55, 0.80, 1.0))
	else:
		reward.text = "+%d audience  ·  +%d shards on first unlock" % [
			aud, MetaProgress.SHARDS_PER_ACHIEVEMENT_FIRST_UNLOCK]
		reward.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	reward.add_theme_font_size_override("font_size", 10)
	col.add_child(reward)

	return panel


func _make_perk_card(perk_id: String) -> PanelContainer:
	var perk: Dictionary = Perks.get_perk(perk_id)
	var owned: bool = MetaProgress.is_owned(perk_id)
	var equipped: bool = MetaProgress.is_equipped(perk_id)
	var cost: int = int(perk.get("cost", 0))

	var border_color: Color = Color(0.32, 0.30, 0.40)
	if equipped:
		border_color = Color(0.30, 0.92, 0.42)  # bright green
	elif owned:
		border_color = Color(0.74, 0.58, 1.0)  # purple

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.07, 0.13, 0.96)
	bg.border_color = border_color
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	bg.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", bg)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	# Header row: icon + name + status tag
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	col.add_child(header)

	var icon := Label.new()
	icon.text = String(perk.get("icon", "*"))
	icon.add_theme_font_size_override("font_size", 18)
	icon.add_theme_color_override("font_color", border_color.lightened(0.15))
	header.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = String(perk.get("name", perk_id)).to_upper()
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", border_color.lightened(0.20))
	header.add_child(name_lbl)

	# Description
	var desc := Label.new()
	desc.text = String(perk.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.68, 0.68, 0.74))
	desc.custom_minimum_size = Vector2(CARD_WIDTH - 24.0, 0.0)
	col.add_child(desc)

	# Status line
	var status := Label.new()
	if equipped:
		status.text = "EQUIPPED"
		status.add_theme_color_override("font_color", Color(0.30, 0.92, 0.42))
	elif owned:
		status.text = "OWNED"
		status.add_theme_color_override("font_color", Color(0.74, 0.58, 1.0))
	else:
		status.text = "%d shards" % cost
		status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	status.add_theme_font_size_override("font_size", 12)
	col.add_child(status)

	# Action button
	var action := Button.new()
	action.add_theme_font_size_override("font_size", 13)
	if not owned:
		action.text = "BUY"
		if MetaProgress.shards < cost:
			action.disabled = true
			action.add_theme_color_override("font_color", Color(0.45, 0.40, 0.50))
		else:
			action.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
		action.pressed.connect(_on_buy_pressed.bind(perk_id))
	elif equipped:
		action.text = "UNEQUIP"
		action.add_theme_color_override("font_color", Color(0.55, 0.95, 0.60))
		action.pressed.connect(_on_unequip_pressed.bind(perk_id))
	else:
		action.text = "EQUIP"
		# Equip is greyed out — but still clickable — when the loadout is
		# full. We still attach the handler so the SFX fires; the autoload
		# returns false and we just don't update anything.
		if MetaProgress.equipped_perks.size() >= Perks.MAX_EQUIPPED:
			action.disabled = true
			action.add_theme_color_override("font_color", Color(0.45, 0.40, 0.50))
		else:
			action.add_theme_color_override("font_color", Color(0.74, 0.58, 1.0))
		action.pressed.connect(_on_equip_pressed.bind(perk_id))
	col.add_child(action)

	return panel


func _on_buy_pressed(perk_id: String) -> void:
	if MetaProgress.purchase_perk(perk_id):
		AudioManager.play("select")
		_refresh()


func _on_equip_pressed(perk_id: String) -> void:
	if MetaProgress.equip_perk(perk_id):
		AudioManager.play("select")
		_refresh()


func _on_unequip_pressed(perk_id: String) -> void:
	if MetaProgress.unequip_perk(perk_id):
		AudioManager.play("select")
		_refresh()


func _on_back() -> void:
	AudioManager.play("select")
	meta_closed.emit()


func _on_shards_changed(_total: int, _delta: int) -> void:
	# Run 36: rebuilt rather than incremented because cost-affordability
	# affects every locked card's button state.
	if is_inside_tree():
		_refresh()


func _on_equipped_changed(_equipped: Array) -> void:
	if is_inside_tree():
		_refresh()
