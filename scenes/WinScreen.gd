extends Control
## Shown when the hero clears all 18 floors — a true victory.
## Run 11: gold-trimmed stone panel, styled stat cards.

signal play_again

# Run 44: meta-unlock toasts surfaced by this run. Populated by `prepare()`
# from Main.gd's pre/post-`record_run_end` delta capture. Empty when the win
# didn't cross any unlock threshold (e.g. a 2nd-class repeat clear) — the
# banner section is skipped entirely in that case.
var _unlocked_skins: Array[String] = []
var _unlocked_perk_slots: int = 0

func prepare(data: Dictionary) -> void:
	## Read the unlock deltas Main.gd captured around `record_run_end`. Called
	## by `_load_scene` BEFORE `_ready`, so the values are live when the UI
	## builds. Defensive: unknown keys / wrong types fall through to the
	## empty defaults so a future Main.gd reorder can't crash this scene.
	var sk_raw: Variant = data.get("unlocked_skins", [])
	if sk_raw is Array:
		_unlocked_skins.clear()
		for v: Variant in sk_raw:
			var sid: String = String(v)
			# Drop entries that aren't in Skins.DEFS — a stale field from a
			# future variant removal would otherwise crash `Skins.get_skin`.
			if Skins.DEFS.has(sid):
				_unlocked_skins.append(sid)
	_unlocked_perk_slots = max(0, int(data.get("unlocked_perk_slots", 0)))

func _ready() -> void:
	# Run 19: finishing the descent is itself an achievement.
	Achievements.unlock("descended")
	_build_ui()

func _build_ui() -> void:
	# ── Background ────────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color(0.55, 0.42, 0.0, 0.10)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glow)

	# ── Stone panel — gold border for victory ─────────────────────────────────
	var outer := PanelContainer.new()
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.offset_left  = -510.0
	outer.offset_top  = -270.0
	outer.offset_right  =  510.0
	outer.offset_bottom =  270.0
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.10, 0.98)
	s.border_color = Color(0.72, 0.56, 0.10)
	s.set_border_width_all(3)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(30.0)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	s.shadow_size  = 18
	outer.add_theme_stylebox_override("panel", s)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	outer.add_child(vbox)

	# ── Header ────────────────────────────────────────────────────────────────
	var floor_lbl := Label.new()
	floor_lbl.text = "ALL %d FLOORS CONQUERED" % GameState.TOTAL_FLOORS
	floor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_lbl.add_theme_font_size_override("font_size", 20)
	floor_lbl.add_theme_color_override("font_color", Color(0.66, 0.54, 0.20))
	vbox.add_child(floor_lbl)

	# ── "YOU WIN" title ───────────────────────────────────────────────────────
	var title_wrap := Control.new()
	title_wrap.custom_minimum_size = Vector2(0.0, 110.0)
	vbox.add_child(title_wrap)

	var shadow_lbl := Label.new()
	shadow_lbl.text = "YOU  WIN"
	shadow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shadow_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow_lbl.offset_left = 3.0; shadow_lbl.offset_top = 4.0
	shadow_lbl.add_theme_font_size_override("font_size", 96)
	shadow_lbl.add_theme_color_override("font_color", Color(0.32, 0.20, 0.0, 0.68))
	title_wrap.add_child(shadow_lbl)

	var title := Label.new()
	title.text = "YOU  WIN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.12))
	title.modulate.a = 0.0
	title_wrap.add_child(title)
	var tw: Tween = create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.80)

	# ── Divider ───────────────────────────────────────────────────────────────
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(940.0, 2.0)
	divider.color = Color(0.60, 0.48, 0.10, 0.70)
	divider.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	# ── System quip ───────────────────────────────────────────────────────────
	var quip := Label.new()
	quip.text = SystemVoice.pick("win")
	quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip.add_theme_font_size_override("font_size", 18)
	quip.add_theme_color_override("font_color", Color(0.80, 0.80, 0.64))
	quip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip.custom_minimum_size = Vector2(940.0, 0.0)
	vbox.add_child(quip)

	# ── Stat cards ────────────────────────────────────────────────────────────
	var stats := HBoxContainer.new()
	# Run 21: tightened separation 24->14 to make room for the GOLD card.
	stats.add_theme_constant_override("separation", 14)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(stats)

	_stat_card(stats, "*", "SCORE",  str(GameState.run_score()),  Color(1.00, 0.84, 0.16))
	_stat_card(stats, "*", "LEVEL",  str(GameState.hero_level),  Color(0.38, 0.60, 1.00))
	_stat_card(stats, "ATK", "KILLS",  str(GameState.total_kills),  Color(0.90, 0.34, 0.20))
	_stat_card(stats, "*", "AUDIENCE", str(GameState.audience_score),  Color(0.96, 0.78, 0.18))
	# Run 21: gold left over at end of run — small contribution to SCORE.
	_stat_card(stats, "$", "GOLD",  str(GameState.hero_gold),  Color(1.00, 0.80, 0.16))

	# Run 36: meta-progression payout for this run. Main.gd already called
	# `MetaProgress.record_run_end` before loading this scene, so the wallet
	# is up to date — we just display the new totals + a "this run earned"
	# breakdown so the player feels the loop closing.
	var shard_payout: int = MetaProgress.shards_for_run(
		GameState.floor_num, GameState.bosses_slain, true, GameState.hero_class)
	var shard_row := Label.new()
	shard_row.text = "$  +%d shards this run  ·  total %d  ·  spend on perks from the title menu" % [
		shard_payout, MetaProgress.shards]
	shard_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shard_row.add_theme_font_size_override("font_size", 14)
	shard_row.add_theme_color_override("font_color", Color(0.86, 0.66, 1.0))
	vbox.add_child(shard_row)

	# Run 44: meta-unlock toasts — surface skin/perk-slot milestones the win
	# just earned so the player doesn't have to open the MetaScreen to notice.
	# Skipped entirely when nothing unlocked (zero visual cost on a repeat
	# class win, which is the steady-state for a returning player).
	if not _unlocked_skins.is_empty() or _unlocked_perk_slots > 0:
		_build_unlock_banners(vbox)

	# Run 19: achievement roster — show what the player earned this run.
	var ach_count: int = Achievements.unlocked_ids.size()
	var ach_total: int = Achievements.DEFS.size()
	var ach_row := Label.new()
	ach_row.text = "*  %d / %d achievements unlocked  *" % [ach_count, ach_total]
	ach_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ach_row.add_theme_font_size_override("font_size", 13)
	ach_row.add_theme_color_override("font_color", Color(0.78, 0.72, 0.50))
	vbox.add_child(ach_row)
	if ach_count > 0:
		var names: Array[String] = []
		for aid: String in Achievements.unlocked_ids:
			var def: Dictionary = Achievements.DEFS.get(aid, {})
			names.append(str(def.get("name", aid)))
		var names_lbl := Label.new()
		names_lbl.text = ", ".join(names)
		names_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		names_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		names_lbl.custom_minimum_size = Vector2(940.0, 0.0)
		names_lbl.add_theme_font_size_override("font_size", 11)
		names_lbl.add_theme_color_override("font_color", Color(0.58, 0.55, 0.40))
		vbox.add_child(names_lbl)

	# ── Button ────────────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn := Button.new()
	btn.text = "PLAY AGAIN"
	btn.custom_minimum_size = Vector2(270.0, 58.0)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(1.0, 0.86, 0.12))
	btn.pressed.connect(_on_play_again)
	btn_row.add_child(btn)


func _build_unlock_banners(parent: VBoxContainer) -> void:
	## Run 44: render one banner per unlock the win earned. Two kinds:
	##  - "★ PERK SLOT UNLOCKED" — fires when `Perks.max_equipped` grew across
	##    record_run_end. The label brightens to two stars (★★) for the
	##    capstone 4th slot so the all-class clear feels distinct from the
	##    first-win 3rd slot.
	##  - "NEW SKIN UNLOCKED — <name>" — one row per skin id in
	##    `_unlocked_skins`. Carries a 22×22 color swatch tinted to the
	##    skin's actual color so the player previews the palette before
	##    opening the MetaScreen → SKINS tab.
	## The whole section is wrapped in a soft-purple-bordered PanelContainer so
	## it reads as a peer to the shard-payout strip above it (meta-progression
	## rewards land in the same visual band).
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.05, 0.13, 0.92)
	ps.border_color = Color(0.78, 0.52, 1.0, 0.72)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(5)
	ps.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	if _unlocked_perk_slots > 0:
		# Two-star prefix when the cap crossed past the 3rd slot (today: the
		# 4th-slot all-class milestone) — single-star otherwise. The exact
		# `Perks.max_equipped(lifetime_stats())` value is the new cap; reading
		# from MetaProgress live ensures the displayed N matches whatever a
		# future bonus-stacking change produces.
		var new_cap: int = Perks.max_equipped(MetaProgress.lifetime_stats())
		var stars: String = "**" if new_cap >= Perks.MAX_EQUIPPED + Perks.WIN_BONUS_SLOTS + Perks.FOURTH_SLOT_BONUS_SLOTS else "*"
		var slot_lbl := Label.new()
		slot_lbl.text = "%s  PERK SLOT UNLOCKED — %d slots equippable" % [stars, new_cap]
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.add_theme_font_size_override("font_size", 16)
		slot_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
		col.add_child(slot_lbl)

	for sid: String in _unlocked_skins:
		var def: Dictionary = Skins.get_skin(sid)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		col.add_child(row)

		var swatch := ColorRect.new()
		swatch.color = Skins.tint_for(sid)
		swatch.custom_minimum_size = Vector2(22.0, 22.0)
		swatch.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(swatch)

		var lbl := Label.new()
		var name_text: String = String(def.get("name", sid))
		lbl.text = "NEW SKIN UNLOCKED — %s" % name_text
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.86, 0.72, 1.0))
		row.add_child(lbl)


func _stat_card(parent: Node, icon: String, label_text: String,
		value_text: String, val_color: Color) -> void:
	var panel := PanelContainer.new()
	# Run 21: shrunk from 270 -> 188 so the new GOLD card fits (5 cards now).
	panel.custom_minimum_size = Vector2(188.0, 90.0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.09, 0.07, 0.13, 0.96)
	ps.border_color = val_color.darkened(0.38)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(4)
	ps.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)

	var ico := Label.new()
	ico.text = icon
	ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ico.add_theme_font_size_override("font_size", 22)
	ico.add_theme_color_override("font_color", val_color)
	col.add_child(ico)

	var val := Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 26)
	val.add_theme_color_override("font_color", val_color)
	col.add_child(val)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.48, 0.46, 0.50))
	col.add_child(lbl)


func _on_play_again() -> void:
	play_again.emit()
