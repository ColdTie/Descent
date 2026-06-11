extends Control
## Post-battle loot choice screen: "Choose One" trade-off items.
## Run 11: styled cards with type-based icon + border colors.
## Run 24: rarity tiers — Common / Rare / Legendary. Rarity gates the pool by
## floor depth and triggers a screen flash + special quip on Legendary picks.

signal loot_chosen(loot_id: String)

# Rarity tiers — drives draw weighting (`weight`), border color, and label.
# Higher floors raise the chance of seeing Rare/Legendary cards.
const RARITY_COMMON: String = "common"
const RARITY_RARE: String = "rare"
const RARITY_LEGENDARY: String = "legendary"

const RARITY_COLORS: Dictionary = {
	RARITY_COMMON:  Color(0.72, 0.72, 0.74),
	RARITY_RARE:  Color(0.42, 0.72, 1.00),
	RARITY_LEGENDARY: Color(1.00, 0.55, 0.10),
}

const RARITY_LABELS: Dictionary = {
	RARITY_COMMON:  "COMMON",
	RARITY_RARE:  "RARE",
	RARITY_LEGENDARY: "LEGENDARY",
}

const LOOT_POOL: Array[Dictionary] = [
	{"id": "heal_small", "type": "heal",  "icon": "+",
	 "rarity": RARITY_COMMON,
	 "name": "Field Dressing",  "value": 30,
	 "desc": "Restore 30 HP. Simple. Effective. Boring."},
	{"id": "heal_large", "type": "heal",  "icon": "+",
	 "rarity": RARITY_RARE,
	 "name": "Elixir of Life",  "value": 60,
	 "desc": "Restore 60 HP. The dungeon begrudgingly provides this."},
	{"id": "atk_boost",  "type": "stat",  "icon": "ATK",  "stat": "attack",  "value": 10,
	 "rarity": RARITY_COMMON,
	 "name": "Berserker Salve",
	 "desc": "+10 Attack. You become marginally scarier."},
	{"id": "def_boost",  "type": "stat",  "icon": "DEF",  "stat": "defense", "value": 3,
	 "rarity": RARITY_COMMON,
	 "name": "Chitin Plate Shard",
	 "desc": "+3 Armor. Every bit helps. Or doesn't."},
	{"id": "hp_boost",  "type": "stat",  "icon": "HP",  "stat": "max_hp",  "value": 25,
	 "rarity": RARITY_COMMON,
	 "name": "Heart of Stone",
	 "desc": "+25 Max HP. The dungeon grows a piece of you."},
	{"id": "warlords_brand","type":"multi","icon": "*",
	 "rarity": RARITY_RARE,
	 "attack": 6, "max_hp": 15,
	 "name": "Warlord's Brand",
	 "desc": "+6 Attack and +15 Max HP. The dungeon brands its survivors."},
	{"id": "floor_skip", "type": "skip",  "icon": "^",
	 "rarity": RARITY_LEGENDARY,
	 "name": "Teleport Shard",
	 "desc": "Skip the next floor entirely. Cowardly but effective."},
	{"id": "spd_boost",  "type": "stat",  "icon": "SPD", "stat": "speed",  "value": 3,
	 "rarity": RARITY_COMMON,
	 "name": "Quicksilver Vial",
	 "desc": "+3 Speed. Act earlier, die later."},
	# Run 24: new rare/legendary items
	{"id": "phoenix_feather", "type": "heal", "icon": "+",
	 "rarity": RARITY_LEGENDARY,
	 "value": 999,
	 "name": "Phoenix Feather",
	 "desc": "Fully restore HP. The System is offended."},
	{"id": "obsidian_edge", "type": "stat", "icon": "ATK", "stat": "attack", "value": 18,
	 "rarity": RARITY_RARE,
	 "name": "Obsidian Edge",
	 "desc": "+18 Attack. The blade hums. Pretend it doesn't."},
	{"id": "stoneforged", "type": "multi", "icon": "*",
	 "rarity": RARITY_LEGENDARY,
	 "attack": 8, "defense": 4, "max_hp": 30,
	 "name": "Stoneforged Pact",
	 "desc": "+8 ATK, +4 DEF, +30 Max HP. A bargain you'll regret later."},
	{"id": "duelist_band", "type": "multi", "icon": "*",
	 "rarity": RARITY_RARE,
	 "attack": 4, "speed": 4,
	 "name": "Duelist's Band",
	 "desc": "+4 Attack and +4 Speed. Faster, sharper, smugger."},
]

# Border/accent colors per item type (kept for legacy compatibility — the
# rarity color now drives the BORDER and the type drives the ICON tint).
const TYPE_COLORS: Dictionary = {
	"heal":  Color(0.18, 0.88, 0.28),
	"stat":  Color(0.92, 0.76, 0.10),
	"multi":  Color(0.95, 0.55, 0.12),
	"skip":  Color(0.62, 0.32, 0.92),
}

# Per-rarity draw weights — these scale with floor depth so deeper floors
# see more Rare/Legendary loot. Index = floor_tier (0 stone, 1 obsidian, 2 void).
const RARITY_WEIGHTS_BY_TIER: Array[Dictionary] = [
	{RARITY_COMMON: 80, RARITY_RARE: 18, RARITY_LEGENDARY: 2},   # Floors 1-6
	{RARITY_COMMON: 55, RARITY_RARE: 35, RARITY_LEGENDARY: 10},  # Floors 7-12
	{RARITY_COMMON: 30, RARITY_RARE: 45, RARITY_LEGENDARY: 25},  # Floors 13-18
]

@onready var _loot_cards:  HBoxContainer = $VBox/LootCards
@onready var _system_label:  Label  = $VBox/SystemLabel
@onready var _continue_button: Button  = $VBox/ContinueButton

var _chosen: String = ""

func _ready() -> void:
	SystemVoice.speak("loot")
	SystemVoice.line_spoken.connect(func(text: String, _d: float) -> void:
		_system_label.text = text)
	_continue_button.pressed.connect(_on_continue)
	_generate_choices()

func _floor_tier() -> int:
	## Tier 0 = floors 1-6, 1 = 7-12, 2 = 13-18. Matches BattleScene's tier math.
	return clamp((GameState.floor_num - 1) / 6, 0, 2)

func _pick_rarity_for_slot(rng: RandomNumberGenerator) -> String:
	## Weighted pick of a rarity for one card slot.
	var weights: Dictionary = RARITY_WEIGHTS_BY_TIER[_floor_tier()]
	var total: int = 0
	for r: String in weights:
		total += int(weights[r])
	var roll: int = rng.randi_range(0, total - 1)
	var cum: int = 0
	for r: String in weights:
		cum += int(weights[r])
		if roll < cum:
			return r
	return RARITY_COMMON

func _generate_choices() -> void:
	## Run 24: each of the 3 slots first rolls a rarity (weighted by tier),
	## then a random item of that rarity. Falls back to common if a tier
	## happens to be empty (defensive). No duplicate items across the slate.
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run_seed ^ (GameState.floor_num * 9001 + 7)
	var picked_ids: Dictionary = {}
	var any_legendary: bool = false
	for _slot: int in range(3):
		var target_rarity: String = _pick_rarity_for_slot(rng)
		var item: Dictionary = _draw_item_of_rarity(target_rarity, picked_ids, rng)
		if item.is_empty():
			# Try lower rarity tiers if the chosen pool was exhausted.
			for fallback: String in [RARITY_RARE, RARITY_COMMON]:
				item = _draw_item_of_rarity(fallback, picked_ids, rng)
				if not item.is_empty():
					break
		if item.is_empty():
			continue
		picked_ids[item["id"]] = true
		if item.get("rarity", RARITY_COMMON) == RARITY_LEGENDARY:
			any_legendary = true
		_loot_cards.add_child(_make_loot_card(item))
	# Legendary card on the slate → screen flash + special quip on entry.
	if any_legendary:
		_flash_legendary_aura()
		SystemVoice.speak_direct("Legendary loot detected. The dungeon must want you dead specifically.")

func _draw_item_of_rarity(rarity: String, exclude: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[Dictionary] = []
	for it: Dictionary in LOOT_POOL:
		if it.get("rarity", RARITY_COMMON) != rarity:
			continue
		if exclude.has(it["id"]):
			continue
		pool.append(it)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]

func _flash_legendary_aura() -> void:
	## Soft orange screen flash so a Legendary slate feels special.
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

func _make_loot_card(item: Dictionary) -> PanelContainer:
	var item_type: String = item.get("type", "stat")
	var type_col: Color = TYPE_COLORS.get(item_type, Color(0.9, 0.7, 0.1))
	var rarity: String = item.get("rarity", RARITY_COMMON)
	var border_col: Color = RARITY_COLORS.get(rarity, type_col)
	var border_w: int = 4 if rarity == RARITY_LEGENDARY else 2

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250.0, 220.0)
	var ps := StyleBoxFlat.new()
	ps.bg_color  = Color(0.07, 0.05, 0.11, 0.97)
	ps.border_color = border_col
	ps.set_border_width_all(border_w)
	ps.set_corner_radius_all(5)
	ps.set_content_margin_all(16.0)
	ps.shadow_color = Color(border_col.r * 0.4, border_col.g * 0.4, border_col.b * 0.4, 0.65)
	ps.shadow_size = 10 if rarity == RARITY_LEGENDARY else 6
	panel.add_theme_stylebox_override("panel", ps)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Rarity label at top
	var rarity_lbl := Label.new()
	rarity_lbl.text = RARITY_LABELS.get(rarity, "")
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	rarity_lbl.add_theme_color_override("font_color", border_col)
	vbox.add_child(rarity_lbl)

	# Icon + name row
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var icon_lbl := Label.new()
	icon_lbl.text = item.get("icon", "*")
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.add_theme_color_override("font_color", type_col)
	header.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = item["name"]
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", border_col.lightened(0.15))
	header.add_child(name_lbl)

	# Thin divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(218.0, 1.0)
	div.color = border_col.darkened(0.42)
	div.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(div)

	var desc_lbl := Label.new()
	desc_lbl.text = item["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.80, 0.70))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.custom_minimum_size = Vector2(218.0, 0.0)
	# Run 32: let the description absorb the leftover card height so every
	# card's TAKE IT button pins to the bottom edge — previously the buttons
	# floated at differing heights depending on description line count.
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "TAKE IT"
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", border_col)
	btn.pressed.connect(_on_loot_selected.bind(item["id"], item, panel, ps))
	vbox.add_child(btn)

	# Pulsing border for Legendary so the eye finds it without reading.
	if rarity == RARITY_LEGENDARY:
		var tw: Tween = create_tween()
		tw.set_loops()
		tw.tween_property(ps, "shadow_size", 16, 1.1) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(ps, "shadow_size", 8, 1.1) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	return panel

func _on_loot_selected(loot_id: String, item: Dictionary,
		panel: PanelContainer, ps: StyleBoxFlat) -> void:
	_chosen = loot_id
	var rarity: String = item.get("rarity", RARITY_COMMON)
	# Legendary picks get a victory sting + special quip.
	if rarity == RARITY_LEGENDARY:
		AudioManager.play("victory", 0.0, -4.0)
		_flash_legendary_aura()
		SystemVoice.speak_direct("A LEGENDARY pick. Bold. Foolish. Both, probably.")
	else:
		AudioManager.play("heal" if item.get("type", "") == "heal" else "select")
	_apply_loot(item)
	for child: Node in _loot_cards.get_children():
		child.modulate = Color(0.42, 0.42, 0.42)
	panel.modulate = Color(1.0, 1.0, 1.0)
	var col: Color = RARITY_COLORS.get(rarity, Color(0.9, 0.7, 0.1))
	ps.border_color = col
	ps.set_border_width_all(4)
	_continue_button.visible = true

func _apply_loot(item: Dictionary) -> void:
	match item["type"]:
		"heal":
			GameState.heal(item.get("value", 30))
			SystemVoice.speak_direct(
				"You've healed %d HP. Try not to need it again." % item.get("value", 30))
		"stat":
			var stat: String = item.get("stat", "attack")
			var val: int = item.get("value", 5)
			match stat:
				"attack":
					GameState.hero_base_stats["attack"] = \
						GameState.hero_base_stats.get("attack", 0) + val
				"defense":
					GameState.hero_base_stats["defense"] = \
						GameState.hero_base_stats.get("defense", 0) + val
				"max_hp":
					GameState.hero_max_hp += val
					GameState.hero_hp = min(GameState.hero_hp + val, GameState.hero_max_hp)
				"speed":
					GameState.hero_base_stats["speed"] = \
						GameState.hero_base_stats.get("speed", 10) + val
			SystemVoice.speak_direct("Stat upgraded. You remain, somehow, alive.")
		"multi":
			GameState.hero_base_stats["attack"] = \
				GameState.hero_base_stats.get("attack", 0) + item.get("attack", 0)
			GameState.hero_base_stats["defense"] = \
				GameState.hero_base_stats.get("defense", 0) + item.get("defense", 0)
			GameState.hero_base_stats["speed"] = \
				GameState.hero_base_stats.get("speed", 10) + item.get("speed", 0)
			var hp_gain: int = item.get("max_hp", 0)
			if hp_gain > 0:
				GameState.hero_max_hp += hp_gain
				GameState.hero_hp = min(GameState.hero_hp + hp_gain, GameState.hero_max_hp)
			SystemVoice.speak_direct("Branded. Stronger and harder to kill. The dungeon notices.")
		"skip":
			GameState.floor_num += 1
			SystemVoice.speak_direct("Skipped a floor. The System judges you silently.")

func _on_continue() -> void:
	loot_chosen.emit(_chosen)
