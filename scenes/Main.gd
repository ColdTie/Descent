extends Node
## Root scene — manages top-level scene transitions.
## Flow: ClassSelect → Battle → (LevelUp?) → Loot → loop
##        On death: Battle → DeathScreen → ClassSelect

const CLASS_SELECT_SCENE := "res://scenes/ClassSelect.tscn"
const BATTLE_SCENE       := "res://scenes/BattleScene.tscn"
const LOOT_SCENE         := "res://scenes/LootScreen.tscn"
const LEVEL_UP_SCENE     := "res://scenes/LevelUpScreen.tscn"
const DEATH_SCENE        := "res://scenes/DeathScreen.tscn"

var _current_scene: Node = null
var _pending_xp: int = 0  # XP waiting to be processed after battle

func _ready() -> void:
	GameState.run_started.connect(_on_run_started)
	GameState.floor_changed.connect(_on_floor_changed)
	_go_to_class_select()

func _go_to_class_select() -> void:
	_load_scene(CLASS_SELECT_SCENE)

func _on_run_started() -> void:
	GameState.descend()

func _on_floor_changed(_floor_num: int) -> void:
	_load_scene(BATTLE_SCENE)

func _load_scene(path: String) -> void:
	if _current_scene != null:
		_current_scene.queue_free()
		_current_scene = null
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Failed to load scene: " + path)
		return
	_current_scene = packed.instantiate()
	add_child(_current_scene)

	# Wire signals based on what the scene exposes
	if _current_scene.has_signal("battle_complete"):
		_current_scene.battle_complete.connect(_on_battle_complete)
	if _current_scene.has_signal("loot_chosen"):
		_current_scene.loot_chosen.connect(_on_loot_chosen)
	if _current_scene.has_signal("upgrade_chosen"):
		_current_scene.upgrade_chosen.connect(_on_upgrade_chosen)
	if _current_scene.has_signal("restart_requested"):
		_current_scene.restart_requested.connect(_on_restart_requested)

func _on_battle_complete(hero_won: bool, xp_earned: int) -> void:
	if not hero_won:
		# Hero died — show death screen
		_load_scene(DEATH_SCENE)
		return

	var leveled_up: bool = GameState.gain_xp(xp_earned)
	if leveled_up:
		_pending_xp = xp_earned
		_load_scene(LEVEL_UP_SCENE)
	else:
		_load_scene(LOOT_SCENE)

func _on_upgrade_chosen(_upgrade_id: String) -> void:
	## After level-up selection, go to the loot screen.
	_load_scene(LOOT_SCENE)

func _on_loot_chosen(_loot_id: String) -> void:
	GameState.descend()

func _on_restart_requested() -> void:
	## From death screen: go back to class selection.
	_go_to_class_select()
