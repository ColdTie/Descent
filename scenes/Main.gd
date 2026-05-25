extends Node
## Root scene — manages top-level scene transitions.
## Run 2: added UpgradeScreen → LootScreen flow after leveling up.

const CLASS_SELECT_SCENE := "res://scenes/ClassSelect.tscn"
const BATTLE_SCENE       := "res://scenes/BattleScene.tscn"
const LOOT_SCENE         := "res://scenes/LootScreen.tscn"
const UPGRADE_SCENE      := "res://scenes/UpgradeScreen.tscn"

var _current_scene: Node = null
var _pending_xp: int = 0    ## XP to apply after battle resolves

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
	## BattleScene handles the death overlay; it emits battle_complete(false, 0)
	## when player clicks "Try Again" — handled in _on_battle_complete below.
	pass

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
	if _current_scene.has_signal("upgrade_chosen"):
		_current_scene.upgrade_chosen.connect(_on_upgrade_chosen)

func _on_battle_complete(hero_won: bool, xp_earned: int) -> void:
	if not hero_won:
		## Player pressed "Try Again" on death screen
		_go_to_class_select()
		return

	## Track kills for stats (engine tracked them; we add xp as proxy)
	var leveled_up: bool = GameState.gain_xp(xp_earned)
	if leveled_up:
		## Show upgrade screen before loot
		_load_scene(UPGRADE_SCENE)
	else:
		_load_scene(LOOT_SCENE)

func _on_upgrade_chosen(_upgrade_type: String, _value: String) -> void:
	## Upgrade applied in UpgradeScreen._apply_upgrade; proceed to loot
	_load_scene(LOOT_SCENE)

func _on_loot_chosen(_loot_id: String) -> void:
	GameState.descend()
