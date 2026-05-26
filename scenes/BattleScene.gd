extends Node2D
## Visual driver for one battle encounter on the hex grid.
## Run 3: ability charges/cooldown HUD, enemy collision fix, victory overlay,
##        floor scaling, class silhouettes.

signal battle_complete(hero_won: bool, xp_earned: int)

const HEX_SIZE: float = 38.0
const HERO_COLOR     := Color(0.25, 0.55, 1.0)
const ENEMY_COLOR    := Color(0.9, 0.2, 0.15)
const LAVA_COLOR     := Color(0.82, 0.32, 0.04)
const FLOOR_COLOR    := Color(0.16, 0.13, 0.19)
const FLOOR_DARK     := Color(0.10, 0.08, 0.13)
const SELECTED_CLR   := Color(1.0, 0.9, 0.2)
const DEAD_MODULATE  := Color(0.35, 0.35, 0.35, 0.4)
const MOVE_CLR       := Color(0.15, 0.85, 0.35, 0.45)
const ATTACK_CLR     := Color(0.9, 0.15, 0.05, 0.55)
const AOE_CLR        := Color(0.9, 0.45, 0.05, 0.35)
const SELF_CLR       := Color(0.6, 0.3, 0.9, 0.5)
const FROST_CLR      := Color(0.25, 0.65, 1.0, 0.5)
const DEPLETED_CLR   := Color(0.40, 0.40, 0.40, 0.90)

var _engine: BattleEngine
var _map: DungeonMap
var _hero: Combatant
var _enemies: Array[Combatant] = []
var _all_combatants: Array[Combatant] = []

# Visual nodes
var _hex_polys: Dictionary = {}      # Vector2i -> Polygon2D
var _entity_nodes: Dictionary = {}   # combatant.id -> Node2D
var _ability_btns: Dictionary = {}   # ability_id -> Button
var _ability_objects: Dictionary = {} # ability_id -> Ability (Run 3)
var _highlight_hexes: Array[Vector2i] = []

var _selected_ability: String = "basic_attack"
var _player_turn: bool = false
var _battle_rng: RandomNumberGenerator
var _enemies_killed: int = 0

@onready var _hex_layer: Node2D = $HexLayer
@onready var _entity_layer: Node2D = $EntityLayer
@onready var _floor_label: Label = $UILayer/FloorLabel
@onready var _system_banner: Panel = $UILayer/SystemBanner
@onready var _system_text: Label = $UILayer/SystemBanner/SystemText
@onready var _ability_bar: HBoxContainer = $UILayer/HUD/AbilityBar
@onready var _turn_indicator: Label = $UILayer/TurnIndicator
@onready var _hero_hp_label: Label = $UILayer/HeroHPLabel

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
	SystemVoice.speak("floor_enter", [GameState.floor_num])
	await get_tree().create_timer(0.4).timeout
	_next_turn()

## ─── Encounter Setup ──────────────────────────────────────────────────────────

func _build_encounter() -> void:
	_battle_rng = RandomNumberGenerator.new()
	_battle_rng.seed = GameState.run_seed + GameState.floor_num * 997

	_map = DungeonMap.new()
	_map.generate(GameState.floor_num, _battle_rng)

	_hero = Combatant.new(
		"hero", "Carl", Combatant.Faction.HERO,
		GameState.hero_hp,
		GameState.hero_base_stats.get("speed", 10)
	)
	_hero.armor = GameState.hero_base_stats.get("defense", 0)
	_hero.attack_bonus = GameState.hero_base_stats.get("attack", 0)
	var raw_abilities: Array = GameState.hero_abilities.duplicate()
	var typed_abilities: Array[String] = []
	for a: String in raw_abilities:
		typed_abilities.append(a)
	_hero.abilities = typed_abilities
	_hero.position = _map.hero_start

	# Build Ability objects for the hero (Run 3: charges + cooldown tracking)
	_ability_objects.clear()
	for ability_id: String in _hero.abilities:
		_ability_objects[ability_id] = Abilities.make_ability(ability_id)

	_enemies.clear()
	var pool: Array[Dictionary] = EnemyDefs.get_enemies_for_floor(GameState.floor_num)
	for i: int in range(_map.spawn_points.size()):
		var def: Dictionary = pool[_battle_rng.randi_range(0, pool.size() - 1)]
		var e: Combatant = EnemyDefs.make_combatant(def, _map.spawn_points[i], _battle_rng)
		_enemies.append(e)

	# Floor scaling: enemies get tougher each floor (Run 3)
	var floor_scale: float = 1.0 + float(GameState.floor_num - 1) * 0.18
	var atk_scale: int = (GameState.floor_num - 1) * 3
	for e: Combatant in _enemies:
		e.max_hp = int(float(e.max_hp) * floor_scale)
		e.hp = e.max_hp
		e.attack_bonus += atk_scale

	_all_combatants = [_hero] + _enemies
	_engine = BattleEngine.new(_battle_rng)
	_engine.battle_ended.connect(_on_battle_ended)
	_engine.action_taken.connect(_on_action_taken)
	_engine.combatant_died.connect(_on_combatant_died)
	_engine.status_ticked.connect(_on_status_ticked)
	_engine.hero_moved.connect(_on_hero_moved)
	_engine.setup(_all_combatants)

## ─── Cave Atmosphere ──────────────────────────────────────────────────────────

func _draw_cave_background() -> void:
	# Subtle dungeon-atmosphere color modulation
	var cm := CanvasModulate.new()
	cm.color = Color(0.78, 0.72, 0.92)
	add_child(cm)

func _draw_stalagmites() -> void:
	## Draw dark triangular stalagmites in the outer ring — purely decorative
	var stalg_container := Node2D.new()
	stalg_container.name = "Stalagmites"
	stalg_container.z_index = -1
	_hex_layer.add_child(stalg_container)

	var stalg_rng := RandomNumberGenerator.new()
	stalg_rng.seed = GameState.run_seed + 31337

	# Ring 6 and 7 are outside the dungeon (radius 5)
	for ring_r: int in [6, 7]:
		for hex: Vector2i in HexGrid.ring(Vector2i.ZERO, ring_r):
			if stalg_rng.randf() > 0.5:
				continue
			var world_pos: Vector2 = HexGrid.hex_to_pixel(hex, HEX_SIZE)
			var height: float = stalg_rng.randf_range(20.0, 55.0)
			var width: float  = stalg_rng.randf_range(12.0, 28.0)
			# Alternate stalactites (up) and stalagmites (down)
			var dir: float = 1.0 if stalg_rng.randf() > 0.5 else -1.0
			var pts := PackedVector2Array()
			pts.append(Vector2(-width * 0.5, 0.0))
			pts.append(Vector2(width * 0.5, 0.0))
			pts.append(Vector2(0.0, -height * dir))
			var poly := Polygon2D.new()
			poly.polygon = pts
			poly.color = Color(0.03, 0.02, 0.05, 0.95)
			poly.position = world_pos
			stalg_container.add_child(poly)

## ─── Drawing ──────────────────────────────────────────────────────────────────

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
			_:
				var shade: float = 0.0 if (hex.x + hex.y) % 2 == 0 else 0.04
				poly.color = FLOOR_COLOR + Color(shade, shade, shade, 0.0)
		_hex_layer.add_child(poly)
		_hex_polys[hex] = poly

		# Hex border
		var border := Line2D.new()
		var bpts: PackedVector2Array = _make_hex_pts(HEX_SIZE - 1.5)
		bpts.append(bpts[0])
		border.points = bpts
		border.width = 1.2
		border.default_color = Color(0.28, 0.22, 0.32)
		poly.add_child(border)

		# Lava shimmer glyph
		if tile_type == "lava":
			var lava_lbl := Label.new()
			lava_lbl.text = "~"
			lava_lbl.add_theme_font_size_override("font_size", 14)
			lava_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.1, 0.9))
			lava_lbl.position = Vector2(-5.0, -8.0)
			poly.add_child(lava_lbl)
			_start_lava_pulse(poly)

		# Click input via Area2D
		var area := Area2D.new()
		area.position = world_pos
		var col := CollisionPolygon2D.new()
		col.polygon = _make_hex_pts(HEX_SIZE - 2.0)
		area.add_child(col)
		area.input_event.connect(_on_hex_input.bind(hex))
		_hex_layer.add_child(area)

func _start_lava_pulse(poly: Polygon2D) -> void:
	## Pulse lava tiles between bright and dim orange
	var tw: Tween = create_tween()
	tw.set_loops()
	# Stagger start so lava doesn't all pulse in sync
	var delay: float = _battle_rng.randf_range(0.0, 1.5)
	tw.tween_interval(delay)
	tw.tween_property(poly, "color", Color(0.98, 0.55, 0.06), 0.7)
	tw.tween_property(poly, "color", Color(0.60, 0.18, 0.01), 0.9)

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

	if c.faction == Combatant.Faction.HERO:
		# Run 3: Class-specific silhouette replaces letter initial
		var silhouette := Polygon2D.new()
		var sil_size: float = HEX_SIZE * 0.33
		match GameState.hero_class:
			"brawler":
				silhouette.polygon = _make_shield_pts(sil_size)
				silhouette.color = Color(0.95, 0.88, 0.65)
			"rogue":
				silhouette.polygon = _make_dagger_pts(sil_size)
				silhouette.color = Color(0.65, 0.95, 0.65)
			"arcanist":
				silhouette.polygon = _make_star_pts(sil_size, 4)
				silhouette.color = Color(0.70, 0.76, 1.0)
			_:
				silhouette.polygon = _make_hex_pts(sil_size * 0.75)
				silhouette.color = Color(0.9, 0.9, 0.9)
		root.add_child(silhouette)
	else:
		# Enemy: keep letter initial
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

	# Status icons area
	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
	status_lbl.position = Vector2(-19.0, -HEX_SIZE * 0.62)
	root.add_child(status_lbl)

	_entity_layer.add_child(root)
	_entity_nodes[c.id] = root

## ─── Ability Bar (Run 3: charges + cooldown display) ─────────────────────────

func _build_ability_bar() -> void:
	for child: Node in _ability_bar.get_children():
		child.queue_free()
	_ability_btns.clear()

	for ability_id: String in _hero.abilities:
		var abl: Dictionary = Abilities.get_ability(ability_id)
		var ab_obj: Ability = _ability_objects.get(ability_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(115.0, 60.0)
		var type_icon: String = _ability_type_icon(abl.get("target", "single_enemy"))
		var charges_str: String = _get_charges_str(ab_obj)
		btn.text = "%s %s\n%s" % [type_icon, abl.get("display_name", ability_id), charges_str]
		btn.add_theme_font_size_override("font_size", 11)
		_style_ability_btn(btn, ability_id, ab_obj)
		btn.pressed.connect(_on_ability_btn.bind(ability_id))
		_ability_bar.add_child(btn)
		_ability_btns[ability_id] = btn

func _ability_type_icon(target_type: String) -> String:
	match target_type:
		"self":          return "✦"
		"all_enemies":   return "💥"
		_:               return "⚔"

func _get_charges_str(ab: Ability) -> String:
	## Returns a compact charge/cooldown indicator string.
	if ab == null:
		return ""
	if ab.max_charges == -1:
		return "∞"
	if ab.cooldown_remaining > 0:
		return "CD: %d" % ab.cooldown_remaining
	# Filled/empty pip display: ● = available charge, ○ = spent
	var dots: String = ""
	for i: int in range(ab.max_charges):
		dots += "●" if i < ab.current_charges else "○"
	return dots

func _style_ability_btn(btn: Button, ability_id: String, ab: Ability) -> void:
	## Apply modulate/disabled state based on charges and selection.
	if ab != null and not ab.can_use():
		btn.modulate = DEPLETED_CLR
		btn.disabled = true
	elif ability_id == _selected_ability:
		btn.modulate = SELECTED_CLR
		btn.disabled = false
	else:
		btn.modulate = Color.WHITE
		btn.disabled = false

func _update_ability_bar_ui() -> void:
	## Refresh button text + state without rebuilding (Run 3).
	for ability_id: String in _ability_btns:
		var btn: Button = _ability_btns.get(ability_id)
		if btn == null:
			continue
		var abl: Dictionary = Abilities.get_ability(ability_id)
		var ab_obj: Ability = _ability_objects.get(ability_id)
		var type_icon: String = _ability_type_icon(abl.get("target", "single_enemy"))
		var charges_str: String = _get_charges_str(ab_obj)
		btn.text = "%s %s\n%s" % [type_icon, abl.get("display_name", ability_id), charges_str]
		_style_ability_btn(btn, ability_id, ab_obj)

func _tick_hero_ability_cooldowns() -> void:
	## Called at end of each hero turn to advance cooldown timers.
	for ability_id: String in _ability_objects:
		var ab: Ability = _ability_objects.get(ability_id)
		if ab != null:
			ab.tick_cooldown()
	_update_ability_bar_ui()

## ─── Turn Logic ───────────────────────────────────────────────────────────────

func _next_turn() -> void:
	if _engine.battle_over:
		return
	var active: Combatant = _engine.begin_turn()
	if active == null:
		return

	if active.faction == Combatant.Faction.HERO:
		_player_turn = true
		_turn_indicator.text = "YOUR TURN — Click to move or attack"
		_turn_indicator.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		_update_highlights()
		_update_hero_hp_label()
	else:
		_player_turn = false
		_clear_highlights()
		_turn_indicator.text = "%s's Turn" % active.display_name
		_turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		await get_tree().create_timer(0.55).timeout
		if not _engine.battle_over:
			_engine.enemy_ai_action(active, _map)
			_sync_entity_positions()
			_update_all_hp_bars()
			_engine.end_turn()
			await get_tree().create_timer(0.25).timeout
			_next_turn()

## ─── Hex Input ────────────────────────────────────────────────────────────────

func _on_hex_input(_viewport: Viewport, event: InputEvent, _shape_idx: int, hex: Vector2i) -> void:
	if not _player_turn or _engine.battle_over:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return

	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	var abl_target: String = abl.get("target", "single_enemy")
	var abl_range: int = abl.get("range", 1)

	# Clicking hero's own hex → use self-target abilities
	if hex == _hero.position:
		if abl_target == "self":
			_do_hero_self_ability()
		return

	# Check for enemy at clicked hex
	var target: Combatant = _find_enemy_at(hex)
	if target != null:
		if not HexGrid.is_in_range(_hero.position, hex, abl_range):
			_show_system_banner("Out of range!", 1.2)
			return
		if abl_target == "all_enemies":
			# AOE centered on target hex
			_do_hero_aoe_ability(hex)
		else:
			_do_hero_attack(target)
		return

	# Clicking an empty hex — check movement or AOE targeting
	if abl_target == "all_enemies" and abl_range > 1:
		# Ranged AOE (fireball): clicking empty hex in range fires it there
		if HexGrid.is_in_range(_hero.position, hex, abl_range):
			_do_hero_aoe_ability(hex)
			return

	# Attempt movement
	if _is_valid_move_hex(hex):
		_do_hero_move(hex)

func _is_valid_move_hex(hex: Vector2i) -> bool:
	if HexGrid.hex_distance(_hero.position, hex) != 1:
		return false
	if not _map.is_passable(hex):
		return false
	# No entity already there
	for c: Combatant in _all_combatants:
		if c.is_alive() and c.position == hex:
			return false
	return true

## ─── Player Actions ───────────────────────────────────────────────────────────

func _do_hero_move(hex: Vector2i) -> void:
	_player_turn = false
	_clear_highlights()
	_engine.move_combatant(_hero, hex)
	# Visual movement handled by _on_hero_moved signal
	var quips: Array[String] = [
		"Tactical repositioning. The System is cautiously optimistic.",
		"You move. The dungeon shrugs.",
		"New position acquired. Try not to die there.",
	]
	_show_system_banner(quips[_battle_rng.randi_range(0, quips.size() - 1)], 1.5)
	await get_tree().create_timer(0.28).timeout
	_tick_hero_ability_cooldowns()
	_engine.end_turn()
	_next_turn()

func _do_hero_attack(target: Combatant) -> void:
	_player_turn = false
	_clear_highlights()
	# Consume ability charge before attack
	var ab_obj: Ability = _ability_objects.get(_selected_ability)
	if ab_obj != null:
		ab_obj.use()
	_engine.perform_attack(_hero, target, _selected_ability)
	SystemVoice.speak("hit")
	_update_all_hp_bars()
	_update_hero_hp_label()
	_tick_hero_ability_cooldowns()
	_engine.end_turn()
	await get_tree().create_timer(0.2).timeout
	_next_turn()

func _do_hero_aoe_ability(center_hex: Vector2i) -> void:
	## Handles fireball (damage AOE) and frost_nova (freeze AOE)
	_player_turn = false
	_clear_highlights()

	# Consume ability charge
	var ab_obj: Ability = _ability_objects.get(_selected_ability)
	if ab_obj != null:
		ab_obj.use()

	var aoe_radius: int = 2  # default AOE radius for fireball

	if _selected_ability == "frost_nova":
		aoe_radius = 1
		# Apply frozen status to all enemies in range 1 of hero (not center_hex)
		var frozen_count: int = 0
		for e: Combatant in _enemies:
			if e.is_alive() and HexGrid.is_in_range(_hero.position, e.position, 1):
				e.apply_status(StatusEffect.frozen(2))
				frozen_count += 1
		if frozen_count > 0:
			SystemVoice.speak_direct("Frost Nova! %d enemies frozen. Cold comfort." % frozen_count)
			_flash_hex_area(_hero.position, 1, FROST_CLR)
		else:
			SystemVoice.speak_direct("Frost Nova fires into empty space. The dungeon sighs.")
	else:
		# Damage AOE (fireball etc.)
		var disk_hexes: Array[Vector2i] = HexGrid.disk(center_hex, aoe_radius)
		var targets: Array[Combatant] = []
		for e: Combatant in _enemies:
			if e.is_alive() and e.position in disk_hexes:
				targets.append(e)
		if not targets.is_empty():
			_engine.perform_aoe_attack(_hero, targets, _selected_ability)
			SystemVoice.speak_direct("Fireball! %d targets caught in the blast." % targets.size())
		else:
			SystemVoice.speak_direct("Fireball detonates. Impressively. On nothing.")
		_flash_hex_area(center_hex, aoe_radius, AOE_CLR)

	_update_all_hp_bars()
	_update_hero_hp_label()
	_tick_hero_ability_cooldowns()
	_engine.end_turn()
	await get_tree().create_timer(0.35).timeout
	_next_turn()

func _do_hero_self_ability() -> void:
	## Use self-target ability (taunt, vanish)
	_player_turn = false
	_clear_highlights()

	# Consume ability charge
	var ab_obj: Ability = _ability_objects.get(_selected_ability)
	if ab_obj != null:
		ab_obj.use()

	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	match _selected_ability:
		"taunt":
			var armor_bonus: int = abl.get("fortified_armor", 5)
			var dur: int = abl.get("fortified_duration", 3)
			_hero.apply_status(StatusEffect.fortified(dur, armor_bonus))
			SystemVoice.speak_direct("Taunted. All enemies focus on you. You asked for this.")
			_flash_hex_area(_hero.position, 0, SELF_CLR)
		"vanish":
			_hero.apply_status(StatusEffect.vanished(3.0))
			SystemVoice.speak_direct("Vanished. Await your moment. Make it count.")
			# Visual: briefly dim hero node
			var hnode: Node2D = _entity_nodes.get(_hero.id)
			if hnode != null:
				var tw: Tween = create_tween()
				tw.tween_property(hnode, "modulate:a", 0.3, 0.3)
		_:
			SystemVoice.speak_direct("Nothing happens. The System is confused too.")

	_update_hero_hp_label()
	_tick_hero_ability_cooldowns()
	_engine.end_turn()
	await get_tree().create_timer(0.3).timeout
	_next_turn()

func _flash_hex_area(center: Vector2i, radius: int, color: Color) -> void:
	## Brief color flash on a set of hexes to show AOE or ability impact
	var hexes: Array[Vector2i] = HexGrid.disk(center, radius)
	for h: Vector2i in hexes:
		var poly: Polygon2D = _hex_polys.get(h)
		if poly == null:
			continue
		var flash := Polygon2D.new()
		flash.polygon = _make_hex_pts(HEX_SIZE - 3.0)
		flash.color = color
		poly.add_child(flash)
		var tw: Tween = create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.45)
		tw.tween_callback(flash.queue_free)

func _find_enemy_at(hex: Vector2i) -> Combatant:
	for e: Combatant in _enemies:
		if e.is_alive() and e.position == hex:
			return e
	return null

func _on_ability_btn(ability_id: String) -> void:
	# Guard: depleted abilities can't be selected
	var ab_obj: Ability = _ability_objects.get(ability_id)
	if ab_obj != null and not ab_obj.can_use():
		_show_system_banner("Not ready. [CD: %d]" % ab_obj.cooldown_remaining, 1.2)
		return
	# If already selected and player's turn → self-target abilities fire immediately
	var abl: Dictionary = Abilities.get_ability(ability_id)
	if _selected_ability == ability_id and _player_turn and abl.get("target", "single_enemy") == "self":
		_do_hero_self_ability()
		return
	_selected_ability = ability_id
	_update_ability_bar_ui()
	if _player_turn:
		_update_highlights()

## ─── Movement Highlighting ────────────────────────────────────────────────────

func _update_highlights() -> void:
	_clear_highlights()
	if not _player_turn:
		return

	# Movement hexes — adjacent, passable, empty
	for n: Vector2i in HexGrid.neighbors(_hero.position):
		if _is_valid_move_hex(n):
			_highlight_hex(n, MOVE_CLR)

	# Ability-range highlights
	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	var abl_target: String = abl.get("target", "single_enemy")
	var abl_range: int = abl.get("range", 1)

	match abl_target:
		"single_enemy":
			for e: Combatant in _enemies:
				if e.is_alive() and HexGrid.is_in_range(_hero.position, e.position, abl_range):
					_highlight_hex(e.position, ATTACK_CLR)
		"all_enemies":
			if abl_range <= 1:
				# Frost nova — show adjacent enemies
				for e: Combatant in _enemies:
					if e.is_alive() and HexGrid.is_in_range(_hero.position, e.position, abl_range):
						_highlight_hex(e.position, FROST_CLR)
			else:
				# Fireball — show reachable area
				for h: Vector2i in HexGrid.disk(_hero.position, abl_range):
					if _map.tile_types.has(h):
						_highlight_hex(h, AOE_CLR)
		"self":
			_highlight_hex(_hero.position, SELF_CLR)

func _highlight_hex(hex: Vector2i, color: Color) -> void:
	var poly: Polygon2D = _hex_polys.get(hex)
	if poly == null:
		return
	if poly.get_node_or_null("Highlight") != null:
		return  # already highlighted
	var overlay := Polygon2D.new()
	overlay.name = "Highlight"
	overlay.polygon = _make_hex_pts(HEX_SIZE - 4.0)
	overlay.color = color
	poly.add_child(overlay)
	_highlight_hexes.append(hex)

func _clear_highlights() -> void:
	for hex: Vector2i in _highlight_hexes:
		var poly: Polygon2D = _hex_polys.get(hex)
		if poly != null:
			var overlay: Node = poly.get_node_or_null("Highlight")
			if overlay != null:
				overlay.queue_free()
	_highlight_hexes.clear()

## ─── Engine Signal Handlers ───────────────────────────────────────────────────

func _on_action_taken(_attacker: Combatant, target: Combatant, damage: int, _ability_id: String) -> void:
	_show_damage_number(target, damage)
	_update_hp_bar(target)
	_update_status_label(target)

func _on_combatant_died(c: Combatant) -> void:
	if c.faction == Combatant.Faction.ENEMY:
		SystemVoice.speak("kill")
		_enemies_killed += 1
	else:
		# Hero died — start death overlay after a moment
		await get_tree().create_timer(0.5).timeout
		_show_death_overlay()
	var node: Node2D = _entity_nodes.get(c.id)
	if node != null:
		node.modulate = DEAD_MODULATE

func _on_status_ticked(c: Combatant, damage: int) -> void:
	if damage > 0:
		_show_damage_number(c, damage, Color(1.0, 0.5, 0.0))
	_update_status_label(c)

func _on_hero_moved(_combatant: Combatant, _from_hex: Vector2i, to_hex: Vector2i) -> void:
	## Animate hero node to new position
	var node: Node2D = _entity_nodes.get(_hero.id)
	if node != null:
		var tw: Tween = create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_QUART)
		tw.tween_property(node, "position", HexGrid.hex_to_pixel(to_hex, HEX_SIZE), 0.22)

func _on_battle_ended(hero_won: bool, xp_earned: int) -> void:
	_player_turn = false
	_clear_highlights()
	if hero_won:
		_turn_indicator.text = "FLOOR CLEARED!"
		_turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		await get_tree().create_timer(0.4).timeout
		_show_victory_overlay(xp_earned)
	else:
		_turn_indicator.text = "DEFEATED"
		_turn_indicator.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
		SystemVoice.speak("death")
		# Death overlay shown by _on_combatant_died when hero dies

## ─── Victory Overlay (Run 3) ─────────────────────────────────────────────────

func _show_victory_overlay(xp_earned: int) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)

	# Dark semi-transparent backdrop
	var bg := ColorRect.new()
	bg.size = Vector2(1280.0, 720.0)
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	cl.add_child(bg)
	var tw_bg: Tween = create_tween()
	tw_bg.tween_property(bg, "color", Color(0.0, 0.0, 0.0, 0.80), 0.7)

	await get_tree().create_timer(0.4).timeout

	# Gold "FLOOR N CLEARED!" title
	var title := Label.new()
	title.text = "FLOOR %d CLEARED!" % GameState.floor_num
	title.position = Vector2(200.0, 130.0)
	title.custom_minimum_size = Vector2(880.0, 0.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.08))
	title.modulate.a = 0.0
	cl.add_child(title)
	var tw_title: Tween = create_tween()
	tw_title.tween_property(title, "modulate:a", 1.0, 0.5)

	# System victory quip
	var victory_quips: Array[String] = [
		"All hostiles eliminated. The System is... almost impressed.",
		"Floor cleared. The dungeon notes your survival with quiet resentment.",
		"Victory. The next floor will be worse. You have been warned.",
		"Enemies neutralised. XP: %d. Grudging acknowledgement granted." % xp_earned,
		"Well. That happened. The dungeon is recalibrating.",
	]
	var quip_lbl := Label.new()
	quip_lbl.text = victory_quips[_battle_rng.randi_range(0, victory_quips.size() - 1)]
	quip_lbl.position = Vector2(140.0, 250.0)
	quip_lbl.custom_minimum_size = Vector2(1000.0, 0.0)
	quip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip_lbl.add_theme_font_size_override("font_size", 18)
	quip_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.65))
	cl.add_child(quip_lbl)

	# Run stats
	var stats_lbl := Label.new()
	stats_lbl.text = "Floor %d  ·  %d enemies slain  ·  XP earned: +%d  ·  Level %d" % [
		GameState.floor_num, _enemies_killed, xp_earned, GameState.hero_level
	]
	stats_lbl.position = Vector2(140.0, 310.0)
	stats_lbl.custom_minimum_size = Vector2(1000.0, 0.0)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 15)
	stats_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
	cl.add_child(stats_lbl)

	# HP status line
	var hp_lbl := Label.new()
	hp_lbl.text = "HP: %d / %d" % [_hero.hp, _hero.max_hp]
	hp_lbl.position = Vector2(140.0, 345.0)
	hp_lbl.custom_minimum_size = Vector2(1000.0, 0.0)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 14)
	var hp_ratio: float = float(_hero.hp) / float(max(1, _hero.max_hp))
	hp_lbl.add_theme_color_override("font_color",
		Color(1.0 - hp_ratio * 0.6, 0.3 + hp_ratio * 0.6, 0.2))
	cl.add_child(hp_lbl)

	# "DESCEND DEEPER" button
	var btn := Button.new()
	btn.text = "DESCEND DEEPER  ▼"
	btn.position = Vector2(465.0, 420.0)
	btn.custom_minimum_size = Vector2(350.0, 60.0)
	btn.add_theme_font_size_override("font_size", 22)
	cl.add_child(btn)

	# Use lambda-in-array pattern to safely pass xp_earned into the callback
	var xp_ref: Array[int] = [xp_earned]
	btn.pressed.connect(func() -> void:
		battle_complete.emit(true, xp_ref[0])
	)

func _on_system_line(text: String, _dur: float) -> void:
	_show_system_banner(text, 2.8)

## ─── Death Overlay ────────────────────────────────────────────────────────────

func _show_death_overlay() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)

	# Dark fade background
	var bg := ColorRect.new()
	bg.size = Vector2(1280.0, 720.0)
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	cl.add_child(bg)
	var tw_bg: Tween = create_tween()
	tw_bg.tween_property(bg, "color", Color(0.0, 0.0, 0.0, 0.82), 1.0)

	await get_tree().create_timer(0.6).timeout

	# "YOU DIED" title
	var title := Label.new()
	title.text = "YOU DIED"
	title.position = Vector2(340.0, 180.0)
	title.custom_minimum_size = Vector2(600.0, 0.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color(0.85, 0.08, 0.08))
	title.modulate.a = 0.0
	cl.add_child(title)
	var tw_title: Tween = create_tween()
	tw_title.tween_property(title, "modulate:a", 1.0, 0.6)

	# System quip
	var quip_lbl := Label.new()
	quip_lbl.position = Vector2(190.0, 300.0)
	quip_lbl.custom_minimum_size = Vector2(900.0, 0.0)
	quip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quip_lbl.add_theme_font_size_override("font_size", 18)
	quip_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.65))
	var death_quips: Array[String] = [
		"You have died. This is embarrassing for both of us.",
		"Dead. The dungeon notes your failure with mild satisfaction.",
		"Game over, Hero. The System was rooting for you. Sort of.",
		"And so ends another run. Badly. As expected.",
	]
	quip_lbl.text = death_quips[_battle_rng.randi_range(0, death_quips.size() - 1)]
	cl.add_child(quip_lbl)

	# Run summary
	var stats_lbl := Label.new()
	stats_lbl.position = Vector2(190.0, 350.0)
	stats_lbl.custom_minimum_size = Vector2(900.0, 0.0)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 15)
	stats_lbl.add_theme_color_override("font_color", Color(0.58, 0.58, 0.58))
	stats_lbl.text = "Floor %d  ·  %d enemies slain  ·  Level %d" % [
		GameState.floor_num, _enemies_killed, GameState.hero_level
	]
	cl.add_child(stats_lbl)

	# TRY AGAIN button
	var btn := Button.new()
	btn.text = "TRY AGAIN"
	btn.position = Vector2(515.0, 430.0)
	btn.custom_minimum_size = Vector2(250.0, 55.0)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_on_death_restart)
	cl.add_child(btn)

func _on_death_restart() -> void:
	battle_complete.emit(false, 0)

## ─── Visual Helpers ───────────────────────────────────────────────────────────

func _sync_entity_positions() -> void:
	## Reconcile visual positions with combatant.position (enemies may have moved)
	for c: Combatant in _all_combatants:
		if not c.is_alive():
			continue
		var node: Node2D = _entity_nodes.get(c.id)
		if node == null:
			continue
		var target_pos: Vector2 = HexGrid.hex_to_pixel(c.position, HEX_SIZE)
		if node.position.distance_to(target_pos) > 1.0:
			var tw: Tween = create_tween()
			tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(node, "position", target_pos, 0.25)

func _update_all_hp_bars() -> void:
	for c: Combatant in _all_combatants:
		_update_hp_bar(c)
		_update_status_label(c)

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

func _update_status_label(c: Combatant) -> void:
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var status_lbl: Label = node.get_node_or_null("StatusLabel")
	if status_lbl == null:
		return
	var icons: Array[String] = []
	for eff: Dictionary in c.status_effects:
		match eff.get("id", ""):
			"burning":  icons.append("🔥")
			"frozen":   icons.append("❄")
			"poisoned": icons.append("☠")
			"fortified":icons.append("🛡")
			"vanished": icons.append("👁")
	status_lbl.text = " ".join(icons)

func _update_hero_hp_label() -> void:
	_hero_hp_label.text = "HP: %d / %d" % [_hero.hp, _hero.max_hp]
	var ratio: float = float(_hero.hp) / float(max(1, _hero.max_hp))
	_hero_hp_label.add_theme_color_override("font_color",
		Color(1.0 - ratio * 0.7, 0.2 + ratio * 0.7, 0.1))

func _show_damage_number(c: Combatant, damage: int, color: Color = Color(1.0, 0.25, 0.1)) -> void:
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var lbl := Label.new()
	lbl.text = "-%d" % damage
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = node.position + Vector2(-14.0, -26.0)
	_entity_layer.add_child(lbl)
	var tw: Tween = create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -52.0), 0.9)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9)
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

## ─── Class Silhouette Helpers (Run 3) ────────────────────────────────────────

func _make_shield_pts(size: float) -> PackedVector2Array:
	## Kite-shield silhouette for Brawler
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, -size))              # top center
	pts.append(Vector2(size * 0.85, -size * 0.45)) # upper right
	pts.append(Vector2(size * 0.72, size * 0.30))  # lower right
	pts.append(Vector2(0.0, size))               # bottom point
	pts.append(Vector2(-size * 0.72, size * 0.30)) # lower left
	pts.append(Vector2(-size * 0.85, -size * 0.45))# upper left
	return pts

func _make_dagger_pts(size: float) -> PackedVector2Array:
	## Dagger silhouette for Rogue: blade tip + crossguard + handle
	var pts := PackedVector2Array()
	# Blade tip (top)
	pts.append(Vector2(0.0, -size))
	pts.append(Vector2(size * 0.14, -size * 0.2))
	# Crossguard right
	pts.append(Vector2(size * 0.45, -size * 0.05))
	pts.append(Vector2(size * 0.45, size * 0.12))
	# Handle right
	pts.append(Vector2(size * 0.12, size * 0.20))
	pts.append(Vector2(size * 0.12, size * 0.92))
	# Pommel
	pts.append(Vector2(0.0, size))
	pts.append(Vector2(-size * 0.12, size * 0.92))
	# Handle left
	pts.append(Vector2(-size * 0.12, size * 0.20))
	# Crossguard left
	pts.append(Vector2(-size * 0.45, size * 0.12))
	pts.append(Vector2(-size * 0.45, -size * 0.05))
	pts.append(Vector2(-size * 0.14, -size * 0.2))
	return pts

func _make_star_pts(size: float, num_points: int) -> PackedVector2Array:
	## N-pointed star for Arcanist
	var pts := PackedVector2Array()
	var inner_r: float = size * 0.40
	for i: int in range(num_points * 2):
		var angle: float = deg_to_rad(float(i) * 180.0 / float(num_points) - 90.0)
		var r: float = size if i % 2 == 0 else inner_r
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	return pts
