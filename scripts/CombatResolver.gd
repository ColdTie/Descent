## CombatResolver — pure static combat math.
##
## All functions take primitive values (ints, strings) rather than Node/Resource
## objects so they can be unit-tested without a running scene tree.
## The rng argument must expose d20() -> int and roll_dice(String) -> int;
## pass the GameRng autoload during play or a seeded test instance in tests.
##
## IMPORTANT: this script does NOT modify any unit's HP.
## The caller (TurnManager) applies damage/healing after inspecting the result.
class_name CombatResolver


## Resolve an attack roll.
##
## Parameters:
##   to_hit_bonus  — weapon's to_hit field
##   damage_dice   — weapon's damage_dice notation (e.g. "1d6")
##   defense       — defender's defense stat
##   current_hp    — defender's current HP (used only to compute 'killed')
##   rng           — object with d20() -> int and roll_dice(String) -> int
##
## Returns a Dictionary:
##   hit     bool   — true if roll >= defense
##   roll    int    — the full to-hit roll (d20 + to_hit_bonus)
##   damage  int    — damage rolled on a hit (0 on miss or empty damage_dice)
##   killed  bool   — true if (current_hp - damage) <= 0 on a hit
static func resolve_attack(
		to_hit_bonus: int,
		damage_dice:  String,
		defense:      int,
		current_hp:   int,
		rng) -> Dictionary:

	var d20_result: int = rng.d20()
	var roll: int = d20_result + to_hit_bonus
	var hit: bool = roll >= defense
	var damage: int = 0
	var killed: bool = false

	if hit and damage_dice != "":
		damage = rng.roll_dice(damage_dice)
		killed = (current_hp - damage) <= 0

	return {
		"hit":    hit,
		"roll":   roll,
		"damage": damage,
		"killed": killed,
	}


## Resolve a consumable heal item.
##
## Parameters:
##   heal_dice — weapon's heal_dice notation (e.g. "1d6")
##   rng       — object with roll_dice(String) -> int
##
## Returns the number of HP restored (0 if heal_dice is empty).
static func resolve_heal(heal_dice: String, rng) -> int:
	if heal_dice == "":
		return 0
	return rng.roll_dice(heal_dice)


## Convenience: build the resolver inputs from Unit + Weapon objects and call
## resolve_attack.  Keeps call sites concise in TurnManager.
static func attack_units(attacker: Unit, defender: Unit, rng) -> Dictionary:
	var w: Weapon = attacker.get_attack_weapon()
	if w == null:
		return {"hit": false, "roll": 0, "damage": 0, "killed": false}
	return resolve_attack(w.to_hit, w.damage_dice, defender.defense, defender.hp, rng)
