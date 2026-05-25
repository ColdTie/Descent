extends Node2D
## Visual driver for one battle encounter on the hex grid.
## Run 2: hero movement, ability effects, cave atmosphere, enemy AI variety.

signal battle_complete(hero_won: bool, xp_earned: int)

const HEX_SIZE: float = 38.0
const HERO_COLOR     := Color(0.25, 0.55, 1.0)
const ENEMY_COLOR    := Color(0.9,  0.2,  0.15)
const LAVA_COLOR     := Color(0.92, 0.38, 0.04)
const FLOOR_COLOR    := Color(0.16, 0.13, 0.19)
const FLOOR_DARK     := Color(0.10, 0.08, 0.13)
const SELECTED_COLOR := Color(1.0,  0.9,  0.2)
const DEAD_MODULATE  := Color(0.35, 0.35, 0.35, 0.4)
const MOVE_HL_COLOR  := Color(0.15, 0.22, 0.40)  # dark blue – valid move
const ATK_HL_COLOR   := Color(0.44, 0.08, 0.08)  # dark red  – attackable
const SELF_HL_COLOR  := Color(0.12, 0.38, 0.18)  # dark green – self-ability

var _engine: BattleEngine
var _map: DungeonMap
var _hero: Combatant
var _enemies: Array[Combatant] = []
var _all_combatants: Array[Combatant] = []

# Visual nodes
var _hex_polys: Dictionary    = {}  # Vector2i  -> Polygon2D
var _entity_nodes: Dictionary = {}  # id (String) -> Node2D
var _ability_btns: Dictionary = {}  # ability_id  -> Button
var _lava_hexes: Array[Vector2i] = []

# Dynamically-created UI nodes
var _atmo_layer: Node2D
var _use_btn: Button
var _mode_label: Label

# State
var _selected_ability: String = "basic_attack"
var _player_turn: bool = false
var _ability_cooldowns: Dictionary = {}  # ability_id -> turns_remaining
var _battle_rng: RandomNumberGenerator

# @onready nodes (defined in .tscn)
@onready var _hex_layer:      Node2D       = $HexLayer
@onready var _entity_layer:   Node2D       = $EntityLayer
@onready var _floor_label:    Label        = $UILayer/FloorLabel
@onready var _system_banner:  Panel        = $UILayer/SystemBanner
@onready var _system_text:    Label        = $UILayer/SystemBanner/SystemText
@onready var _ability_bar:    HBoxContainer= $UILayer/HUD/AbilityBar
@onready var _turn_indicator: Label        = $UILayer/TurnIndicator
@onready var _hero_hp_label:  Label        = $UILayer/HeroHPLabel

## ─── Ready ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# ── Atmosphere layer (behind hex tiles) ──
	_atmo_layer = Node2D.new()
	_atmo_layer.name = "AtmoLayer"
	add_child(_atmo_layer)
	move_child(_atmo_layer, 1)   # after Background, before HexLayer

	# ── Dynamic UI nodes ──
	_use_btn = Button.new()
	_use_btn.name = "UseButton"
	_use_btn.text = "USE"
	_use_btn.custom_minimum_size = Vector2(72.0, 52.0)
	_use_btn.add_theme_font_size_override("font_size", 13)
	_use_btn.visible = false
	_use_btn.pressed.connect(_on_use_btn_pressed)
	$UILayer/HUD/AbilityBar.add_child(_use_btn)

	_mode_label = Label.new()
	_mode_label.name = "ModeLabel"
	_mode_label.text = ""
	_mode_label.add_theme_font_size_override("font_size", 13)
	_mode_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.55))
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mode_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_mode_label.offset_left = -220.0
	_mode_label.offset_top  = 58.0
	_mode_label.offset_right = -8.0
	_mode_label.offset_bottom = 82.0
	$UILayer.add_child(_mode_label)

	# ── Build encounter ──
	SystemVoice.line_spoken.connect(_on_system_line)
	_floor_label.text = "Floor %d" % GameState.floor_num
	_build_encounter()
	_draw_cave_atmosphere()
	_draw_hex_grid()
	_draw_entities()
	_build_ability_bar()
	_setup_lava_animation()

	SystemVoice.speak("floor_enter", [GameState.floor_num])
	await get_tree().create_timer(0.4).timeout
	_next_turn()

## ─── Encounter Setup ──────────────────────────────────────────────────────────

func _build_encounter() -> void:
	_battle_rng = RandomNumberGenerator.new()
	_battle_rng.seed = GameState.run_seed + GameState.floor_num * 997

	_map = DungeonMap.new()
	_map.generate(GameState.floor_num, _battle_rng)

	# Hero
	_hero = Combatant.new(
		"hero", "Carl", Combatant.Faction.HERO,
		GameState.hero_hp,
		GameState.hero_base_stats.get("speed", 10)
	)
	_hero.armor        = GameState.hero_base_stats.get("defense", 0)
	_hero.attack_bonus = GameState.hero_base_stats.get("attack",  0)
	_hero.abilities    = GameState.hero_abilities.duplicate()
	_hero.position     = _map.hero_start

	# Enemies
	_enemies.clear()
	var pool: Array[Dictionary] = EnemyDefs.get_enemies_for_floor(GameState.floor_num)
	for i: int in range(_map.spawn_points.size()):
		var def: Dictionary = pool[_battle_rng.randi_range(0, pool.size() - 1)]
		var e: Combatant    = EnemyDefs.make_combatant(def, _map.spawn_points[i], _battle_rng)
		_enemies.append(e)

	_all_combatants.clear()
	_all_combatants.append(_hero)
	for e: Combatant in _enemies:
		_all_combatants.append(e)
	_engine = BattleEngine.new(_battle_rng)
	_engine.battle_ended.connect(_on_battle_ended)
	_engine.action_taken.connect(_on_action_taken)
	_engine.combatant_died.connect(_on_combatant_died)
	_engine.combatant_moved.connect(_on_combatant_moved)
	_engine.status_ticked.connect(_on_status_ticked)
	_engine.turn_skipped.connect(_on_turn_skipped)
	_engine.setup(_all_combatants)

## ─── Cave Atmosphere ──────────────────────────────────────────────────────────

func _draw_cave_atmosphere() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = GameState.run_seed ^ 0xCAFE1337

	var rock_color := Color(0.04, 0.025, 0.055)  # Near-black with faint purple

	# Bottom stalagmites (pointing upward)
	for i: int in range(14):
		var x: float  = 30.0 + i * 90.0 + rng.randf_range(-25.0, 25.0)
		var base_y: float = 720.0
		var w: float  = rng.randf_range(14.0, 38.0)
		var h: float  = rng.randf_range(35.0, 160.0)
		var poly      := Polygon2D.new()
		poly.polygon  = PackedVector2Array([
			Vector2(x - w * 0.5, base_y),
			Vector2(x + w * 0.5, base_y),
			Vector2(x,           base_y - h),
		])
		poly.color    = rock_color
		_atmo_layer.add_child(poly)
		# Second layer for depth variation
		if rng.randf() > 0.5:
			var poly2     := Polygon2D.new()
			var x2: float  = x + rng.randf_range(-20.0, 20.0)
			var w2: float  = w * rng.randf_range(0.4, 0.8)
			var h2: float  = h * rng.randf_range(0.5, 0.9)
			poly2.polygon = PackedVector2Array([
				Vector2(x2 - w2 * 0.5, base_y),
				Vector2(x2 + w2 * 0.5, base_y),
				Vector2(x2,            base_y - h2),
			])
			poly2.color = rock_color.lightened(0.04)
			_atmo_layer.add_child(poly2)

	# Top stalactites (pointing downward)
	for i: int in range(11):
		var x: float  = 50.0 + i * 112.0 + rng.randf_range(-30.0, 30.0)
		var w: float  = rng.randf_range(18.0, 42.0)
		var h: float  = rng.randf_range(25.0, 110.0)
		var poly      := Polygon2D.new()
		poly.polygon  = PackedVector2Array([
			Vector2(x - w * 0.5, 0.0),
			Vector2(x + w * 0.5, 0.0),
			Vector2(x,           h),
		])
		poly.color    = rock_color
		_atmo_layer.add_child(poly)

	# Left wall protrusions
	for i: int in range(5):
		var y: float = 90.0 + i * 115.0 + rng.randf_range(-20.0, 20.0)
		var w: float = rng.randf_range(28.0, 90.0)
		var h: float = rng.randf_range(16.0, 38.0)
		var poly     := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(0.0, y - h * 0.5),
			Vector2(0.0, y + h * 0.5),
			Vector2(w,   y),
		])
		poly.color   = rock_color
		_atmo_layer.add_child(poly)

	# Right wall protrusions
	for i: int in range(5):
		var y: float = 90.0 + i * 115.0 + rng.randf_range(-20.0, 20.0)
		var w: float = rng.randf_range(28.0, 90.0)
		var h: float = rng.randf_range(16.0, 38.0)
		var poly     := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(1280.0,     y - h * 0.5),
			Vector2(1280.0,     y + h * 0.5),
			Vector2(1280.0 - w, y),
		])
		poly.color   = rock_color
		_atmo_layer.add_child(poly)

## ─── Hex Grid Drawing ─────────────────────────────────────────────────────────

func _draw_hex_grid() -> void:
	for hex: Vector2i in _map.tile_types:
		var tile_type: String = _map.tile_types[hex]
		var world_pos: Vector2 = HexGrid.hex_to_pixel(hex, HEX_SIZE)

		var poly := Polygon2D.new()
		poly.polygon  = _make_hex_pts(HEX_SIZE - 2.0)
		poly.position = world_pos
		poly.color    = _base_tile_color(hex, tile_type)
		_hex_layer.add_child(poly)
		_hex_polys[hex] = poly

		# Border
		var border := Line2D.new()
		var pts: PackedVector2Array = _make_hex_pts(HEX_SIZE - 1.5)
		pts.append(pts[0])
		border.points        = pts
		border.width         = 1.2
		border.default_color = Color(0.28, 0.22, 0.32)
		poly.add_child(border)

		if tile_type == "lava":
			# Animated inner glow polygon
			var glow := Polygon2D.new()
			glow.polygon = _make_hex_pts(HEX_SIZE - 9.0)
			glow.color   = Color(1.0, 0.65, 0.1, 0.75)
			glow.name    = "LavaGlow"
			poly.add_child(glow)
			_lava_hexes.append(hex)

			# Ripple symbol
			var lbl := Label.new()
			lbl.text = "~"
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.1, 0.8))
			lbl.position = Vector2(-5.0, -8.0)
			poly.add_child(lbl)

		# Click detection
		var area := Area2D.new()
		area.position = world_pos
		var col := CollisionPolygon2D.new()
		col.polygon = _make_hex_pts(HEX_SIZE - 2.0)
		area.add_child(col)
		area.input_event.connect(_on_hex_input.bind(hex))
		_hex_layer.add_child(area)

func _base_tile_color(hex: Vector2i, tile_type: String = "") -> Color:
	if tile_type.is_empty():
		tile_type = _map.tile_types.get(hex, "floor")
	if tile_type == "lava":
		return LAVA_COLOR
	var shade: float = 0.0 if (hex.x + hex.y) % 2 == 0 else 0.03
	return FLOOR_COLOR + Color(shade, shade, shade)

## ─── Entity Drawing ───────────────────────────────────────────────────────────

func _draw_entities() -> void:
	for c: Combatant in _all_combatants:
		_spawn_entity_node(c)

func _spawn_entity_node(c: Combatant) -> void:
	var root := Node2D.new()
	root.position = HexGrid.hex_to_pixel(c.position, HEX_SIZE)

	var body := Polygon2D.new()
	body.polygon = _make_hex_pts(HEX_SIZE * 0.42)
	body.color   = HERO_COLOR if c.faction == Combatant.Faction.HERO else ENEMY_COLOR
	root.add_child(body)

	var lbl := Label.new()
	lbl.text                  = c.display_name.left(1).to_upper()
	lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.size     = Vector2(24.0, 24.0)
	lbl.position = Vector2(-12.0, -12.0)
	root.add_child(lbl)

	# HP bar background
	var hp_bg := ColorRect.new()
	hp_bg.size     = Vector2(38.0, 5.0)
	hp_bg.position = Vector2(-19.0, HEX_SIZE * 0.48)
	hp_bg.color    = Color(0.25, 0.0, 0.0)
	root.add_child(hp_bg)

	var hp_bar := ColorRect.new()
	hp_bar.name     = "HPBar"
	hp_bar.size     = Vector2(38.0, 5.0)
	hp_bar.position = Vector2(-19.0, HEX_SIZE * 0.48)
	hp_bar.color    = Color(0.2, 0.88, 0.2)
	root.add_child(hp_bar)

	_entity_layer.add_child(root)
	_entity_nodes[c.id] = root

## ─── Ability Bar ──────────────────────────────────────────────────────────────

func _build_ability_bar() -> void:
	# Clear existing ability buttons (keep the USE button which is last)
	var to_remove: Array[Node] = []
	for child: Node in _ability_bar.get_children():
		if child != _use_btn:
			to_remove.append(child)
	for n: Node in to_remove:
		n.queue_free()
	_ability_btns.clear()

	for ability_id: String in _hero.abilities:
		var abl: Dictionary = Abilities.get_ability(ability_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90.0, 52.0)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_ability_btn.bind(ability_id))
		_ability_bar.add_child(btn)
		_ability_btns[ability_id] = btn

	# Ensure USE button is at the end
	_ability_bar.move_child(_use_btn, _ability_bar.get_child_count() - 1)
	_refresh_ability_bar()

func _refresh_ability_bar() -> void:
	for ability_id: String in _ability_btns:
		var btn: Button = _ability_btns[ability_id]
		var abl: Dictionary = Abilities.get_ability(ability_id)
		var name_text: String = abl.get("display_name", ability_id)
		var cd: int = _ability_cooldowns.get(ability_id, 0)
		if cd > 0:
			btn.text    = "%s\n[CD:%d]" % [name_text, cd]
			btn.modulate = Color(0.5, 0.5, 0.5)
			btn.disabled = true
		else:
			btn.text     = name_text
			btn.disabled = false
			btn.modulate = SELECTED_COLOR if ability_id == _selected_ability else Color.WHITE

	# Show USE button only for instant/aoe/self abilities on player turn
	var abl: Dictionary  = Abilities.get_ability(_selected_ability)
	var target: String   = abl.get("target", "single_enemy")
	var is_instant: bool = (target == "self") or (target == "all_enemies")
	_use_btn.visible  = is_instant and _player_turn
	_use_btn.text     = "USE\n%s" % abl.get("display_name", _selected_ability).left(8)

func _tick_ability_cooldowns() -> void:
	for key: String in _ability_cooldowns.keys():
		if _ability_cooldowns[key] > 0:
			_ability_cooldowns[key] -= 1

func _use_ability_cooldown(ability_id: String) -> void:
	var abl: Dictionary = Abilities.get_ability(ability_id)
	var cd: int = abl.get("cooldown_turns", 0)
	if cd > 0:
		_ability_cooldowns[ability_id] = cd

func _check_ability_usable(ability_id: String) -> bool:
	return _ability_cooldowns.get(ability_id, 0) == 0

## ─── Lava Animation ───────────────────────────────────────────────────────────

func _setup_lava_animation() -> void:
	for hex: Vector2i in _lava_hexes:
		var poly: Polygon2D = _hex_polys.get(hex)
		if poly == null:
			continue
		var glow: Polygon2D = poly.get_node_or_null("LavaGlow")
		if glow == null:
			continue
		# Phase offset so tiles pulse asynchronously
		var phase: float = fmod(float(abs(hex.x * 7 + hex.y * 13)) * 0.23, 1.8)
		var tw: Tween = create_tween()
		tw.set_loops()
		tw.tween_interval(phase)
		tw.tween_property(glow, "color",
			Color(1.0, 0.78, 0.18, 0.92), 0.65).set_trans(Tween.TRANS_SINE)
		tw.tween_property(glow, "color",
			Color(0.82, 0.28, 0.0,  0.50), 1.1 ).set_trans(Tween.TRANS_SINE)

## ─── Hex Highlights ───────────────────────────────────────────────────────────

func _update_hex_highlights() -> void:
	# Reset all non-lava tiles to base color
	for hex: Vector2i in _hex_polys:
		if _map.tile_types.get(hex, "floor") != "lava":
			var poly: Polygon2D = _hex_polys[hex]
			poly.color = _base_tile_color(hex)

	if not _player_turn:
		return

	var abl: Dictionary  = Abilities.get_ability(_selected_ability)
	var rng_val: int     = abl.get("range", 1)
	var target: String   = abl.get("target", "single_enemy")

	# Blue: adjacent passable empty hexes — movement options
	for n: Vector2i in HexGrid.neighbors(_hero.position):
		if _map.tile_types.get(n, "wall") == "floor" and _find_combatant_at(n) == null:
			var poly: Polygon2D = _hex_polys.get(n)
			if poly != null:
				poly.color = MOVE_HL_COLOR

	# Green: hero's own hex when self-ability is selected
	if target == "self":
		var hp: Polygon2D = _hex_polys.get(_hero.position)
		if hp != null:
			hp.color = SELF_HL_COLOR

	# Red: reachable enemies when attack is selected
	if target in ["single_enemy", "all_enemies"]:
		for e: Combatant in _enemies:
			if e.is_alive() and HexGrid.hex_distance(_hero.position, e.position) <= rng_val:
				var poly: Polygon2D = _hex_polys.get(e.position)
				if poly != null:
					poly.color = ATK_HL_COLOR

## ─── Turn Logic ───────────────────────────────────────────────────────────────

func _next_turn() -> void:
	if _engine.battle_over:
		return
	var active: Combatant = _engine.begin_turn()
	if active == null:
		return

	if active.faction == Combatant.Faction.HERO:
		_tick_ability_cooldowns()
		_player_turn = true
		_turn_indicator.text = "YOUR TURN"
		_turn_indicator.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		_update_hero_hp_label()
		_update_hex_highlights()
		_refresh_ability_bar()
		_update_mode_label()
	else:
		_player_turn = false
		_use_btn.visible = false
		_turn_indicator.text = "%s's Turn" % active.display_name
		_turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		_update_hex_highlights()
		await get_tree().create_timer(0.55).timeout
		if not _engine.battle_over:
			_engine.enemy_ai_action(active)
			_update_all_hp_bars()
			_engine.end_turn()
			await get_tree().create_timer(0.25).timeout
			_next_turn()

func _update_hero_hp_label() -> void:
	_hero_hp_label.text = "HP: %d / %d" % [_hero.hp, _hero.max_hp]
	var ratio: float = float(_hero.hp) / float(max(1, _hero.max_hp))
	_hero_hp_label.add_theme_color_override("font_color",
		Color(1.0, ratio * 0.85 + 0.15, ratio * 0.85 + 0.15))

func _update_mode_label() -> void:
	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	var target: String  = abl.get("target", "single_enemy")
	match target:
		"single_enemy":
			_mode_label.text = "▶ Click enemy to attack"
		"all_enemies":
			_mode_label.text = "▶ Press USE for AOE"
		"self":
			_mode_label.text = "▶ Press USE to activate"
		_:
			_mode_label.text = ""

## ─── Input ────────────────────────────────────────────────────────────────────

func _on_hex_input(_viewport: Viewport, event: InputEvent, _shape_idx: int, hex: Vector2i) -> void:
	if not _player_turn or _engine.battle_over:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return

	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	var target_type: String = abl.get("target", "single_enemy")

	# Self/AOE abilities — redirect to USE button logic
	if target_type != "single_enemy":
		_trigger_instant_ability()
		return

	# Single-enemy attack
	var target_c: Combatant = _find_enemy_at(hex)
	if target_c != null:
		var rng_val: int = abl.get("range", 1)
		if HexGrid.hex_distance(_hero.position, target_c.position) > rng_val:
			_flash_banner("Out of range.")
			return
		if not _check_ability_usable(_selected_ability):
			_flash_banner("Ability on cooldown.")
			return
		_do_hero_attack(target_c, _selected_ability)
		return

	# Empty adjacent hex — move
	if HexGrid.hex_distance(_hero.position, hex) == 1:
		if _engine.can_move_to(_hero, hex):
			_do_hero_move(hex)
		elif _map.tile_types.get(hex, "wall") == "lava":
			_flash_banner("That's lava. (Click it again to confirm.)")
		else:
			_flash_banner("Blocked.")

func _on_ability_btn(ability_id: String) -> void:
	_selected_ability = ability_id
	_refresh_ability_bar()
	_update_hex_highlights()
	_update_mode_label()

func _on_use_btn_pressed() -> void:
	_trigger_instant_ability()

func _trigger_instant_ability() -> void:
	if not _player_turn or _engine.battle_over:
		return
	if not _check_ability_usable(_selected_ability):
		_flash_banner("Ability on cooldown.")
		return
	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	var target_type: String = abl.get("target", "single_enemy")
	if target_type == "all_enemies":
		_do_hero_aoe(_selected_ability)
	elif target_type == "self":
		_do_hero_self_ability(_selected_ability)

## ─── Hero Actions ─────────────────────────────────────────────────────────────

func _do_hero_attack(target: Combatant, ability_id: String) -> void:
	_player_turn = false
	_use_btn.visible = false
	_use_ability_cooldown(ability_id)
	_engine.perform_attack(_hero, target, ability_id)
	SystemVoice.speak("hit")
	_update_all_hp_bars()
	_update_hero_hp_label()
	_engine.end_turn()
	await get_tree().create_timer(0.2).timeout
	_next_turn()

func _do_hero_aoe(ability_id: String) -> void:
	## Fireball / Frost Nova: hit all enemies within range of hero.
	_player_turn = false
	_use_btn.visible = false
	_use_ability_cooldown(ability_id)

	var abl: Dictionary = Abilities.get_ability(ability_id)
	var rng_val: int    = abl.get("range", 1)
	var hits: int       = 0

	for enemy: Combatant in _enemies:
		if enemy.is_alive() and HexGrid.hex_distance(_hero.position, enemy.position) <= rng_val:
			if ability_id == "frost_nova":
				enemy.apply_status(StatusEffect.frozen())
				_show_floating_text(enemy, "FROZEN", Color(0.5, 0.9, 1.0))
			else:
				_engine.perform_attack(_hero, enemy, ability_id)
			hits += 1

	if ability_id == "fireball":
		SystemVoice.speak("fireball")
	elif ability_id == "frost_nova":
		SystemVoice.speak("frost_nova")

	_update_all_hp_bars()
	_engine.end_turn()
	await get_tree().create_timer(0.35).timeout
	_next_turn()

func _do_hero_self_ability(ability_id: String) -> void:
	_player_turn = false
	_use_btn.visible = false
	_use_ability_cooldown(ability_id)

	match ability_id:
		"taunt":
			_hero.apply_status(StatusEffect.fortified(3, 5))
			SystemVoice.speak("taunt")
			_show_floating_text(_hero, "FORTIFIED +5", Color(0.9, 0.85, 0.2))
		"vanish":
			_hero.apply_status(StatusEffect.vanish())
			SystemVoice.speak("vanish")
			_show_floating_text(_hero, "VANISHED 3×", Color(0.6, 0.25, 0.9))
		_:
			pass

	_engine.end_turn()
	await get_tree().create_timer(0.3).timeout
	_next_turn()

func _do_hero_move(target_hex: Vector2i) -> void:
	_player_turn = false
	_use_btn.visible = false
	_engine.perform_move(_hero, target_hex)
	# Visual handled by _on_combatant_moved signal

	# Lava damage on entry
	if _map.tile_types.get(target_hex, "floor") == "lava":
		var lava_dmg: int = 5
		_hero.take_damage(lava_dmg)
		GameState.hero_hp = _hero.hp
		_show_floating_text(_hero, "-%d LAVA" % lava_dmg, LAVA_COLOR)
		_update_hp_bar(_hero)
		SystemVoice.speak("lava_step")
		if not _hero.is_alive():
			_engine.end_turn()
			return

	SystemVoice.speak("hero_move")
	_update_hero_hp_label()
	_engine.end_turn()
	await get_tree().create_timer(0.2).timeout
	_next_turn()

## ─── Engine Signal Handlers ───────────────────────────────────────────────────

func _on_action_taken(_attacker: Combatant, target: Combatant, damage: int, _ability_id: String) -> void:
	_show_floating_text(target, "-%d" % damage, Color(1.0, 0.25, 0.1))
	_update_hp_bar(target)
	if target.faction == Combatant.Faction.HERO:
		_update_hero_hp_label()
		SystemVoice.speak("player_hit")

func _on_combatant_died(c: Combatant) -> void:
	if c.faction == Combatant.Faction.ENEMY:
		SystemVoice.speak("kill")
		GameState.enemies_killed += 1
	var node: Node2D = _entity_nodes.get(c.id)
	if node != null:
		node.modulate = DEAD_MODULATE

func _on_combatant_moved(c: Combatant, _from_hex: Vector2i, to_hex: Vector2i) -> void:
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var new_pos: Vector2 = HexGrid.hex_to_pixel(to_hex, HEX_SIZE)
	var tw: Tween = create_tween()
	tw.tween_property(node, "position", new_pos, 0.22).set_trans(Tween.TRANS_CUBIC)

func _on_status_ticked(c: Combatant, damage: int) -> void:
	if damage > 0:
		_show_floating_text(c, "-%d" % damage, Color(1.0, 0.5, 0.0))
		_update_hp_bar(c)
		if c.faction == Combatant.Faction.HERO:
			_update_hero_hp_label()

func _on_turn_skipped(c: Combatant) -> void:
	_show_floating_text(c, "FROZEN", Color(0.5, 0.9, 1.0))

func _on_battle_ended(hero_won: bool, xp_earned: int) -> void:
	_player_turn = false
	_use_btn.visible = false
	# Sync HP back to GameState
	GameState.hero_hp = _hero.hp
	if hero_won:
		_turn_indicator.text = "VICTORY!"
		_turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		SystemVoice.speak_direct(
			"Enemies cleared. XP gained: %d. The System is mildly impressed." % xp_earned)
	else:
		_turn_indicator.text = "DEFEATED"
		_turn_indicator.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
		SystemVoice.speak("death")
	_update_hex_highlights()
	await get_tree().create_timer(1.8).timeout
	battle_complete.emit(hero_won, xp_earned)

func _on_system_line(text: String, _dur: float) -> void:
	_show_system_banner(text, 2.8)

## ─── Utility ──────────────────────────────────────────────────────────────────

func _update_all_hp_bars() -> void:
	for c: Combatant in _all_combatants:
		_update_hp_bar(c)

func _update_hp_bar(c: Combatant) -> void:
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var hp_bar: ColorRect = node.get_node_or_null("HPBar")
	if hp_bar == null:
		return
	var ratio: float   = float(c.hp) / float(max(1, c.max_hp))
	hp_bar.size.x      = 38.0 * clampf(ratio, 0.0, 1.0)
	hp_bar.color       = Color(1.0 - ratio * 0.8, 0.2 + ratio * 0.68, 0.1)

func _show_floating_text(c: Combatant, text: String, color: Color) -> void:
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = node.position + Vector2(-22.0, -30.0)
	_entity_layer.add_child(lbl)
	var tw: Tween = create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -52.0), 0.90)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.90)
	tw.tween_callback(lbl.queue_free)

func _show_system_banner(text: String, duration: float) -> void:
	_system_banner.visible = true
	_system_text.text      = text
	var tw: Tween = create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func() -> void: _system_banner.visible = false)

func _flash_banner(text: String) -> void:
	_show_system_banner(text, 1.4)

func _find_enemy_at(hex: Vector2i) -> Combatant:
	for e: Combatant in _enemies:
		if e.is_alive() and e.position == hex:
			return e
	return null

func _find_combatant_at(hex: Vector2i) -> Combatant:
	for c: Combatant in _all_combatants:
		if c.is_alive() and c.position == hex:
			return c
	return null

func _make_hex_pts(size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(6):
		var angle: float = deg_to_rad(60.0 * float(i) - 30.0)
		pts.append(Vector2(cos(angle) * size, sin(angle) * size))
	return pts
