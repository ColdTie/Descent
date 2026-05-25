extends Node2D
## Visual driver for one battle encounter on the hex grid.
## Run 2: hero movement, ability effects, cave atmosphere, frozen/vanish/AOE.

signal battle_complete(hero_won: bool, xp_earned: int)

const HEX_SIZE: float = 38.0
const HERO_COLOR       := Color(0.25, 0.55, 1.0)
const ENEMY_COLOR      := Color(0.9, 0.2, 0.15)
const LAVA_COLOR       := Color(0.92, 0.38, 0.04)
const FLOOR_COLOR      := Color(0.16, 0.13, 0.19)
const FLOOR_DARK       := Color(0.10, 0.08, 0.13)
const SELECTED_ABILITY := Color(1.0, 0.9, 0.2)
const DEAD_MODULATE    := Color(0.35, 0.35, 0.35, 0.4)
const MOVE_HIGHLIGHT   := Color(0.2, 0.95, 0.3, 0.48)
const ATTACK_HIGHLIGHT := Color(0.95, 0.25, 0.1, 0.38)
const AOE_HIGHLIGHT    := Color(1.0, 0.55, 0.0, 0.40)
const FROZEN_COLOR     := Color(0.4, 0.7, 1.0)

# ─── State ────────────────────────────────────────────────────────────────────

var _engine: BattleEngine
var _map: DungeonMap
var _hero: Combatant
var _enemies: Array[Combatant] = []
var _all_combatants: Array[Combatant] = []

var _hex_polys: Dictionary = {}    # Vector2i -> Polygon2D
var _entity_nodes: Dictionary = {} # combatant.id -> Node2D
var _ability_btns: Dictionary = {} # ability_id -> Button
var _highlight_nodes: Array[Node2D] = []
var _lava_polys: Array[Polygon2D] = []  # for pulse animation

var _selected_ability: String = "basic_attack"
var _player_turn: bool = false
var _player_moved: bool = false   # hero already moved this turn
var _battle_rng: RandomNumberGenerator

# ─── Scene Nodes ─────────────────────────────────────────────────────────────

@onready var _hex_layer: Node2D = $HexLayer
@onready var _entity_layer: Node2D = $EntityLayer
@onready var _floor_label: Label = $UILayer/FloorLabel
@onready var _system_banner: Panel = $UILayer/SystemBanner
@onready var _system_text: Label = $UILayer/SystemBanner/SystemText
@onready var _ability_bar: HBoxContainer = $UILayer/HUD/AbilityBar
@onready var _turn_indicator: Label = $UILayer/TurnIndicator
@onready var _hero_hp_label: Label = $UILayer/HeroHPLabel
@onready var _highlight_layer: Node2D = $HighlightLayer
@onready var _end_turn_btn: Button = $UILayer/EndTurnButton

# ─── Ready ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_floor_label.text = "Floor %d" % GameState.floor_num
	SystemVoice.line_spoken.connect(_on_system_line)
	_build_encounter()
	_draw_cave_background()
	_draw_hex_grid()
	_draw_stalagmites()
	_draw_entities()
	_build_ability_bar()
	_update_hero_hp_label()
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_start_lava_pulse()
	SystemVoice.speak("floor_enter", [GameState.floor_num])
	await get_tree().create_timer(0.4).timeout
	_next_turn()

# ─── Encounter Setup ──────────────────────────────────────────────────────────

func _build_encounter() -> void:
	_battle_rng = RandomNumberGenerator.new()
	_battle_rng.seed = GameState.run_seed + GameState.floor_num * 997

	_map = DungeonMap.new()
	_map.generate(GameState.floor_num, _battle_rng)

	# Hero
	var cls_data: Dictionary = Classes.get_class_data(GameState.hero_class)
	_hero = Combatant.new(
		"hero", cls_data.get("display_name", "Carl"), Combatant.Faction.HERO,
		GameState.hero_hp,
		GameState.hero_base_stats.get("speed", 10)
	)
	_hero.armor = GameState.hero_base_stats.get("defense", 0)
	_hero.stats = GameState.hero_base_stats.duplicate()
	_hero.abilities = GameState.hero_abilities.duplicate()
	_hero.position = _map.hero_start

	# Enemies
	_enemies.clear()
	var pool: Array[Dictionary] = EnemyDefs.get_enemies_for_floor(GameState.floor_num)
	for i: int in range(_map.spawn_points.size()):
		var def: Dictionary = pool[_battle_rng.randi_range(0, pool.size() - 1)]
		var e: Combatant = EnemyDefs.make_combatant(def, _map.spawn_points[i], _battle_rng)
		_enemies.append(e)

	# Build typed array manually (GDScript 4: can't assign Array to Array[T])
	_all_combatants.clear()
	_all_combatants.append(_hero)
	for e: Combatant in _enemies:
		_all_combatants.append(e)
	_engine = BattleEngine.new(_battle_rng)
	_engine.setup_map(_map)
	_engine.battle_ended.connect(_on_battle_ended)
	_engine.action_taken.connect(_on_action_taken)
	_engine.combatant_died.connect(_on_combatant_died)
	_engine.status_ticked.connect(_on_status_ticked)
	_engine.entity_moved.connect(_on_entity_moved)
	_engine.setup(_all_combatants)

# ─── Cave Background & Atmosphere ─────────────────────────────────────────────

func _draw_cave_background() -> void:
	## Dark gradient background with canvas modulate for dungeon feel.
	var bg := ColorRect.new()
	bg.position = Vector2(-640, -380)
	bg.size = Vector2(1280, 760)
	bg.color = Color(0.04, 0.03, 0.07)
	_hex_layer.add_child(bg)

func _draw_stalagmites() -> void:
	## Draw rock spire silhouettes at the dungeon edges for atmosphere.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _battle_rng.seed + 7777

	var edge_positions: Array[Vector2] = []
	# Generate stalagmite bases along the outer map edge
	for angle_deg: float in [0.0, 30.0, 60.0, 90.0, 120.0, 150.0, 180.0, 210.0, 240.0, 270.0, 300.0, 330.0]:
		var angle: float = deg_to_rad(angle_deg + rng.randf_range(-15.0, 15.0))
		var radius: float = HEX_SIZE * 5.2 + rng.randf_range(0.0, HEX_SIZE * 0.8)
		edge_positions.append(Vector2(cos(angle) * radius, sin(angle) * radius))

	for base: Vector2 in edge_positions:
		var count: int = rng.randi_range(1, 3)
		for i: int in range(count):
			var offset: float = rng.randf_range(-22.0, 22.0)
			var h: float = rng.randf_range(30.0, 85.0)
			var w: float = rng.randf_range(8.0, 20.0)
			var root_pos: Vector2 = base + Vector2(offset, rng.randf_range(-8.0, 8.0))
			_draw_spire(_hex_layer, root_pos, h, w)

func _draw_spire(parent: Node2D, base: Vector2, height: float, width: float) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-width * 0.5, 0.0),
		Vector2(width * 0.5, 0.0),
		Vector2(width * 0.15, -height * 0.55),
		Vector2(0.0, -height),
		Vector2(-width * 0.15, -height * 0.55),
	])
	poly.position = base
	poly.color = Color(0.06, 0.05, 0.08)
	parent.add_child(poly)

# ─── Hex Grid Drawing ─────────────────────────────────────────────────────────

func _draw_hex_grid() -> void:
	for hex: Vector2i in _map.tile_types:
		var tile_type: String = _map.tile_types[hex]
		var world_pos: Vector2 = HexGrid.hex_to_pixel(hex, HEX_SIZE)

		var poly := Polygon2D.new()
		poly.polygon = _make_hex_pts(HEX_SIZE - 2.0)
		poly.position = world_pos
		match tile_type:
			"lava":
				poly.color = LAVA_COLOR
				_lava_polys.append(poly)
			_:
				var shade: float = 0.0 if (hex.x + hex.y) % 2 == 0 else 0.03
				poly.color = FLOOR_COLOR + Color(shade, shade, shade)
		_hex_layer.add_child(poly)
		_hex_polys[hex] = poly

		var border := Line2D.new()
		var pts: PackedVector2Array = _make_hex_pts(HEX_SIZE - 1.5)
		pts.append(pts[0])
		border.points = pts
		border.width = 1.2
		border.default_color = Color(0.28, 0.22, 0.32)
		poly.add_child(border)

		if tile_type == "lava":
			var lava_lbl := Label.new()
			lava_lbl.text = "~"
			lava_lbl.add_theme_font_size_override("font_size", 14)
			lava_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.1, 0.8))
			lava_lbl.position = Vector2(-5.0, -8.0)
			poly.add_child(lava_lbl)

		var area := Area2D.new()
		area.position = world_pos
		var col := CollisionPolygon2D.new()
		col.polygon = _make_hex_pts(HEX_SIZE - 2.0)
		area.add_child(col)
		area.input_event.connect(_on_hex_input.bind(hex))
		_hex_layer.add_child(area)

func _start_lava_pulse() -> void:
	## Pulse lava tiles between bright and slightly dimmer orange.
	if _lava_polys.is_empty():
		return
	var tw: Tween = create_tween().set_loops()
	for lp: Polygon2D in _lava_polys:
		var pulse_color: Color = LAVA_COLOR * 0.70
		tw.tween_property(lp, "color", pulse_color, 0.9)
		tw.tween_property(lp, "color", LAVA_COLOR, 0.9)

# ─── Entity Drawing ───────────────────────────────────────────────────────────

func _draw_entities() -> void:
	for c: Combatant in _all_combatants:
		_spawn_entity_node(c)

func _spawn_entity_node(c: Combatant) -> void:
	var root := Node2D.new()
	root.position = HexGrid.hex_to_pixel(c.position, HEX_SIZE)

	var body := Polygon2D.new()
	body.polygon = _make_hex_pts(HEX_SIZE * 0.42)
	body.color = HERO_COLOR if c.faction == Combatant.Faction.HERO else ENEMY_COLOR
	body.name = "Body"
	root.add_child(body)

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

# ─── Ability Bar ──────────────────────────────────────────────────────────────

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
			btn.modulate = SELECTED_ABILITY
		btn.pressed.connect(_on_ability_btn.bind(ability_id))
		_ability_bar.add_child(btn)
		_ability_btns[ability_id] = btn

# ─── Turn Logic ───────────────────────────────────────────────────────────────

func _next_turn() -> void:
	if _engine.battle_over:
		return
	var active: Combatant = _engine.begin_turn()
	if active == null:
		return

	if active.faction == Combatant.Faction.HERO:
		# Check if hero is frozen
		if _engine.active_turn_skipped:
			_player_turn = false
			_turn_indicator.text = "FROZEN"
			_turn_indicator.add_theme_color_override("font_color", FROZEN_COLOR)
			_show_system_banner("%s is frozen solid!" % active.display_name, 1.2)
			await get_tree().create_timer(0.9).timeout
			if not _engine.battle_over:
				_engine.end_turn()
				_next_turn()
			return
		_player_turn = true
		_player_moved = false
		_turn_indicator.text = "YOUR TURN"
		_turn_indicator.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		_end_turn_btn.visible = true
		_refresh_highlights()
	else:
		_player_turn = false
		_clear_highlights()
		_end_turn_btn.visible = false

		if _engine.active_turn_skipped:
			_turn_indicator.text = "%s: FROZEN" % active.display_name
			_turn_indicator.add_theme_color_override("font_color", FROZEN_COLOR)
			await get_tree().create_timer(0.55).timeout
			if not _engine.battle_over:
				_engine.end_turn()
				await get_tree().create_timer(0.2).timeout
				_next_turn()
			return

		_turn_indicator.text = "%s's Turn" % active.display_name
		_turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		await get_tree().create_timer(0.55).timeout
		if not _engine.battle_over:
			_engine.enemy_ai_action(active)
			_update_all_hp_bars()
			_engine.end_turn()
			await get_tree().create_timer(0.25).timeout
			_next_turn()

# ─── Input: Hex Click ────────────────────────────────────────────────────────

func _on_hex_input(_viewport: Viewport, event: InputEvent, _shape_idx: int, hex: Vector2i) -> void:
	if not _player_turn or _engine.battle_over:
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return

	var target: Combatant = _find_enemy_at(hex)
	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	var target_type: String = abl.get("target", "single_enemy")
	var range_val: int = abl.get("range", 1)

	if target_type == "self":
		# Self-cast handled by button; clicking hex does nothing
		return

	if target != null:
		# Clicked on an enemy
		if not HexGrid.is_in_range(_hero.position, target.position, range_val):
			_show_system_banner("Out of range. Maybe move first?", 1.4)
			return
		_do_hero_ability(target, hex)
	elif target_type == "all_enemies" and _selected_ability == "fireball":
		# Fireball: click any hex as center point
		if HexGrid.is_in_range(_hero.position, hex, range_val):
			# Create a dummy center combatant at that hex
			var dummy := Combatant.new("_center", "", Combatant.Faction.ENEMY, 1, 1)
			dummy.position = hex
			_do_hero_ability(dummy, hex)
	elif not _player_moved and _map.is_passable(hex) and _find_combatant_at(hex) == null:
		# Empty passable hex: move there (if adjacent and not yet moved)
		if HexGrid.hex_distance(_hero.position, hex) == 1:
			_move_hero_to(hex)

func _do_hero_ability(target: Combatant, target_hex: Vector2i) -> void:
	_player_turn = false
	_clear_highlights()
	_end_turn_btn.visible = false
	_engine.perform_ability(_hero, _selected_ability, target)
	_show_ability_vfx(_selected_ability, target_hex)
	_update_all_hp_bars()
	_engine.end_turn()
	await get_tree().create_timer(0.25).timeout
	_next_turn()

func _move_hero_to(hex: Vector2i) -> void:
	_hero.position = hex
	_player_moved = true
	# Animate node to new position
	var node: Node2D = _entity_nodes.get(_hero.id)
	if node != null:
		var target_world: Vector2 = HexGrid.hex_to_pixel(hex, HEX_SIZE)
		var tw: Tween = create_tween()
		tw.tween_property(node, "position", target_world, 0.18)
	SystemVoice.speak_direct("Repositioned. Marginally.")
	# Refresh highlights: now show attack options from new position
	_refresh_highlights()

func _on_end_turn_pressed() -> void:
	if not _player_turn or _engine.battle_over:
		return
	_player_turn = false
	_clear_highlights()
	_end_turn_btn.visible = false
	_engine.end_turn()
	_next_turn()

# ─── Input: Ability Buttons ──────────────────────────────────────────────────

func _on_ability_btn(ability_id: String) -> void:
	if not _player_turn or _engine.battle_over:
		return
	var abl: Dictionary = Abilities.get_ability(ability_id)
	var target_type: String = abl.get("target", "single_enemy")
	# Self-targeting and from-self AOE abilities fire immediately
	if target_type == "self" or (target_type == "all_enemies" and ability_id == "frost_nova"):
		# Also require player turn
		_do_hero_self_ability(ability_id)
		return
	# Otherwise: select and refresh highlights
	_selected_ability = ability_id
	for id: String in _ability_btns:
		_ability_btns[id].modulate = Color.WHITE
	if _ability_btns.has(ability_id):
		_ability_btns[ability_id].modulate = SELECTED_ABILITY
	_refresh_highlights()

func _do_hero_self_ability(ability_id: String) -> void:
	_player_turn = false
	_clear_highlights()
	_end_turn_btn.visible = false
	_engine.perform_ability(_hero, ability_id, null)
	_update_all_hp_bars()
	_show_self_ability_vfx(ability_id)
	# Brief System quip
	match ability_id:
		"taunt":
			SystemVoice.speak_direct("You've taunted them. They are now extra motivated to kill you. +5 armor.")
		"vanish":
			SystemVoice.speak_direct("You vanish. Next hit deals 3× damage. Try not to sneeze.")
		"frost_nova":
			SystemVoice.speak_direct("Cold eruption. Adjacent foes flash-frozen.")
	await get_tree().create_timer(0.3).timeout
	_engine.end_turn()
	await get_tree().create_timer(0.2).timeout
	_next_turn()

# ─── Highlights ───────────────────────────────────────────────────────────────

func _refresh_highlights() -> void:
	_clear_highlights()
	if not _player_turn or _engine.battle_over:
		return

	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	var range_val: int = abl.get("range", 1)

	# Show movable hexes (green) if hero hasn't moved yet
	if not _player_moved:
		var neighbors: Array[Vector2i] = HexGrid.neighbors(_hero.position)
		for n: Vector2i in neighbors:
			if _map.is_passable(n) and _find_combatant_at(n) == null:
				_add_hex_highlight(n, MOVE_HIGHLIGHT)

	# Fireball: show AOE ring preview on each reachable hex
	if _selected_ability == "fireball":
		var reachable: Array[Vector2i] = HexGrid.disk(_hero.position, range_val)
		for h: Vector2i in reachable:
			if _map.tile_types.has(h):
				_add_hex_highlight(h, AOE_HIGHLIGHT)
	else:
		# Show attackable enemies (red)
		for e: Combatant in _enemies:
			if e.is_alive() and HexGrid.is_in_range(_hero.position, e.position, range_val):
				_add_hex_highlight(e.position, ATTACK_HIGHLIGHT)

func _add_hex_highlight(hex: Vector2i, color: Color) -> void:
	var world_pos: Vector2 = HexGrid.hex_to_pixel(hex, HEX_SIZE)
	var poly := Polygon2D.new()
	poly.polygon = _make_hex_pts(HEX_SIZE - 3.0)
	poly.position = world_pos
	poly.color = color
	_highlight_layer.add_child(poly)
	_highlight_nodes.append(poly)

func _clear_highlights() -> void:
	for n: Node2D in _highlight_nodes:
		n.queue_free()
	_highlight_nodes.clear()

# ─── Engine Signal Handlers ───────────────────────────────────────────────────

func _on_action_taken(_attacker: Combatant, target: Combatant, damage: int, ability_id: String) -> void:
	if damage > 0:
		_show_damage_number(target, damage)
	if ability_id in ["taunt", "vanish"] and damage == 0:
		_show_buff_text(_attacker, ability_id)
	_update_hp_bar(target)

func _on_combatant_died(c: Combatant) -> void:
	if c.faction == Combatant.Faction.ENEMY:
		SystemVoice.speak("kill")
		GameState.enemies_killed += 1
	var node: Node2D = _entity_nodes.get(c.id)
	if node != null:
		node.modulate = DEAD_MODULATE

func _on_status_ticked(c: Combatant, damage: int) -> void:
	if damage > 0:
		_show_damage_number(c, damage, Color(1.0, 0.5, 0.0))

func _on_entity_moved(c: Combatant, _from_hex: Vector2i, to_hex: Vector2i) -> void:
	## Animate enemy sliding to new hex.
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var target_world: Vector2 = HexGrid.hex_to_pixel(to_hex, HEX_SIZE)
	var tw: Tween = create_tween()
	tw.tween_property(node, "position", target_world, 0.20)

func _on_battle_ended(hero_won: bool, xp_earned: int) -> void:
	_player_turn = false
	_clear_highlights()
	_end_turn_btn.visible = false
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

# ─── Visual Effects ───────────────────────────────────────────────────────────

func _show_ability_vfx(ability_id: String, center_hex: Vector2i) -> void:
	var center_world: Vector2 = HexGrid.hex_to_pixel(center_hex, HEX_SIZE)
	match ability_id:
		"fireball":
			_flash_area_ring(center_world, 2, Color(1.0, 0.45, 0.0, 0.65))
		"frost_nova":
			_flash_area_ring(HexGrid.hex_to_pixel(_hero.position, HEX_SIZE), 1, Color(0.4, 0.75, 1.0, 0.60))
		"backstab":
			_flash_hit_burst(center_world, Color(0.9, 0.1, 0.5, 0.7))
		"power_strike":
			_flash_hit_burst(center_world, Color(1.0, 0.8, 0.0, 0.7))

func _show_self_ability_vfx(ability_id: String) -> void:
	var hero_world: Vector2 = HexGrid.hex_to_pixel(_hero.position, HEX_SIZE)
	match ability_id:
		"taunt":
			_flash_hit_burst(hero_world, Color(0.8, 0.0, 0.0, 0.5))
		"vanish":
			_flash_hit_burst(hero_world, Color(0.2, 0.2, 0.2, 0.8))
		"frost_nova":
			_flash_area_ring(hero_world, 1, Color(0.4, 0.75, 1.0, 0.60))

func _flash_area_ring(world_center: Vector2, hex_radius: int, color: Color) -> void:
	## Briefly draw a colored ring of hexes to show AOE.
	var hexes: Array[Vector2i] = HexGrid.disk(HexGrid.pixel_to_hex(world_center, HEX_SIZE), hex_radius)
	for h: Vector2i in hexes:
		if not _map.tile_types.has(h):
			continue
		var flash := Polygon2D.new()
		flash.polygon = _make_hex_pts(HEX_SIZE - 2.0)
		flash.position = HexGrid.hex_to_pixel(h, HEX_SIZE)
		flash.color = color
		_highlight_layer.add_child(flash)
		var tw: Tween = create_tween()
		tw.tween_property(flash, "color:a", 0.0, 0.45)
		tw.tween_callback(flash.queue_free)

func _flash_hit_burst(world_pos: Vector2, color: Color) -> void:
	var flash := ColorRect.new()
	flash.size = Vector2(50.0, 50.0)
	flash.position = world_pos + Vector2(-25.0, -25.0)
	flash.color = color
	_highlight_layer.add_child(flash)
	var tw: Tween = create_tween()
	tw.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.18)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.18)
	tw.tween_callback(flash.queue_free)

# ─── HP Bar Updates ───────────────────────────────────────────────────────────

func _update_all_hp_bars() -> void:
	for c: Combatant in _all_combatants:
		_update_hp_bar(c)
	_update_hero_hp_label()

func _update_hp_bar(c: Combatant) -> void:
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var hp_bar: ColorRect = node.get_node_or_null("HPBar")
	if hp_bar == null:
		return
	var ratio: float = float(c.hp) / float(max(1, c.max_hp))
	hp_bar.size.x = 38.0 * clampf(ratio, 0.0, 1.0)
	hp_bar.color = Color(1.0 - ratio * 0.8, 0.2 + ratio * 0.68, 0.1)

func _update_hero_hp_label() -> void:
	_hero_hp_label.text = "HP: %d / %d" % [_hero.hp, _hero.max_hp]
	var ratio: float = float(_hero.hp) / float(max(1, _hero.max_hp))
	_hero_hp_label.add_theme_color_override("font_color", Color(1.0 - ratio * 0.7, 0.35 + ratio * 0.65, 0.1))

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

func _show_buff_text(_c: Combatant, ability_id: String) -> void:
	## Float a small text label showing buff applied.
	var node: Node2D = _entity_nodes.get(_hero.id)
	if node == null:
		return
	var lbl := Label.new()
	lbl.text = "FORTIFIED!" if ability_id == "taunt" else "VANISHED!"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4) if ability_id == "taunt" else Color(0.7, 0.7, 0.7))
	lbl.position = node.position + Vector2(-28.0, -40.0)
	_entity_layer.add_child(lbl)
	var tw: Tween = create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -36.0), 1.0)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.tween_callback(lbl.queue_free)

func _show_system_banner(text: String, duration: float) -> void:
	_system_banner.visible = true
	_system_text.text = text
	var tw: Tween = create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func() -> void: _system_banner.visible = false)

# ─── Helpers ──────────────────────────────────────────────────────────────────

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
