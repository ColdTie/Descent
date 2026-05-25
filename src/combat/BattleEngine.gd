class_name BattleEngine
## Pure rules engine for one battle encounter.
## No Node dependency — driven by BattleScene for visuals.
## All randomness routes through the rng parameter for testability.

signal turn_started(combatant: Combatant)
signal action_taken(attacker: Combatant, target: Combatant, damage: int, ability_id: String)
signal combatant_died(combatant: Combatant)
signal battle_ended(hero_won: bool, xp_earned: int)
signal status_ticked(combatant: Combatant, damage: int)
signal combatant_moved(combatant: Combatant, from_hex: Vector2i, to_hex: Vector2i)  ## Run 2
signal buff_applied(combatant: Combatant, ability_id: String)                        ## Run 2

var combatants: Array[Combatant] = []
var turn_order: Array[Combatant] = []
var current_turn_idx: int = 0
var turn_number: int = 0
var battle_over: bool = false
var hero_won: bool = false
var total_xp: int = 0
var enemies_defeated: int = 0    ## Run 2: track for death screen

var rng: RandomNumberGenerator
var passable_tiles: Dictionary = {}   ## Run 2: hex -> bool, for enemy pathfinding

func _init(p_rng: RandomNumberGenerator = null) -> void:
	if p_rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = 12345
	else:
		rng = p_rng

## p_passable: DungeonMap.passable — hex->bool (only "floor" tiles are passable)
func setup(p_combatants: Array[Combatant], p_passable: Dictionary = {}) -> void:
	combatants = p_combatants.duplicate()
	passable_tiles = p_passable
	_build_turn_order()
	current_turn_idx = 0
	turn_number = 0
	battle_over = false
	hero_won = false
	total_xp = 0
	enemies_defeated = 0
	## Initialize ability states for all combatants
	for c: Combatant in combatants:
		c.init_ability_states()

func _build_turn_order() -> void:
	turn_order = combatants.duplicate()
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
	var checked: int = 0
	var size: int = turn_order.size()
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
	advance_to_next_living()
	var active: Combatant = get_active_combatant()
	if active == null:
		return null
	turn_number += 1

	## Tick ability cooldowns at turn start
	active.tick_ability_cooldowns()

	## Tick status effects
	var status_dmg: int = active.tick_statuses()
	if status_dmg > 0:
		status_ticked.emit(active, status_dmg)
	if not active.is_alive():
		_on_combatant_died(active)
		current_turn_idx = (current_turn_idx + 1) % max(1, turn_order.size())
		return begin_turn()

	## Skip-turn check (frozen, stunned, etc.)
	if active.has_skip_turn_effect():
		turn_started.emit(active)  ## So UI can show "FROZEN"
		current_turn_idx = (current_turn_idx + 1) % max(1, turn_order.size())
		## Guard against all-frozen infinite loop (shouldn't happen, but safety)
		if turn_number > 500:
			return null
		return begin_turn()

	turn_started.emit(active)
	return active

## ─── Damage Pipeline ──────────────────────────────────────────────────────────

func _calculate_raw_damage(attacker: Combatant, _target: Combatant, ability_id: String) -> int:
	## Returns raw damage BEFORE armor (armor is handled in take_damage).
	var ability_data: Dictionary = Abilities.get_ability(ability_id)
	var base: int = ability_data.get("base_damage", 10)
	var atk_bonus: int = attacker.attack_bonus  ## Run 2 fix: use actual attack_bonus field
	var variance: float = rng.randf_range(0.8, 1.2)
	var raw: int = int(float(base + atk_bonus) * variance)
	## Vanish multiplier: 3× damage on next attack
	if attacker.vanish_active:
		raw = raw * 3
		attacker.vanish_active = false
	return max(1, raw)

func _apply_damage_to(attacker: Combatant, target: Combatant, ability_id: String) -> void:
	var abl: Dictionary = Abilities.get_ability(ability_id)
	var ignore_armor: bool = abl.get("ignore_armor", false)
	var raw: int = _calculate_raw_damage(attacker, target, ability_id)
	var actual: int = target.take_damage(raw, ignore_armor)
	action_taken.emit(attacker, target, actual, ability_id)
	## Apply on-hit status effects
	if abl.get("applies_frozen", false):
		target.apply_status(StatusEffect.frozen(2))
	if not target.is_alive():
		_on_combatant_died(target)

## Legacy single-target attack — kept for test compatibility
func perform_attack(attacker: Combatant, target: Combatant, ability_id: String = "basic_attack") -> int:
	var abl: Dictionary = Abilities.get_ability(ability_id)
	var ignore_armor: bool = abl.get("ignore_armor", false)
	var raw: int = _calculate_raw_damage(attacker, target, ability_id)
	var actual: int = target.take_damage(raw, ignore_armor)
	attacker.use_ability(ability_id)
	action_taken.emit(attacker, target, actual, ability_id)
	if abl.get("applies_frozen", false):
		target.apply_status(StatusEffect.frozen(2))
	if not target.is_alive():
		_on_combatant_died(target)
	_check_battle_end()
	return actual

## ─── perform_action: handles all ability types ────────────────────────────────

func perform_action(attacker: Combatant, target_hex: Vector2i, ability_id: String) -> void:
	## Dispatches by ability target type. Called by BattleScene instead of perform_attack.
	if not attacker.can_use_ability(ability_id):
		return  ## Out of charges / on cooldown
	var abl: Dictionary = Abilities.get_ability(ability_id)
	var target_type: String = abl.get("target", "single_enemy")
	attacker.use_ability(ability_id)

	match target_type:
		"single_enemy":
			var target: Combatant = _find_combatant_at(target_hex)
			if target != null and target.faction != attacker.faction and target.is_alive():
				_apply_damage_to(attacker, target, ability_id)

		"all_enemies":
			## Fireball: center = target_hex, radius = abl.range
			## Frost Nova: center = attacker.position, radius = abl.range (1)
			var center: Vector2i
			if ability_id == "frost_nova":
				center = attacker.position
			else:
				center = target_hex
			var range_val: int = abl.get("range", 1)
			for c: Combatant in combatants:
				if c.faction != attacker.faction and c.is_alive():
					if HexGrid.hex_distance(center, c.position) <= range_val:
						_apply_damage_to(attacker, c, ability_id)

		"self":
			match ability_id:
				"taunt":
					var armor_bonus: int = abl.get("fortified_armor", 5)
					var duration: int = abl.get("fortified_duration", 3)
					attacker.apply_status(StatusEffect.fortified(duration, armor_bonus))
					buff_applied.emit(attacker, ability_id)
				"vanish":
					attacker.vanish_active = true
					buff_applied.emit(attacker, ability_id)
				_:
					buff_applied.emit(attacker, ability_id)

	_check_battle_end()

## ─── Movement ─────────────────────────────────────────────────────────────────

func move_combatant(c: Combatant, dest: Vector2i) -> bool:
	## Moves combatant to dest hex. Caller validates passability + occupancy.
	var from: Vector2i = c.position
	c.position = dest
	combatant_moved.emit(c, from, dest)
	return true

func _find_combatant_at(hex: Vector2i) -> Combatant:
	for c: Combatant in combatants:
		if c.is_alive() and c.position == hex:
			return c
	return null

func _is_hex_occupied(hex: Vector2i) -> bool:
	for c: Combatant in combatants:
		if c.is_alive() and c.position == hex:
			return true
	return false

## Greedy pathfinding: pick adjacent passable unoccupied hex closest to target
func _find_best_move_toward(mover: Combatant, target_pos: Vector2i) -> Vector2i:
	var best: Vector2i = mover.position
	var best_dist: int = HexGrid.hex_distance(mover.position, target_pos)
	for neighbor: Vector2i in HexGrid.neighbors(mover.position):
		## Must be passable OR no passable data provided
		if not passable_tiles.is_empty() and not passable_tiles.get(neighbor, false):
			continue
		if _is_hex_occupied(neighbor):
			continue
		var d: int = HexGrid.hex_distance(neighbor, target_pos)
		if d < best_dist:
			best_dist = d
			best = neighbor
	return best

## ─── Enemy AI ─────────────────────────────────────────────────────────────────

func enemy_ai_action(enemy: Combatant) -> void:
	## .filter() returns untyped Array — use loop instead (CLAUDE.md gotcha)
	var heroes: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.faction == Combatant.Faction.HERO and c.is_alive():
			heroes.append(c)
	if heroes.is_empty():
		return
	var target: Combatant = heroes[0]

	## Pick usable ability
	var usable: Array[String] = []
	for abl_id: String in enemy.abilities:
		if enemy.can_use_ability(abl_id):
			usable.append(abl_id)
	if usable.is_empty():
		## All on cooldown — still try basic_attack as fallback
		usable = ["basic_attack"]

	var ability_id: String = usable[rng.randi_range(0, usable.size() - 1)]
	var abl: Dictionary = Abilities.get_ability(ability_id)
	var attack_range: int = abl.get("range", 1)
	var dist: int = HexGrid.hex_distance(enemy.position, target.position)

	## Ranged enemies (range ≥ 3) prefer to stand still and shoot
	var prefers_ranged: bool = (attack_range >= 3)

	if dist <= attack_range:
		## In range: attack
		perform_action(enemy, target.position, ability_id)
	elif not prefers_ranged:
		## Close-range enemy: move toward hero
		var dest: Vector2i = _find_best_move_toward(enemy, target.position)
		if dest != enemy.position:
			move_combatant(enemy, dest)
		## Re-check range after moving
		dist = HexGrid.hex_distance(enemy.position, target.position)
		if dist <= attack_range:
			perform_action(enemy, target.position, ability_id)
	## Ranged enemy out of range: do nothing (wait for hero to approach)

## ─── Turn Management ──────────────────────────────────────────────────────────

func end_turn() -> void:
	current_turn_idx = (current_turn_idx + 1) % max(1, turn_order.size())
	_check_battle_end()

func _remove_dead_from_order() -> void:
	var filtered: Array[Combatant] = []
	for c: Combatant in turn_order:
		if c.is_alive():
			filtered.append(c)
	turn_order = filtered

func _check_battle_end() -> bool:
	var living_heroes: int = 0
	var living_enemies: int = 0
	for c: Combatant in combatants:
		if c.is_alive():
			if c.faction == Combatant.Faction.HERO:
				living_heroes += 1
			else:
				living_enemies += 1
	if living_heroes == 0:
		battle_over = true
		hero_won = false
		battle_ended.emit(false, 0)
		return true
	if living_enemies == 0:
		battle_over = true
		hero_won = true
		for c: Combatant in combatants:
			if c.faction == Combatant.Faction.ENEMY:
				total_xp += c.xp_reward
		battle_ended.emit(true, total_xp)
		return true
	return false

func _on_combatant_died(c: Combatant) -> void:
	if c.faction == Combatant.Faction.ENEMY:
		enemies_defeated += 1
	combatant_died.emit(c)
