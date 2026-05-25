class_name Combatant
## Pure data class representing one fighter in a battle.
## No Node inheritance — fully serializable, testable headlessly.

enum Faction { HERO, ENEMY }

var id: String = ""
var display_name: String = ""
var faction: Faction = Faction.ENEMY
var hp: int = 0
var max_hp: int = 0
var armor: int = 0
var speed: int = 0  # higher = acts earlier in turn order
var position: Vector2i = Vector2i.ZERO  # hex grid coords (q, r)
var status_effects: Array[Dictionary] = []
var abilities: Array[String] = []
var xp_reward: int = 0
var sprite_key: String = ""
var stats: Dictionary = {}  # {attack, defense, speed} — for hero, mirrors GameState

func _init(p_id: String, p_name: String, p_faction: Faction, p_hp: int, p_speed: int = 10) -> void:
	id = p_id
	display_name = p_name
	faction = p_faction
	max_hp = p_hp
	hp = p_hp
	speed = p_speed

func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int, ignore_armor: bool = false) -> int:
	## Returns actual damage dealt. Armor is applied here (not in BattleEngine).
	var net_armor: int = 0 if ignore_armor else get_effective_armor()
	var dealt: int = max(0, amount - net_armor)
	hp = max(0, hp - dealt)
	return dealt

func heal(amount: int) -> int:
	var actual: int = min(amount, max_hp - hp)
	hp += actual
	return actual

func apply_status(effect: Dictionary) -> void:
	# effect: {id, name, duration, damage_per_turn, armor_mod, skip_turn, ...}
	status_effects.append(effect)

func has_status(status_id: String) -> bool:
	for eff: Dictionary in status_effects:
		if eff.get("id", "") == status_id:
			return true
	return false

func remove_status(status_id: String) -> void:
	var remaining: Array[Dictionary] = []
	for eff: Dictionary in status_effects:
		if eff.get("id", "") != status_id:
			remaining.append(eff)
	status_effects = remaining

func tick_statuses() -> int:
	## Applies per-turn effects, returns total damage taken.
	var total_dmg: int = 0
	var remaining: Array[Dictionary] = []
	for eff: Dictionary in status_effects:
		if eff.has("damage_per_turn"):
			var dmg: int = eff["damage_per_turn"]
			hp = max(0, hp - dmg)
			total_dmg += dmg
		eff["duration"] -= 1
		if eff["duration"] > 0:
			remaining.append(eff)
	status_effects = remaining
	return total_dmg

func get_effective_armor() -> int:
	var bonus: int = 0
	for eff: Dictionary in status_effects:
		bonus += eff.get("armor_mod", 0)
	return armor + bonus

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"faction": faction,
		"hp": hp,
		"max_hp": max_hp,
		"armor": armor,
		"speed": speed,
		"stats": stats.duplicate(),
		"position": {"q": position.x, "r": position.y},
		"status_effects": status_effects.duplicate(true),
		"abilities": abilities.duplicate(),
		"xp_reward": xp_reward,
	}
