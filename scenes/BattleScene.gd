extends Node2D
## Visual driver for one battle encounter on the hex grid.
## Run 3: ability charges/cooldowns in HUD, lava heat damage, floor scaling, enemy collision fix.

signal battle_complete(hero_won: bool, xp_earned: int, enemies_killed: int)

const HEX_SIZE: float = 38.0
const HERO_COLOR     := Color(0.25, 0.55, 1.0)
const ENEMY_COLOR    := Color(0.9, 0.2, 0.15)
const SELECTED_CLR   := Color(1.0, 0.9, 0.2)
const DEAD_MODULATE  := Color(0.35, 0.35, 0.35, 0.4)
const MOVE_CLR       := Color(0.15, 0.85, 0.35, 0.45)
const ATTACK_CLR     := Color(0.9, 0.15, 0.05, 0.55)
const AOE_CLR        := Color(0.9, 0.45, 0.05, 0.35)
const SELF_CLR       := Color(0.6, 0.3, 0.9, 0.5)
const FROST_CLR      := Color(0.25, 0.65, 1.0, 0.5)
const LAVA_HEAT_CLR  := Color(1.0, 0.45, 0.0, 0.9)

# Floor-theme colors — initialized in _setup_floor_theme() before drawing begins
var LAVA_COLOR  := Color(0.88, 0.36, 0.04)
var LAVA_GLOW   := Color(1.0, 0.60, 0.08, 0.35)
var LAVA_BORDER := Color(0.95, 0.42, 0.04)
var FLOOR_COLOR := Color(0.18, 0.15, 0.22)
var FLOOR_ALT   := Color(0.14, 0.11, 0.17)
var STONE_EDGE  := Color(0.38, 0.30, 0.45)
var ATMO_COLOR  := Color(0.82, 0.76, 0.96)

var _engine: BattleEngine
var _map: DungeonMap
var _hero: Combatant
var _enemies: Array[Combatant] = []
var _all_combatants: Array[Combatant] = []

# Visual nodes
var _hex_polys: Dictionary = {}    # Vector2i -> Polygon2D
var _entity_nodes: Dictionary = {} # combatant.id -> Node2D
var _ability_btns: Dictionary = {} # ability_id -> Button
var _highlight_hexes: Array[Vector2i] = []

# Ability charge tracking: ability_id -> Ability object
var _hero_ability_objs: Dictionary = {}

# VFX: preloaded effect textures keyed by ability_id
var _effect_textures: Dictionary = {}

var _selected_ability: String = "basic_attack"
var _player_turn: bool = false
var _battle_rng: RandomNumberGenerator
var _enemies_killed: int = 0
var _first_kill_done: bool = false   # for first_kill quip
var _boss: Combatant = null
var _boss_hp_fill: ColorRect = null
var _boss_glow_tween: Tween = null
var _donut: Combatant = null
var _donut_hp_label: Label = null
var _hero_dead: bool = false

@onready var _hex_layer: Node2D = $HexLayer
@onready var _entity_layer: Node2D = $EntityLayer
@onready var _floor_label: Label = $UILayer/FloorLabel
@onready var _system_banner: Panel = $UILayer/SystemBanner
@onready var _system_text: Label = $UILayer/SystemBanner/SystemText
@onready var _ability_bar: HBoxContainer = $UILayer/HUD/AbilityBar
@onready var _turn_indicator: Label = $UILayer/TurnIndicator
@onready var _hero_hp_label: Label = $UILayer/HeroHPLabel

func _ready() -> void:
	_floor_label.text = "Floor %d / %d" % [GameState.floor_num, GameState.TOTAL_FLOORS]
	_setup_floor_theme()
	SystemVoice.line_spoken.connect(_on_system_line)
	_build_encounter()
	_load_effect_textures()
	_draw_cave_background()
	_draw_hex_grid()
	_draw_stalagmites()
	_draw_entities()
	_build_ability_bar()
	_build_boss_hp_bar()
	_build_donut_hp_label()
	_build_inferno_map()
	_update_hero_hp_label()
	SystemVoice.speak("floor_enter", [GameState.floor_num])
	await get_tree().create_timer(0.4).timeout
	_next_turn()

## ─── Floor Theme ──────────────────────────────────────────────────────────────

func _setup_floor_theme() -> void:
	## Set tile and atmosphere colors based on floor tier.
	## Tier 0 = Floors 1-6 (Stone), Tier 1 = 7-12 (Obsidian), Tier 2 = 13-18 (Abyss/Void).
	var tier: int = (GameState.floor_num - 1) / 6
	match tier:
		1:  # Obsidian halls — cold blue-black stone, arcane blue-fire
			FLOOR_COLOR  = Color(0.07, 0.09, 0.18)
			FLOOR_ALT    = Color(0.04, 0.06, 0.13)
			STONE_EDGE   = Color(0.20, 0.28, 0.55)
			LAVA_COLOR   = Color(0.06, 0.28, 0.82)
			LAVA_GLOW    = Color(0.15, 0.50, 1.0, 0.30)
			LAVA_BORDER  = Color(0.18, 0.52, 1.0)
			ATMO_COLOR   = Color(0.68, 0.76, 1.0)
		2:  # The Abyss — near-black void with crackling void-purple energy
			FLOOR_COLOR  = Color(0.04, 0.02, 0.08)
			FLOOR_ALT    = Color(0.02, 0.01, 0.05)
			STONE_EDGE   = Color(0.40, 0.10, 0.52)
			LAVA_COLOR   = Color(0.52, 0.00, 0.72)
			LAVA_GLOW    = Color(0.70, 0.05, 0.90, 0.28)
			LAVA_BORDER  = Color(0.80, 0.10, 0.95)
			ATMO_COLOR   = Color(0.70, 0.62, 0.96)
		_:  # Default stone (floors 1-6)
			FLOOR_COLOR  = Color(0.18, 0.15, 0.22)
			FLOOR_ALT    = Color(0.14, 0.11, 0.17)
			STONE_EDGE   = Color(0.38, 0.30, 0.45)
			LAVA_COLOR   = Color(0.88, 0.36, 0.04)
			LAVA_GLOW    = Color(1.0, 0.60, 0.08, 0.35)
			LAVA_BORDER  = Color(0.95, 0.42, 0.04)
			ATMO_COLOR   = Color(0.82, 0.76, 0.96)

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

	# Build Ability objects for charge/cooldown tracking
	_hero_ability_objs.clear()
	for ability_id: String in _hero.abilities:
		var abl_data: Dictionary = Abilities.get_ability(ability_id)
		var abl_obj := Ability.new(ability_id, abl_data.get("display_name", ability_id))
		abl_obj.max_charges = abl_data.get("max_charges", 1)
		abl_obj.cooldown_turns = abl_data.get("cooldown_turns", 0)
		abl_obj.cooldown_remaining = 0
		# current_charges: unlimited (-1) always stays ready; else fill to max
		if abl_obj.max_charges > 0:
			abl_obj.current_charges = abl_obj.max_charges
		else:
			abl_obj.current_charges = 1  # sentinel for unlimited
		_hero_ability_objs[ability_id] = abl_obj

	_enemies.clear()
	# Spawn boss at dedicated boss spawn point
	var boss: Combatant = EnemyDefs.make_boss(GameState.floor_num, _map.boss_spawn, _battle_rng)
	_enemies.append(boss)

	var pool: Array[Dictionary] = EnemyDefs.get_enemies_for_floor(GameState.floor_num)
	for i: int in range(_map.spawn_points.size()):
		# Skip the boss_spawn if a regular enemy would land on it
		if _map.spawn_points[i] == _map.boss_spawn:
			continue
		var def: Dictionary = pool[_battle_rng.randi_range(0, pool.size() - 1)]
		# Pass floor_num for scaling
		var e: Combatant = EnemyDefs.make_combatant(def, _map.spawn_points[i], _battle_rng, GameState.floor_num)
		_enemies.append(e)

	# Build Donut companion — she joins every run
	_donut = Combatant.new("donut", "Donut", Combatant.Faction.HERO, 50, 12)
	_donut.armor = 0
	_donut.attack_bonus = 3
	var donut_abilities: Array[String] = ["basic_attack"]
	_donut.abilities = donut_abilities
	_donut.sprite_key = "companion_donut"
	_donut.xp_reward = 0
	var donut_start: Vector2i = _map.hero_start
	for n: Vector2i in HexGrid.neighbors(_map.hero_start):
		if _map.is_passable(n):
			donut_start = n
			break
	_donut.position = donut_start

	_all_combatants.clear()
	_all_combatants.append(_hero)
	_all_combatants.append(_donut)
	for e: Combatant in _enemies:
		_all_combatants.append(e)
	_engine = BattleEngine.new(_battle_rng)
	_engine.battle_ended.connect(_on_battle_ended)
	_engine.action_taken.connect(_on_action_taken)
	_engine.combatant_died.connect(_on_combatant_died)
	_engine.status_ticked.connect(_on_status_ticked)
	_engine.hero_moved.connect(_on_hero_moved)
	_engine.boss_enraged.connect(_on_boss_enraged)
	_engine.setup(_all_combatants)

## ─── Effect VFX ───────────────────────────────────────────────────────────────

func _load_effect_textures() -> void:
	var fx_map: Dictionary = {
		"basic_attack":   "res://assets/effects/fx_impact.png",
		"power_strike":   "res://assets/effects/fx_power_strike.png",
		"backstab":       "res://assets/effects/fx_backstab.png",
		"fireball":       "res://assets/effects/fx_fireball.png",
		"frost_nova":     "res://assets/effects/fx_frost.png",
		"taunt":          "res://assets/effects/fx_taunt.png",
		"vanish":         "res://assets/effects/fx_vanish.png",
		"shield_bash":    "res://assets/effects/fx_impact.png",
		"shadow_step":    "res://assets/effects/fx_shadow_step.png",
		"lava_heat":      "res://assets/effects/fx_lava_heat.png",
		"enemy_claw":     "res://assets/effects/fx_impact.png",
		"enemy_bite":     "res://assets/effects/fx_backstab.png",
		"enemy_fireball": "res://assets/effects/fx_fireball.png",
		"bone_volley":    "res://assets/effects/fx_impact.png",
		"hellfire_aoe":   "res://assets/effects/fx_fireball.png",
	}
	for id: String in fx_map:
		var path: String = fx_map[id]
		if ResourceLoader.exists(path):
			_effect_textures[id] = load(path) as Texture2D

func _play_ability_effect(hex: Vector2i, ability_id: String) -> void:
	var tex: Texture2D = _effect_textures.get(ability_id, _effect_textures.get("basic_attack"))
	if tex == null:
		return
	var pixel_pos: Vector2 = HexGrid.hex_to_pixel(hex, HEX_SIZE)
	var fx := Sprite2D.new()
	fx.texture        = tex
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.position       = pixel_pos + Vector2(0.0, -20.0)
	fx.scale          = Vector2(0.5, 0.5)
	fx.z_index        = 20
	_entity_layer.add_child(fx)
	var tw: Tween = create_tween()
	tw.tween_property(fx, "scale", Vector2(1.6, 1.6), 0.42) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.42) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(fx.queue_free)

## ─── Idle Animation ───────────────────────────────────────────────────────────

func _start_idle_bob(sprite: Sprite2D, is_hero: bool) -> void:
	## Slow breathing bob: hero moves gently, enemies bounce more assertively.
	var base_y: float  = -24.0
	var amp:    float  = 2.0 if is_hero else 3.5
	var period: float  = 1.8 if is_hero else 1.2
	var tw: Tween = create_tween()
	tw.set_loops()
	tw.tween_property(sprite, "position:y", base_y - amp, period * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "position:y", base_y + amp * 0.4, period * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

## ─── Cave Atmosphere ──────────────────────────────────────────────────────────

func _draw_cave_background() -> void:
	# Atmosphere tint — color varies by floor tier
	var cm := CanvasModulate.new()
	cm.color = ATMO_COLOR
	add_child(cm)

	# Vignette — four dark gradient strips around the viewport edges
	var ui: CanvasLayer = $UILayer
	for edge_rect: Array in [
		[0, 0, 1280, 80],     # top
		[0, 640, 1280, 80],   # bottom
		[0, 0, 90, 720],      # left
		[1190, 0, 90, 720],   # right
	]:
		var cr := ColorRect.new()
		cr.position = Vector2(edge_rect[0], edge_rect[1])
		cr.size = Vector2(edge_rect[2], edge_rect[3])
		cr.color = Color(0.03, 0.01, 0.06, 0.72)
		cr.z_index = -10
		ui.add_child(cr)

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
		var is_lava: bool = tile_type == "lava"
		match tile_type:
			"lava":
				poly.color = LAVA_COLOR
			_:
				var alt: bool = (hex.x + hex.y) % 2 == 0
				poly.color = FLOOR_COLOR if alt else FLOOR_ALT
		_hex_layer.add_child(poly)
		_hex_polys[hex] = poly

		# Lava: add a soft glow polygon behind the tile
		if is_lava:
			var glow_poly := Polygon2D.new()
			glow_poly.polygon = _make_hex_pts(HEX_SIZE + 4.0)
			glow_poly.color = LAVA_GLOW
			glow_poly.position = world_pos
			glow_poly.z_index = -1
			_hex_layer.add_child(glow_poly)

		# Hex border — thicker for lava, stone-purple for floor
		var border := Line2D.new()
		var bpts: PackedVector2Array = _make_hex_pts(HEX_SIZE - 1.5)
		bpts.append(bpts[0])
		border.points = bpts
		border.width = 1.6 if is_lava else 1.0
		border.default_color = LAVA_BORDER if is_lava else STONE_EDGE
		poly.add_child(border)

		# Stone cracks on floor tiles
		if not is_lava:
			_add_stone_texture(poly, hex)

		# Lava shimmer glyph
		if is_lava:
			var lava_lbl := Label.new()
			lava_lbl.text = "~"
			lava_lbl.add_theme_font_size_override("font_size", 15)
			lava_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.1, 0.95))
			lava_lbl.position = Vector2(-6.0, -9.0)
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

func _add_stone_texture(poly: Polygon2D, hex: Vector2i) -> void:
	## Draw subtle procedural cracks on stone floor tiles — purely decorative.
	var rng := RandomNumberGenerator.new()
	rng.seed = hex.x * 1733 + hex.y * 9001 + GameState.run_seed
	var num_cracks: int = rng.randi_range(1, 3)
	for _i: int in range(num_cracks):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float  = rng.randf_range(2.0, HEX_SIZE * 0.45)
		var length: float = rng.randf_range(5.0, 14.0)
		var sx: float = cos(angle) * dist
		var sy: float = sin(angle) * dist
		var crack := Line2D.new()
		crack.add_point(Vector2(sx, sy))
		crack.add_point(Vector2(
			sx + cos(angle + rng.randf_range(-0.6, 0.6)) * length,
			sy + sin(angle + rng.randf_range(-0.6, 0.6)) * length
		))
		crack.width = 0.7
		crack.default_color = Color(0.05, 0.03, 0.08, rng.randf_range(0.35, 0.65))
		poly.add_child(crack)
	# Occasional small dark moss/shadow patch
	if rng.randf() < 0.30:
		var patch := Polygon2D.new()
		var px: float = rng.randf_range(-12.0, 12.0)
		var py: float = rng.randf_range(-12.0, 12.0)
		var pr: float = rng.randf_range(4.0, 8.0)
		var pts := PackedVector2Array()
		for j: int in range(6):
			var a: float = deg_to_rad(60.0 * float(j))
			pts.append(Vector2(px + cos(a) * pr, py + sin(a) * pr))
		patch.polygon = pts
		patch.color = Color(0.03, 0.02, 0.06, rng.randf_range(0.15, 0.30))
		poly.add_child(patch)

func _start_lava_pulse(poly: Polygon2D) -> void:
	## Pulse lava tiles between bright and dim — colors follow floor theme
	var bright: Color = LAVA_COLOR.lightened(0.25)
	var dim:    Color = LAVA_COLOR.darkened(0.38)
	var tw: Tween = create_tween()
	tw.set_loops()
	var delay: float = _battle_rng.randf_range(0.0, 1.5)
	tw.tween_interval(delay)
	tw.tween_property(poly, "color", bright, 0.7)
	tw.tween_property(poly, "color", dim, 0.9)

func _draw_entities() -> void:
	for c: Combatant in _all_combatants:
		_spawn_entity_node(c)

func _spawn_entity_node(c: Combatant) -> void:
	var root := Node2D.new()
	root.position = HexGrid.hex_to_pixel(c.position, HEX_SIZE)

	var sprite_path: String = _get_sprite_path(c)
	var sprite_tex: Texture2D = null
	if ResourceLoader.exists(sprite_path):
		sprite_tex = load(sprite_path) as Texture2D
	var is_boss: bool = c.sprite_key.begins_with("boss")

	if sprite_tex != null:
		# Ground shadow (drawn first — appears visually behind all other layers)
		var shadow := Polygon2D.new()
		shadow.polygon = _make_hex_pts(HEX_SIZE * (0.54 if is_boss else 0.44))
		shadow.color = Color(0.0, 0.0, 0.0, 0.50)
		shadow.position = Vector2(0.0, HEX_SIZE * 0.28)
		root.add_child(shadow)

		# Colored glow ring — class color for hero, gold for Donut, blood-red for enemies, void-purple for bosses
		var glow_poly := Polygon2D.new()
		glow_poly.polygon = _make_hex_pts(HEX_SIZE * (0.84 if is_boss else 0.72))
		glow_poly.position = Vector2(0.0, -12.0)
		if is_boss:
			glow_poly.color = Color(0.55, 0.0, 0.78, 0.42)
		elif c.sprite_key == "companion_donut":
			glow_poly.color = Color(0.95, 0.72, 0.10, 0.42)
		elif c.faction == Combatant.Faction.HERO:
			var gc := _hero_class_color()
			gc.a = 0.38
			glow_poly.color = gc
		else:
			glow_poly.color = Color(0.78, 0.06, 0.04, 0.28)
		root.add_child(glow_poly)

		# Boss glow pulses like a heartbeat
		if is_boss:
			glow_poly.name = "GlowRing"
			_boss_glow_tween = create_tween()
			_boss_glow_tween.set_loops()
			_boss_glow_tween.tween_property(glow_poly, "color",
				Color(0.55, 0.0, 0.78, 0.68), 1.1) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			_boss_glow_tween.tween_property(glow_poly, "color",
				Color(0.55, 0.0, 0.78, 0.28), 1.4) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		# Dark disc behind sprite body for readability against any hex colour
		var disc := Polygon2D.new()
		disc.polygon = _make_hex_pts(HEX_SIZE * (0.70 if is_boss else 0.60))
		disc.color = Color(0.0, 0.0, 0.0, 0.52)
		disc.position = Vector2(0.0, -10.0)
		root.add_child(disc)

		var sprite := Sprite2D.new()
		sprite.texture = sprite_tex
		# 30% smaller than original sizes for better battlefield readability
		var sprite_scale: float = 0.67 if is_boss else 0.55
		sprite.scale = Vector2(sprite_scale, sprite_scale)
		sprite.position = Vector2(0.0, -24.0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(sprite)

		# Idle breathing bob (enemies bounce a bit faster than hero)
		var is_hero: bool = c.faction == Combatant.Faction.HERO
		_start_idle_bob(sprite, is_hero)
	else:
		# Fallback: coloured hex + glyph
		var body := Polygon2D.new()
		var body_size: float = HEX_SIZE * (0.55 if is_boss else 0.42)
		body.polygon = _make_hex_pts(body_size)
		if is_boss:
			body.color = Color(0.5, 0.0, 0.7)
		elif c.faction == Combatant.Faction.HERO:
			body.color = _hero_class_color()
		else:
			body.color = ENEMY_COLOR
		root.add_child(body)
		var lbl := Label.new()
		lbl.text = _entity_glyph(c)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 15 if not is_boss else 20)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0) if is_boss else Color.WHITE)
		lbl.size = Vector2(24.0, 24.0)
		lbl.position = Vector2(-12.0, -12.0)
		root.add_child(lbl)

	# Enemy name tag (small, above HP bar)
	if c.faction == Combatant.Faction.ENEMY:
		var name_tag := Label.new()
		name_tag.text = c.display_name
		name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_tag.add_theme_font_size_override("font_size", 8)
		var tag_color: Color = Color(1.0, 0.62, 0.95) if is_boss else Color(0.78, 0.58, 0.58)
		name_tag.add_theme_color_override("font_color", tag_color)
		name_tag.custom_minimum_size = Vector2(60.0, 0.0)
		name_tag.position = Vector2(-30.0, HEX_SIZE * 0.48)
		root.add_child(name_tag)

	# HP bar — wide border + background + coloured fill
	var HP_W: float = 46.0
	var HP_H: float = 8.0
	var hp_y: float = HEX_SIZE * 0.58

	var hp_border := ColorRect.new()
	hp_border.size = Vector2(HP_W + 2.0, HP_H + 2.0)
	hp_border.position = Vector2(-(HP_W + 2.0) * 0.5, hp_y)
	hp_border.color = Color(0.05, 0.03, 0.07)
	root.add_child(hp_border)

	var hp_bg := ColorRect.new()
	hp_bg.size = Vector2(HP_W, HP_H)
	hp_bg.position = Vector2(-HP_W * 0.5, hp_y + 1.0)
	hp_bg.color = Color(0.28, 0.04, 0.04)
	root.add_child(hp_bg)

	var hp_bar := ColorRect.new()
	hp_bar.name = "HPBar"
	hp_bar.size = Vector2(HP_W, HP_H)
	hp_bar.position = Vector2(-HP_W * 0.5, hp_y + 1.0)
	hp_bar.color = Color(0.18, 0.88, 0.22)
	root.add_child(hp_bar)

	# Status icons
	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
	status_lbl.position = Vector2(-19.0, -HEX_SIZE * 0.62)
	root.add_child(status_lbl)

	_entity_layer.add_child(root)
	_entity_nodes[c.id] = root

func _hero_class_color() -> Color:
	var cls_data: Dictionary = Classes.get_class_data(GameState.hero_class)
	return cls_data.get("icon_color", HERO_COLOR)

func _get_sprite_path(c: Combatant) -> String:
	if c.sprite_key == "companion_donut":
		return "res://assets/sprites/companion_donut.png"
	var base: String = "hero_%s" % GameState.hero_class if c.faction == Combatant.Faction.HERO \
		else "enemy_%s" % c.sprite_key
	return "res://assets/sprites/%s.png" % base

func _entity_glyph(c: Combatant) -> String:
	if c.sprite_key == "companion_donut":
		return "🐱"
	if c.faction == Combatant.Faction.HERO:
		match GameState.hero_class:
			"brawler": return "⚔"
			"rogue":   return "🗡"
			"arcanist":return "✦"
		return "C"
	# Enemy glyphs by sprite_key
	match c.sprite_key:
		"imp":     return "👿"
		"goblin":  return "G"
		"skeleton":return "💀"
		"demon":   return "D"
		"golem":   return "⬡"
		"boss_dungeon_lord":  return "♛"
		"boss_warden":        return "⛓"
		"boss_abyss_keeper":  return "☠"
	if c.sprite_key.begins_with("boss"): return "♛"
	return c.display_name.left(1).to_upper()

## ─── Boss HP Bar ──────────────────────────────────────────────────────────────

func _build_boss_hp_bar() -> void:
	## Find the boss combatant and build a top-center HP bar for it.
	for e: Combatant in _enemies:
		if e.sprite_key.begins_with("boss"):
			_boss = e
			break
	if _boss == null:
		return
	# Announce boss encounter after a brief delay so floor_enter lands first
	get_tree().create_timer(1.8).timeout.connect(func() -> void: SystemVoice.speak("boss_encounter"))

	var ui: CanvasLayer = $UILayer
	var bar_w: float = 400.0

	# Label
	var name_lbl := Label.new()
	name_lbl.text = "☠  %s  ☠" % _boss.display_name.to_upper()
	name_lbl.position = Vector2(640.0 - bar_w / 2.0, 68.0)
	name_lbl.custom_minimum_size = Vector2(bar_w, 0.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 1.0))
	ui.add_child(name_lbl)

	# Outer border
	var border := ColorRect.new()
	border.position = Vector2(640.0 - bar_w / 2.0 - 2.0, 86.0)
	border.size = Vector2(bar_w + 4.0, 18.0)
	border.color = Color(0.5, 0.0, 0.6)
	ui.add_child(border)

	# Background
	var bg := ColorRect.new()
	bg.position = Vector2(640.0 - bar_w / 2.0, 88.0)
	bg.size = Vector2(bar_w, 14.0)
	bg.color = Color(0.12, 0.0, 0.16)
	ui.add_child(bg)

	# Fill
	_boss_hp_fill = ColorRect.new()
	_boss_hp_fill.position = Vector2(640.0 - bar_w / 2.0, 88.0)
	_boss_hp_fill.size = Vector2(bar_w, 14.0)
	_boss_hp_fill.color = Color(0.72, 0.10, 0.82)
	ui.add_child(_boss_hp_fill)

## ─── Donut Companion ──────────────────────────────────────────────────────────

func _build_donut_hp_label() -> void:
	var lbl := Label.new()
	lbl.name = "DonutHPLabel"
	lbl.text = "🐱 Donut  50 / 50"
	lbl.position = Vector2(16.0, 86.0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.72, 0.10))
	$UILayer.add_child(lbl)
	_donut_hp_label = lbl

func _update_donut_hp_label() -> void:
	if _donut_hp_label == null or _donut == null:
		return
	if not _donut.is_alive():
		_donut_hp_label.text = "🐱 Donut  KO"
		_donut_hp_label.add_theme_color_override("font_color", Color(0.45, 0.35, 0.35))
	else:
		_donut_hp_label.text = "🐱 Donut  %d / %d" % [_donut.hp, _donut.max_hp]
		var ratio: float = float(_donut.hp) / float(max(1, _donut.max_hp))
		_donut_hp_label.add_theme_color_override("font_color",
			Color(1.0 - ratio * 0.5, 0.52 + ratio * 0.20, 0.05))

func _resolve_donut_turn() -> void:
	if not _donut.is_alive() or _engine.battle_over or _hero_dead:
		_engine.end_turn()
		await get_tree().create_timer(0.15).timeout
		_next_turn()
		return

	var nearest: Combatant = _get_nearest_enemy_to(_donut.position)
	if nearest != null:
		var dist: int = HexGrid.hex_distance(_donut.position, nearest.position)
		if dist <= 1:
			_play_ability_effect(nearest.position, "basic_attack")
			_engine.perform_attack(_donut, nearest, "basic_attack")
			_update_all_hp_bars()
			_update_donut_hp_label()
		else:
			_engine.move_toward(_donut, nearest.position, _map)
			_sync_entity_positions()

	await get_tree().create_timer(0.40).timeout
	if not _engine.battle_over and not _hero_dead:
		_engine.end_turn()
		_next_turn()

func _get_nearest_enemy_to(pos: Vector2i) -> Combatant:
	var nearest: Combatant = null
	var best_dist: int = 999
	for e: Combatant in _enemies:
		if e.is_alive():
			var d: int = HexGrid.hex_distance(pos, e.position)
			if d < best_dist:
				best_dist = d
				nearest = e
	return nearest

## ─── Inferno Map ──────────────────────────────────────────────────────────────

func _build_inferno_map() -> void:
	## Bottom-right panel: Dante's Inferno-style cross-section of 18 floors.
	## Funnel shape — widest at top (Floor 1), narrowing to the abyss.
	var ui: CanvasLayer = $UILayer
	var MAP_W: float = 152.0
	var PANEL_X: float = 1280.0 - MAP_W - 4.0
	var PANEL_Y: float = 630.0
	var PANEL_H: float = 88.0
	var TITLE_H: float = 11.0
	var FLOOR_H: float = (PANEL_H - TITLE_H) / 18.0

	# Dark background
	var bg := ColorRect.new()
	bg.position = Vector2(PANEL_X, PANEL_Y)
	bg.size = Vector2(MAP_W, PANEL_H)
	bg.color = Color(0.03, 0.01, 0.07, 0.96)
	bg.z_index = 5
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)

	# Title
	var title := Label.new()
	title.text = "DESCENT"
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", Color(0.48, 0.36, 0.08))
	title.position = Vector2(PANEL_X, PANEL_Y + 1.0)
	title.custom_minimum_size = Vector2(MAP_W, TITLE_H)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.z_index = 6
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(title)

	for i: int in range(18):
		var floor_n: int = i + 1
		var taper: float = 1.0 - float(i) / 17.0 * 0.44
		var fw: float = MAP_W * taper
		var fx: float = PANEL_X + (MAP_W - fw) * 0.5
		var fy: float = PANEL_Y + TITLE_H + float(i) * FLOOR_H

		var slice_col: Color
		if floor_n < GameState.floor_num:
			slice_col = Color(0.30, 0.21, 0.05, 0.90)
		elif floor_n == GameState.floor_num:
			slice_col = Color(0.90, 0.70, 0.10, 1.0)
		else:
			var fade: float = float(floor_n - GameState.floor_num) / 18.0
			slice_col = Color(0.09, 0.04, 0.14 + fade * 0.08, 0.85)

		var slice := ColorRect.new()
		slice.position = Vector2(fx, fy)
		slice.size = Vector2(fw, max(1.0, FLOOR_H - 0.8))
		slice.color = slice_col
		slice.z_index = 6
		slice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(slice)

		# Thin separator line
		var sep := ColorRect.new()
		sep.position = Vector2(PANEL_X, fy + FLOOR_H - 0.6)
		sep.size = Vector2(MAP_W, 0.8)
		sep.color = Color(0.0, 0.0, 0.0, 0.45)
		sep.z_index = 7
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(sep)

		# Label on current floor only
		if floor_n == GameState.floor_num:
			var fn_lbl := Label.new()
			fn_lbl.text = "▶ %d" % floor_n
			fn_lbl.add_theme_font_size_override("font_size", 7)
			fn_lbl.add_theme_color_override("font_color", Color(0.05, 0.03, 0.0, 1.0))
			fn_lbl.position = Vector2(fx, fy)
			fn_lbl.custom_minimum_size = Vector2(fw, FLOOR_H)
			fn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fn_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fn_lbl.z_index = 8
			fn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui.add_child(fn_lbl)

func _update_boss_hp_bar() -> void:
	if _boss == null or _boss_hp_fill == null:
		return
	var ratio: float = float(_boss.hp) / float(max(1, _boss.max_hp))
	_boss_hp_fill.size.x = 400.0 * clampf(ratio, 0.0, 1.0)
	if _boss.is_enraged:
		# Enraged phase: crimson-orange gradient
		_boss_hp_fill.color = Color(1.0, 0.25 + ratio * 0.15, 0.04)
	else:
		_boss_hp_fill.color = Color(0.72 - ratio * 0.22, 0.10 + ratio * 0.08, 0.82 - ratio * 0.42)

## ─── Ability Bar ──────────────────────────────────────────────────────────────

func _build_ability_bar() -> void:
	for child: Node in _ability_bar.get_children():
		child.queue_free()
	_ability_btns.clear()

	for ability_id: String in _hero.abilities:
		var abl: Dictionary = Abilities.get_ability(ability_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(118.0, 64.0)
		btn.pressed.connect(_on_ability_btn.bind(ability_id))
		_ability_bar.add_child(btn)
		_ability_btns[ability_id] = btn

	_refresh_ability_bar()

func _refresh_ability_bar() -> void:
	## Update button labels and disabled state to reflect current charges/cooldowns.
	for ability_id: String in _ability_btns:
		var btn: Button = _ability_btns[ability_id]
		var abl: Dictionary = Abilities.get_ability(ability_id)
		var abl_obj: Ability = _hero_ability_objs.get(ability_id)

		# Icon row
		var atype: String = abl.get("target", "single_enemy")
		var type_icon: String = "⚔"
		if atype == "self":
			type_icon = "✦"
		elif atype == "all_enemies":
			type_icon = "💥"

		# Charge / cooldown display
		var charge_str: String = ""
		var on_cooldown: bool = false
		if abl_obj != null:
			if abl_obj.max_charges == -1:
				# Unlimited — always available
				charge_str = "∞"
			elif abl_obj.cooldown_remaining > 0:
				# On cooldown
				charge_str = "↻ %d" % abl_obj.cooldown_remaining
				on_cooldown = true
			else:
				# Show charge dots: filled vs empty
				var dots: String = ""
				for i: int in range(abl_obj.max_charges):
					dots += "●" if i < abl_obj.current_charges else "○"
				charge_str = dots

		btn.text = "%s  %s\n%s" % [type_icon, abl.get("display_name", ability_id), charge_str]
		btn.add_theme_font_size_override("font_size", 11)
		btn.disabled = on_cooldown

		# Color: selected = gold, depleted = dim, normal = white
		if on_cooldown:
			btn.modulate = Color(0.45, 0.45, 0.45)
		elif ability_id == _selected_ability:
			btn.modulate = SELECTED_CLR
		else:
			btn.modulate = Color.WHITE

## ─── Turn Logic ───────────────────────────────────────────────────────────────

func _next_turn() -> void:
	if _engine.battle_over:
		return
	var active: Combatant = _engine.begin_turn()
	if active == null:
		return

	if _hero_dead:
		return

	if active.faction == Combatant.Faction.HERO:
		# Donut auto-resolves her turn
		if active.id == "donut":
			_turn_indicator.text = "Donut's Turn"
			_turn_indicator.add_theme_color_override("font_color", Color(0.95, 0.72, 0.10))
			await get_tree().create_timer(0.35).timeout
			if not _engine.battle_over and not _hero_dead:
				await _resolve_donut_turn()
			return

		# Tick ability cooldowns at the start of each hero turn
		for id: String in _hero_ability_objs:
			_hero_ability_objs[id].tick_cooldown()
		_refresh_ability_bar()

		# Near-death warning (≤25% HP) — occasional, not every single turn
		var hp_ratio: float = float(_hero.hp) / float(max(1, _hero.max_hp))
		if hp_ratio <= 0.25 and _battle_rng.randf() < 0.55:
			SystemVoice.speak("near_death")

		# Apply lava heat damage if adjacent to lava
		_apply_lava_heat(active)
		if _engine.battle_over:
			return

		_player_turn = true
		_turn_indicator.text = "YOUR TURN — Click to move or attack"
		_turn_indicator.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		_update_highlights()
		_update_hero_hp_label()
	else:
		# Apply lava heat to enemies too — makes lava tactically meaningful
		_apply_lava_heat(active)
		if _engine.battle_over:
			return

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
			# Surrounded check: fire quip if 3+ enemies are now adjacent to hero
			if not _engine.battle_over:
				var adj_enemies: int = _count_adjacent_enemies()
				if adj_enemies >= 3 and _battle_rng.randf() < 0.50:
					SystemVoice.speak("surrounded")
			await get_tree().create_timer(0.25).timeout
			_next_turn()

func _apply_lava_heat(c: Combatant) -> void:
	## Deal heat damage to a combatant for each adjacent lava tile.
	## One adjacent lava = 3 damage; two = 6; three+ = 10.
	if _engine.battle_over:
		return
	var lava_adj: int = 0
	for n: Vector2i in HexGrid.neighbors(c.position):
		if _map.get_tile_type(n) == "lava":
			lava_adj += 1
	if lava_adj == 0:
		return
	var heat_dmg: int = 3 + (lava_adj - 1) * 3
	var actual: int = _engine.apply_environment_damage(c, heat_dmg)
	_play_ability_effect(c.position, "lava_heat")
	_show_damage_number(c, actual, LAVA_HEAT_CLR)
	_update_hp_bar(c)
	if c.faction == Combatant.Faction.HERO:
		_update_hero_hp_label()
		_show_system_banner("Lava heat! -%d HP. The floor is trying to kill you. Literally." % actual, 2.0)

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
			SystemVoice.speak("out_of_range")
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
	SystemVoice.speak("move")
	await get_tree().create_timer(0.28).timeout
	_engine.end_turn()
	_next_turn()

func _find_teleport_hex_near(target: Combatant) -> Vector2i:
	## Find the closest empty passable hex adjacent to target (for Shadow Step).
	var best: Vector2i = _hero.position
	var best_dist: int = HexGrid.hex_distance(_hero.position, target.position)
	for n: Vector2i in HexGrid.neighbors(target.position):
		if not _map.is_passable(n):
			continue
		var occupied: bool = false
		for c: Combatant in _all_combatants:
			if c.is_alive() and c.position == n:
				occupied = true
				break
		if occupied:
			continue
		var d: int = HexGrid.hex_distance(_hero.position, n)
		if d < best_dist:
			best_dist = d
			best = n
	return best

func _do_hero_attack(target: Combatant) -> void:
	# Check cooldown/charges before attacking
	var abl_obj: Ability = _hero_ability_objs.get(_selected_ability)
	if abl_obj != null and not abl_obj.can_use():
		SystemVoice.speak("ability_cooldown")
		return

	var abl_data: Dictionary = Abilities.get_ability(_selected_ability)
	_player_turn = false
	_clear_highlights()

	# Shadow Step: teleport adjacent to target before striking
	if abl_data.get("teleport_to_target", false):
		var from_hex: Vector2i = _hero.position
		var dest: Vector2i = _find_teleport_hex_near(target)
		if dest != from_hex:
			_play_ability_effect(from_hex, "shadow_step")
			_hero.position = dest
			var hero_node: Node2D = _entity_nodes.get(_hero.id)
			if hero_node != null:
				var tw: Tween = create_tween()
				tw.set_ease(Tween.EASE_OUT)
				tw.set_trans(Tween.TRANS_BACK)
				tw.tween_property(hero_node, "position", HexGrid.hex_to_pixel(dest, HEX_SIZE), 0.18)
				await tw.finished
			_play_ability_effect(dest, "shadow_step")
			SystemVoice.speak("shadow_step")

	_play_ability_effect(target.position, _selected_ability)
	_engine.perform_attack(_hero, target, _selected_ability)
	match _selected_ability:
		"backstab":     SystemVoice.speak("ability_backstab")
		"shield_bash":  SystemVoice.speak("shield_bash")
		"shadow_step":  pass  # quip already played above during teleport
		_:              SystemVoice.speak("hit")

	# Apply on-hit status effects (poison_blade, etc.)
	if target.is_alive() and abl_data.get("applies_poisoned", false):
		var dur: int = abl_data.get("poison_duration", 4)
		target.apply_status(StatusEffect.poisoned(dur, 6))
		_update_status_label(target)
		SystemVoice.speak_direct(
			"Poison applied. %s has %d turns to regret being adjacent to you." \
			% [target.display_name, dur])

	# Consume the charge
	if abl_obj != null:
		abl_obj.use()
	_update_all_hp_bars()
	_update_hero_hp_label()
	_refresh_ability_bar()

	# Handle pushback (shield_bash and any ability with pushback > 0)
	var pushback: int = abl_data.get("pushback", 0)
	if pushback > 0 and target.is_alive() and not _engine.battle_over:
		var path: Array[Vector2i] = _engine.push_combatant(_hero, target, pushback, _map)
		if not path.is_empty():
			await _animate_push(target, path)
			# If they landed on lava — big environmental hit
			if not _engine.battle_over and _map.get_tile_type(path[-1]) == "lava":
				var lava_dmg: int = _engine.apply_environment_damage(target, 28)
				_show_damage_number(target, lava_dmg, LAVA_HEAT_CLR)
				if target.is_alive():
					_hit_flash(target)
				_update_all_hp_bars()
				SystemVoice.speak("pushed_into_lava")

	if not _engine.battle_over:
		_engine.end_turn()
		await get_tree().create_timer(0.2).timeout
		_next_turn()

func _animate_push(c: Combatant, path: Array[Vector2i]) -> void:
	## Slide entity node along each hex in path with a quick tween.
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	for hex: Vector2i in path:
		var tw: Tween = create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_QUART)
		tw.tween_property(node, "position", HexGrid.hex_to_pixel(hex, HEX_SIZE), 0.12)
		await tw.finished

func _do_hero_aoe_ability(center_hex: Vector2i) -> void:
	## Handles fireball (damage AOE) and frost_nova (freeze AOE)
	var abl_obj: Ability = _hero_ability_objs.get(_selected_ability)
	if abl_obj != null and not abl_obj.can_use():
		SystemVoice.speak("ability_cooldown")
		return

	_player_turn = false
	_clear_highlights()

	var aoe_radius: int = 2  # default AOE radius for fireball

	if _selected_ability == "frost_nova":
		aoe_radius = 1
		_play_ability_effect(_hero.position, "frost_nova")
		# Apply frozen status to all enemies in range 1 of hero (not center_hex)
		var frozen_count: int = 0
		for e: Combatant in _enemies:
			if e.is_alive() and HexGrid.is_in_range(_hero.position, e.position, 1):
				e.apply_status(StatusEffect.frozen(2))
				_play_ability_effect(e.position, "frost_nova")
				frozen_count += 1
		if frozen_count > 0:
			SystemVoice.speak_direct(SystemVoice.pick("ability_frost_hit") % frozen_count)
			_flash_hex_area(_hero.position, 1, FROST_CLR)
		else:
			SystemVoice.speak("ability_frost_miss")
	else:
		# Damage AOE (fireball etc.)
		_play_ability_effect(center_hex, _selected_ability)
		var disk_hexes: Array[Vector2i] = HexGrid.disk(center_hex, aoe_radius)
		var targets: Array[Combatant] = []
		for e: Combatant in _enemies:
			if e.is_alive() and e.position in disk_hexes:
				targets.append(e)
		if not targets.is_empty():
			_engine.perform_aoe_attack(_hero, targets, _selected_ability)
			SystemVoice.speak_direct(SystemVoice.pick("ability_fireball_hit") % targets.size())
		else:
			SystemVoice.speak("ability_fireball_miss")
		_flash_hex_area(center_hex, aoe_radius, AOE_CLR)

	# Consume the charge
	if abl_obj != null:
		abl_obj.use()

	_update_all_hp_bars()
	_update_hero_hp_label()
	_refresh_ability_bar()
	_engine.end_turn()
	await get_tree().create_timer(0.35).timeout
	_next_turn()

func _do_hero_self_ability() -> void:
	## Use self-target ability (taunt, vanish)
	var abl_obj: Ability = _hero_ability_objs.get(_selected_ability)
	if abl_obj != null and not abl_obj.can_use():
		SystemVoice.speak("ability_cooldown")
		return

	_player_turn = false
	_clear_highlights()

	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	match _selected_ability:
		"taunt":
			var armor_bonus: int = abl.get("fortified_armor", 5)
			var dur: int = abl.get("fortified_duration", 3)
			_hero.apply_status(StatusEffect.fortified(dur, armor_bonus))
			SystemVoice.speak("ability_taunt")
			_play_ability_effect(_hero.position, "taunt")
			_flash_hex_area(_hero.position, 0, SELF_CLR)
		"vanish":
			_hero.apply_status(StatusEffect.vanished(3.0))
			SystemVoice.speak("ability_vanish")
			_play_ability_effect(_hero.position, "vanish")
			# Visual: briefly dim hero node
			var hnode: Node2D = _entity_nodes.get(_hero.id)
			if hnode != null:
				var tw: Tween = create_tween()
				tw.tween_property(hnode, "modulate:a", 0.3, 0.3)
		_:
			SystemVoice.speak_direct("Nothing happens. The System is confused too.")

	# Consume the charge
	if abl_obj != null:
		abl_obj.use()

	_update_hero_hp_label()
	_refresh_ability_bar()
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

func _count_adjacent_enemies() -> int:
	## Count living enemies within hex distance 1 of the hero.
	var count: int = 0
	for e: Combatant in _enemies:
		if e.is_alive() and HexGrid.hex_distance(_hero.position, e.position) <= 1:
			count += 1
	return count

func _find_enemy_at(hex: Vector2i) -> Combatant:
	for e: Combatant in _enemies:
		if e.is_alive() and e.position == hex:
			return e
	return null

func _on_ability_btn(ability_id: String) -> void:
	# Check if on cooldown — if so, show message and don't select
	var abl_obj: Ability = _hero_ability_objs.get(ability_id)
	if abl_obj != null and not abl_obj.can_use():
		_show_system_banner("On cooldown: %d turns remain." % abl_obj.cooldown_remaining, 1.5)
		return

	# If already selected and player's turn → self-target abilities fire immediately
	var abl: Dictionary = Abilities.get_ability(ability_id)
	if _selected_ability == ability_id and _player_turn and abl.get("target", "single_enemy") == "self":
		_do_hero_self_ability()
		return
	_selected_ability = ability_id
	_refresh_ability_bar()
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

	# Don't highlight if ability is on cooldown
	var abl_obj: Ability = _hero_ability_objs.get(_selected_ability)
	if abl_obj != null and not abl_obj.can_use():
		return

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

func _on_action_taken(attacker: Combatant, target: Combatant, damage: int, ability_id: String) -> void:
	# Show hit effect at target for enemy attacks (hero attacks fire at the call site)
	if attacker.faction == Combatant.Faction.ENEMY:
		_play_ability_effect(target.position, ability_id)
	_show_damage_number(target, damage)
	_hit_flash(target)
	_update_hp_bar(target)
	_update_status_label(target)
	_update_boss_hp_bar()
	# Contextual player-hit commentary — fire ~40% of the time to avoid spam
	if target.faction == Combatant.Faction.HERO and attacker.faction == Combatant.Faction.ENEMY:
		if _battle_rng.randf() < 0.40:
			SystemVoice.speak("took_hit_comment")

func _on_combatant_died(c: Combatant) -> void:
	if c.faction == Combatant.Faction.ENEMY:
		_enemies_killed += 1
		if not _first_kill_done:
			_first_kill_done = true
			SystemVoice.speak("first_kill")
		elif c.sprite_key.begins_with("boss"):
			SystemVoice.speak("boss_killed")
		else:
			SystemVoice.speak("kill")
		# Delay grey-out so the hit-flash tween finishes first
		_grey_out_entity_delayed(c.id)
	elif c.id == "donut":
		# Donut knocked out — run continues
		SystemVoice.speak_direct("Donut is down. The princess is displeased. Extremely.")
		_grey_out_entity_delayed(c.id)
	else:
		# Player hero died — end the battle immediately regardless of Donut's state
		if _hero_dead:
			return
		_hero_dead = true
		var node: Node2D = _entity_nodes.get(c.id)
		if node != null:
			node.modulate = DEAD_MODULATE
		if not _engine.battle_over:
			_engine.battle_over = true
			_engine.hero_won = false
			_engine.battle_ended.emit(false, 0)
		await get_tree().create_timer(0.5).timeout
		_show_death_overlay()

func _grey_out_entity_delayed(entity_id: String) -> void:
	## Wait for hit-flash tween to finish, then apply death grey.
	await get_tree().create_timer(0.22).timeout
	var node: Node2D = _entity_nodes.get(entity_id)
	if node != null:
		node.modulate = DEAD_MODULATE

func _on_status_ticked(c: Combatant, damage: int) -> void:
	if damage > 0:
		_show_damage_number(c, damage, Color(1.0, 0.5, 0.0))
	_update_status_label(c)
	if c.faction == Combatant.Faction.HERO:
		_sync_hero_alpha()

func _on_hero_moved(_combatant: Combatant, _from_hex: Vector2i, to_hex: Vector2i) -> void:
	## Animate hero node to new position
	var node: Node2D = _entity_nodes.get(_hero.id)
	if node != null:
		var tw: Tween = create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_QUART)
		tw.tween_property(node, "position", HexGrid.hex_to_pixel(to_hex, HEX_SIZE), 0.22)

func _on_boss_enraged(boss: Combatant) -> void:
	## Boss phase 2 trigger: swap glow to crimson-orange, play hit flash, quip.
	var node: Node2D = _entity_nodes.get(boss.id)
	if node != null:
		var glow: Polygon2D = node.get_node_or_null("GlowRing") as Polygon2D
		if glow != null and _boss_glow_tween != null:
			_boss_glow_tween.kill()
		if glow != null:
			glow.color = Color(1.0, 0.12, 0.06, 0.75)
			_boss_glow_tween = create_tween()
			_boss_glow_tween.set_loops()
			_boss_glow_tween.tween_property(glow, "color",
				Color(1.0, 0.35, 0.04, 0.85), 0.6) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			_boss_glow_tween.tween_property(glow, "color",
				Color(0.9, 0.08, 0.04, 0.35), 0.8) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_hit_flash(boss)
	_update_boss_hp_bar()
	var quip: String = SystemVoice.pick("boss_enraged")
	_show_system_banner("⚠ ENRAGED: %s — %s" % [boss.display_name, quip], 4.0)

func _on_battle_ended(hero_won: bool, xp_earned: int) -> void:
	_player_turn = false
	_clear_highlights()
	if hero_won:
		_turn_indicator.text = "VICTORY!"
		_turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		SystemVoice.speak_direct("All threats eliminated. XP: %d." % xp_earned)
		# Brief pause then emit battle_complete (routes to VictoryScreen)
		await get_tree().create_timer(1.2).timeout
		battle_complete.emit(true, xp_earned, _enemies_killed)
	else:
		_turn_indicator.text = "DEFEATED"
		_turn_indicator.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
		SystemVoice.speak("death")
		# Death overlay shown by _on_combatant_died when hero dies

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
	battle_complete.emit(false, 0, _enemies_killed)

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
	_update_boss_hp_bar()
	_update_donut_hp_label()
	_sync_hero_alpha()

func _update_hp_bar(c: Combatant) -> void:
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var hp_bar: ColorRect = node.get_node_or_null("HPBar")
	if hp_bar == null:
		return
	var ratio: float = float(c.hp) / float(max(1, c.max_hp))
	hp_bar.size.x = 46.0 * clampf(ratio, 0.0, 1.0)
	# Green → yellow → red gradient as HP drops
	hp_bar.color = Color(1.0 - ratio * 0.78, 0.18 + ratio * 0.70, 0.08)

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

func _sync_hero_alpha() -> void:
	## Restore hero's alpha to 1.0 when vanish has expired.
	var hnode: Node2D = _entity_nodes.get(_hero.id)
	if hnode == null:
		return
	var is_vanished: bool = false
	for eff: Dictionary in _hero.status_effects:
		if eff.get("id", "") == "vanished":
			is_vanished = true
			break
	var target_alpha: float = 0.3 if is_vanished else 1.0
	if abs(hnode.modulate.a - target_alpha) > 0.05:
		var tw: Tween = create_tween()
		tw.tween_property(hnode, "modulate:a", target_alpha, 0.25)

func _hit_flash(c: Combatant) -> void:
	## White brightness flare + squish-scale pulse for punchy combat feel.
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(node, "modulate", Color(2.8, 2.8, 2.8, 1.0), 0.04)
	tw.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.14)
	# Squish-and-recover for tactile weight
	var tw2: Tween = create_tween()
	tw2.tween_property(node, "scale", Vector2(1.10, 0.88), 0.06)
	tw2.tween_property(node, "scale", Vector2(1.0,  1.0),  0.12)

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
