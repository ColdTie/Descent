extends Node
## Central run state: current floor, hero stats, run seed, etc.
## Run 2: added total_kills tracking for death screen.

signal floor_changed(floor_num: int)
signal hero_died
signal run_started
signal level_up_ready(new_level: int)

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
var total_kills: int = 0    ## Run 2: accumulated across all floors

const XP_PER_LEVEL: int = 100

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
	var cls_data: Dictionary = Classes.get_class_data(class_id)
	hero_max_hp = cls_data.get("hp", 100)
	hero_hp = hero_max_hp
	## Array[String] can't be assigned from untyped get() — must iterate (see CLAUDE.md)
	hero_abilities.clear()
	var raw_abilities: Array = cls_data.get("abilities", [])
	for a: String in raw_abilities:
		hero_abilities.append(a)
	hero_base_stats = cls_data.get("stats", {}).duplicate()
	run_started.emit()

func descend() -> void:
	floor_num += 1
	floor_changed.emit(floor_num)

func gain_xp(amount: int) -> bool:
	hero_xp += amount
	if hero_xp >= hero_level * XP_PER_LEVEL:
		hero_xp -= hero_level * XP_PER_LEVEL
		hero_level += 1
		level_up_ready.emit(hero_level)
		return true  ## leveled up
	return false

func take_damage(amount: int) -> void:
	hero_hp = max(0, hero_hp - amount)
	if hero_hp <= 0:
		hero_died.emit()

func heal(amount: int) -> void:
	hero_hp = min(hero_max_hp, hero_hp + amount)

func add_kills(n: int) -> void:
	total_kills += n
