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

const DONUT_LINES: Dictionary = {
	"floor_enter": [
		"Mrrrow. Another floor. What *lovely* decor. 'Early Dungeon Nightmare.'",
		"I had a perfectly good nap scheduled. Just so you know.",
		"Oh, more monsters. Truly. What a treat. I'm thrilled.",
		"You really should stop volunteering for these things, Carl.",
		"The vibes here are *atrocious*. Noted for the record.",
		"It smells like bad decisions and sulfur down here.",
	],
	"enemy_killed": [
		"*yawns* One down. Wake me when it's over.",
		"Oh, they're dead. How dreadful for them.",
		"You got one! You're welcome — I cheered. Internally.",
		"Mrrph. That one was ugly. Not a compliment to your aim.",
		"Satisfying. Almost as satisfying as tuna. Almost.",
		"See? You CAN do it. Sometimes. Occasionally.",
		"Another one bites the dust. Technically the lava.",
		"*tail flick of approval*",
	],
	"boss_encounter": [
		"That one is VERY large. I have several concerns.",
		"I am going to need you to not die. Please. I'm serious.",
		"Oh no. Oh no no no. Carl. CARL. That's a BOSS.",
		"That's a boss. You've fought those before. You've also died before. Focus.",
		"I'm not panicking. You're panicking. I'm a LITTLE panicking.",
		"*presses paws to face* It's fine. It's totally fine. We're fine.",
	],
	"hero_hurt": [
		"OW. I felt that from here. That looked like it *hurt*.",
		"They hit you! How RUDE. Hit them back harder.",
		"Mrrow! Can we maybe dodge? As a concept?",
		"That's going to leave a mark. Dodge NEXT time!",
		"Can we establish a 'not-getting-hit' policy? Going forward?",
		"*winces* Less of that, please.",
	],
	"hero_near_death": [
		"Okay. OKAY. We are NOT dying today. CATEGORICALLY not dying.",
		"LOW HP! LOW HP, CARL. This is NOT the time for heroics!",
		"I'm watching through my paws. Please stop almost dying.",
		"If you die I will be SO annoyed. Personally. Permanently.",
		"Is there a healing option?? DO THE HEALING THING. *NOW.*",
		"*frantic tail lashing* CARL!!!",
	],
	"victory": [
		"You did it! *purrs* Don't tell anyone I was worried. I wasn't.",
		"Survived! As I fully expected. I was never worried at all.",
		"That's one more floor. I'll allow it.",
		"*stretches luxuriously* Good job. Now go deeper. Immediately.",
		"Excellent! You're alive! The System is annoyed! Perfect outcome.",
		"We're alive. I'm choosing to be calm about that.",
	],
	"hero_killed": [
		"...Carl? ...Carl!? I TOLD you about that lava!!",
		"Well. That happened. I am choosing to be unimpressed right now.",
		"MRROOWW. Okay. Deep breaths. We try again. WE TRY AGAIN.",
		"You died. I'm devastated. Mostly I'm just cold. It's very cold here.",
		"*sits next to Carl* ...rude.",
	],
	"ability_used": [
		"Show them who's boss!",
		"Ooh, that looked very dramatic and intentional.",
		"*twitches tail approvingly*",
		"Nice form. Very menacing. 10 out of 10.",
		"That's the spirit! More of that!",
		"Yeeees! Like THAT!",
		"Go go go go go!",
	],
	"allies_arrive": [
		"Oh! Look, Carl, you have FRIENDS. Don't ruin this for me.",
		"Survivors! Real ones! Try not to get them killed. Try, Carl.",
		"Reinforcements. I almost believe this floor likes you. Almost.",
		"Backup! Backup is here! *purrs* This is a NICE change.",
		"Other people! In MY dungeon! How exciting and also concerning.",
		"They came to help. Be NICE. Use your soft voice. I MEAN it.",
	],
	"ally_fell": [
		"Mrrooow... no... not them too. We owed them better.",
		"They went down for YOU, Carl. Remember that. Loudly.",
		"*tail droops* That one was a friend. The dungeon will pay.",
		"Down. One of the good ones. I'm noting this. Permanently.",
		"They fell. The System owes us an apology. It will not give one.",
	],
}

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
var _allies: Array[Combatant] = []
var _all_combatants: Array[Combatant] = []

# Ally HP labels in the top-left HUD column (one per ally) — populated by _build_ally_panel().
var _ally_hp_labels: Dictionary = {}  # combatant.id -> Label

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
var _donut_speech_lbl: Label = null
var _donut_speech_tween: Tween = null
var _donut_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _donut_last_line: Dictionary = {}
var _hero_dead: bool = false

# Run 19: achievement toast queue + per-attack tracking
var _achievement_layer: CanvasLayer = null
var _audience_widget: Label = null
var _audience_flash_tween: Tween = null
var _pending_toasts: Array[Dictionary] = []
var _toast_showing: bool = false
var _attack_pre_hp: int = 0   # snapshot of target HP before _do_hero_attack — for one-shot detection

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
	_build_donut_hologram()
	_build_inferno_map()
	_build_ally_panel()
	_build_achievement_overlay()
	_update_hero_hp_label()
	# Run 19: floor-milestone achievements fire as soon as the floor loads.
	if GameState.floor_num == 9:
		Achievements.unlock("the_descent")
	elif GameState.floor_num == 15:
		Achievements.unlock("deep_dweller")
	SystemVoice.speak("floor_enter", [GameState.floor_num])
	get_tree().create_timer(2.0).timeout.connect(func() -> void: _donut_say(_donut_pick("floor_enter")))
	# Allies arrival flavor — System banner + Donut quip if any joined this floor.
	if not _allies.is_empty():
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			SystemVoice.speak_direct("Survivors detected. %d allied combatant(s) joined the encounter." % _allies.size()))
		get_tree().create_timer(2.6).timeout.connect(func() -> void:
			_donut_say(_donut_pick("allies_arrive")))
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
	_donut_rng.seed = GameState.run_seed ^ 0xD0047

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
	# Bosses only appear on milestone floors (every 3rd). Regular floors are waves.
	var has_boss: bool = EnemyDefs.is_boss_floor(GameState.floor_num)
	if has_boss:
		var boss: Combatant = EnemyDefs.make_boss(GameState.floor_num, _map.boss_spawn, _battle_rng)
		_enemies.append(boss)

	var pool: Array[Dictionary] = EnemyDefs.get_enemies_for_floor(GameState.floor_num)
	for i: int in range(_map.spawn_points.size()):
		# On boss floors, keep the boss_spawn hex clear for the boss
		if has_boss and _map.spawn_points[i] == _map.boss_spawn:
			continue
		var def: Dictionary = pool[_battle_rng.randi_range(0, pool.size() - 1)]
		# Pass floor_num for scaling
		var e: Combatant = EnemyDefs.make_combatant(def, _map.spawn_points[i], _battle_rng, GameState.floor_num)
		_enemies.append(e)

	# Allies: floor-specific NPCs that join Carl for one battle.
	# On floor 3 (first boss), two survivors (Marcus + Lina) appear adjacent to hero start.
	_allies.clear()
	var ally_defs: Array[Dictionary] = Allies.get_allies_for_floor(GameState.floor_num)
	if not ally_defs.is_empty():
		var ally_spots: Array[Vector2i] = _find_ally_spawn_hexes(ally_defs.size())
		for i: int in range(min(ally_defs.size(), ally_spots.size())):
			var a: Combatant = Allies.make_ally(ally_defs[i], ally_spots[i], _battle_rng)
			_allies.append(a)

	_all_combatants.clear()
	_all_combatants.append(_hero)
	for a2: Combatant in _allies:
		_all_combatants.append(a2)
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

	# Run 19: subscribe to achievement + audience streams for the toast/HUD UI.
	if not Achievements.achievement_unlocked.is_connected(_on_achievement_unlocked):
		Achievements.achievement_unlocked.connect(_on_achievement_unlocked)
	if not GameState.audience_gained.is_connected(_on_audience_gained):
		GameState.audience_gained.connect(_on_audience_gained)

func _find_ally_spawn_hexes(count: int) -> Array[Vector2i]:
	## Pick up to `count` passable, unoccupied hexes near the hero start.
	## Prefers ring 1 (adjacent), then ring 2 if needed. Skips lava and enemies.
	var result: Array[Vector2i] = []
	var enemy_positions: Dictionary = {}
	for e: Combatant in _enemies:
		enemy_positions[e.position] = true
	for radius: int in [1, 2]:
		for h: Vector2i in HexGrid.ring(_map.hero_start, radius):
			if result.size() >= count:
				break
			if h == _map.hero_start:
				continue
			if not _map.is_passable(h):
				continue
			if enemy_positions.has(h):
				continue
			result.append(h)
		if result.size() >= count:
			break
	return result

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
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		elif c.sprite_key.begins_with("ally_"):
			glow_poly.color = _ally_glow_color(c)
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
		# 30% smaller than original sizes for better battlefield readability.
		# Donut (companion) renders much smaller — she's a cat, not a fighter.
		var sprite_scale: float = 0.55
		if is_boss:
			sprite_scale = 0.67
		elif c.sprite_key == "companion_donut":
			sprite_scale = 0.22
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
	# Ally name tag — short first-name only so it fits, gold to read "friendly"
	elif c.sprite_key.begins_with("ally_"):
		var first_name: String = c.display_name.split(" ")[0]
		var ally_tag := Label.new()
		ally_tag.text = first_name
		ally_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ally_tag.add_theme_font_size_override("font_size", 9)
		ally_tag.add_theme_color_override("font_color", Color(0.96, 0.82, 0.28))
		ally_tag.custom_minimum_size = Vector2(60.0, 0.0)
		ally_tag.position = Vector2(-30.0, HEX_SIZE * 0.48)
		root.add_child(ally_tag)

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

func _ally_glow_color(c: Combatant) -> Color:
	## Look up the ally's glow color from Allies.ALLIES_BY_FLOOR by sprite_key.
	for _floor: int in Allies.ALLIES_BY_FLOOR:
		var pool: Array = Allies.ALLIES_BY_FLOOR[_floor]
		for def: Dictionary in pool:
			if def.get("sprite_key", "") == c.sprite_key:
				return def.get("glow_color", Color(0.85, 0.85, 0.4, 0.42))
	return Color(0.85, 0.85, 0.4, 0.42)

func _get_sprite_path(c: Combatant) -> String:
	if c.sprite_key == "companion_donut":
		return "res://assets/sprites/companion_donut.png"
	if c.sprite_key.begins_with("ally_"):
		return "res://assets/sprites/%s.png" % c.sprite_key
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
	get_tree().create_timer(3.2).timeout.connect(func() -> void: _donut_say(_donut_pick("boss_encounter")))

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

## ─── Donut Hologram ───────────────────────────────────────────────────────────

func _build_donut_hologram() -> void:
	var ui: CanvasLayer = $UILayer
	var PX: float = 8.0
	var PY: float = 476.0
	var PW: float = 162.0
	var PH: float = 148.0

	# Outer glow border (teal)
	var outer := ColorRect.new()
	outer.position = Vector2(PX - 2.0, PY - 2.0)
	outer.size = Vector2(PW + 4.0, PH + 4.0)
	outer.color = Color(0.10, 0.88, 0.78, 0.75)
	outer.z_index = 10
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(outer)

	# Dark panel background
	var bg := ColorRect.new()
	bg.position = Vector2(PX, PY)
	bg.size = Vector2(PW, PH)
	bg.color = Color(0.02, 0.07, 0.11, 0.92)
	bg.z_index = 11
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)

	# Header strip
	var header_bg := ColorRect.new()
	header_bg.position = Vector2(PX, PY)
	header_bg.size = Vector2(PW, 17.0)
	header_bg.color = Color(0.04, 0.18, 0.22, 1.0)
	header_bg.z_index = 12
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(header_bg)

	var header_lbl := Label.new()
	header_lbl.text = "📡  ADVISOR: DONUT"
	header_lbl.position = Vector2(PX, PY + 1.0)
	header_lbl.custom_minimum_size = Vector2(PW, 15.0)
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_font_size_override("font_size", 9)
	header_lbl.add_theme_color_override("font_color", Color(0.28, 1.0, 0.85))
	header_lbl.z_index = 13
	header_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(header_lbl)

	# Donut sprite with hologram tint
	var sprite_path := "res://assets/sprites/companion_donut.png"
	if ResourceLoader.exists(sprite_path):
		var tex := load(sprite_path) as Texture2D
		var sprite_rect := TextureRect.new()
		sprite_rect.texture = tex
		sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite_rect.position = Vector2(PX + PW * 0.5 - 38.0, PY + 20.0)
		sprite_rect.size = Vector2(76.0, 76.0)
		sprite_rect.modulate = Color(0.45, 1.0, 0.92, 0.90)
		sprite_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite_rect.z_index = 13
		sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(sprite_rect)

	# Scanlines overlay
	var scan_count: int = int(PH / 3)
	for i: int in range(scan_count):
		var scan := ColorRect.new()
		scan.position = Vector2(PX, PY + float(i) * 3.0)
		scan.size = Vector2(PW, 1.0)
		scan.color = Color(0.0, 0.0, 0.0, 0.22)
		scan.z_index = 14
		scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(scan)

	# Footer text
	var footer := Label.new()
	footer.text = "── holographic ──"
	footer.position = Vector2(PX, PY + PH - 15.0)
	footer.custom_minimum_size = Vector2(PW, 13.0)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 8)
	footer.add_theme_color_override("font_color", Color(0.18, 0.58, 0.52, 0.55))
	footer.z_index = 13
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(footer)

	# Speech bubble background (above hologram, hidden until Donut speaks)
	var bubble_bg := ColorRect.new()
	bubble_bg.name = "DonutBubbleBg"
	bubble_bg.position = Vector2(PX - 1.0, PY - 131.0)
	bubble_bg.size = Vector2(PW + 2.0, 126.0)
	bubble_bg.color = Color(0.03, 0.12, 0.16, 0.88)
	bubble_bg.z_index = 14
	bubble_bg.modulate.a = 0.0
	bubble_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bubble_bg)

	var bubble_border := ColorRect.new()
	bubble_border.name = "DonutBubbleBorder"
	bubble_border.position = Vector2(PX - 2.0, PY - 132.0)
	bubble_border.size = Vector2(PW + 4.0, 128.0)
	bubble_border.color = Color(0.10, 0.88, 0.78, 0.65)
	bubble_border.z_index = 13
	bubble_border.modulate.a = 0.0
	bubble_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bubble_border)

	# Connector arrow pointing down to hologram
	var arrow := Label.new()
	arrow.name = "DonutBubbleArrow"
	arrow.text = "▼"
	arrow.position = Vector2(PX + PW * 0.5 - 6.0, PY - 8.0)
	arrow.add_theme_font_size_override("font_size", 10)
	arrow.add_theme_color_override("font_color", Color(0.10, 0.88, 0.78, 0.65))
	arrow.z_index = 15
	arrow.modulate.a = 0.0
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(arrow)

	# Speech label inside bubble
	_donut_speech_lbl = Label.new()
	_donut_speech_lbl.text = ""
	_donut_speech_lbl.position = Vector2(PX + 6.0, PY - 127.0)
	_donut_speech_lbl.custom_minimum_size = Vector2(PW - 10.0, 0.0)
	_donut_speech_lbl.size = Vector2(PW - 10.0, 118.0)
	_donut_speech_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_donut_speech_lbl.add_theme_font_size_override("font_size", 12)
	_donut_speech_lbl.add_theme_color_override("font_color", Color(0.85, 1.0, 0.96))
	_donut_speech_lbl.modulate.a = 0.0
	_donut_speech_lbl.z_index = 15
	_donut_speech_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_donut_speech_lbl)

	# Hologram flicker tween on the outer border
	var flicker: Tween = create_tween()
	flicker.set_loops()
	flicker.tween_property(outer, "modulate:a", 0.55, 0.18)
	flicker.tween_property(outer, "modulate:a", 1.0, 0.12)
	flicker.tween_interval(1.1)
	flicker.tween_property(outer, "modulate:a", 0.65, 0.08)
	flicker.tween_property(outer, "modulate:a", 1.0, 0.10)
	flicker.tween_interval(2.3)

func _donut_say(text: String, duration: float = 3.8) -> void:
	if _donut_speech_lbl == null:
		return
	_donut_speech_lbl.text = text
	var ui: CanvasLayer = $UILayer
	var bubble_bg: ColorRect = ui.get_node_or_null("DonutBubbleBg") as ColorRect
	var bubble_border: ColorRect = ui.get_node_or_null("DonutBubbleBorder") as ColorRect
	var arrow: Label = ui.get_node_or_null("DonutBubbleArrow") as Label

	if _donut_speech_tween != null:
		_donut_speech_tween.kill()
	_donut_speech_tween = create_tween()
	_donut_speech_tween.tween_property(_donut_speech_lbl, "modulate:a", 1.0, 0.28)
	if bubble_bg != null:
		_donut_speech_tween.parallel().tween_property(bubble_bg, "modulate:a", 1.0, 0.28)
	if bubble_border != null:
		_donut_speech_tween.parallel().tween_property(bubble_border, "modulate:a", 1.0, 0.28)
	if arrow != null:
		_donut_speech_tween.parallel().tween_property(arrow, "modulate:a", 1.0, 0.28)
	_donut_speech_tween.tween_interval(duration)
	_donut_speech_tween.tween_property(_donut_speech_lbl, "modulate:a", 0.0, 0.50)
	if bubble_bg != null:
		_donut_speech_tween.parallel().tween_property(bubble_bg, "modulate:a", 0.0, 0.50)
	if bubble_border != null:
		_donut_speech_tween.parallel().tween_property(bubble_border, "modulate:a", 0.0, 0.50)
	if arrow != null:
		_donut_speech_tween.parallel().tween_property(arrow, "modulate:a", 0.0, 0.50)

func _donut_pick(category: String) -> String:
	var pool: Array = DONUT_LINES.get(category, ["..."])
	var last: int = _donut_last_line.get(category, -1)
	var idx: int = _donut_rng.randi_range(0, pool.size() - 1)
	if pool.size() > 1 and idx == last:
		idx = (idx + 1) % pool.size()
	_donut_last_line[category] = idx
	return pool[idx]

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

## ─── Ally HP Panel ────────────────────────────────────────────────────────────

func _build_ally_panel() -> void:
	## Stack one HP label per ally under the hero HP label (top-left).
	_ally_hp_labels.clear()
	if _allies.is_empty():
		return
	var ui: CanvasLayer = $UILayer
	var base_y: float = _hero_hp_label.position.y + 22.0
	for i: int in range(_allies.size()):
		var a: Combatant = _allies[i]
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.96, 0.82, 0.28))
		lbl.position = Vector2(_hero_hp_label.position.x, base_y + float(i) * 18.0)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(lbl)
		_ally_hp_labels[a.id] = lbl
		_update_ally_hp_label(a)

func _update_ally_hp_label(c: Combatant) -> void:
	var lbl: Label = _ally_hp_labels.get(c.id)
	if lbl == null:
		return
	var first_name: String = c.display_name.split(" ")[0]
	if c.is_alive():
		lbl.text = "%s — HP %d/%d" % [first_name, c.hp, c.max_hp]
		var ratio: float = float(c.hp) / float(max(1, c.max_hp))
		lbl.add_theme_color_override("font_color",
			Color(1.0 - ratio * 0.65, 0.55 + ratio * 0.35, 0.18))
	else:
		lbl.text = "%s — fallen" % first_name
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

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

	if active == _hero:
		# Run 19: count Carl's own turns this floor (for "speed_run").
		Achievements.note_hero_turn()
		# Tick ability cooldowns at the start of each hero turn
		for id: String in _hero_ability_objs:
			_hero_ability_objs[id].tick_cooldown()
		_refresh_ability_bar()

		# Near-death warning (≤25% HP) — occasional, not every single turn
		var hp_ratio: float = float(_hero.hp) / float(max(1, _hero.max_hp))
		if hp_ratio <= 0.25 and _battle_rng.randf() < 0.55:
			SystemVoice.speak("near_death")
		if hp_ratio <= 0.25 and _battle_rng.randf() < 0.45:
			_donut_say(_donut_pick("hero_near_death"))

		# Apply lava heat damage if adjacent to lava
		_apply_lava_heat(active)
		if _engine.battle_over:
			return

		_player_turn = true
		_turn_indicator.text = "YOUR TURN — Click to move or attack"
		_turn_indicator.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		_update_highlights()
		_update_hero_hp_label()
	elif active.faction == Combatant.Faction.HERO:
		# Ally turn — auto-driven (move toward nearest enemy, attack if adjacent)
		_apply_lava_heat(active)
		if _engine.battle_over:
			return
		_player_turn = false
		_clear_highlights()
		_turn_indicator.text = "%s's Turn" % active.display_name
		_turn_indicator.add_theme_color_override("font_color", Color(0.96, 0.82, 0.28))
		await get_tree().create_timer(0.45).timeout
		if not _engine.battle_over:
			_resolve_ally_turn(active)
			_sync_entity_positions()
			_update_all_hp_bars()
			_engine.end_turn()
			await get_tree().create_timer(0.22).timeout
			_next_turn()
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

func _resolve_ally_turn(ally: Combatant) -> void:
	## Ally AI: close on the nearest living enemy and basic-attack if adjacent.
	## Allies inherit the HERO crit roll in BattleEngine (faction-gated, not _hero-gated).
	if _enemies.is_empty():
		return
	var nearest: Combatant = null
	var best_d: int = 1000000
	for e: Combatant in _enemies:
		if not e.is_alive():
			continue
		var d: int = HexGrid.hex_distance(ally.position, e.position)
		if d < best_d:
			best_d = d
			nearest = e
	if nearest == null:
		return
	if best_d <= 1:
		_play_ability_effect(nearest.position, "basic_attack")
		_engine.perform_attack(ally, nearest, "basic_attack")
	else:
		var moved: bool = _engine.move_toward(ally, nearest.position, _map)
		if moved and HexGrid.hex_distance(ally.position, nearest.position) <= 1:
			_play_ability_effect(nearest.position, "basic_attack")
			_engine.perform_attack(ally, nearest, "basic_attack")

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
	AudioManager.play("lava", 0.1)
	_play_ability_effect(c.position, "lava_heat")
	_show_damage_number(c, actual, LAVA_HEAT_CLR)
	_update_hp_bar(c)
	if c == _hero:
		_update_hero_hp_label()
		_show_system_banner("Lava heat! -%d HP. The floor is trying to kill you. Literally." % actual, 2.0)
	elif c.sprite_key.begins_with("ally_"):
		_update_ally_hp_label(c)

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
	AudioManager.play("move", 0.12)
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
			AudioManager.play("ability")
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

	# Run 19: track ability variety for "combo_master" + capture pre-hit HP
	# so the death handler can decide whether this was a one-shot ("headshot").
	Achievements.note_ability_used(_selected_ability)
	_attack_pre_hp = target.hp

	_play_ability_effect(target.position, _selected_ability)
	_engine.perform_attack(_hero, target, _selected_ability)
	# Run 19: _attack_pre_hp is only meaningful for the death emission that
	# fires *inside* perform_attack (synchronously, before this line runs).
	# Reset it now so a later poison/lava death can't mis-attribute as a one-shot.
	_attack_pre_hp = 0
	match _selected_ability:
		"backstab":     SystemVoice.speak("ability_backstab")
		"shield_bash":  SystemVoice.speak("shield_bash")
		"shadow_step":  pass  # quip already played above during teleport
		_:              SystemVoice.speak("hit")
	if _battle_rng.randf() < 0.22:
		_donut_say(_donut_pick("ability_used"))

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
				else:
					# Run 19: pushing an enemy to its death via lava counts toward
					# the "Lava Lord" achievement (3 lava-push kills per run).
					GameState.lava_push_kills += 1
					GameState.award_audience(15, "lava_kill")
					if GameState.lava_push_kills >= 3:
						Achievements.unlock("lava_lord")
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

	# Run 19: count AOE casts toward ability-variety achievement.
	Achievements.note_ability_used(_selected_ability)

	_player_turn = false
	_clear_highlights()

	var aoe_radius: int = 2  # default AOE radius for fireball

	if _selected_ability == "frost_nova":
		aoe_radius = 1
		AudioManager.play("frost")
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
		AudioManager.play("fire")
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

	# Run 19: self-target casts also count toward "combo_master".
	Achievements.note_ability_used(_selected_ability)

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
	AudioManager.play("select")
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

	var was_crit: bool = _engine.last_attack_was_crit and attacker.faction == Combatant.Faction.HERO
	if was_crit:
		# Gold, larger damage number + extra flash + quip for critical hits
		_show_damage_number(target, damage, Color(1.0, 0.85, 0.1), true)
		AudioManager.play("crit", 0.05)
		if _battle_rng.randf() < 0.5:
			SystemVoice.speak("critical_hit")
		# Run 19: track crits for the streak achievement + audience favor.
		Achievements.note_crit()
		GameState.award_audience(10, "crit")
	else:
		_show_damage_number(target, damage)
		# Audio: hero hits vs hero gets hurt
		if target.faction == Combatant.Faction.HERO:
			AudioManager.play("hurt", 0.06)
		else:
			AudioManager.play("hit", 0.08)

	_hit_flash(target)
	_update_hp_bar(target)
	_update_status_label(target)
	_update_boss_hp_bar()
	if target.sprite_key.begins_with("ally_"):
		_update_ally_hp_label(target)
	# Contextual player-hit commentary — fire ~40% of the time, only for Carl.
	# (Quips address "you" / Carl directly, so they don't make sense for allies.)
	if target == _hero and attacker.faction == Combatant.Faction.ENEMY:
		# Run 19: mark this floor as no-longer-untouchable.
		if damage > 0:
			Achievements.note_hero_took_damage()
		if _battle_rng.randf() < 0.40:
			SystemVoice.speak("took_hit_comment")
		if _battle_rng.randf() < 0.28:
			_donut_say(_donut_pick("hero_hurt"))

func _on_combatant_died(c: Combatant) -> void:
	if c.faction == Combatant.Faction.ENEMY:
		_enemies_killed += 1
		AudioManager.play("kill", 0.1)
		# Run 19: achievements + audience favor on enemy death.
		Achievements.unlock("first_blood")
		GameState.award_audience(5, "kill")
		var is_boss_kill: bool = c.sprite_key.begins_with("boss") or c.is_boss
		if is_boss_kill:
			Achievements.unlock("boss_slayer")
			GameState.award_audience(50, "boss_kill")
			if c.is_enraged:
				Achievements.unlock("enrage_killer")
		# One-shot detection: if THIS attack's damage met or exceeded target's max HP.
		if _attack_pre_hp > 0 and _attack_pre_hp >= c.max_hp:
			Achievements.unlock("headshot")
		_attack_pre_hp = 0
		if not _first_kill_done:
			_first_kill_done = true
			SystemVoice.speak("first_kill")
		elif is_boss_kill:
			SystemVoice.speak("boss_killed")
		else:
			SystemVoice.speak("kill")
		# Delay grey-out so the hit-flash tween finishes first
		_grey_out_entity_delayed(c.id)
		# Donut hologram reacts to kills occasionally
		if _battle_rng.randf() < 0.42:
			get_tree().create_timer(0.55).timeout.connect(
				func() -> void: _donut_say(_donut_pick("enemy_killed")))
	elif c == _hero:
		# Player hero died — end the battle immediately
		if _hero_dead:
			return
		_hero_dead = true
		_donut_say(_donut_pick("hero_killed"))
		var node: Node2D = _entity_nodes.get(c.id)
		if node != null:
			node.modulate = DEAD_MODULATE
		if not _engine.battle_over:
			_engine.battle_over = true
			_engine.hero_won = false
			_engine.battle_ended.emit(false, 0)
		await get_tree().create_timer(0.5).timeout
		_show_death_overlay()
	else:
		# Ally fell — battle continues. Mourn them and grey them out.
		SystemVoice.speak_direct("%s has fallen. They bought you time. Use it." % c.display_name)
		_donut_say(_donut_pick("ally_fell"))
		_grey_out_entity_delayed(c.id)
		_update_ally_hp_label(c)

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

func _on_hero_moved(combatant: Combatant, _from_hex: Vector2i, to_hex: Vector2i) -> void:
	## Animate moved hero-faction node to new position (player hero or ally).
	var node: Node2D = _entity_nodes.get(combatant.id)
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
	AudioManager.play("enrage")
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
		AudioManager.play("victory")
		# Run 19: end-of-floor achievement evaluation. Order is intentional —
		# floor-clear bonus first (always earned), then conditionals.
		GameState.award_audience(GameState.floor_num * 10, "floor_clear")
		_evaluate_floor_clear_achievements()
		SystemVoice.speak_direct("All threats eliminated. XP: %d." % xp_earned)
		get_tree().create_timer(0.5).timeout.connect(func() -> void: _donut_say(_donut_pick("victory")))
		# Brief pause then emit battle_complete (routes to VictoryScreen)
		await get_tree().create_timer(1.2).timeout
		battle_complete.emit(true, xp_earned, _enemies_killed)
	else:
		_turn_indicator.text = "DEFEATED"
		_turn_indicator.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
		AudioManager.play("defeat")
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
	stats_lbl.text = "Floor %d  ·  %d enemies slain  ·  Level %d  ·  Score %d" % [
		GameState.floor_num, GameState.total_kills + _enemies_killed,
		GameState.hero_level, GameState.run_score()
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
	_sync_hero_alpha()
	for a: Combatant in _allies:
		_update_ally_hp_label(a)

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

func _show_damage_number(c: Combatant, damage: int, color: Color = Color(1.0, 0.25, 0.1),
		is_crit: bool = false) -> void:
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var lbl := Label.new()
	if is_crit:
		lbl.text = "-%d CRIT!" % damage
		lbl.add_theme_font_size_override("font_size", 30)
	else:
		lbl.text = "-%d" % damage
		lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = node.position + Vector2(-14.0, -26.0)
	_entity_layer.add_child(lbl)
	var rise: float = -64.0 if is_crit else -52.0
	var tw: Tween = create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, rise), 0.9)
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


## ─── Run 19: Achievement toast UI + Audience HUD widget ───────────────────────

func _build_achievement_overlay() -> void:
	## Top-right CanvasLayer holding the audience score widget and stacked
	## achievement toasts. Layered above everything else so popups never get
	## hidden by hex tiles or the boss HP bar.
	_achievement_layer = CanvasLayer.new()
	_achievement_layer.layer = 5
	add_child(_achievement_layer)

	# Audience score widget — top-right, always visible, flashes on gain.
	var widget := PanelContainer.new()
	widget.position = Vector2(1080.0, 12.0)
	widget.custom_minimum_size = Vector2(188.0, 38.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.12, 0.86)
	sb.border_color = Color(0.95, 0.78, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6.0)
	widget.add_theme_stylebox_override("panel", sb)
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achievement_layer.add_child(widget)

	_audience_widget = Label.new()
	_audience_widget.text = "★ AUDIENCE  %d" % GameState.audience_score_floor
	_audience_widget.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_audience_widget.add_theme_font_size_override("font_size", 14)
	_audience_widget.add_theme_color_override("font_color", Color(0.95, 0.82, 0.22))
	_audience_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.add_child(_audience_widget)


func _on_audience_gained(_amount: int, _reason: String) -> void:
	## Update the widget text and flash gold briefly.
	if _audience_widget == null:
		return
	_audience_widget.text = "★ AUDIENCE  %d" % GameState.audience_score_floor
	if _audience_flash_tween != null and _audience_flash_tween.is_valid():
		_audience_flash_tween.kill()
	# Briefly enlarge + pure-gold flash, then settle back.
	_audience_widget.modulate = Color(1.6, 1.4, 0.6, 1.0)
	_audience_flash_tween = create_tween()
	_audience_flash_tween.tween_property(_audience_widget, "modulate",
		Color(1.0, 1.0, 1.0, 1.0), 0.45).set_ease(Tween.EASE_OUT)


func _on_achievement_unlocked(_id: String, def: Dictionary) -> void:
	_pending_toasts.append(def)
	if not _toast_showing:
		_show_next_toast()


func _show_next_toast() -> void:
	if _pending_toasts.is_empty() or _achievement_layer == null:
		_toast_showing = false
		return
	_toast_showing = true
	var def: Dictionary = _pending_toasts.pop_front()

	var panel := PanelContainer.new()
	panel.position = Vector2(1280.0, 56.0)  # off-screen right, slides in
	panel.custom_minimum_size = Vector2(280.0, 64.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.10, 0.95)
	sb.border_color = Color(0.96, 0.78, 0.18)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(8.0)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.shadow_size = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achievement_layer.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)

	var head := Label.new()
	head.text = "✦ ACHIEVEMENT UNLOCKED"
	head.add_theme_font_size_override("font_size", 11)
	head.add_theme_color_override("font_color", Color(0.96, 0.78, 0.18))
	vb.add_child(head)

	var name_lbl := Label.new()
	name_lbl.text = def.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86))
	vb.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = def.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.62))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(260.0, 0.0)
	vb.add_child(desc_lbl)

	# Slide in from the right, hold, slide out — then queue the next toast.
	var tw: Tween = create_tween()
	tw.tween_property(panel, "position:x", 988.0, 0.32) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(2.6)
	tw.tween_property(panel, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(panel.queue_free)
	tw.tween_callback(_show_next_toast)

	AudioManager.play("select", 0.0)
	if _battle_rng != null and _battle_rng.randf() < 0.50:
		SystemVoice.speak("achievement_unlocked")


func _evaluate_floor_clear_achievements() -> void:
	## Called at the moment the battle is won. Achievements that depend on the
	## state of the just-finished floor (no damage taken, low HP, ally survival,
	## fast clear) are evaluated here.
	if not Achievements.took_damage_this_floor():
		Achievements.unlock("untouchable")
	var hp_ratio: float = float(_hero.hp) / float(max(1, _hero.max_hp))
	if hp_ratio < 0.20:
		Achievements.unlock("low_hp_hero")
	if Achievements.get_hero_turns_this_floor() <= 6:
		Achievements.unlock("speed_run")
	if not _allies.is_empty():
		var all_alive: bool = true
		for a: Combatant in _allies:
			if not a.is_alive():
				all_alive = false
				break
		if all_alive:
			Achievements.unlock("team_player")
