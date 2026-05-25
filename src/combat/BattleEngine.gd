class_name BattleEngine
## Pure rules engine for one battle encounter.
## No Node dependency — driven by BattleScene for visuals.
## All randomness routes through the rng parameter for testability.

signal turn_started(combatant: Combatant)
signal action_taken(attacker: Combatant, target: Combatant, damage: int, ability_id: String)
signal combatant_died(combatant: Combatant)
signal battle_ended(hero_won: bool, xp_earned: int)
signal status_ticked(combatant: Combatant, damage: int)

var combatants: Array[Combatant] = []
var turn_order: Array[Combatant] = []
var current_turn_idx: int = 0
var turn_number: int = 0
var battle_over: bool = false
var hero_won: bool = false
var total_xp: int = 0

var rng: RandomNumberGenerator

func _init(p_rng: RandomNumberGenerator = null) -> void:
	if p_rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = 12345
	else:
		rng = p_rng

func setup(p_combatants: Array[Combatant]) -> void:
	combatants = p_combatants.duplicate()
	_build_turn_order()
	current_turn_idx = 0
	turn_number = 0
	battle_over = false
	hero_won = false
	total_xp = 0

func _build_turn_order() -> void:
	turn_order = combatants.duplicate()
	# Sort by speed descending, break ties by faction (hero goes first)
	turn_order.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		if a.speed != b.speed:
			return a.speed > b.speed
		return a.faction == Combatant.Faction.HERO
	)

func get_active_combatant() -> Combatant:
	if turn_order.is_empty():
		return null
	return turn_order[current_turn_idx % turn_order.size()]

func advance_to_next_living() -> void:
	## Advance current_turn_idx past dead combatants
	var checked: int = 0
	var size: int = turn_order.size()
	while checked < size:
		current_turn_idx = (current_turn_idx) % size
		if turn_order[current_turn_idx].is_alive():
			break
		current_turn_idx = (current_turn_idx + 1) % size
		checked += 1

func begin_turn() -> Combatant:
	if battle_over:
		return null
	_remove_dead_from_order()
	if _check_battle_end():
		return null
	advance_to_next_living()
	var active: Combatant = get_active_combatant()
	if active == null:
		return null
	turn_number += 1
	# Tick status effects
	var status_dmg: int = active.tick_statuses()
	if status_dmg > 0:
		status_ticked.emit(active, status_dmg)
	if not active.is_alive():
		_on_combatant_died(active)
		current_turn_idx = (current_turn_idx + 1) % max(1, turn_order.size())
		return begin_turn()
	turn_started.emit(active)
	return active

func perform_attack(attacker: Combatant, target: Combatant, ability_id: String = "basic_attack") -> int:
	## Returns damage dealt. Emits action_taken.
	var dmg: int = _calculate_damage(attacker, target, ability_id)
	var actual: int = target.take_damage(dmg)
	action_taken.emit(attacker, target, actual, ability_id)
	if not target.is_alive():
		_on_combatant_died(target)
	return actual

func _calculate_damage(attacker: Combatant, target: Combatant, ability_id: String) -> int:
	var ability_data: Dictionary = Abilities.get_ability(ability_id)
	var base: int = ability_data.get("base_damage", 10)
	# Add attacker stats
	var atk_bonus: int = attacker.to_dict().get("stats", {}).get("attack", 0)
	# Variance: ±20%
	var variance: float = rng.randf_range(0.8, 1.2)
	var raw: int = int(float(base + atk_bonus) * variance)
	var final_dmg: int = max(1, raw - target.get_effective_armor())
	return final_dmg

func enemy_ai_action(enemy: Combatant) -> void:
	## Simple AI: attack the hero
	var heroes: Array[Combatant] = combatants.filter(
		func(c: Combatant) -> bool: return c.faction == Combatant.Faction.HERO and c.is_alive()
	)
	if heroes.is_empty():
		return
	var target: Combatant = heroes[0]
	var ability_id: String = "basic_attack"
	if not enemy.abilities.is_empty():
		ability_id = enemy.abilities[rng.randi_range(0, enemy.abilities.size() - 1)]
	perform_attack(enemy, target, ability_id)

func end_turn() -> void:
	current_turn_idx = (current_turn_idx + 1) % max(1, turn_order.size())
	_check_battle_end()

func _remove_dead_from_order() -> void:
	turn_order = turn_order.filter(func(c: Combatant) -> bool: return c.is_alive())

func _check_battle_end() -> bool:
	var living_heroes: int = combatants.filter(
		func(c: Combatant) -> bool: return c.faction == Combatant.Faction.HERO and c.is_alive()
	).size()
	var living_enemies: int = combatants.filter(
		func(c: Combatant) -> bool: return c.faction == Combatant.Faction.ENEMY and c.is_alive()
	).size()
	if living_heroes == 0:
		battle_over = true
		hero_won = false
		battle_ended.emit(false, 0)
		return true
	if living_enemies == 0:
		battle_over = true
		hero_won = true
		# Sum XP from dead enemies
		for c in combatants:
			if c.faction == Combatant.Faction.ENEMY:
				total_xp += c.xp_reward
		battle_ended.emit(true, total_xp)
		return true
	return false

func _on_combatant_died(c: Combatant) -> void:
	combatant_died.emit(c)
