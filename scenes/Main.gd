extends Node
## Root scene — manages top-level scene transitions.

const CLASS_SELECT_SCENE := "res://scenes/ClassSelect.tscn"
const BATTLE_SCENE := "res://scenes/BattleScene.tscn"
const VICTORY_SCENE := "res://scenes/VictoryScreen.tscn"
const LOOT_SCENE := "res://scenes/LootScreen.tscn"
const LEVEL_UP_SCENE := "res://scenes/LevelUp.tscn"
const WIN_SCENE := "res://scenes/WinScreen.tscn"

var _current_scene: Node = null
# Pending data from the last battle, used to pass to VictoryScreen
var _pending_xp: int = 0
var _pending_kills: int = 0

func _ready() -> void:
	GameState.run_started.connect(_on_run_started)
	GameState.floor_changed.connect(_on_floor_changed)
	GameState.hero_died.connect(_on_hero_died)
	_go_to_class_select()

func _go_to_class_select() -> void:
	_load_scene(CLASS_SELECT_SCENE)

func _on_run_started() -> void:
	GameState.descend()

func _on_floor_changed(_floor_num: int) -> void:
	_load_scene(BATTLE_SCENE)

func _on_hero_died() -> void:
	# Show death text via SystemVoice, then back to class select
	await get_tree().create_timer(2.5).timeout
	_go_to_class_select()

func _load_scene(path: String) -> void:
	if _current_scene != null:
		_current_scene.queue_free()
		_current_scene = null
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Failed to load scene: " + path)
		return
	_current_scene = packed.instantiate()
	# Pass pending data to scenes that accept it (e.g. VictoryScreen)
	if _current_scene.has_method("prepare"):
		_current_scene.call("prepare", {"xp": _pending_xp, "kills": _pending_kills})
	add_child(_current_scene)
	# Connect signals
	if _current_scene.has_signal("battle_complete"):
		_current_scene.battle_complete.connect(_on_battle_complete)
	if _current_scene.has_signal("floor_cleared"):
		_current_scene.floor_cleared.connect(_on_floor_cleared)
	if _current_scene.has_signal("loot_chosen"):
		_current_scene.loot_chosen.connect(_on_loot_chosen)
	if _current_scene.has_signal("upgrade_chosen"):
		_current_scene.upgrade_chosen.connect(_on_upgrade_chosen)
	if _current_scene.has_signal("play_again"):
		_current_scene.play_again.connect(_go_to_class_select)

func _on_battle_complete(hero_won: bool, xp_earned: int, enemies_killed: int) -> void:
	if not hero_won:
		# Hero died — reset and go back to class select
		GameState.hero_hp = 0
		_go_to_class_select()
		return
	# Store data for VictoryScreen
	_pending_xp = xp_earned
	_pending_kills = enemies_killed
	_load_scene(VICTORY_SCENE)

func _on_floor_cleared() -> void:
	## Called when player clicks "Descend Deeper" on the Victory Screen.
	var leveled_up: bool = GameState.gain_xp(_pending_xp)
	if leveled_up:
		_load_scene(LEVEL_UP_SCENE)
	else:
		_load_scene(LOOT_SCENE)

func _on_upgrade_chosen(_upgrade_id: String) -> void:
	_load_scene(LOOT_SCENE)

func _on_loot_chosen(_loot_id: String) -> void:
	# Check win condition before descending
	if GameState.floor_num >= GameState.TOTAL_FLOORS:
		_load_scene(WIN_SCENE)
		return
	# Small HP regen between floors
	GameState.regen_between_floors()
	GameState.descend()
