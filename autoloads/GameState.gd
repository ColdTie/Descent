extends Node
## Central run state: current floor, hero stats, run seed, etc.

signal floor_changed(floor_num: int)
signal hero_died
signal run_started

var run_seed: int = 0
var floor_num: int = 0
var hero_class: String = ""
var hero_hp: int = 0
var hero_max_hp: int = 0
var hero_xp: int = 0
var hero_level: int = 1
var hero_gold: int = 0
var hero_abilities: Array[String] = []
var hero_base_stats: Dictionary = {}

# Run statistics — for end-of-run score and summary screens
var total_kills: int = 0
var bosses_slain: int = 0

# Run 19: Audience score — DCC reality-show layer. Showy plays earn points
# (crits, lava kills, low-HP wins, achievements). `audience_score_floor` is the
# tally for the current floor; `audience_score` is the run total.
var audience_score: int = 0
var audience_score_floor: int = 0
# Run 19: lava-push kill counter for the "Lava Lord" achievement (run-wide).
var lava_push_kills: int = 0

# Run 19: signal fired whenever audience score changes — drives the HUD blip.
signal audience_gained(amount: int, reason: String)

const XP_PER_LEVEL: int = 100
const TOTAL_FLOORS: int = 18

func start_run(class_id: String, seed_val: int = -1) -> void:
	if seed_val < 0:
		seed_val = randi()
	run_seed = seed_val
	GameRng.reseed(seed_val)
	floor_num = 0
	hero_class = class_id
	hero_xp = 0
	hero_level = 1
	hero_gold = 0
	total_kills = 0
	bosses_slain = 0
	audience_score = 0
	audience_score_floor = 0
	lava_push_kills = 0
	var cls_data: Dictionary = Classes.get_class_data(class_id)
	hero_max_hp = cls_data.get("hp", 100)
	hero_hp = hero_max_hp
	hero_abilities.clear()
	var raw_abilities: Array = cls_data.get("abilities", [])
	for a: String in raw_abilities:
		hero_abilities.append(a)
	hero_base_stats = cls_data.get("stats", {}).duplicate()
	run_started.emit()

func descend() -> void:
	floor_num += 1
	audience_score_floor = 0
	floor_changed.emit(floor_num)


func award_audience(amount: int, reason: String = "") -> void:
	## Add audience favor — emits a signal so HUD widgets can react.
	## Pure addition; never negative.
	if amount <= 0:
		return
	audience_score += amount
	audience_score_floor += amount
	audience_gained.emit(amount, reason)

func gain_xp(amount: int) -> bool:
	hero_xp += amount
	if hero_xp >= hero_level * XP_PER_LEVEL:
		hero_xp -= hero_level * XP_PER_LEVEL
		hero_level += 1
		return true  # leveled up
	return false

func take_damage(amount: int) -> void:
	hero_hp = max(0, hero_hp - amount)
	if hero_hp <= 0:
		hero_died.emit()

func heal(amount: int) -> void:
	hero_hp = min(hero_max_hp, hero_hp + amount)

func regen_between_floors() -> int:
	var regen: int = max(5, hero_max_hp / 10)
	var old_hp: int = hero_hp
	hero_hp = min(hero_max_hp, hero_hp + regen)
	return hero_hp - old_hp

func run_score() -> int:
	## Composite end-of-run score: depth dominates, with bonuses for kills,
	## bosses, level, and audience favor (Run 19). Used on the win / death
	## summary screens.
	return floor_num * 1000 + total_kills * 25 + bosses_slain * 250 \
		+ hero_level * 100 + audience_score * 2
