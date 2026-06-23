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
const SHOP_SCENE := "res://scenes/Shop.tscn"
const META_SCENE := "res://scenes/MetaScreen.tscn"

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
# Run 36: ensures `_record_meta_end` only fires once per run (death OR win,
# whichever happens first). Reset in `_on_run_started`.
var _meta_recorded: bool = false
# Run 44: skins / perk-slot unlocks the win just earned. Captured in
# `_record_meta_end(true)` by comparing pre/post `MetaProgress` state, then
# passed through `_load_scene` → `WinScreen.prepare` so the win screen can
# show a single-paint toast banner instead of forcing the player to open the
# MetaScreen to notice. Reset in `_on_run_started` so a death-then-new-run
# can't leak the previous win's toasts onto the next win.
var _pending_unlocked_skins: Array[String] = []
var _pending_unlocked_perk_slots: int = 0

func _ready() -> void:
	GameState.run_started.connect(_on_run_started)
	GameState.floor_changed.connect(_on_floor_changed)
	GameState.hero_died.connect(_on_hero_died)
	_go_to_title()

func _go_to_title() -> void:
	_load_scene(TITLE_SCENE)

func _go_to_class_select() -> void:
	_load_scene(CLASS_SELECT_SCENE)

func _go_to_meta() -> void:
	_load_scene(META_SCENE)

func _on_new_run_requested() -> void:
	# Run 28: starting a brand-new run from the title screen — drop any
	# stale save so it can't reappear if the player escapes back to title
	# before reaching the first checkpoint.
	GameState.clear_save_on_disk()
	_go_to_class_select()

func _on_run_started() -> void:
	# Run 36: clear the meta-record guard so the next run-end pays out.
	_meta_recorded = false
	# Run 44: clear any pending unlock toasts so the next win starts clean.
	_pending_unlocked_skins.clear()
	_pending_unlocked_perk_slots = 0
	GameState.descend()

func _on_floor_changed(_floor_num: int) -> void:
	# Run 28: every floor entry is a stable checkpoint — combat hasn't started
	# yet, HP regen between floors has already applied, and any pending
	# upgrades/loot/shop choices are committed. Persist before loading the
	# scene so a crash/refresh during BattleScene init still has a save.
	_persist_run()
	_load_scene(BATTLE_SCENE)

func _on_hero_died() -> void:
	# Run 28: hero died — clear the save so the title screen doesn't offer
	# CONTINUE on a dead run. Then back to class select.
	GameState.clear_save_on_disk()
	# Run 36: pay out meta-progression shards for the depth reached + bosses
	# slain. Recorded before the title-screen route so the shard counter on
	# title reflects the new balance.
	_record_meta_end(false)
	await get_tree().create_timer(2.5).timeout
	_go_to_class_select()


func _on_hero_meta_died() -> void:
	## Run 45: BattleScene's death overlay signals that the hero just died and
	## the overlay is about to render. Run the meta-record now so the overlay
	## can read MetaProgress.shards for the payout breakdown. The existing
	## `_record_meta_end` guard prevents a double-pay if `_on_hero_died` later
	## fires for the same run (today only reachable via QUIT TO TITLE, which is
	## hidden behind the death overlay — but defense in depth).
	_record_meta_end(false)


func _record_meta_end(won: bool) -> void:
	## Run 36: idempotent run-end meta hook. Called from both the death path
	## and the WinScreen route — guarded by `_meta_recorded` so a quick win
	## (death follows immediately for any reason) doesn't double-pay.
	if _meta_recorded:
		return
	_meta_recorded = true
	# Run 44: capture pre-record state so a winning run can show "you just
	# unlocked X" toasts on the WinScreen. Both deltas are derived from the
	# same pre/post snapshot pair, so a single record_run_end call can't
	# desync them. Done unconditionally (the cost is two cheap reads) so we
	# don't have to branch the variable initialization on `won`.
	var prev_class_wins: int = MetaProgress.class_win_count(GameState.hero_class)
	var prev_stats: Dictionary = MetaProgress.lifetime_stats()
	MetaProgress.record_run_end(
		GameState.floor_num,
		GameState.bosses_slain,
		won,
		GameState.run_score(),
		GameState.hero_class,
	)
	if won:
		var new_class_wins: int = MetaProgress.class_win_count(GameState.hero_class)
		var new_stats: Dictionary = MetaProgress.lifetime_stats()
		_pending_unlocked_skins = Skins.newly_unlocked_in_range(
			GameState.hero_class, prev_class_wins, new_class_wins)
		_pending_unlocked_perk_slots = Perks.slots_gained(prev_stats, new_stats)


func _persist_run() -> void:
	## Run 28: snapshot GameState + Achievements.unlocked_ids to disk. Best
	## effort — silent if file I/O fails (the game keeps running unsaved).
	var ach: Node = get_node_or_null("/root/Achievements")
	var extra: Dictionary = {}
	if ach != null:
		var ids: Array = ach.get("unlocked_ids")
		if ids != null:
			extra["unlocked_achievements"] = ids.duplicate()
	GameState.write_save_to_disk(extra)


func _resume_from_save() -> void:
	## Run 28: TitleScreen → CONTINUE. Read the save, apply it to GameState
	## and Achievements, then drop into the saved floor's BattleScene.
	var data: Dictionary = GameState.read_save_from_disk()
	if data.is_empty():
		_go_to_class_select()
		return
	if not GameState.apply_snapshot(data):
		_go_to_class_select()
		return
	# Reseed RNG from the saved run seed so floor generation is at least
	# self-consistent across resumes within a single saved run.
	GameRng.reseed(GameState.run_seed)
	# Restore achievement unlocks before _load_scene → BattleScene fires the
	# floor_changed signal (which resets per-floor counters, not unlocks).
	var ach: Node = get_node_or_null("/root/Achievements")
	if ach != null:
		var saved_ids: Variant = data.get("unlocked_achievements", [])
		if saved_ids is Array:
			var typed_ids: Array[String] = []
			for v: Variant in saved_ids:
				typed_ids.append(String(v))
			ach.unlocked_ids = typed_ids
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
	# Pass pending data to scenes that accept it (e.g. VictoryScreen, PatchNotes)
	# Run 44: include the win-unlock deltas so WinScreen.prepare() can surface
	# them. Other scenes silently ignore unknown keys via dict.get() defaults.
	if _current_scene.has_method("prepare"):
		_current_scene.call("prepare", {
			"xp": _pending_xp,
			"kills": _pending_kills,
			"floor": _pending_next_floor,
			"unlocked_skins": _pending_unlocked_skins.duplicate(),
			"unlocked_perk_slots": _pending_unlocked_perk_slots,
		})
	add_child(_current_scene)
	# Connect signals
	if _current_scene.has_signal("battle_complete"):
		_current_scene.battle_complete.connect(_on_battle_complete)
	# Run 45: BattleScene emits `hero_meta_died` right before rendering its
	# death overlay so the meta-progression payout lands BEFORE the overlay
	# reads MetaProgress.shards for display. Routed through the same idempotent
	# `_record_meta_end(false)` the pause-menu QUIT-TO-TITLE path uses, so the
	# Main-level `_meta_recorded` flag prevents a double-pay if both paths fire
	# for the same run (impossible today — the pause menu is hidden behind the
	# death overlay — but defense in depth).
	if _current_scene.has_signal("hero_meta_died"):
		_current_scene.hero_meta_died.connect(_on_hero_meta_died)
	if _current_scene.has_signal("floor_cleared"):
		_current_scene.floor_cleared.connect(_on_floor_cleared)
	if _current_scene.has_signal("loot_chosen"):
		_current_scene.loot_chosen.connect(_on_loot_chosen)
	if _current_scene.has_signal("upgrade_chosen"):
		_current_scene.upgrade_chosen.connect(_on_upgrade_chosen)
	if _current_scene.has_signal("play_again"):
		_current_scene.play_again.connect(_go_to_class_select)
	if _current_scene.has_signal("start_game"):
		_current_scene.start_game.connect(_on_new_run_requested)
	if _current_scene.has_signal("continue_run"):
		_current_scene.continue_run.connect(_resume_from_save)
	if _current_scene.has_signal("sponsor_chosen"):
		_current_scene.sponsor_chosen.connect(_on_sponsor_chosen)
	if _current_scene.has_signal("patch_notes_dismissed"):
		_current_scene.patch_notes_dismissed.connect(_on_patch_notes_dismissed)
	if _current_scene.has_signal("shop_left"):
		_current_scene.shop_left.connect(_on_shop_left)
	# Run 36: TitleScreen → META button opens the meta-progression screen.
	# When the player backs out of MetaScreen we return to TitleScreen so
	# they can re-read the (possibly updated) shard counter / CONTINUE state.
	if _current_scene.has_signal("open_meta"):
		_current_scene.open_meta.connect(_go_to_meta)
	if _current_scene.has_signal("meta_closed"):
		_current_scene.meta_closed.connect(_go_to_title)

func _on_battle_complete(hero_won: bool, xp_earned: int, enemies_killed: int) -> void:
	if not hero_won:
		# Hero died — reset and go back to class select
		GameState.hero_hp = 0
		_go_to_class_select()
		return
	# Store data for VictoryScreen + accumulate run stats.
	# Run 32: apply the one-shot Combat Instincts XP bonus here so the boosted
	# number is what the VictoryScreen displays AND what gain_xp later consumes.
	_pending_xp = GameState.consume_xp_bonus(xp_earned)
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
		# Run 28: run complete — clear the save so CONTINUE doesn't dangle.
		GameState.clear_save_on_disk()
		# Run 36: pay out the full-clear shard bonus (+ first-class-win) so the
		# WinScreen can read the new balance on its first frame.
		_record_meta_end(true)
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
	_route_to_shop_or_descend()

func _on_patch_notes_dismissed() -> void:
	GameState.patch_notes_seen.append(_pending_next_floor)
	_pending_next_floor = 0
	_route_to_shop_or_descend()

func _route_to_shop_or_descend() -> void:
	## Run 21: between loot/patch-notes and the actual descent, the merchant
	## may take a turn. Cadence + affordability gating live in Shop.gd.
	if Shop.should_show_shop(GameState.floor_num, GameState.hero_gold):
		_load_scene(SHOP_SCENE)
		return
	GameState.descend()

func _on_shop_left() -> void:
	GameState.descend()
