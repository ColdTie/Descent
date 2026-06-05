extends Node2D
## Visual driver for one battle encounter on the hex grid.
## Run 3: ability charges/cooldowns in HUD, lava heat damage, floor scaling, enemy collision fix.

signal battle_complete(hero_won: bool, xp_earned: int, enemies_killed: int)

const HEX_SIZE: float = 38.0
const HERO_COLOR  := Color(0.25, 0.55, 1.0)
const ENEMY_COLOR  := Color(0.9, 0.2, 0.15)
const SELECTED_CLR  := Color(1.0, 0.9, 0.2)
const DEAD_MODULATE  := Color(0.35, 0.35, 0.35, 0.4)
const MOVE_CLR  := Color(0.15, 0.85, 0.35, 0.45)
const ATTACK_CLR  := Color(0.9, 0.15, 0.05, 0.55)
const AOE_CLR  := Color(0.9, 0.45, 0.05, 0.35)
const SELF_CLR  := Color(0.6, 0.3, 0.9, 0.5)
const FROST_CLR  := Color(0.25, 0.65, 1.0, 0.5)
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
var LAVA_GLOW  := Color(1.0, 0.60, 0.08, 0.35)
var LAVA_BORDER := Color(0.95, 0.42, 0.04)
var FLOOR_COLOR := Color(0.18, 0.15, 0.22)
var FLOOR_ALT  := Color(0.14, 0.11, 0.17)
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
var _hex_polys: Dictionary = {}  # Vector2i -> Polygon2D
var _entity_nodes: Dictionary = {} # combatant.id -> Node2D
var _ability_btns: Dictionary = {} # ability_id -> Button
var _highlight_hexes: Array[Vector2i] = []

# Ability charge tracking: ability_id -> Ability object
var _hero_ability_objs: Dictionary = {}

# VFX: preloaded effect textures keyed by ability_id
var _effect_textures: Dictionary = {}

var _selected_ability: String = "basic_attack"
var _player_turn: bool = false
# Per-turn action budget: a hero turn may chain ONE move + ONE basic attack
# (either order), OR a single ability (which always ends the turn). Flags are
# reset in _next_turn() when it's Carl's turn again.
var _moved_this_turn: bool = false
var _basic_attacked_this_turn: bool = false
# Run 24: generic "any attack landed this turn" flag. Set by basic attacks,
# single-target abilities, AOE abilities, and self-target abilities. Used in
# _do_hero_move so the rule "move + any attack ends the turn" is explicit
# and robust to future abilities that might not auto-end the turn.
var _attacked_this_turn: bool = false
var _end_turn_btn: Button = null
var _battle_rng: RandomNumberGenerator
var _enemies_killed: int = 0
var _first_kill_done: bool = false  # for first_kill quip
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
var _attack_pre_hp: int = 0  # snapshot of target HP before _do_hero_attack — for one-shot detection

# Run 21: gold HUD widget — sits below the audience widget. Flashes on gain.
var _gold_widget: Label = null
var _gold_flash_tween: Tween = null

# Active screen-shake tweens, one per world layer — killed before a new shake
# starts so back-to-back impacts don't fight each other on the same property.
var _shake_tweens: Array[Tween] = []

# Run 24: pause overlay + combat log. Pause overlay is a CanvasLayer; ESC
# toggles it. Combat log is a small scrolling panel of the last ~6 events,
# anchored top-right under the HP/audience/gold widgets.
var _pause_layer: CanvasLayer = null
var _pause_visible: bool = false
var _combat_log_panel: PanelContainer = null
var _combat_log_vbox: VBoxContainer = null
const COMBAT_LOG_MAX: int = 6
var _quit_to_title_callback: Callable = Callable()

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
	# Tier-appropriate ambient music loop. Crossfades from whatever was playing
	# (title track on floor 1, previous tier's loop on the 7/13 transitions).
	AudioManager.play_music(AudioManager.music_for_floor(GameState.floor_num), 1.6)
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
	_build_top_left_hud_backing()
	_build_combat_log()
	_build_pause_menu()
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
			FLOOR_ALT  = Color(0.04, 0.06, 0.13)
			STONE_EDGE  = Color(0.20, 0.28, 0.55)
			LAVA_COLOR  = Color(0.06, 0.28, 0.82)
			LAVA_GLOW  = Color(0.15, 0.50, 1.0, 0.30)
			LAVA_BORDER  = Color(0.18, 0.52, 1.0)
			ATMO_COLOR  = Color(0.68, 0.76, 1.0)
		2:  # The Abyss — near-black void with crackling void-purple energy
			FLOOR_COLOR  = Color(0.04, 0.02, 0.08)
			FLOOR_ALT  = Color(0.02, 0.01, 0.05)
			STONE_EDGE  = Color(0.40, 0.10, 0.52)
			LAVA_COLOR  = Color(0.52, 0.00, 0.72)
			LAVA_GLOW  = Color(0.70, 0.05, 0.90, 0.28)
			LAVA_BORDER  = Color(0.80, 0.10, 0.95)
			ATMO_COLOR  = Color(0.70, 0.62, 0.96)
		_:  # Default stone (floors 1-6)
			FLOOR_COLOR  = Color(0.18, 0.15, 0.22)
			FLOOR_ALT  = Color(0.14, 0.11, 0.17)
			STONE_EDGE  = Color(0.38, 0.30, 0.45)
			LAVA_COLOR  = Color(0.88, 0.36, 0.04)
			LAVA_GLOW  = Color(1.0, 0.60, 0.08, 0.35)
			LAVA_BORDER  = Color(0.95, 0.42, 0.04)
			ATMO_COLOR  = Color(0.82, 0.76, 0.96)

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
	var boss_hexes: Array[Vector2i] = []
	if has_boss:
		var boss_count: int = EnemyDefs.boss_count_for_floor(GameState.floor_num)
		boss_hexes = _pick_boss_spawn_hexes(boss_count)
		for bh: Vector2i in boss_hexes:
			var boss: Combatant = EnemyDefs.make_boss(GameState.floor_num, bh, _battle_rng)
			_enemies.append(boss)

	# Some boss floors (Floor 6 Lizard Titans) suppress all regular spawns —
	# the bosses ARE the encounter.
	if not (has_boss and EnemyDefs.suppress_regular_enemies(GameState.floor_num)):
		var pool: Array[Dictionary] = EnemyDefs.get_enemies_for_floor(GameState.floor_num)
		for i: int in range(_map.spawn_points.size()):
			# Keep every boss hex clear for the boss(es)
			if _map.spawn_points[i] in boss_hexes:
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
	# Run 21: gold widget reacts to award_gold from this scene + any spends.
	if not GameState.gold_gained.is_connected(_on_gold_gained):
		GameState.gold_gained.connect(_on_gold_gained)

func _pick_boss_spawn_hexes(count: int) -> Array[Vector2i]:
	## Returns up to `count` passable hexes for boss spawns. First is _map.boss_spawn;
	## additional bosses fill from the rings around it. Skips lava + duplicates.
	var result: Array[Vector2i] = [_map.boss_spawn]
	if count <= 1:
		return result
	for radius: int in [1, 2]:
		for h: Vector2i in HexGrid.ring(_map.boss_spawn, radius):
			if result.size() >= count:
				break
			if h in result:
				continue
			if not _map.is_passable(h):
				continue
			if h == _map.hero_start:
				continue
			result.append(h)
		if result.size() >= count:
			break
	return result

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
		"basic_attack":  "res://assets/effects/fx_impact.png",
		"power_strike":  "res://assets/effects/fx_power_strike.png",
		"backstab":  "res://assets/effects/fx_backstab.png",
		"fireball":  "res://assets/effects/fx_fireball.png",
		"frost_nova":  "res://assets/effects/fx_frost.png",
		"taunt":  "res://assets/effects/fx_taunt.png",
		"vanish":  "res://assets/effects/fx_vanish.png",
		"shield_bash":  "res://assets/effects/fx_impact.png",
		"shadow_step":  "res://assets/effects/fx_shadow_step.png",
		"mana_shield":  "res://assets/effects/fx_mana_shield.png",
		"lava_heat":  "res://assets/effects/fx_lava_heat.png",
		"enemy_claw":  "res://assets/effects/fx_impact.png",
		"enemy_bite":  "res://assets/effects/fx_backstab.png",
		"enemy_fireball": "res://assets/effects/fx_fireball.png",
		"bone_volley":  "res://assets/effects/fx_impact.png",
		"hellfire_aoe":  "res://assets/effects/fx_fireball.png",
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
	fx.texture  = tex
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.position  = pixel_pos + Vector2(0.0, -20.0)
	fx.scale  = Vector2(0.5, 0.5)
	fx.z_index  = 20
	_entity_layer.add_child(fx)
	var tw: Tween = create_tween()
	tw.tween_property(fx, "scale", Vector2(1.6, 1.6), 0.42) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.42) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(fx.queue_free)

	# Heavy-impact abilities get a brief screen shake for tactile weight.
	# Light ones (basic_attack, heal, vanish, taunt, mana_shield, lava_heat
	# ambient, frost shimmer) stay calm — overusing shake numbs the effect.
	match ability_id:
		"fireball":
			_screen_shake(6.5, 0.26)
		"power_strike", "backstab":
			_screen_shake(5.0, 0.20)
		"frost_nova", "shadow_step":
			_screen_shake(3.5, 0.18)

## ─── Idle Animation ───────────────────────────────────────────────────────────

func _start_idle_bob(sprite: Sprite2D, is_hero: bool) -> Tween:
	## Slow breathing bob: hero moves gently, enemies bounce more assertively.
	## Returns the looping tween so the caller can kill it on death.
	var base_y: float  = -24.0
	var amp:  float  = 2.0 if is_hero else 3.5
	var period: float  = 1.8 if is_hero else 1.2
	var tw: Tween = create_tween()
	tw.set_loops()
	tw.tween_property(sprite, "position:y", base_y - amp, period * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "position:y", base_y + amp * 0.4, period * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	return tw

## ─── Cave Atmosphere ──────────────────────────────────────────────────────────

func _draw_cave_background() -> void:
	# Atmosphere tint — color varies by floor tier
	var cm := CanvasModulate.new()
	cm.color = ATMO_COLOR
	add_child(cm)

	# Vignette — four dark gradient strips around the viewport edges
	var ui: CanvasLayer = $UILayer
	for edge_rect: Array in [
		[0, 0, 1280, 80],  # top
		[0, 640, 1280, 80],  # bottom
		[0, 0, 90, 720],  # left
		[1190, 0, 90, 720],  # right
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
		if is_lava:
			# Lava keeps a flat fill — the pulse tween animates poly.color directly.
			poly.color = LAVA_COLOR
		else:
			# Stone floor: pick base/alt shade, then nudge per-tile so the floor
			# isn't a regular checker pattern. Hash drives a small ±brightness wobble.
			var alt: bool = (hex.x + hex.y) % 2 == 0
			var base: Color = FLOOR_COLOR if alt else FLOOR_ALT
			var h: int = absi(hex.x * 73856093 ^ hex.y * 19349663 ^ GameState.run_seed)
			var nudge: float = (float(h % 1000) / 1000.0) - 0.5  # -0.5..+0.5
			base = base.lightened(nudge * 0.12)
			# Vertical gradient via per-vertex colors — top vertices catch the
			# "overhead light", bottom vertices fall into shadow. Reads as carved
			# stone instead of a flat-painted tile.
			# _make_hex_pts order: 0=upper-right, 1=lower-right, 2=bottom,
			# 3=lower-left, 4=upper-left, 5=top.
			var top: Color = base.lightened(0.28)
			var mid: Color = base
			var bot: Color = base.darkened(0.42)
			var vc := PackedColorArray()
			vc.append(top)              # 0 upper-right
			vc.append(mid.darkened(0.18)) # 1 lower-right
			vc.append(bot)              # 2 bottom
			vc.append(mid.darkened(0.18)) # 3 lower-left
			vc.append(top)              # 4 upper-left
			vc.append(top.lightened(0.06)) # 5 top
			poly.vertex_colors = vc
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

		# Top-edge bevel: thin lighter strip on the upper edges only — gives the
		# floor tile a chiseled-stone feel under the cave's overhead light.
		# _make_hex_pts angles: i=0 upper-right, i=4 upper-left, i=5 top.
		# Skipping for lava (the pulse + border are already busy enough).
		if not is_lava:
			var hpts: PackedVector2Array = _make_hex_pts(HEX_SIZE - 2.5)
			var bevel := Line2D.new()
			var bvpts := PackedVector2Array()
			bvpts.append(hpts[4])
			bvpts.append(hpts[5])
			bvpts.append(hpts[0])
			bevel.points = bvpts
			bevel.width = 1.4
			bevel.default_color = Color(STONE_EDGE.r, STONE_EDGE.g, STONE_EDGE.b, 0.55).lightened(0.35)
			bevel.joint_mode = Line2D.LINE_JOINT_ROUND
			poly.add_child(bevel)

			# Bottom-edge shadow: a slightly darker strip on the lower edges so the
			# tile reads as raised.
			var shadow_edge := Line2D.new()
			var septs := PackedVector2Array()
			septs.append(hpts[1])
			septs.append(hpts[2])
			septs.append(hpts[3])
			shadow_edge.points = septs
			shadow_edge.width = 1.2
			shadow_edge.default_color = Color(0.0, 0.0, 0.0, 0.40)
			shadow_edge.joint_mode = Line2D.LINE_JOINT_ROUND
			poly.add_child(shadow_edge)

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
	var dim:  Color = LAVA_COLOR.darkened(0.38)
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

	# Pick the faction tint that drives stand-ring + aura color.
	var faction_tint: Color
	if is_boss:
		faction_tint = Color(0.85, 0.10, 0.95)
	elif c.sprite_key == "companion_donut":
		faction_tint = Color(0.95, 0.72, 0.10)
	elif c.sprite_key.begins_with("ally_"):
		var ag := _ally_glow_color(c)
		faction_tint = Color(ag.r, ag.g, ag.b)
	elif c.faction == Combatant.Faction.HERO:
		faction_tint = _hero_class_color()
	else:
		faction_tint = Color(0.95, 0.22, 0.16)

	if sprite_tex != null:
		# Floor halo: outer faint hex + inner brighter disk. Stacked, the two
		# read as a faction-tinted "spotlight" pooling on the standing tile.
		var floor_halo := Polygon2D.new()
		floor_halo.polygon = _make_hex_pts(HEX_SIZE - 5.0)
		floor_halo.color = Color(faction_tint.r, faction_tint.g, faction_tint.b, 0.08)
		root.add_child(floor_halo)
		var halo_core := Polygon2D.new()
		halo_core.polygon = _make_hex_pts(HEX_SIZE * 0.55)
		halo_core.color = Color(faction_tint.r, faction_tint.g, faction_tint.b, 0.28)
		halo_core.position = Vector2(0.0, 2.0)
		root.add_child(halo_core)

		# Stand ring: corner brackets at each of the 6 hex corners, pointing
		# inward along the two adjacent edges. Reads as "selected unit"
		# framing — way more deliberate than a flat outline. Container is
		# named "StandRing" so existing code can still find/tween it.
		var stand_ring := Node2D.new()
		stand_ring.name = "StandRing"
		var sr_pts: PackedVector2Array = _make_hex_pts(HEX_SIZE - 5.5)
		var bracket_color := Color(faction_tint.r, faction_tint.g, faction_tint.b, 0.95)
		var bracket_width: float = 2.8 if is_boss else 2.2
		var bracket_len: float = 7.5 if is_boss else 6.5
		for i: int in range(6):
			var corner: Vector2 = sr_pts[i]
			var prev_c: Vector2 = sr_pts[(i + 5) % 6]
			var next_c: Vector2 = sr_pts[(i + 1) % 6]
			var dir_a: Vector2 = (prev_c - corner).normalized() * bracket_len
			var dir_b: Vector2 = (next_c - corner).normalized() * bracket_len
			var seg := Line2D.new()
			var spts := PackedVector2Array()
			spts.append(corner + dir_a)
			spts.append(corner)
			spts.append(corner + dir_b)
			seg.points = spts
			seg.width = bracket_width
			seg.default_color = bracket_color
			seg.joint_mode = Line2D.LINE_JOINT_ROUND
			seg.begin_cap_mode = Line2D.LINE_CAP_ROUND
			seg.end_cap_mode = Line2D.LINE_CAP_ROUND
			stand_ring.add_child(seg)
		root.add_child(stand_ring)

		# Subtle pulse on the player hero's brackets so the eye finds Carl fast.
		if c.faction == Combatant.Faction.HERO and c == _hero:
			var pulse_tw: Tween = create_tween()
			pulse_tw.set_loops()
			pulse_tw.tween_property(stand_ring, "modulate:a", 0.55, 0.95) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			pulse_tw.tween_property(stand_ring, "modulate:a", 1.0, 0.95) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		# Ground shadow: wide-but-shallow ellipse at the feet. We fake the squish
		# by scaling the hex polygon's y.
		var shadow := Polygon2D.new()
		shadow.polygon = _make_hex_pts(HEX_SIZE * (0.54 if is_boss else 0.44))
		shadow.color = Color(0.0, 0.0, 0.0, 0.50)
		shadow.position = Vector2(0.0, HEX_SIZE * 0.30)
		shadow.scale = Vector2(1.0, 0.55)
		root.add_child(shadow)

		# Aura glow ring (existing) — sits at upper torso, gives a soft halo around the sprite.
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
			# Lizard Titans on Floor 6 use the regular-mob scale — they read
			# as wiry predators, not hulks, and there are two of them.
			sprite_scale = 0.45 if c.sprite_key == "boss_lizard_titan" else 0.67
		elif c.sprite_key == "companion_donut":
			sprite_scale = 0.22
		sprite.scale = Vector2(sprite_scale, sprite_scale)
		sprite.position = Vector2(0.0, -24.0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(sprite)

		# Idle breathing bob (enemies bounce a bit faster than hero).
		# Stash the tween + sprite on the root so _grey_out_entity_delayed
		# can halt the loop on death — otherwise the corpse keeps floating.
		var is_hero: bool = c.faction == Combatant.Faction.HERO
		var bob_tw: Tween = _start_idle_bob(sprite, is_hero)
		root.set_meta("bob_tween", bob_tw)
		root.set_meta("bob_sprite", sprite)
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

	# HP bar — wide border + background + coloured fill (Run 22 tweaks: 50×11).
	var HP_W: float = 50.0
	var HP_H: float = 11.0
	var hp_y: float = HEX_SIZE * 0.58

	# Lizard Titans get a bright cyan outer frame so the duo reads as a unique
	# encounter at a glance — pairs with the cyan eyes + belly on the sprite.
	var is_lizard: bool = c.sprite_key == "boss_lizard_titan"
	if is_lizard:
		var hp_outline := ColorRect.new()
		hp_outline.size = Vector2(HP_W + 6.0, HP_H + 6.0)
		hp_outline.position = Vector2(-(HP_W + 6.0) * 0.5, hp_y - 2.0)
		hp_outline.color = Color(0.30, 0.78, 1.0)
		root.add_child(hp_outline)

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
	# Run 22 (fix): glyph fallback used when sprite art isn't loaded. ASCII
	# only — the default Godot font draws missing-glyph boxes for emoji.
	if c.sprite_key == "companion_donut":
		return "D"
	if c.faction == Combatant.Faction.HERO:
		match GameState.hero_class:
			"brawler": return "B"
			"rogue":   return "R"
			"arcanist":return "A"
		return "C"
	# Enemy glyphs by sprite_key
	match c.sprite_key:
		"imp":     return "i"
		"goblin":  return "G"
		"skeleton":return "S"
		"demon":   return "D"
		"golem":   return "o"
		"boss_dungeon_lord":  return "*"
		"boss_warden":  return "⛓"
		"boss_abyss_keeper":  return "X"
	if c.sprite_key.begins_with("boss"): return "*"
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
	name_lbl.text = "X  %s  X" % _boss.display_name.to_upper()
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
	header_lbl.text = ">>  ADVISOR: DONUT"
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
	arrow.text = ""
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
			fn_lbl.text = " %d" % floor_n
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
	_end_turn_btn = null

	for ability_id: String in _hero.abilities:
		var abl: Dictionary = Abilities.get_ability(ability_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(118.0, 64.0)
		btn.pressed.connect(_on_ability_btn.bind(ability_id))
		_ability_bar.add_child(btn)
		_ability_btns[ability_id] = btn

	# End-of-turn button sits at the right of the ability bar. Lit only after
	# the player has used part of their combo (so they can commit without
	# being forced to find a target for the leftover basic attack).
	_end_turn_btn = Button.new()
	_end_turn_btn.custom_minimum_size = Vector2(118.0, 64.0)
	_end_turn_btn.text = "END TURN"
	_end_turn_btn.add_theme_font_size_override("font_size", 12)
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_ability_bar.add_child(_end_turn_btn)

	_refresh_ability_bar()

func _refresh_ability_bar() -> void:
	## Update button labels and disabled state to reflect current charges/cooldowns.
	# Combo lockout: once the player has moved or basic-attacked this turn,
	# every ability except Basic Attack is locked out (no move + ability combo).
	var combo_locked: bool = _moved_this_turn or _basic_attacked_this_turn
	for ability_id: String in _ability_btns:
		var btn: Button = _ability_btns[ability_id]
		var abl: Dictionary = Abilities.get_ability(ability_id)
		var abl_obj: Ability = _hero_ability_objs.get(ability_id)

		# Charge / cooldown display (Run 22 fix: dropped emoji type-icon; the
		# default Godot font renders ATK/*/AoE as missing-glyph boxes. The ability
		# name + charges line is plenty without it.)
		var charge_str: String = ""
		var on_cooldown: bool = false
		if abl_obj != null:
			if abl_obj.max_charges == -1:
				# Unlimited — always available. Use ASCII infinity stand-in.
				charge_str = "(unlimited)"
			elif abl_obj.cooldown_remaining > 0:
				# On cooldown
				charge_str = "CD %d" % abl_obj.cooldown_remaining
				on_cooldown = true
			else:
				# Show charge dots: filled vs empty
				var dots: String = ""
				for i: int in range(abl_obj.max_charges):
					dots += "*" if i < abl_obj.current_charges else "."
				charge_str = dots

		btn.text = "%s\n%s" % [abl.get("display_name", ability_id), charge_str]
		btn.add_theme_font_size_override("font_size", 11)
		btn.disabled = on_cooldown

		# Run 22: ability buttons now use real styleboxes (gold-frame on the
		# selected ability, dim grey when on cooldown). Previously just a
		# subtle `modulate` change — players regularly missed which ability
		# was armed for the next click.
		var is_selected: bool = ability_id == _selected_ability and not on_cooldown
		var depleted_no_charges: bool = (not on_cooldown) and (abl_obj != null) \
			and abl_obj.max_charges > 0 and abl_obj.current_charges <= 0
		var combo_blocked: bool = combo_locked and ability_id != "basic_attack"
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(6.0)
		sb.set_border_width_all(2)
		if combo_blocked:
			sb.bg_color = Color(0.06, 0.05, 0.09, 0.90)
			sb.border_color = Color(0.18, 0.16, 0.22)
			btn.modulate = Color(0.45, 0.45, 0.45)
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("hover", sb)
			btn.add_theme_stylebox_override("pressed", sb)
			btn.add_theme_stylebox_override("disabled", sb)
			btn.add_theme_stylebox_override("focus", sb)
			continue
		if on_cooldown or depleted_no_charges:
			sb.bg_color = Color(0.08, 0.06, 0.10, 0.90)
			sb.border_color = Color(0.22, 0.20, 0.26)
			btn.modulate = Color(0.55, 0.55, 0.55)
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
		elif is_selected:
			sb.bg_color = Color(0.32, 0.22, 0.04, 0.96)
			sb.border_color = Color(1.0, 0.84, 0.18)
			sb.shadow_color = Color(1.0, 0.78, 0.10, 0.45)
			sb.shadow_size = 6
			btn.modulate = Color.WHITE
			btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.62))
		else:
			sb.bg_color = Color(0.11, 0.09, 0.15, 0.92)
			sb.border_color = Color(0.40, 0.32, 0.18)
			btn.modulate = Color.WHITE
			btn.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("disabled", sb)
		btn.add_theme_stylebox_override("focus", sb)

	# End Turn button: lit/usable only after the player started their combo.
	if _end_turn_btn != null:
		var armed: bool = _player_turn and combo_locked
		_end_turn_btn.disabled = not armed
		var esb := StyleBoxFlat.new()
		esb.set_corner_radius_all(4)
		esb.set_content_margin_all(6.0)
		esb.set_border_width_all(2)
		if armed:
			esb.bg_color = Color(0.32, 0.10, 0.08, 0.96)
			esb.border_color = Color(0.95, 0.42, 0.22)
			esb.shadow_color = Color(0.95, 0.42, 0.22, 0.45)
			esb.shadow_size = 6
			_end_turn_btn.modulate = Color.WHITE
			_end_turn_btn.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62))
		else:
			esb.bg_color = Color(0.08, 0.06, 0.10, 0.90)
			esb.border_color = Color(0.22, 0.20, 0.26)
			_end_turn_btn.modulate = Color(0.55, 0.55, 0.55)
			_end_turn_btn.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
		_end_turn_btn.add_theme_stylebox_override("normal", esb)
		_end_turn_btn.add_theme_stylebox_override("hover", esb)
		_end_turn_btn.add_theme_stylebox_override("pressed", esb)
		_end_turn_btn.add_theme_stylebox_override("disabled", esb)
		_end_turn_btn.add_theme_stylebox_override("focus", esb)

func _on_end_turn_pressed() -> void:
	## Manual end-of-turn — fires after a combo step when the player doesn't
	## want (or can't) complete the second half.
	if not _player_turn or _engine.battle_over:
		return
	if not (_moved_this_turn or _basic_attacked_this_turn):
		return  # button shouldn't have been enabled
	AudioManager.play("select", -0.05)
	_player_turn = false
	_clear_highlights()
	_refresh_ability_bar()
	_engine.end_turn()
	_next_turn()

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
		# Reset the move/attack combo flags — a fresh turn earns both back.
		_moved_this_turn = false
		_basic_attacked_this_turn = false
		_attacked_this_turn = false
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
		_turn_indicator.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		_update_highlights()
		_update_turn_hint()
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
	# Run 23 (UX): right-click anywhere on the grid deselects the current
	# ability and snaps back to Basic Attack. Gives the player a quick "back
	# out" if they armed the wrong ability and just want to move/attack.
	if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		if _selected_ability != "basic_attack":
			AudioManager.play("select", -0.05)
			_selected_ability = "basic_attack"
			_refresh_ability_bar()
			_update_highlights()
			_update_turn_hint()
		return
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return

	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	var abl_target: String = abl.get("target", "single_enemy")
	var abl_range: int = abl.get("range", 1)

	# Clicking hero's own hex -> use self-target abilities
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
	# Combo rule: only 1 move per turn — once spent, no more move hexes are valid.
	if _moved_this_turn:
		return false
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
	_moved_this_turn = true
	await get_tree().create_timer(0.28).timeout
	# Combo rule (Run 24): move + ANY attack ends the turn automatically.
	# Previously only `_basic_attacked_this_turn` was checked. Now any attack
	# that landed (basic OR ability) auto-ends the turn after the move so the
	# player never has to click END TURN after a move+attack combo.
	if _attacked_this_turn or _basic_attacked_this_turn or _engine.battle_over:
		_engine.end_turn()
		_next_turn()
	else:
		# Force the cursor back to Basic Attack — abilities are locked out
		# after a move (per the "no abilities in a combo" rule).
		_selected_ability = "basic_attack"
		_player_turn = true
		_refresh_ability_bar()
		_update_highlights()
		_update_turn_hint()

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
	# Combo rule: a basic attack is once per turn. Block re-entry.
	if _selected_ability == "basic_attack" and _basic_attacked_this_turn:
		return
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
		"backstab":  SystemVoice.speak("ability_backstab")
		"shield_bash":  SystemVoice.speak("shield_bash")
		"shadow_step":  pass  # quip already played above during teleport
		_:  SystemVoice.speak("hit")
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

	if _engine.battle_over:
		return
	# Combo rule: a basic attack does NOT end the turn if the player still has
	# their free 1-hex move. Abilities always end the turn.
	var is_basic: bool = _selected_ability == "basic_attack"
	if is_basic:
		_basic_attacked_this_turn = true
	# Run 24: generic "attacked this turn" flag — any single-target attack
	# (basic or ability) sets it so a follow-up move auto-ends the turn.
	_attacked_this_turn = true
	if is_basic and not _moved_this_turn:
		_player_turn = true
		_refresh_ability_bar()
		_update_highlights()
		_update_turn_hint()
	else:
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

	# Run 24: AOE counts as an attack for the move/attack combo flag.
	_attacked_this_turn = true
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
		"mana_shield":
			# Run 21: Arcanist's class-unique unlock. Absorbs the next N damage
			# before armor/HP — see Combatant._consume_mana_shield.
			var absorb: int = int(abl.get("mana_shield_amount", 40))
			_hero.apply_status(StatusEffect.mana_shield(absorb))
			SystemVoice.speak("ability_mana_shield")
			_play_ability_effect(_hero.position, "mana_shield")
			_flash_hex_area(_hero.position, 0, Color(0.32, 0.62, 1.0, 0.55))
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

	# If already selected and player's turn -> self-target abilities fire immediately
	var abl: Dictionary = Abilities.get_ability(ability_id)
	if _selected_ability == ability_id and _player_turn and abl.get("target", "single_enemy") == "self":
		_do_hero_self_ability()
		return
	AudioManager.play("select")
	_selected_ability = ability_id
	_refresh_ability_bar()
	if _player_turn:
		_update_highlights()
		_update_turn_hint()

## ─── Movement Highlighting ────────────────────────────────────────────────────

func _update_turn_hint() -> void:
	## Run 23 (UX): the turn indicator now tells the player exactly what each
	## click will do given their currently armed ability. Previously it was
	## a static "Click to move or attack" — players didn't realize that
	## clicking an empty green hex still moved them with an ability armed.
	if not _player_turn:
		return
	# Make sure the label is wide enough for the hint string. The .tscn ships
	# at 264px; widen to 1040 so the multi-segment hint fits on one line.
	_turn_indicator.offset_right = 1056.0

	# Combo mode: once Carl has moved or basic-attacked, abilities are locked
	# and the only legal extra step is the OTHER half of the move/attack combo.
	if _moved_this_turn and not _basic_attacked_this_turn:
		_turn_indicator.text = "MOVED  •  click ENEMY for Basic Attack  •  or END TURN"
		return
	if _basic_attacked_this_turn and not _moved_this_turn:
		_turn_indicator.text = "ATTACKED  •  GREEN = move 1 hex  •  or END TURN"
		return

	var abl: Dictionary = Abilities.get_ability(_selected_ability)
	var name_s: String = String(abl.get("display_name", _selected_ability))
	var target: String = String(abl.get("target", "single_enemy"))
	var action_segment: String
	match target:
		"single_enemy":
			action_segment = "click ENEMY for %s" % name_s
		"all_enemies":
			var abl_range: int = int(abl.get("range", 1))
			if abl_range <= 1:
				action_segment = "%s hits all adjacent foes" % name_s
			else:
				action_segment = "click ORANGE tile to drop %s" % name_s
		"self":
			action_segment = "click YOURSELF for %s" % name_s
		_:
			action_segment = "%s armed" % name_s
	_turn_indicator.text = "YOUR TURN  •  GREEN = move  •  %s  •  right-click cancels" % action_segment


func _update_highlights() -> void:
	_clear_highlights()
	if not _player_turn:
		return

	# Movement hexes — adjacent, passable, empty.
	# Run 23 (UX): drawn as a thin GREEN RING (Line2D outline) rather than a
	# fill so they remain unmistakably "move here" even when an ability is
	# armed and the rest of the grid is painted with attack/AOE fills.
	for n: Vector2i in HexGrid.neighbors(_hero.position):
		if _is_valid_move_hex(n):
			_highlight_move_ring(n)

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

func _highlight_move_ring(hex: Vector2i) -> void:
	## Run 23 (UX): movement marker rendered as a thin green ring so it stays
	## legible on top of any subsequent ability-zone fill (red / orange / blue).
	## Distinct child name "MoveRing" lets the ability code ALSO paint the same
	## hex if needed without colliding on dedupe.
	## Run 23 fix: NO looping tween on the ring. The previous pulse tween was
	## created via BattleScene.create_tween(), so when _clear_highlights queue-
	## freed the ring its tween survived and kept trying to animate a dead
	## node every frame — that's what locked the game up after a few turns of
	## clicking abilities.
	var poly: Polygon2D = _hex_polys.get(hex)
	if poly == null:
		return
	if poly.get_node_or_null("MoveRing") != null:
		return
	var ring := Line2D.new()
	ring.name = "MoveRing"
	var pts: PackedVector2Array = _make_hex_pts(HEX_SIZE - 5.0)
	pts.append(pts[0])  # close the loop
	ring.points = pts
	ring.width = 3.0
	ring.default_color = Color(0.30, 1.0, 0.45, 0.95)
	ring.joint_mode = Line2D.LINE_JOINT_ROUND
	ring.z_index = 1   # above ability fills so the green ring is always visible
	poly.add_child(ring)
	_highlight_hexes.append(hex)

func _clear_highlights() -> void:
	for hex: Vector2i in _highlight_hexes:
		var poly: Polygon2D = _hex_polys.get(hex)
		if poly != null:
			# Wipe both the fill overlay AND the move ring (Run 23) — either
			# may exist on a given hex.
			for child_name: String in ["Highlight", "MoveRing"]:
				var child: Node = poly.get_node_or_null(child_name)
				if child != null:
					child.queue_free()
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
		_screen_shake(4.5, 0.20)
		if _battle_rng.randf() < 0.5:
			SystemVoice.speak("critical_hit")
		# Run 19: track crits for the streak achievement + audience favor.
		Achievements.note_crit()
		GameState.award_audience(10, "crit")
		_combat_log_add("CRIT! %s -> %s for %d" % [_short_name(attacker), _short_name(target), damage],
			Color(1.0, 0.85, 0.1))
	else:
		_show_damage_number(target, damage)
		# Audio: hero hits vs hero gets hurt
		if target.faction == Combatant.Faction.HERO:
			AudioManager.play("hurt", 0.06)
		else:
			AudioManager.play("hit", 0.08)
		var line_color: Color = Color(0.78, 0.92, 0.78) if attacker.faction == Combatant.Faction.HERO \
			else Color(0.95, 0.55, 0.45)
		_combat_log_add("%s -> %s for %d" % [_short_name(attacker), _short_name(target), damage],
			line_color)

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
		_combat_log_add("%s slain" % _short_name(c), Color(1.0, 0.78, 0.18))
		# Run 19: achievements + audience favor on enemy death.
		Achievements.unlock("first_blood")
		GameState.award_audience(5, "kill")
		# Run 21: gold drops scale with floor depth (see Shop.gold_for_*).
		GameState.award_gold(Shop.gold_for_kill(GameState.floor_num), "kill")
		var is_boss_kill: bool = c.sprite_key.begins_with("boss") or c.is_boss
		if is_boss_kill:
			Achievements.unlock("boss_slayer")
			GameState.award_audience(50, "boss_kill")
			GameState.award_gold(Shop.gold_for_boss(GameState.floor_num), "boss_kill")
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
		_combat_log_add("Carl has fallen.", Color(0.95, 0.18, 0.18))
		_donut_say(_donut_pick("hero_killed"))
		var node: Node2D = _entity_nodes.get(c.id)
		if node != null:
			node.modulate = DEAD_MODULATE
			_halt_idle_bob(node)
		if not _engine.battle_over:
			_engine.battle_over = true
			_engine.hero_won = false
			_engine.battle_ended.emit(false, 0)
		await get_tree().create_timer(0.5).timeout
		_show_death_overlay()
	else:
		# Ally fell — battle continues. Mourn them and grey them out.
		_combat_log_add("%s has fallen." % _short_name(c), Color(0.95, 0.45, 0.42))
		SystemVoice.speak_direct("%s has fallen. They bought you time. Use it." % c.display_name)
		_donut_say(_donut_pick("ally_fell"))
		_grey_out_entity_delayed(c.id)
		_update_ally_hp_label(c)

func _grey_out_entity_delayed(entity_id: String) -> void:
	## Wait for hit-flash tween to finish, then apply death grey AND stop the
	## idle bob loop so the corpse stops floating up and down.
	await get_tree().create_timer(0.22).timeout
	var node: Node2D = _entity_nodes.get(entity_id)
	if node != null:
		node.modulate = DEAD_MODULATE
		_halt_idle_bob(node)

func _halt_idle_bob(node: Node2D) -> void:
	## Kill the looped bob tween on this entity and snap its sprite back to the
	## idle rest position so a dead body settles instead of drifting mid-bounce.
	if node.has_meta("bob_tween"):
		var tw: Tween = node.get_meta("bob_tween")
		if tw != null and tw.is_valid():
			tw.kill()
		node.remove_meta("bob_tween")
	if node.has_meta("bob_sprite"):
		var spr: Sprite2D = node.get_meta("bob_sprite")
		if spr != null:
			spr.position = Vector2(0.0, -24.0)
		node.remove_meta("bob_sprite")

func _on_status_ticked(c: Combatant, damage: int) -> void:
	if damage > 0:
		_show_damage_number(c, damage, Color(1.0, 0.5, 0.0))
		_combat_log_add("%s takes %d (status)" % [_short_name(c), damage],
			Color(1.0, 0.55, 0.05))
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
	_screen_shake(9.0, 0.45)
	_update_boss_hp_bar()
	var quip: String = SystemVoice.pick("boss_enraged")
	_show_system_banner("⚠ ENRAGED: %s — %s" % [boss.display_name, quip], 4.0)

func _on_battle_ended(hero_won: bool, xp_earned: int) -> void:
	_player_turn = false
	_clear_highlights()
	if hero_won:
		_turn_indicator.text = "VICTORY!"
		_turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		_combat_log_add("Floor %d cleared." % GameState.floor_num, Color(1.0, 0.85, 0.1))
		AudioManager.play("victory")
		# Run 19: end-of-floor achievement evaluation. Order is intentional —
		# floor-clear bonus first (always earned), then conditionals.
		GameState.award_audience(GameState.floor_num * 10, "floor_clear")
		# Run 21: clearing the floor itself is a payday on top of per-kill drops.
		GameState.award_gold(Shop.gold_for_clear(GameState.floor_num), "floor_clear")
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
	hp_bar.size.x = 50.0 * clampf(ratio, 0.0, 1.0)
	# Green -> yellow -> red gradient as HP drops
	hp_bar.color = Color(1.0 - ratio * 0.78, 0.18 + ratio * 0.70, 0.08)

func _update_status_label(c: Combatant) -> void:
	var node: Node2D = _entity_nodes.get(c.id)
	if node == null:
		return
	var status_lbl: Label = node.get_node_or_null("StatusLabel")
	if status_lbl == null:
		return
	# Run 22 (fix): use ASCII letter codes — the emoji glyphs above rendered as
	# missing-glyph boxes in Godot's default font.
	var icons: Array[String] = []
	for eff: Dictionary in c.status_effects:
		match eff.get("id", ""):
			"burning":  icons.append("[BRN]")
			"frozen":  icons.append("[FRZ]")
			"poisoned":  icons.append("[PSN]")
			"fortified":  icons.append("[DEF]")
			"vanished":  icons.append("[HID]")
			"mana_shield": icons.append("[SHD]")
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

func _screen_shake(intensity: float = 5.0, duration: float = 0.22) -> void:
	## Brief offset oscillation on the world layers (hex + entities) for impact
	## punch. UILayer is a CanvasLayer so the HUD stays put; Background is the
	## sibling ColorRect at the BattleScene root and is also unaffected.
	## Any in-flight shake is killed first so back-to-back impacts don't fight.
	for old: Tween in _shake_tweens:
		if old != null and old.is_valid():
			old.kill()
	_shake_tweens.clear()
	var base: Vector2 = Vector2(640.0, 340.0)
	var offsets: Array[Vector2] = [
		Vector2(intensity, -intensity * 0.55),
		Vector2(-intensity * 0.85, intensity * 0.70),
		Vector2(intensity * 0.55, intensity * 0.40),
		Vector2(-intensity * 0.30, -intensity * 0.25),
		Vector2.ZERO,
	]
	var step: float = duration / float(offsets.size())
	for layer: Node2D in [_hex_layer, _entity_layer]:
		layer.position = base
		var ltw: Tween = create_tween()
		for off: Vector2 in offsets:
			ltw.tween_property(layer, "position", base + off, step) \
				.set_trans(Tween.TRANS_SINE)
		_shake_tweens.append(ltw)

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

## ─── Top-Left HUD Backing ────────────────────────────────────────────────────

func _build_top_left_hud_backing() -> void:
	## Stone-styled panel behind the Floor and Turn labels so the top-left HUD
	## reads as a cohesive widget and matches the audience/gold panels at top-right.
	var ui: CanvasLayer = $UILayer
	var bg := Panel.new()
	bg.position = Vector2(8.0, 8.0)
	bg.size = Vector2(300.0, 82.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.12, 0.78)
	sb.border_color = Color(0.95, 0.78, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)
	# Render behind the existing labels in tree order.
	ui.move_child(bg, 0)


## ─── Run 19: Achievement toast UI + Audience HUD widget ───────────────────────

func _build_achievement_overlay() -> void:
	## Top-right CanvasLayer holding the audience score widget and stacked
	## achievement toasts. Layered above everything else so popups never get
	## hidden by hex tiles or the boss HP bar.
	_achievement_layer = CanvasLayer.new()
	_achievement_layer.layer = 5
	add_child(_achievement_layer)

	# Run 22 (fix): widgets were colliding with the HeroHPLabel at (1070,16).
	# Stack them BELOW the hero HP line instead — top-right column, y=58+.
	var widget := PanelContainer.new()
	widget.position = Vector2(1080.0, 58.0)
	widget.custom_minimum_size = Vector2(188.0, 34.0)
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
	_audience_widget.text = _audience_widget_text()
	_audience_widget.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_audience_widget.add_theme_font_size_override("font_size", 13)
	_audience_widget.add_theme_color_override("font_color", Color(0.95, 0.82, 0.22))
	_audience_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.add_child(_audience_widget)

	# Run 21: gold widget — moved (with the audience widget) below the hero HP line.
	var gold_panel := PanelContainer.new()
	gold_panel.position = Vector2(1080.0, 98.0)
	gold_panel.custom_minimum_size = Vector2(188.0, 30.0)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.08, 0.06, 0.12, 0.86)
	gsb.border_color = Color(0.78, 0.58, 0.10)
	gsb.set_border_width_all(1)
	gsb.set_corner_radius_all(4)
	gsb.set_content_margin_all(6.0)
	gold_panel.add_theme_stylebox_override("panel", gsb)
	gold_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achievement_layer.add_child(gold_panel)

	_gold_widget = Label.new()
	_gold_widget.text = "GOLD  %d" % GameState.hero_gold
	_gold_widget.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_widget.add_theme_font_size_override("font_size", 13)
	_gold_widget.add_theme_color_override("font_color", Color(1.0, 0.86, 0.18))
	_gold_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_panel.add_child(_gold_widget)


func _on_audience_gained(_amount: int, _reason: String) -> void:
	## Update the widget text and flash gold briefly.
	if _audience_widget == null:
		return
	_audience_widget.text = _audience_widget_text()
	if _audience_flash_tween != null and _audience_flash_tween.is_valid():
		_audience_flash_tween.kill()
	# Briefly enlarge + pure-gold flash, then settle back.
	_audience_widget.modulate = Color(1.6, 1.4, 0.6, 1.0)
	_audience_flash_tween = create_tween()
	_audience_flash_tween.tween_property(_audience_widget, "modulate",
		Color(1.0, 1.0, 1.0, 1.0), 0.45).set_ease(Tween.EASE_OUT)


func _audience_widget_text() -> String:
	## Run 22: show run-total audience plus the threshold for the next sponsor
	## offer. Format: "* AUDIENCE  N / T". When all earnable thresholds for
	## the current `audience_score` are already taken, fall back to the next
	## multiple — keeps the progression bar honest even after sponsor accepts.
	var total: int = GameState.audience_score
	var taken: int = GameState.sponsor_offers_taken
	var threshold: int = int(Sponsors.SPONSOR_THRESHOLD) * (taken + 1)
	return "AUDIENCE  %d / %d" % [total, threshold]


func _on_gold_gained(_amount: int, _reason: String) -> void:
	## Run 21: refresh the HUD coin-count and flash gold briefly.
	if _gold_widget == null:
		return
	_gold_widget.text = "GOLD  %d" % GameState.hero_gold
	if _gold_flash_tween != null and _gold_flash_tween.is_valid():
		_gold_flash_tween.kill()
	_gold_widget.modulate = Color(1.6, 1.35, 0.55, 1.0)
	_gold_flash_tween = create_tween()
	_gold_flash_tween.tween_property(_gold_widget, "modulate",
		Color(1.0, 1.0, 1.0, 1.0), 0.40).set_ease(Tween.EASE_OUT)


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
	head.text = "* ACHIEVEMENT UNLOCKED"
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


## ─── Pause Menu (Run 24) ─────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	## ESC toggles the pause overlay. Suppressed when the run has ended (the
	## death overlay / victory transition own the screen at that point).
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not (k.pressed and not k.echo):
		return
	if k.keycode == KEY_ESCAPE:
		if _hero_dead or (_engine != null and _engine.battle_over):
			return
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _build_pause_menu() -> void:
	## Build the pause CanvasLayer once and keep it hidden until ESC.
	## Lives on a high layer so it draws over the HUD and overlays.
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 50
	_pause_layer.visible = false
	add_child(_pause_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -240.0
	panel.offset_top = -220.0
	panel.offset_right = 240.0
	panel.offset_bottom = 220.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.11, 0.98)
	sb.border_color = Color(0.78, 0.60, 0.12)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(24.0)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", sb)
	_pause_layer.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.18))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "The dungeon waits. It's patient. It has nowhere to be."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(420.0, 0.0)
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.75, 0.72, 0.66))
	vb.add_child(sub)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(420.0, 1.0)
	div.color = Color(0.60, 0.20, 0.08, 0.6)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(div)

	# SFX volume slider row
	vb.add_child(_make_volume_row("SFX VOLUME", AudioManager.master_volume_db,
		func(v: float) -> void: AudioManager.set_sfx_volume_db(v)))
	# Music volume slider row
	vb.add_child(_make_volume_row("MUSIC VOLUME", AudioManager.music_volume_db,
		func(v: float) -> void: AudioManager.set_music_volume_db(v)))

	# Toggle row: SFX on/off + MUSIC on/off
	var toggle_row := HBoxContainer.new()
	toggle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	toggle_row.add_theme_constant_override("separation", 12)
	vb.add_child(toggle_row)

	var sfx_btn := Button.new()
	sfx_btn.text = ("SFX: ON" if AudioManager.sfx_enabled else "SFX: OFF")
	sfx_btn.custom_minimum_size = Vector2(140.0, 36.0)
	sfx_btn.pressed.connect(_on_pause_toggle_sfx.bind(sfx_btn))
	toggle_row.add_child(sfx_btn)

	var music_btn := Button.new()
	music_btn.text = ("MUSIC: ON" if AudioManager.music_enabled else "MUSIC: OFF")
	music_btn.custom_minimum_size = Vector2(170.0, 36.0)
	music_btn.pressed.connect(_on_pause_toggle_music.bind(music_btn))
	toggle_row.add_child(music_btn)

	# Action buttons
	var resume_btn := Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(320.0, 44.0)
	resume_btn.add_theme_font_size_override("font_size", 18)
	resume_btn.add_theme_color_override("font_color", Color(0.45, 1.0, 0.45))
	resume_btn.pressed.connect(_toggle_pause)
	vb.add_child(resume_btn)

	var quit_btn := Button.new()
	quit_btn.text = "QUIT TO TITLE"
	quit_btn.custom_minimum_size = Vector2(320.0, 36.0)
	quit_btn.add_theme_font_size_override("font_size", 14)
	quit_btn.add_theme_color_override("font_color", Color(0.95, 0.5, 0.45))
	quit_btn.pressed.connect(_quit_to_title)
	vb.add_child(quit_btn)


func _make_volume_row(label_text: String, initial_db: float, on_changed: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.86, 0.82, 0.70))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = -40.0
	slider.max_value = 0.0
	slider.step = 1.0
	slider.value = clamp(initial_db, -40.0, 0.0)
	slider.custom_minimum_size = Vector2(220.0, 28.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_changed)
	row.add_child(slider)
	return row


func _toggle_pause() -> void:
	if _pause_layer == null:
		return
	_pause_visible = not _pause_visible
	_pause_layer.visible = _pause_visible
	# Halting the SceneTree pause would freeze our tween-driven UI; instead we
	# rely on _player_turn / _engine.battle_over to gate input from the grid.
	# The pause overlay itself blocks clicks via its full-screen dim ColorRect.
	if _pause_visible:
		AudioManager.play("select", -0.04)
	else:
		AudioManager.play("select", 0.02)


func _on_pause_toggle_sfx(btn: Button) -> void:
	var on: bool = AudioManager.toggle_enabled()
	btn.text = "SFX: ON" if on else "SFX: OFF"
	if on:
		AudioManager.play("select")


func _on_pause_toggle_music(btn: Button) -> void:
	var on: bool = AudioManager.toggle_music_enabled()
	btn.text = "MUSIC: ON" if on else "MUSIC: OFF"
	AudioManager.play("select")


func _quit_to_title() -> void:
	## Tear down the run and return to TitleScreen. Routed through Main via
	## GameState.hero_died (existing handler routes to ClassSelect).
	AudioManager.play("select")
	if _pause_layer != null:
		_pause_layer.visible = false
	AudioManager.stop_music(0.5)
	GameState.hero_hp = 0
	GameState.hero_died.emit()


## ─── Combat Log (Run 24) ─────────────────────────────────────────────────────

func _build_combat_log() -> void:
	## A small scrolling log of the last COMBAT_LOG_MAX events. Sits in the
	## top-right HUD column under the gold widget. Pure-UI; populated by
	## `_combat_log_add()` from existing combat hooks.
	_combat_log_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.07, 0.78)
	sb.border_color = Color(0.55, 0.42, 0.18, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8.0)
	_combat_log_panel.add_theme_stylebox_override("panel", sb)
	_combat_log_panel.position = Vector2(1080.0, 140.0)
	_combat_log_panel.size = Vector2(188.0, 174.0)
	_combat_log_panel.custom_minimum_size = Vector2(188.0, 174.0)
	_combat_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UILayer.add_child(_combat_log_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	_combat_log_panel.add_child(outer)

	var header := Label.new()
	header.text = "COMBAT LOG"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.95, 0.78, 0.18))
	outer.add_child(header)

	_combat_log_vbox = VBoxContainer.new()
	_combat_log_vbox.add_theme_constant_override("separation", 2)
	outer.add_child(_combat_log_vbox)


func _combat_log_add(text: String, color: Color = Color(0.82, 0.82, 0.78)) -> void:
	## Append a line; trim to COMBAT_LOG_MAX entries.
	if _combat_log_vbox == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_log_vbox.add_child(lbl)
	while _combat_log_vbox.get_child_count() > COMBAT_LOG_MAX:
		var first: Node = _combat_log_vbox.get_child(0)
		_combat_log_vbox.remove_child(first)
		first.queue_free()
	# Brief brightness flash so the eye catches the new entry.
	lbl.modulate = Color(1.4, 1.4, 1.4, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(lbl, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.45)


func _short_name(c: Combatant) -> String:
	## Trim long combatant names for the log column.
	if c == null:
		return "?"
	var n: String = c.display_name
	var space_idx: int = n.find(" ")
	if space_idx > 0 and n.length() > 10:
		return n.substr(0, space_idx)
	return n
