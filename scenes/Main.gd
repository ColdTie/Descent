extends Node
## Root scene — manages top-level scene transitions.
## Run 3: Added VictoryScreen between battle win and LootScreen.

const CLASS_SELECT_SCENE := "res://scenes/ClassSelect.tscn"
const BATTLE_SCENE := "res://scenes/BattleScene.tscn"
const LOOT_SCENE := "res://scenes/LootScreen.tscn"
const LEVEL_UP_SCENE := "res://scenes/LevelUp.tscn"
const VICTORY_SCENE := "res://scenes/VictoryScreen.tscn"

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
	if _current_scene.has_signal("victory_confirmed"):
		_current_scene.victory_confirmed.connect(_on_victory_confirmed)
	if _current_scene.has_signal("loot_chosen"):
		_current_scene.loot_chosen.connect(_on_loot_chosen)
	if _current_scene.has_signal("upgrade_chosen"):
		_current_scene.upgrade_chosen.connect(_on_upgrade_chosen)

func _on_battle_complete(hero_won: bool, _xp_earned: int) -> void:
	if not hero_won:
		# Hero died — reset HP in GameState and go back to class select
		GameState.hero_hp = 0
		_go_to_class_select()
		return
	# Run 3: show victory screen; XP/level-up applied after player clicks Descend.
	# (GameState.last_battle_xp and last_battle_kills were set by BattleScene.)
	_load_scene(VICTORY_SCENE)

func _on_victory_confirmed() -> void:
	## Called when player clicks Descend on the victory screen.
	var leveled_up: bool = GameState.gain_xp(GameState.last_battle_xp)
	if leveled_up:
		_load_scene(LEVEL_UP_SCENE)
	else:
		_load_scene(LOOT_SCENE)

func _on_upgrade_chosen(_upgrade_id: String) -> void:
	_load_scene(LOOT_SCENE)

func _on_loot_chosen(_loot_id: String) -> void:
	GameState.descend()
