extends Node
## Root scene — manages top-level scene transitions.

const TITLE_SCENE := "res://scenes/TitleScreen.tscn"
const CLASS_SELECT_SCENE := "res://scenes/ClassSelect.tscn"
const BATTLE_SCENE := "res://scenes/BattleScene.tscn"
const VICTORY_SCENE := "res://scenes/VictoryScreen.tscn"
const LOOT_SCENE := "res://scenes/LootScreen.tscn"
const LEVEL_UP_SCENE := "res://scenes/LevelUp.tscn"
const WIN_SCENE := "res://scenes/WinScreen.tscn"
const SPONSOR_SCENE := "res://scenes/SponsorOffer.tscn"
const PATCH_NOTES_SCENE := "res://scenes/PatchNotes.tscn"

var _current_scene: Node = null
# Pending data from the last battle, used to pass to VictoryScreen
var _pending_xp: int = 0
var _pending_kills: int = 0
# Run 20: deferred level-up flag — sponsor offer can run BEFORE LevelUp,
# so we resolve XP up-front and remember whether to route to LevelUp after.
var _pending_leveled: bool = false
# Run 20: floor we're about to enter when patch notes pop. PatchNotes scene
# reads this via `prepare()` so it knows which tier's notes to show.
var _pending_next_floor: int = 0

func _ready() -> void:
	GameState.run_started.connect(_on_run_started)
	GameState.floor_changed.connect(_on_floor_changed)
	GameState.hero_died.connect(_on_hero_died)
	_go_to_title()

func _go_to_title() -> void:
	_load_scene(TITLE_SCENE)

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
	# Pass pending data to scenes that accept it (e.g. VictoryScreen, PatchNotes)
	if _current_scene.has_method("prepare"):
		_current_scene.call("prepare", {
			"xp": _pending_xp,
			"kills": _pending_kills,
			"floor": _pending_next_floor,
		})
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
	if _current_scene.has_signal("start_game"):
		_current_scene.start_game.connect(_go_to_class_select)
	if _current_scene.has_signal("sponsor_chosen"):
		_current_scene.sponsor_chosen.connect(_on_sponsor_chosen)
	if _current_scene.has_signal("patch_notes_dismissed"):
		_current_scene.patch_notes_dismissed.connect(_on_patch_notes_dismissed)

func _on_battle_complete(hero_won: bool, xp_earned: int, enemies_killed: int) -> void:
	if not hero_won:
		# Hero died — reset and go back to class select
		GameState.hero_hp = 0
		_go_to_class_select()
		return
	# Store data for VictoryScreen + accumulate run stats
	_pending_xp = xp_earned
	_pending_kills = enemies_killed
	GameState.total_kills += enemies_killed
	if EnemyDefs.is_boss_floor(GameState.floor_num):
		GameState.bosses_slain += 1
	_load_scene(VICTORY_SCENE)

func _on_floor_cleared() -> void:
	## Called when player clicks "Descend Deeper" on the Victory Screen.
	## Run 20: resolve XP up-front, then check for a sponsor pop-up before
	## routing to LevelUp/Loot. Sponsor offers fire when audience score has
	## crossed a multiple of `Sponsors.SPONSOR_THRESHOLD` that we haven't
	## already paid out.
	_pending_leveled = GameState.gain_xp(_pending_xp)
	if Sponsors.sponsors_owed(GameState.audience_score, GameState.sponsor_offers_taken) > 0:
		_load_scene(SPONSOR_SCENE)
		return
	_post_sponsor_route()

func _on_sponsor_chosen(_sponsor_id: String) -> void:
	## SponsorOffer increments `sponsor_offers_taken` on accept; we just
	## resume the normal LevelUp / Loot flow.
	_post_sponsor_route()

func _post_sponsor_route() -> void:
	if _pending_leveled:
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
	# Run 20: at tier transitions (floors 7, 13), the System ships "patch
	# notes" before the actual descent. Show once per tier per run.
	var next_floor: int = GameState.floor_num + 1
	if PatchNotes.has_notes_for(next_floor) and not GameState.patch_notes_seen.has(next_floor):
		_pending_next_floor = next_floor
		_load_scene(PATCH_NOTES_SCENE)
		return
	GameState.descend()

func _on_patch_notes_dismissed() -> void:
	GameState.patch_notes_seen.append(_pending_next_floor)
	_pending_next_floor = 0
	GameState.descend()
