class_name Ability
## Pure data + logic for an ability. No Node dependency.

enum TargetType { SELF, SINGLE_ENEMY, ALL_ENEMIES, CONE, LINE }
enum AbilityType { ATTACK, HEAL, BUFF, DEBUFF, MOVE }

var id: String = ""
var display_name: String = ""
var description: String = ""
var ability_type: AbilityType = AbilityType.ATTACK
var target_type: TargetType = TargetType.SINGLE_ENEMY
var base_damage: int = 0
var base_heal: int = 0
var max_charges: int = 1
var current_charges: int = 1
var cooldown_turns: int = 0
var cooldown_remaining: int = 0
var range_tiles: int = 1
var xp_cost: int = 0  # for upgrade screen
var icon_key: String = ""

func _init(p_id: String, p_name: String) -> void:
	id = p_id
	display_name = p_name

func can_use() -> bool:
	if max_charges == -1:
		return true  # unlimited
	return current_charges > 0

func use() -> bool:
	if not can_use():
		return false
	if max_charges > 0:
		current_charges -= 1
	cooldown_remaining = cooldown_turns
	return true

func tick_cooldown() -> void:
	if cooldown_remaining > 0:
		cooldown_remaining -= 1
	if cooldown_remaining == 0 and current_charges < max_charges:
		current_charges = min(max_charges, current_charges + 1)

func recharge_full() -> void:
	current_charges = max_charges
	cooldown_remaining = 0
