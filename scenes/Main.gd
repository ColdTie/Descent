extends Node
## Root scene — manages top-level scene transitions.

const CLASS_SELECT_SCENE := "res://scenes/ClassSelect.tscn"
const BATTLE_SCENE := "res://scenes/BattleScene.tscn"
const LOOT_SCENE := "res://scenes/LootScreen.tscn"

var _current_scene: Node = null

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
	add_child(_current_scene)
	if _current_scene.has_signal("battle_complete"):
		_current_scene.battle_complete.connect(_on_battle_complete)
	if _current_scene.has_signal("loot_chosen"):
		_current_scene.loot_chosen.connect(_on_loot_chosen)

func _on_battle_complete(hero_won: bool, xp_earned: int) -> void:
	if not hero_won:
		return
	var leveled_up: bool = GameState.gain_xp(xp_earned)
	if leveled_up:
		SystemVoice.speak("level_up")
	_load_scene(LOOT_SCENE)

func _on_loot_chosen(_loot_id: String) -> void:
	GameState.descend()
