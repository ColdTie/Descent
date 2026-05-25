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
var attack_bonus: int = 0        ## Added Run 2: actually apply hero's attack stat
var speed: int = 0               ## higher = acts earlier in turn order
var position: Vector2i = Vector2i.ZERO   ## hex grid coords (q, r)
var status_effects: Array[Dictionary] = []
var abilities: Array[String] = []
var ability_states: Dictionary = {}  ## ability_id -> {current_charges, cooldown_remaining}
var xp_reward: int = 0
var sprite_key: String = ""
var vanish_active: bool = false   ## Run 2: 3× damage multiplier on next attack

func _init(p_id: String, p_name: String, p_faction: Faction, p_hp: int, p_speed: int = 10) -> void:
	id = p_id
	display_name = p_name
	faction = p_faction
	max_hp = p_hp
	hp = p_hp
	speed = p_speed

func is_alive() -> bool:
	return hp > 0

## Run 2: raw damage; armor mitigation happens in BattleEngine._calculate_damage.
## ignore_armor=true for backstab-style abilities.
func take_damage(amount: int, ignore_armor: bool = false) -> int:
	var armor_val: int = 0 if ignore_armor else get_effective_armor()
	var actual: int = max(0, amount - armor_val)
	hp = max(0, hp - actual)
	return actual

func heal(amount: int) -> int:
	var actual: int = min(amount, max_hp - hp)
	hp += actual
	return actual

func apply_status(effect: Dictionary) -> void:
	## effect: {id, name, duration, damage_per_turn, armor_mod}
	## Stack: remove any existing same-id status, then add (refresh)
	status_effects = status_effects.filter(func(e: Dictionary) -> bool: return e.get("id", "") != effect.get("id", ""))
	status_effects.append(effect)

func tick_statuses() -> int:
	## Applies per-turn effects, returns total damage taken.
	## Does NOT skip turn here — caller checks has_skip_turn_effect() after.
	var total_dmg: int = 0
	var remaining: Array[Dictionary] = []
	for eff: Dictionary in status_effects:
		if eff.has("damage_per_turn") and eff["damage_per_turn"] > 0:
			var dmg: int = eff["damage_per_turn"]
			hp = max(0, hp - dmg)
			total_dmg += dmg
		eff["duration"] -= 1
		if eff["duration"] > 0:
			remaining.append(eff)
	status_effects = remaining
	return total_dmg

func has_skip_turn_effect() -> bool:
	## Returns true if combatant is frozen (or has any skip_turn status).
	for eff: Dictionary in status_effects:
		if eff.get("skip_turn", false):
			return true
	return false

func get_effective_armor() -> int:
	var bonus: int = 0
	for eff: Dictionary in status_effects:
		bonus += eff.get("armor_mod", 0)
	return armor + bonus

## ─── Ability Charge / Cooldown ────────────────────────────────────────────────

func init_ability_states() -> void:
	## Must be called after abilities array is set.
	## Reads initial charges from Abilities data.
	ability_states.clear()
	for ability_id: String in abilities:
		var abl: Dictionary = Abilities.get_ability(ability_id)
		var max_ch: int = abl.get("max_charges", -1)
		ability_states[ability_id] = {
			"max_charges": max_ch,
			"current_charges": max_ch,  ## -1 = unlimited
			"cooldown_turns": abl.get("cooldown_turns", 0),
			"cooldown_remaining": 0,
		}

func can_use_ability(ability_id: String) -> bool:
	if not ability_states.has(ability_id):
		return true  ## Unknown ability — allow (backwards compat)
	var state: Dictionary = ability_states[ability_id]
	var max_ch: int = state.get("max_charges", -1)
	if max_ch < 0:
		return true  ## Unlimited charges
	return state.get("current_charges", 0) > 0 and state.get("cooldown_remaining", 0) == 0

func use_ability(ability_id: String) -> void:
	if not ability_states.has(ability_id):
		return
	var state: Dictionary = ability_states[ability_id]
	var max_ch: int = state.get("max_charges", -1)
	if max_ch >= 0:
		state["current_charges"] = max(0, state.get("current_charges", 1) - 1)
	state["cooldown_remaining"] = state.get("cooldown_turns", 0)

func tick_ability_cooldowns() -> void:
	## Called at the start of each of this combatant's turns.
	for ability_id: String in ability_states:
		var state: Dictionary = ability_states[ability_id]
		var cd: int = state.get("cooldown_remaining", 0)
		if cd > 0:
			cd -= 1
			state["cooldown_remaining"] = cd
		## Refill charge when cooldown finishes
		if cd == 0:
			var max_ch: int = state.get("max_charges", -1)
			if max_ch > 0:
				state["current_charges"] = min(max_ch, state.get("current_charges", 0) + 1)

func recharge_all() -> void:
	for ability_id: String in ability_states:
		var state: Dictionary = ability_states[ability_id]
		var max_ch: int = state.get("max_charges", -1)
		if max_ch >= 0:
			state["current_charges"] = max_ch
		state["cooldown_remaining"] = 0

## ─── Serialization ────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"faction": faction,
		"hp": hp,
		"max_hp": max_hp,
		"armor": armor,
		"attack_bonus": attack_bonus,
		"speed": speed,
		"position": {"q": position.x, "r": position.y},
		"status_effects": status_effects.duplicate(true),
		"abilities": abilities.duplicate(),
		"xp_reward": xp_reward,
		"vanish_active": vanish_active,
	}
