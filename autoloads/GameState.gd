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
var total_kills: int = 0  # enemies killed this run (for first-kill commentary)

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
	hero_abilities = cls_data.get("abilities", []).duplicate()
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
		return true  # leveled up
	return false

func take_damage(amount: int) -> void:
	hero_hp = max(0, hero_hp - amount)
	if hero_hp <= 0:
		hero_died.emit()

func heal(amount: int) -> void:
	hero_hp = min(hero_max_hp, hero_hp + amount)

func heal_between_floors() -> void:
	## Passive HP trickle between floors (~8% of max HP, minimum 5).
	var regen: int = max(5, int(hero_max_hp * 0.08))
	heal(regen)
