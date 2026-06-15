extends Node
## Run 19: DCC-style achievement system.
##
## The System announces unlocks in a top-right toast. Each achievement has a
## name, hidden flag, and an unlock condition that's evaluated externally
## (BattleScene/GameState call `unlock()` when they detect a trigger).
##
## State is per-run: cleared on `GameState.run_started`. End-of-run screens read
## `unlocked_ids` to show what the player earned.

signal achievement_unlocked(id: String, def: Dictionary)

const DEFS: Dictionary = {
	"first_blood": {
		"name": "First Blood",
		"desc": "Kill an enemy. The dungeon files the paperwork.",
		"hidden": false,
		"audience": 10,
	},
	"boss_slayer": {
		"name": "Boss Slayer",
		"desc": "Drop a boss-tier entity. The dungeon's HR department is short one VIP.",
		"hidden": false,
		"audience": 40,
	},
	"untouchable": {
		"name": "Untouchable",
		"desc": "Clear a floor without taking a single point of damage.",
		"hidden": false,
		"audience": 50,
	},
	"crit_streak": {
		"name": "Crit Streak",
		"desc": "Land 3 critical hits on the same floor. The dungeon flinches.",
		"hidden": false,
		"audience": 30,
	},
	"lava_lord": {
		"name": "Lava Lord",
		"desc": "Push 3 enemies into lava across the run. Physics, weaponized.",
		"hidden": false,
		"audience": 35,
	},
	"the_descent": {
		"name": "Halfway to Hell",
		"desc": "Reach floor 9. Significantly deeper than expected.",
		"hidden": false,
		"audience": 25,
	},
	"deep_dweller": {
		"name": "Deep Dweller",
		"desc": "Reach floor 15. The dungeon is now visibly annoyed.",
		"hidden": false,
		"audience": 40,
	},
	"descended": {
		"name": "The Descent",
		"desc": "Clear all 18 floors. The dungeon files a formal grievance.",
		"hidden": false,
		"audience": 200,
	},
	"low_hp_hero": {
		"name": "Statistical Anomaly",
		"desc": "Win a battle with under 20% HP. The audience loved that.",
		"hidden": false,
		"audience": 25,
	},
	"team_player": {
		"name": "Team Player",
		"desc": "Keep both Floor-3 allies alive through their battle.",
		"hidden": false,
		"audience": 30,
	},
	"combo_master": {
		"name": "Combo Master",
		"desc": "Use 4 different abilities in a single floor.",
		"hidden": false,
		"audience": 25,
	},
	"headshot": {
		"name": "Clean Cut",
		"desc": "One-shot any enemy. Quick. Quiet. The dungeon is impressed.",
		"hidden": false,
		"audience": 20,
	},
	"enrage_killer": {
		"name": "Phase Two Survivor",
		"desc": "Kill a boss after it enters its enraged state.",
		"hidden": false,
		"audience": 35,
	},
	"speed_run": {
		"name": "Efficient",
		"desc": "Clear any floor in 6 of your own turns or fewer.",
		"hidden": false,
		"audience": 25,
	},
}


var unlocked_ids: Array[String] = []
var _floor_state: Dictionary = {}


func _ready() -> void:
	# Duck-typed singleton lookup so this script still compiles in --script
	# test mode where autoloads aren't registered yet.
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.connect("run_started",  _on_run_started)
		gs.connect("floor_changed", _on_floor_changed)


func _on_run_started() -> void:
	unlocked_ids.clear()
	_floor_state.clear()


func _on_floor_changed(_floor_num: int) -> void:
	## Reset per-floor counters (crit streak, ability variety, turn count).
	_floor_state = {
		"crits": 0,
		"abilities_used": {},
		"hero_turns": 0,
		"took_damage": false,
	}


func is_unlocked(id: String) -> bool:
	return unlocked_ids.has(id)


func unlock(id: String) -> bool:
	## Returns true if this was a NEW unlock (so callers can avoid duplicate
	## quips / audience awards). Safe to call repeatedly.
	if not DEFS.has(id):
		push_warning("Achievements.unlock: unknown id '%s'" % id)
		return false
	if unlocked_ids.has(id):
		return false
	unlocked_ids.append(id)
	var def: Dictionary = DEFS[id]
	# Duck-typed call so this script compiles cleanly without an autoload context
	# (matches the safer pattern used in _ready).
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("award_audience", int(def.get("audience", 10)), "achievement")
	# Run 37: first-ever unlock of this id pays the meta-progression bonus.
	# Duck-typed so this script still loads in --script test mode where
	# /root/MetaProgress isn't registered.
	var mp: Node = get_node_or_null("/root/MetaProgress")
	if mp != null:
		mp.call("award_for_achievement", id)
	achievement_unlocked.emit(id, def)
	return true


# ── Per-floor trackers (called from BattleScene) ──────────────────────────

func note_crit() -> void:
	_floor_state["crits"] = int(_floor_state.get("crits", 0)) + 1
	if int(_floor_state["crits"]) >= 3:
		unlock("crit_streak")


func note_ability_used(ability_id: String) -> void:
	var used: Dictionary = _floor_state.get("abilities_used", {})
	used[ability_id] = true
	_floor_state["abilities_used"] = used
	if used.size() >= 4:
		unlock("combo_master")


func note_hero_turn() -> void:
	_floor_state["hero_turns"] = int(_floor_state.get("hero_turns", 0)) + 1


func get_hero_turns_this_floor() -> int:
	return int(_floor_state.get("hero_turns", 0))


func note_hero_took_damage() -> void:
	_floor_state["took_damage"] = true


func took_damage_this_floor() -> bool:
	return bool(_floor_state.get("took_damage", false))
