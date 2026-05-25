class_name BattleEngine
## Pure rules engine for one battle encounter.
## No Node dependency — driven by BattleScene for visuals.
## All randomness routes through the rng parameter for testability.

signal turn_started(combatant: Combatant)
signal turn_skipped(combatant: Combatant)
signal action_taken(attacker: Combatant, target: Combatant, damage: int, ability_id: String)
signal combatant_died(combatant: Combatant)
signal combatant_moved(combatant: Combatant, from_hex: Vector2i, to_hex: Vector2i)
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
	if size == 0:
		return
	while checked < size:
		current_turn_idx = current_turn_idx % size
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

	# Safety: cap iterations to avoid infinite loop when everyone is frozen
	var max_tries: int = turn_order.size() * 3 + 2
	var tries: int = 0

	while tries < max_tries:
		tries += 1
		advance_to_next_living()
		var active: Combatant = get_active_combatant()
		if active == null:
			return null

		turn_number += 1

		# Check frozen / skip_turn BEFORE ticking — tick consumes 1 duration
		if active.has_skip_turn():
			active.tick_statuses()
			turn_skipped.emit(active)
			current_turn_idx = (current_turn_idx + 1) % max(1, turn_order.size())
			continue

		# Normal status tick
		var status_dmg: int = active.tick_statuses()
		if status_dmg > 0:
			status_ticked.emit(active, status_dmg)

		if not active.is_alive():
			_on_combatant_died(active)
			_remove_dead_from_order()
			if _check_battle_end():
				return null
			current_turn_idx = current_turn_idx % max(1, turn_order.size())
			continue

		turn_started.emit(active)
		return active

	return null  # everyone frozen — shouldn't normally happen

## ─── Movement ─────────────────────────────────────────────────────────────────

func can_move_to(mover: Combatant, target_hex: Vector2i) -> bool:
	## Returns true if target_hex is adjacent and unoccupied by a living combatant.
	if HexGrid.hex_distance(mover.position, target_hex) != 1:
		return false
	for c: Combatant in combatants:
		if c.is_alive() and c != mover and c.position == target_hex:
			return false
	return true

func perform_move(mover: Combatant, target_hex: Vector2i) -> bool:
	## Move mover to target_hex. Returns false if illegal.
	if not can_move_to(mover, target_hex):
		return false
	var old_pos: Vector2i = mover.position
	mover.position = target_hex
	combatant_moved.emit(mover, old_pos, target_hex)
	return true

## ─── Combat ───────────────────────────────────────────────────────────────────

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
	# Add attacker stats bonus
	var atk_bonus: int = attacker.attack_bonus
	# Variance: ±20%
	var variance: float = rng.randf_range(0.8, 1.2)
	var raw: int = int(float(base + atk_bonus) * variance)

	# Check vanish multiplier — consume the status immediately
	var multiplier: float = 1.0
	if attacker.consume_status("vanish"):
		multiplier = 3.0

	# Armor (may be overridden by ability flag)
	var effective_armor: int = 0
	if not ability_data.get("ignore_armor", false):
		effective_armor = target.get_effective_armor()

	var final_dmg: int = max(1, int(float(raw - effective_armor) * multiplier))
	return final_dmg

## ─── Enemy AI ─────────────────────────────────────────────────────────────────

func enemy_ai_action(enemy: Combatant) -> void:
	var untyped: Array = combatants.filter(
		func(c: Combatant) -> bool: return c.faction == Combatant.Faction.HERO and c.is_alive()
	)
	if untyped.is_empty():
		return
	var hero: Combatant = untyped[0] as Combatant

	match enemy.ai_behavior:
		"rush":
			_ai_rush(enemy, hero)
		"flank":
			_ai_flank(enemy, hero)
		"ranged":
			_ai_ranged(enemy, hero)
		"cautious":
			_ai_cautious(enemy, hero)
		_:
			_ai_rush(enemy, hero)

func _ai_rush(enemy: Combatant, hero: Combatant) -> void:
	## Move toward hero; attack when in range.
	var ability_id: String = _pick_ability(enemy)
	var ability_data: Dictionary = Abilities.get_ability(ability_id)
	var attack_range: int = ability_data.get("range", 1)
	var dist: int = HexGrid.hex_distance(enemy.position, hero.position)
	if dist > attack_range:
		var best: Vector2i = _find_move_toward(enemy, hero.position)
		if best != enemy.position:
			perform_move(enemy, best)
		dist = HexGrid.hex_distance(enemy.position, hero.position)
	if dist <= attack_range:
		perform_attack(enemy, hero, ability_id)

func _ai_flank(enemy: Combatant, hero: Combatant) -> void:
	## Try to reach a hex adjacent to hero from an unexpected angle.
	var ability_id: String = _pick_ability(enemy)
	var ability_data: Dictionary = Abilities.get_ability(ability_id)
	var attack_range: int = ability_data.get("range", 1)
	var dist: int = HexGrid.hex_distance(enemy.position, hero.position)
	if dist > attack_range:
		# Try to move to a neighbor of the hero not directly in line
		var flank_hex: Vector2i = _find_flank_move(enemy, hero.position)
		if flank_hex != enemy.position:
			perform_move(enemy, flank_hex)
		dist = HexGrid.hex_distance(enemy.position, hero.position)
	if dist <= attack_range:
		perform_attack(enemy, hero, ability_id)

func _ai_ranged(enemy: Combatant, hero: Combatant) -> void:
	## Prefer staying at range 2-3; use ranged attack. Retreat if hero is adjacent.
	var ability_id: String = _pick_ranged_ability(enemy)
	var ability_data: Dictionary = Abilities.get_ability(ability_id)
	var attack_range: int = ability_data.get("range", 1)
	var dist: int = HexGrid.hex_distance(enemy.position, hero.position)

	# If hero is too close, try to retreat
	if dist <= 1:
		var retreat: Vector2i = _find_move_away(enemy, hero.position)
		if retreat != enemy.position:
			perform_move(enemy, retreat)
		dist = HexGrid.hex_distance(enemy.position, hero.position)

	if dist <= attack_range:
		perform_attack(enemy, hero, ability_id)

func _ai_cautious(enemy: Combatant, hero: Combatant) -> void:
	## Only moves if hero is more than 3 away; attacks when adjacent.
	var ability_id: String = _pick_ability(enemy)
	var dist: int = HexGrid.hex_distance(enemy.position, hero.position)
	if dist > 3:
		var best: Vector2i = _find_move_toward(enemy, hero.position)
		if best != enemy.position:
			perform_move(enemy, best)
		dist = HexGrid.hex_distance(enemy.position, hero.position)
	if dist <= 1:
		perform_attack(enemy, hero, ability_id)

## ─── AI Helpers ───────────────────────────────────────────────────────────────

func _pick_ability(enemy: Combatant) -> String:
	if enemy.abilities.is_empty():
		return "basic_attack"
	return enemy.abilities[rng.randi_range(0, enemy.abilities.size() - 1)]

func _pick_ranged_ability(enemy: Combatant) -> String:
	## Prefer abilities with range > 1; fall back to basic.
	for ab: String in enemy.abilities:
		if Abilities.get_ability(ab).get("range", 1) > 1:
			return ab
	return _pick_ability(enemy)

func _find_move_toward(mover: Combatant, target_hex: Vector2i) -> Vector2i:
	var neighbors: Array[Vector2i] = HexGrid.neighbors(mover.position)
	var best: Vector2i = mover.position
	var best_dist: int = HexGrid.hex_distance(mover.position, target_hex)
	for n: Vector2i in neighbors:
		if _is_hex_free(mover, n):
			var d: int = HexGrid.hex_distance(n, target_hex)
			if d < best_dist:
				best_dist = d
				best = n
	return best

func _find_move_away(mover: Combatant, threat_hex: Vector2i) -> Vector2i:
	var neighbors: Array[Vector2i] = HexGrid.neighbors(mover.position)
	var best: Vector2i = mover.position
	var best_dist: int = HexGrid.hex_distance(mover.position, threat_hex)
	for n: Vector2i in neighbors:
		if _is_hex_free(mover, n):
			var d: int = HexGrid.hex_distance(n, threat_hex)
			if d > best_dist:
				best_dist = d
				best = n
	return best

func _find_flank_move(mover: Combatant, target_hex: Vector2i) -> Vector2i:
	## Find a hex adjacent to target, not the closest to mover's current path.
	var hero_neighbors: Array[Vector2i] = HexGrid.neighbors(target_hex)
	var best: Vector2i = mover.position
	var best_dist: int = HexGrid.hex_distance(mover.position, target_hex)

	# Shuffle hero_neighbors for unpredictability
	var n: int = hero_neighbors.size()
	for i: int in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = hero_neighbors[i]
		hero_neighbors[i] = hero_neighbors[j]
		hero_neighbors[j] = tmp

	for flank: Vector2i in hero_neighbors:
		# This hex must be reachable in one step from mover
		if HexGrid.hex_distance(mover.position, flank) == 1 and _is_hex_free(mover, flank):
			best = flank
			break

	# Fall back to move-toward if no flank found
	if best == mover.position:
		best = _find_move_toward(mover, target_hex)
	return best

func _is_hex_free(mover: Combatant, hex: Vector2i) -> bool:
	for c: Combatant in combatants:
		if c.is_alive() and c != mover and c.position == hex:
			return false
	return true

## ─── Turn Management ──────────────────────────────────────────────────────────

func end_turn() -> void:
	current_turn_idx = (current_turn_idx + 1) % max(1, turn_order.size())
	_check_battle_end()

func _remove_dead_from_order() -> void:
	var filtered: Array = turn_order.filter(func(c: Combatant) -> bool: return c.is_alive())
	turn_order.clear()
	for c in filtered:
		turn_order.append(c as Combatant)

func _check_battle_end() -> bool:
	var untyped_heroes: Array = combatants.filter(
		func(c: Combatant) -> bool: return c.faction == Combatant.Faction.HERO and c.is_alive()
	)
	var untyped_enemies: Array = combatants.filter(
		func(c: Combatant) -> bool: return c.faction == Combatant.Faction.ENEMY and c.is_alive()
	)
	if untyped_heroes.is_empty():
		battle_over = true
		hero_won = false
		battle_ended.emit(false, 0)
		return true
	if untyped_enemies.is_empty():
		battle_over = true
		hero_won = true
		for c: Combatant in combatants:
			if c.faction == Combatant.Faction.ENEMY:
				total_xp += c.xp_reward
		battle_ended.emit(true, total_xp)
		return true
	return false

func _on_combatant_died(c: Combatant) -> void:
	combatant_died.emit(c)
