extends Node2D
## Visual driver for one battle encounter on the hex grid.
## Run 2: hero movement, ability effects, enemy AI movement, cave atmosphere, death screen.

signal battle_complete(hero_won: bool, xp_earned: int)

const HEX_SIZE: float = 38.0
const HERO_COLOR     := Color(0.25, 0.55, 1.0)
const ENEMY_COLOR    := Color(0.9, 0.2, 0.15)
const LAVA_COLOR     := Color(0.92, 0.38, 0.04)
const FLOOR_COLOR    := Color(0.16, 0.13, 0.19)
const FLOOR_DARK     := Color(0.10, 0.08, 0.13)
const MOVE_HINT_COLOR  := Color(0.2, 0.8, 0.3, 0.35)   ## green highlight: can move here
const ATTACK_HINT_COLOR:= Color(0.9, 0.2, 0.1, 0.40)   ## red highlight: can attack here
const SELECTED_ABILITY_COLOR := Color(1.0, 0.9, 0.2)
const DEAD_MODULATE  := Color(0.35, 0.35, 0.35, 0.4)

var _engine: BattleEngine
var _map: DungeonMap
var _hero: Combatant
var _enemies: Array[Combatant] = []
var _all_combatants: Array[Combatant] = []

## Visual nodes
var _hex_polys: Dictionary = {}          ## Vector2i -> Polygon2D
var _hex_highlights: Dictionary = {}     ## Vector2i -> Polygon2D (highlight overlay)
var _entity_nodes: Dictionary = {}       ## combatant.id -> Node2D
var _ability_btns: Dictionary = {}       ## ability_id -> Button
var _lava_polys: Array[Polygon2D] = []   ## for lava pulse animation

var _selected_ability: String = "basic_attack"
var _player_turn: bool = false
var _battle_rng: RandomNumberGenerator
var _enemies_defeated: int = 0          ## for death screen stats

@onready var _hex_layer: Node2D   = $HexLayer
@onready var _entity_layer: Node2D = $EntityLayer
@onready var _floor_label: Label  = $UILayer/FloorLabel
@onready var _system_banner: Panel  = $UILayer/SystemBanner
@onready var _system_text: Label    = $UILayer/SystemBanner/SystemText
@onready var _ability_bar: HBoxContainer = $UILayer/HUD/AbilityBar
@onready var _turn_indicator: Label = $UILayer/TurnIndicator
@onready var _hero_hp_label: Label  = $UILayer/HeroHPLabel

func _ready() -> void:
	_floor_label.text = "Floor %d" % GameState.floor_num
	SystemVoice.line_spoken.connect(_on_system_line)
	_build_encounter()
	_draw_cave_background()
	_draw_hex_grid()
	_draw_entities()
	_build_ability_bar()
	_start_lava_pulse()
	_update_hero_hp_label()
	SystemVoice.speak("floor_enter", [GameState.floor_num])
	await get_tree().create_timer(0.4).timeout
	_next_turn()

## ─── Encounter Setup ──────────────────────────────────────────────────────────

func _build_encounter() -> void:
	_battle_rng = RandomNumberGenerator.new()
	_battle_rng.seed = GameState.run_seed + GameState.floor_num * 997

	_map = DungeonMap.new()
	_map.generate(GameState.floor_num, _battle_rng)

	## Hero
	_hero = Combatant.new(
		"hero", "Carl", Combatant.Faction.HERO,
		GameState.hero_hp,
		GameState.hero_base_stats.get("speed", 10)
	)
	_hero.armor = GameState.hero_base_stats.get("defense", 0)
	_hero.attack_bonus = GameState.hero_base_stats.get("attack", 0)  ## Run 2 fix
	_hero.abilities = GameState.hero_abilities.duplicate()
	_hero.position = _map.hero_start

	## Enemies
	_enemies.clear()
	var pool: Array[Dictionary] = EnemyDefs.get_enemies_for_floor(GameState.floor_num)
	for i: int in range(_map.spawn_points.size()):
		var def: Dictionary = pool[_battle_rng.randi_range(0, pool.size() - 1)]
		var e: Combatant = EnemyDefs.make_combatant(def, _map.spawn_points[i], _battle_rng)
		_enemies.append(e)

	## Array literal + typed array → untyped; must build manually (CLAUDE.md gotcha)
	_all_combatants.clear()
	_all_combatants.append(_hero)
	for e: Combatant in _enemies:
		_all_combatants.append(e)
	_engine = BattleEngine.new(_battle_rng)
	_engine.battle_ended.connect(_on_battle_ended)
	_engine.action_taken.connect(_on_action_taken)
	_engine.combatant_died.connect(_on_combatant_died)
	_engine.status_ticked.connect(_on_status_ticked)
	_engine.combatant_moved.connect(_on_combatant_moved)    ## Run 2
	_engine.buff_applied.connect(_on_buff_applied)          ## Run 2
	_engine.turn_started.connect(_on_turn_started)          ## Run 2
	## Init hero ability states explicitly before engine.setup() so the bar reads them fresh
	_hero.init_ability_states()
	_engine.setup(_all_combatants, _map.passable)           ## Run 2: pass passable tiles

## ─── Cave Atmosphere ──────────────────────────────────────────────────────────

func _draw_cave_background() -> void:
	## Dark dungeon ambient tint (purple-black)
	var mod := CanvasModulate.new()
	mod.color = Color(0.72, 0.64, 0.82, 1.0)
	add_child(mod)

	## Stalagmite silhouettes at map boundary
	var edge_hexes: Array[Vector2i] = HexGrid.ring(Vector2i.ZERO, _map.radius)
	for hex: Vector2i in edge_hexes:
		_draw_stalagmite(HexGrid.hex_to_pixel(hex, HEX_SIZE))
	## Second outer ring — more silhouettes
	for hex: Vector2i in HexGrid.ring(Vector2i.ZERO, _map.radius + 1):
		if randi() % 2 == 0:  ## 50% chance for variety
			_draw_stalagmite(HexGrid.hex_to_pixel(hex, HEX_SIZE))

func _draw_stalagmite(world_pos: Vector2) -> void:
	## Three tall dark triangles around a point, simulating cave stalactites
	for i: int in range(3):
		var offset: Vector2 = Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0))
		var h: float = randf_range(22.0, 44.0)
		var w: float = randf_range(8.0, 16.0)
		var tip: Vector2 = world_pos + offset + Vector2(0.0, -h)
		var base_l: Vector2 = world_pos + offset + Vector2(-w * 0.5, 0.0)
		var base_r: Vector2 = world_pos + offset + Vector2(w * 0.5, 0.0)
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([tip, base_l, base_r])
		poly.color = Color(0.04, 0.03, 0.06, 0.92)
		poly.z_index = 20  ## Render on top
		_hex_layer.add_child(poly)

## ─── Hex Grid ─────────────────────────────────────────────────────────────────

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

		## Border
		var border := Line2D.new()
		var pts: PackedVector2Array = _make_hex_pts(HEX_SIZE - 1.5)
		pts.append(pts[0])
		border.points = pts
		border.width = 1.2
		border.default_color = Color(0.28, 0.22, 0.32)
		poly.add_child(border)

		## Lava shimmer label "~"
		if tile_type == "lava":
			var lava_lbl := Label.new()
			lava_lbl.text = "~"
			lava_lbl.add_theme_font_size_override("font_size", 14)
			lava_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.1, 0.8))
			lava_lbl.position = Vector2(-5.0, -8.0)
			poly.add_child(lava_lbl)

		## Click detection via Area2D
		var area := Area2D.new()
		area.position = world_pos
		var col := CollisionPolygon2D.new()
		col.polygon = _make_hex_pts(HEX_SIZE - 2.0)
		area.add_child(col)
		area.input_event.connect(_on_hex_input.bind(hex))
		_hex_layer.add_child(area)

func _start_lava_pulse() -> void:
	## Animate lava tiles with a soft brightness pulse
	if _lava_polys.is_empty():
		return
	var tw: Tween = create_tween()
	tw.set_loops()
	for lp: Polygon2D in _lava_polys:
		tw.tween_property(lp, "color", LAVA_COLOR * 1.25, 0.7)
		tw.tween_property(lp, "color", LAVA_COLOR * 0.85, 0.7)

## ─── Hex Highlights ───────────────────────────────────────────────────────────

func _refresh_hex_highlights() -> void:
	## Clear existing highlights
	for hex: Vector2i in _hex_highlights:
		var h: Polygon2D = _hex_highlights[hex]
		if is_instance_valid(h):
			h.queue_free()
	_hex_highlights.clear()

	if not _player_turn or _engine.battle_over:
		return

	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	var target_type: String = abl.get("target", "single_enemy")
	var attack_range: int = abl.get("range", 1)

	if target_type == "single_enemy":
		## Green for movable hexes
		for hex: Vector2i in _map.tile_types:
			if _map.tile_types[hex] == "floor" and HexGrid.hex_distance(_hero.position, hex) == 1:
				if not _is_occupied_by_any(hex):
					_add_hex_highlight(hex, MOVE_HINT_COLOR)
		## Red for enemies in range
		for e: Combatant in _enemies:
			if e.is_alive() and HexGrid.is_in_range(_hero.position, e.position, attack_range):
				_add_hex_highlight(e.position, ATTACK_HINT_COLOR)

	elif target_type == "all_enemies":
		## Show AoE splash area around hero (frost_nova) or possible targets (fireball)
		if ability_id_is_hero_centered(abl):
			for hex: Vector2i in HexGrid.disk(_hero.position, attack_range):
				if _map.tile_types.has(hex):
					_add_hex_highlight(hex, ATTACK_HINT_COLOR)
		else:
			## Fireball: highlight enemies in range (potential blast centers)
			for e: Combatant in _enemies:
				if e.is_alive() and HexGrid.is_in_range(_hero.position, e.position, attack_range):
					_add_hex_highlight(e.position, ATTACK_HINT_COLOR)

func ability_id_is_hero_centered(abl: Dictionary) -> bool:
	## True for abilities like frost_nova that center on the caster
	return abl.get("id", "") == "frost_nova"

func _add_hex_highlight(hex: Vector2i, color: Color) -> void:
	if _hex_highlights.has(hex):
		return
	var world_pos: Vector2 = HexGrid.hex_to_pixel(hex, HEX_SIZE)
	var highlight := Polygon2D.new()
	highlight.polygon = _make_hex_pts(HEX_SIZE - 3.0)
	highlight.position = world_pos
	highlight.color = color
	highlight.z_index = 5
	_hex_layer.add_child(highlight)
	_hex_highlights[hex] = highlight

func _is_occupied_by_any(hex: Vector2i) -> bool:
	for c: Combatant in _all_combatants:
		if c.is_alive() and c.position == hex:
			return true
	return false

## ─── Entities ─────────────────────────────────────────────────────────────────

func _draw_entities() -> void:
	for c: Combatant in _all_combatants:
		_spawn_entity_node(c)

func _spawn_entity_node(c: Combatant) -> void:
	var root := Node2D.new()
	root.position = HexGrid.hex_to_pixel(c.position, HEX_SIZE)
	root.z_index = 10

	## Body hex
	var body := Polygon2D.new()
	body.polygon = _make_hex_pts(HEX_SIZE * 0.42)
	body.color = HERO_COLOR if c.faction == Combatant.Faction.HERO else ENEMY_COLOR
	root.add_child(body)

	## Letter initial
	var lbl := Label.new()
	lbl.text = c.display_name.left(1).to_upper()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.size = Vector2(24.0, 24.0)
	lbl.position = Vector2(-12.0, -12.0)
	root.add_child(lbl)

	## HP bar background
	var hp_bg := ColorRect.new()
	hp_bg.size = Vector2(38.0, 5.0)
	hp_bg.position = Vector2(-19.0, HEX_SIZE * 0.48)
	hp_bg.color = Color(0.25, 0.0, 0.0)
	root.add_child(hp_bg)

	## HP bar fill
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
		_refresh_ability_btn_text(btn, ability_id, abl)
		if ability_id == _selected_ability:
			btn.modulate = SELECTED_ABILITY_COLOR
		btn.pressed.connect(_on_ability_btn.bind(ability_id))
		_ability_bar.add_child(btn)
		_ability_btns[ability_id] = btn

func _refresh_ability_btn_text(btn: Button, ability_id: String, abl: Dictionary) -> void:
	var name_str: String = abl.get("display_name", ability_id)
	var state: Dictionary = _hero.ability_states.get(ability_id, {})
	var max_ch: int = state.get("max_charges", -1)
	var cur_ch: int = state.get("current_charges", -1)
	var cd: int = state.get("cooldown_remaining", 0)
	var sub: String = ""
	if max_ch < 0:
		sub = "∞"  ## Unlimited
	elif cd > 0:
		sub = "CD:%d" % cd
	else:
		sub = "%d/%d" % [cur_ch, max_ch]
	btn.text = "%s\n[%s]" % [name_str, sub]

func _refresh_all_ability_btns() -> void:
	for ability_id: String in _ability_btns:
		var btn: Button = _ability_btns[ability_id]
		var abl: Dictionary = Abilities.get_ability(ability_id)
		_refresh_ability_btn_text(btn, ability_id, abl)
		## Dim if unavailable
		if not _hero.can_use_ability(ability_id):
			btn.modulate = Color(0.4, 0.4, 0.4)
		elif ability_id == _selected_ability:
			btn.modulate = SELECTED_ABILITY_COLOR
		else:
			btn.modulate = Color.WHITE

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
		_refresh_hex_highlights()
		_refresh_all_ability_btns()
	else:
		_player_turn = false
		_turn_indicator.text = "%s's Turn" % active.display_name
		_turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
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

	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	var target_type: String = abl.get("target", "single_enemy")

	## Self-targeting buffs: activate immediately on any click
	if target_type == "self":
		if _hero.can_use_ability(_selected_ability):
			_do_hero_action(hex)
		else:
			_show_system_banner("Ability not ready.", 1.2)
		return

	## AoE abilities (fireball, frost_nova): activate on click
	if target_type == "all_enemies":
		var attack_range: int = abl.get("range", 1)
		## For frost_nova (hero-centered): always valid
		## For fireball: check hero is within range of click target
		if ability_id_is_hero_centered(abl) or HexGrid.is_in_range(_hero.position, hex, attack_range):
			if _hero.can_use_ability(_selected_ability):
				_do_hero_action(hex)
			else:
				_show_system_banner("Ability not ready.", 1.2)
		else:
			_show_system_banner("Out of range!", 1.2)
		return

	## Single-enemy: click enemy → attack; click empty floor → move
	var target: Combatant = _find_enemy_at(hex)
	if target != null:
		var attack_range: int = abl.get("range", 1)
		if not HexGrid.is_in_range(_hero.position, target.position, attack_range):
			_show_system_banner("Out of range!", 1.2)
			return
		if not _hero.can_use_ability(_selected_ability):
			_show_system_banner("Ability not ready.", 1.2)
			return
		_do_hero_action(hex)
	else:
		## Empty hex: try movement
		if _is_valid_move_target(hex):
			_do_hero_move(hex)

func _is_valid_move_target(hex: Vector2i) -> bool:
	if HexGrid.hex_distance(_hero.position, hex) != 1:
		return false
	if not _map.is_passable(hex):
		return false
	if _is_occupied_by_any(hex):
		return false
	return true

func _do_hero_action(target_hex: Vector2i) -> void:
	_player_turn = false
	_refresh_hex_highlights()  ## Clear highlights while acting
	_engine.perform_action(_hero, target_hex, _selected_ability)
	SystemVoice.speak("hit")
	_update_all_hp_bars()
	_update_hero_hp_label()
	_refresh_all_ability_btns()
	_engine.end_turn()
	await get_tree().create_timer(0.2).timeout
	_next_turn()

func _do_hero_move(dest: Vector2i) -> void:
	_player_turn = false
	_refresh_hex_highlights()
	_engine.move_combatant(_hero, dest)
	## Animate hero node
	var hero_node: Node2D = _entity_nodes.get(_hero.id)
	if hero_node != null:
		var tw: Tween = create_tween()
		tw.tween_property(hero_node, "position", HexGrid.hex_to_pixel(dest, HEX_SIZE), 0.18)
	_engine.end_turn()
	await get_tree().create_timer(0.22).timeout
	_next_turn()

func _find_enemy_at(hex: Vector2i) -> Combatant:
	for e: Combatant in _enemies:
		if e.is_alive() and e.position == hex:
			return e
	return null

func _on_ability_btn(ability_id: String) -> void:
	_selected_ability = ability_id
	_refresh_all_ability_btns()
	_refresh_hex_highlights()

## ─── Engine Signal Handlers ───────────────────────────────────────────────────

func _on_turn_started(_c: Combatant) -> void:
	## Could show frozen banner, etc.
	pass

func _on_action_taken(attacker: Combatant, target: Combatant, damage: int, ability_id: String) -> void:
	if damage > 0:
		_show_damage_number(target, damage)
	_update_hp_bar(target)
	## AoE flash: fireball leaves burn marks
	if ability_id == "fireball" and attacker.faction == Combatant.Faction.HERO:
		_flash_hex(target.position, Color(1.0, 0.5, 0.0, 0.7))
	elif ability_id == "frost_nova":
		_flash_hex(target.position, Color(0.4, 0.7, 1.0, 0.65))

func _on_combatant_died(c: Combatant) -> void:
	if c.faction == Combatant.Faction.ENEMY:
		SystemVoice.speak("kill")
		_enemies_defeated += 1
	var node: Node2D = _entity_nodes.get(c.id)
	if node != null:
		node.modulate = DEAD_MODULATE

func _on_status_ticked(c: Combatant, damage: int) -> void:
	if damage > 0:
		_show_damage_number(c, damage, Color(1.0, 0.5, 0.0))

func _on_combatant_moved(c: Combatant, _from: Vector2i, to: Vector2i) -> void:
	## Animate enemy movement
	if c.faction == Combatant.Faction.ENEMY:
		var node: Node2D = _entity_nodes.get(c.id)
		if node != null:
			var tw: Tween = create_tween()
			tw.tween_property(node, "position", HexGrid.hex_to_pixel(to, HEX_SIZE), 0.22)

func _on_buff_applied(c: Combatant, ability_id: String) -> void:
	## Visual feedback for self-buffs
	match ability_id:
		"vanish":
			_show_system_banner("VANISHED — next attack ×3!", 2.0)
			_flash_entity(c, Color(0.6, 0.2, 0.9, 0.8))
		"taunt":
			_show_system_banner("TAUNTING — armor increased!", 2.0)
			_flash_entity(c, Color(1.0, 0.7, 0.0, 0.8))

func _on_battle_ended(hero_won: bool, xp_earned: int) -> void:
	_player_turn = false
	_refresh_hex_highlights()
	if hero_won:
		_turn_indicator.text = "VICTORY!"
		_turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		SystemVoice.speak_direct(
			"Enemies cleared. XP gained: %d. The System is mildly impressed." % xp_earned
		)
		await get_tree().create_timer(1.8).timeout
		battle_complete.emit(true, xp_earned)
	else:
		## Hero died: show death screen
		SystemVoice.speak("death")
		await get_tree().create_timer(0.6).timeout
		_show_death_screen(xp_earned)

func _on_system_line(text: String, _dur: float) -> void:
	_show_system_banner(text, 2.8)

## ─── Death Screen ─────────────────────────────────────────────────────────────

func _show_death_screen(_xp: int) -> void:
	## Full-screen overlay as a CanvasLayer
	var canvas := CanvasLayer.new()
	canvas.layer = 128
	add_child(canvas)

	## Dark background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	canvas.add_child(bg)
	## Fade in
	var fade: Tween = create_tween()
	fade.tween_property(bg, "color", Color(0.0, 0.0, 0.0, 0.78), 0.6)

	## Center container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-300.0, -220.0)
	vbox.custom_minimum_size = Vector2(600.0, 440.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	canvas.add_child(vbox)

	## YOU DIED header
	var died_lbl := Label.new()
	died_lbl.text = "YOU DIED"
	died_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	died_lbl.add_theme_font_size_override("font_size", 64)
	died_lbl.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	vbox.add_child(died_lbl)

	## System quip (picked from death pool already spoken)
	var quip_lbl := Label.new()
	quip_lbl.text = "The System is not surprised."
	quip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip_lbl.add_theme_font_size_override("font_size", 16)
	quip_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.6))
	quip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip_lbl.custom_minimum_size = Vector2(560.0, 0.0)
	vbox.add_child(quip_lbl)

	## Stats panel
	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	var stats_lbl := Label.new()
	stats_lbl.text = (
		"Floor Reached:     %d\n" +
		"Enemies Defeated:  %d\n" +
		"Level Attained:    %d"
	) % [GameState.floor_num, _enemies_defeated, GameState.hero_level]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 18)
	stats_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65))
	vbox.add_child(stats_lbl)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	## Try Again button
	var retry_btn := Button.new()
	retry_btn.text = "TRY AGAIN"
	retry_btn.custom_minimum_size = Vector2(200.0, 50.0)
	retry_btn.add_theme_font_size_override("font_size", 20)
	retry_btn.pressed.connect(_on_retry_pressed)
	vbox.add_child(retry_btn)

	## Slight delay before button becomes interactive
	retry_btn.disabled = true
	await get_tree().create_timer(1.2).timeout
	retry_btn.disabled = false

## ─── Visual Helpers ───────────────────────────────────────────────────────────

func _on_retry_pressed() -> void:
	battle_complete.emit(false, 0)

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
	hp_bar.color = Color(1.0 - ratio * 0.8, 0.2 + ratio * 0.68, 0.1)

func _update_hero_hp_label() -> void:
	_hero_hp_label.text = "HP: %d / %d" % [_hero.hp, _hero.max_hp]
	var ratio: float = float(_hero.hp) / float(max(1, _hero.max_hp))
	_hero_hp_label.add_theme_color_override("font_color", Color(1.0 - ratio * 0.8, 0.2 + ratio * 0.68, 0.1))

func _show_damage_number(c: Combatant, damage: int, color: Color = Color(1.0, 0.25, 0.1)) -> void:
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var lbl := Label.new()
	lbl.text = "-%d" % damage
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = node.position + Vector2(-14.0, -22.0)
	lbl.z_index = 50
	_entity_layer.add_child(lbl)
	var tw: Tween = create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -48.0), 0.85)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.85)
	tw.tween_callback(lbl.queue_free)

func _flash_hex(hex: Vector2i, color: Color) -> void:
	## Brief colored flash on a hex (for AoE effects)
	var world_pos: Vector2 = HexGrid.hex_to_pixel(hex, HEX_SIZE)
	var flash := Polygon2D.new()
	flash.polygon = _make_hex_pts(HEX_SIZE - 2.0)
	flash.position = world_pos
	flash.color = color
	flash.z_index = 8
	_hex_layer.add_child(flash)
	var tw: Tween = create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.4)
	tw.tween_callback(flash.queue_free)

func _flash_entity(c: Combatant, color: Color) -> void:
	## Brief colored glow on an entity
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var flash := Polygon2D.new()
	flash.polygon = _make_hex_pts(HEX_SIZE * 0.50)
	flash.color = color
	flash.z_index = 12
	node.add_child(flash)
	var tw: Tween = create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.55)
	tw.tween_callback(flash.queue_free)

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
