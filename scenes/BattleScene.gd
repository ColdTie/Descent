extends Node2D
## Visual driver for one battle encounter on the hex grid.

signal battle_complete(hero_won: bool, xp_earned: int)

const HEX_SIZE: float = 38.0
const HERO_COLOR := Color(0.25, 0.55, 1.0)
const ENEMY_COLOR := Color(0.9, 0.2, 0.15)
const LAVA_COLOR := Color(0.92, 0.38, 0.04)
const FLOOR_COLOR := Color(0.16, 0.13, 0.19)
const FLOOR_DARK := Color(0.10, 0.08, 0.13)
const SELECTED_ABILITY_COLOR := Color(1.0, 0.9, 0.2)
const DEAD_MODULATE := Color(0.35, 0.35, 0.35, 0.4)

var _engine: BattleEngine
var _map: DungeonMap
var _hero: Combatant
var _enemies: Array[Combatant] = []
var _all_combatants: Array[Combatant] = []

# Visual nodes
var _hex_polys: Dictionary = {}    # Vector2i -> Polygon2D
var _entity_nodes: Dictionary = {} # combatant.id -> Node2D
var _ability_btns: Dictionary = {} # ability_id -> Button

var _selected_ability: String = "basic_attack"
var _player_turn: bool = false
var _battle_rng: RandomNumberGenerator

@onready var _hex_layer: Node2D = $HexLayer
@onready var _entity_layer: Node2D = $EntityLayer
@onready var _floor_label: Label = $UILayer/FloorLabel
@onready var _system_banner: Panel = $UILayer/SystemBanner
@onready var _system_text: Label = $UILayer/SystemBanner/SystemText
@onready var _ability_bar: HBoxContainer = $UILayer/HUD/AbilityBar
@onready var _turn_indicator: Label = $UILayer/TurnIndicator

func _ready() -> void:
	_floor_label.text = "Floor %d" % GameState.floor_num
	SystemVoice.line_spoken.connect(_on_system_line)
	_build_encounter()
	_draw_hex_grid()
	_draw_entities()
	_build_ability_bar()
	SystemVoice.speak("floor_enter", [GameState.floor_num])
	# Begin battle after a beat
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
	_hero.armor = GameState.hero_base_stats.get("defense", 0)
	_hero.abilities = GameState.hero_abilities.duplicate()
	_hero.position = _map.hero_start

	# Enemies
	_enemies.clear()
	var pool: Array[Dictionary] = EnemyDefs.get_enemies_for_floor(GameState.floor_num)
	for i: int in range(_map.spawn_points.size()):
		var def: Dictionary = pool[_battle_rng.randi_range(0, pool.size() - 1)]
		var e: Combatant = EnemyDefs.make_combatant(def, _map.spawn_points[i], _battle_rng)
		_enemies.append(e)

	_all_combatants = [_hero] + _enemies
	_engine = BattleEngine.new(_battle_rng)
	_engine.battle_ended.connect(_on_battle_ended)
	_engine.action_taken.connect(_on_action_taken)
	_engine.combatant_died.connect(_on_combatant_died)
	_engine.status_ticked.connect(_on_status_ticked)
	_engine.setup(_all_combatants)

## ─── Drawing ──────────────────────────────────────────────────────────────────

func _draw_hex_grid() -> void:
	for hex: Vector2i in _map.tile_types:
		var tile_type: String = _map.tile_types[hex]
		var world_pos: Vector2 = HexGrid.hex_to_pixel(hex, HEX_SIZE)

		# Tile polygon
		var poly := Polygon2D.new()
		poly.polygon = _make_hex_pts(HEX_SIZE - 2.0)
		poly.position = world_pos
		match tile_type:
			"lava":
				poly.color = LAVA_COLOR
			_:
				# Alternate shade for checkerboard feel
				var shade: float = 0.0 if (hex.x + hex.y) % 2 == 0 else 0.03
				poly.color = FLOOR_COLOR + Color(shade, shade, shade)
		_hex_layer.add_child(poly)
		_hex_polys[hex] = poly

		# Border line
		var border := Line2D.new()
		var pts: PackedVector2Array = _make_hex_pts(HEX_SIZE - 1.5)
		pts.append(pts[0])
		border.points = pts
		border.width = 1.2
		border.default_color = Color(0.28, 0.22, 0.32)
		poly.add_child(border)

		# Lava shimmer label
		if tile_type == "lava":
			var lava_lbl := Label.new()
			lava_lbl.text = "~"
			lava_lbl.add_theme_font_size_override("font_size", 14)
			lava_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.1, 0.8))
			lava_lbl.position = Vector2(-5.0, -8.0)
			poly.add_child(lava_lbl)

		# Click input via Area2D
		var area := Area2D.new()
		area.position = world_pos
		var col := CollisionPolygon2D.new()
		col.polygon = _make_hex_pts(HEX_SIZE - 2.0)
		area.add_child(col)
		area.input_event.connect(_on_hex_input.bind(hex))
		_hex_layer.add_child(area)

func _draw_entities() -> void:
	for c: Combatant in _all_combatants:
		_spawn_entity_node(c)

func _spawn_entity_node(c: Combatant) -> void:
	var root := Node2D.new()
	root.position = HexGrid.hex_to_pixel(c.position, HEX_SIZE)

	# Body hex
	var body := Polygon2D.new()
	body.polygon = _make_hex_pts(HEX_SIZE * 0.42)
	body.color = HERO_COLOR if c.faction == Combatant.Faction.HERO else ENEMY_COLOR
	root.add_child(body)

	# Letter initial
	var lbl := Label.new()
	lbl.text = c.display_name.left(1).to_upper()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.size = Vector2(24.0, 24.0)
	lbl.position = Vector2(-12.0, -12.0)
	root.add_child(lbl)

	# HP bar background
	var hp_bg := ColorRect.new()
	hp_bg.size = Vector2(38.0, 5.0)
	hp_bg.position = Vector2(-19.0, HEX_SIZE * 0.48)
	hp_bg.color = Color(0.25, 0.0, 0.0)
	root.add_child(hp_bg)

	# HP bar fill
	var hp_bar := ColorRect.new()
	hp_bar.name = "HPBar"
	hp_bar.size = Vector2(38.0, 5.0)
	hp_bar.position = Vector2(-19.0, HEX_SIZE * 0.48)
	hp_bar.color = Color(0.2, 0.88, 0.2)
	root.add_child(hp_bar)

	_entity_layer.add_child(root)
	_entity_nodes[c.id] = root

## ─── Ability Bar ──────────────────────────────────────────────────────────────

func _build_ability_bar() -> void:
	for child: Node in _ability_bar.get_children():
		child.queue_free()
	_ability_btns.clear()

	for ability_id: String in _hero.abilities:
		var abl: Dictionary = Abilities.get_ability(ability_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90.0, 52.0)
		btn.text = abl.get("display_name", ability_id)
		btn.add_theme_font_size_override("font_size", 11)
		if ability_id == _selected_ability:
			btn.modulate = SELECTED_ABILITY_COLOR
		btn.pressed.connect(_on_ability_btn.bind(ability_id))
		_ability_bar.add_child(btn)
		_ability_btns[ability_id] = btn

## ─── Turn Logic ───────────────────────────────────────────────────────────────

func _next_turn() -> void:
	if _engine.battle_over:
		return
	var active: Combatant = _engine.begin_turn()
	if active == null:
		return

	if active.faction == Combatant.Faction.HERO:
		_player_turn = true
		_turn_indicator.text = "YOUR TURN"
		_turn_indicator.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
	else:
		_player_turn = false
		_turn_indicator.text = "%s's Turn" % active.display_name
		_turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		# Enemy acts after brief delay
		await get_tree().create_timer(0.55).timeout
		if not _engine.battle_over:
			_engine.enemy_ai_action(active)
			_update_all_hp_bars()
			_engine.end_turn()
			await get_tree().create_timer(0.25).timeout
			_next_turn()

## ─── Input ────────────────────────────────────────────────────────────────────

func _on_hex_input(_viewport: Viewport, event: InputEvent, _shape_idx: int, hex: Vector2i) -> void:
	if not _player_turn or _engine.battle_over:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return

	# Find enemy on clicked hex
	var target: Combatant = _find_enemy_at(hex)
	if target == null:
		return

	# Range check
	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	var rng: int = abl.get("range", 1)
	if not HexGrid.is_in_range(_hero.position, target.position, rng):
		_show_system_banner("Out of range!", 1.2)
		return

	_do_hero_attack(target)

func _do_hero_attack(target: Combatant) -> void:
	_player_turn = false
	_engine.perform_attack(_hero, target, _selected_ability)
	SystemVoice.speak("hit")
	_update_all_hp_bars()
	_engine.end_turn()
	await get_tree().create_timer(0.2).timeout
	_next_turn()

func _find_enemy_at(hex: Vector2i) -> Combatant:
	for e: Combatant in _enemies:
		if e.is_alive() and e.position == hex:
			return e
	return null

func _on_ability_btn(ability_id: String) -> void:
	_selected_ability = ability_id
	for id: String in _ability_btns:
		_ability_btns[id].modulate = Color.WHITE
	if _ability_btns.has(ability_id):
		_ability_btns[ability_id].modulate = SELECTED_ABILITY_COLOR

## ─── Engine Signal Handlers ───────────────────────────────────────────────────

func _on_action_taken(_attacker: Combatant, target: Combatant, damage: int, _ability_id: String) -> void:
	_show_damage_number(target, damage)
	_update_hp_bar(target)

func _on_combatant_died(c: Combatant) -> void:
	if c.faction == Combatant.Faction.ENEMY:
		SystemVoice.speak("kill")
	var node: Node2D = _entity_nodes.get(c.id)
	if node != null:
		node.modulate = DEAD_MODULATE

func _on_status_ticked(c: Combatant, damage: int) -> void:
	if damage > 0:
		_show_damage_number(c, damage, Color(1.0, 0.5, 0.0))

func _on_battle_ended(hero_won: bool, xp_earned: int) -> void:
	_player_turn = false
	if hero_won:
		_turn_indicator.text = "VICTORY!"
		_turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		SystemVoice.speak_direct("Enemies cleared. XP gained: %d. The System is mildly impressed." % xp_earned)
	else:
		_turn_indicator.text = "DEFEATED"
		_turn_indicator.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
		SystemVoice.speak("death")
	await get_tree().create_timer(1.8).timeout
	battle_complete.emit(hero_won, xp_earned)

func _on_system_line(text: String, _dur: float) -> void:
	_show_system_banner(text, 2.8)

## ─── Visual Helpers ───────────────────────────────────────────────────────────

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
	var ratio: float = float(c.hp) / float(max(1, c.max_hp))
	hp_bar.size.x = 38.0 * clampf(ratio, 0.0, 1.0)
	# Color shifts red as HP drops
	hp_bar.color = Color(1.0 - ratio * 0.8, 0.2 + ratio * 0.68, 0.1)

func _show_damage_number(c: Combatant, damage: int, color: Color = Color(1.0, 0.25, 0.1)) -> void:
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var lbl := Label.new()
	lbl.text = "-%d" % damage
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = node.position + Vector2(-14.0, -22.0)
	_entity_layer.add_child(lbl)
	var tw: Tween = create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -48.0), 0.85)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.85)
	tw.tween_callback(lbl.queue_free)

func _show_system_banner(text: String, duration: float) -> void:
	_system_banner.visible = true
	_system_text.text = text
	var tw: Tween = create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func() -> void: _system_banner.visible = false)

func _make_hex_pts(size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(6):
		var angle: float = deg_to_rad(60.0 * float(i) - 30.0)
		pts.append(Vector2(cos(angle) * size, sin(angle) * size))
	return pts
