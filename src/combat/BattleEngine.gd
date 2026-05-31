class_name BattleEngine
## Pure rules engine for one battle encounter.
## No Node dependency — driven by BattleScene for visuals.
## All randomness routes through the rng parameter for testability.

signal turn_started(combatant: Combatant)
signal action_taken(attacker: Combatant, target: Combatant, damage: int, ability_id: String)
signal combatant_died(combatant: Combatant)
signal battle_ended(hero_won: bool, xp_earned: int)
signal status_ticked(combatant: Combatant, damage: int)
signal hero_moved(combatant: Combatant, from_hex: Vector2i, to_hex: Vector2i)
signal boss_enraged(boss: Combatant)

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
	var ability_data: Dictionary = Abilities.get_ability(ability_id)
	var ignore_armor: bool = ability_data.get("ignore_armor", false)
	var actual: int = target.take_damage(dmg, ignore_armor)
	action_taken.emit(attacker, target, actual, ability_id)
	if not target.is_alive():
		_on_combatant_died(target)
	else:
		_check_boss_enrage(target)
	return actual

func _check_boss_enrage(c: Combatant) -> void:
	if not c.is_boss or c.is_enraged:
		return
	var hp_ratio: float = float(c.hp) / float(max(1, c.max_hp))
	if hp_ratio < 0.30:
		c.is_enraged = true
		c.speed += 4
		c.attack_bonus += 4
		boss_enraged.emit(c)

func perform_aoe_attack(attacker: Combatant, targets: Array[Combatant], ability_id: String) -> Array[int]:
	## Attack all targets with ability_id, returning list of damage values dealt.
	var results: Array[int] = []
	for target: Combatant in targets:
		results.append(perform_attack(attacker, target, ability_id))
	return results

func apply_environment_damage(c: Combatant, dmg: int) -> int:
	## Apply damage from environmental sources (lava heat, etc.).
	## Bypasses armor — environment is indifferent to your plate mail.
	## Returns actual damage dealt. Handles death if HP hits 0.
	var actual: int = c.take_damage(dmg, true)  # ignore_armor = true
	if not c.is_alive():
		_on_combatant_died(c)
	return actual

func _calculate_damage(attacker: Combatant, target: Combatant, ability_id: String) -> int:
	## Returns raw damage before armor reduction.
	## Armor is applied by the caller via take_damage(dmg, ignore_armor).
	var ability_data: Dictionary = Abilities.get_ability(ability_id)
	var base: int = ability_data.get("base_damage", 10)
	# Add attacker flat attack bonus
	var atk_bonus: int = attacker.attack_bonus
	# Variance: ±20%
	var variance: float = rng.randf_range(0.8, 1.2)
	var raw: int = int(float(base + atk_bonus) * variance)
	# Check for vanished multiplier (consumed on first attack)
	var vanish_mult: float = 1.0
	var new_statuses: Array[Dictionary] = []
	for eff: Dictionary in attacker.status_effects:
		if eff.get("id", "") == "vanished":
			vanish_mult = eff.get("damage_multiplier", 1.0)
		else:
			new_statuses.append(eff)
	if vanish_mult != 1.0:
		attacker.status_effects = new_statuses
	raw = int(float(raw) * vanish_mult)
	# Guarantee minimum 1 raw damage (armor may still reduce to 0)
	return max(1, raw)

func enemy_ai_action(enemy: Combatant, map: DungeonMap = null) -> void:
	## Smart AI based on enemy type (sprite_key)
	if is_combatant_frozen(enemy):
		return  # frozen enemies skip their turn
	var heroes: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.faction == Combatant.Faction.HERO and c.is_alive():
			heroes.append(c)
	if heroes.is_empty():
		return
	# Vanished heroes are invisible — enemies skip their turn rather than targeting them
	var visible_heroes: Array[Combatant] = []
	for c: Combatant in heroes:
		var is_vanished: bool = false
		for eff: Dictionary in c.status_effects:
			if eff.get("id", "") == "vanished":
				is_vanished = true
				break
		if not is_vanished:
			visible_heroes.append(c)
	if visible_heroes.is_empty():
		return  # all heroes vanished — enemy idles
	# Target the nearest visible hero
	var target: Combatant = visible_heroes[0]
	var best_target_dist: int = HexGrid.hex_distance(enemy.position, target.position)
	for h: Combatant in visible_heroes:
		var d: int = HexGrid.hex_distance(enemy.position, h.position)
		if d < best_target_dist:
			best_target_dist = d
			target = h

	match enemy.sprite_key:
		"golem":
			# Golems stay put, only use ranged ability if in range
			var ranged_id: String = "enemy_fireball"
			if enemy.abilities.has(ranged_id) and HexGrid.is_in_range(enemy.position, target.position, 3):
				perform_attack(enemy, target, ranged_id)
			# else do nothing (too far, wait)
		"goblin":
			# Goblins try to flank: move if not adjacent, then attack
			var dist: int = HexGrid.hex_distance(enemy.position, target.position)
			if dist > 1 and map != null:
				_move_toward(enemy, target.position, map)
			if HexGrid.hex_distance(enemy.position, target.position) <= 1:
				var ability_id: String = enemy.abilities[rng.randi_range(0, enemy.abilities.size() - 1)]
				perform_attack(enemy, target, ability_id)
		"imp":
			# Imps rush: always move toward hero, attack if adjacent
			var dist: int = HexGrid.hex_distance(enemy.position, target.position)
			if dist > 1 and map != null:
				_move_toward(enemy, target.position, map)
			if HexGrid.hex_distance(enemy.position, target.position) <= 1:
				perform_attack(enemy, target, "enemy_claw")
		"skeleton":
			# Skeletons with bone_volley prefer ranged; otherwise close and claw
			if enemy.abilities.has("bone_volley") and HexGrid.is_in_range(enemy.position, target.position, 3):
				perform_attack(enemy, target, "bone_volley")
			elif HexGrid.hex_distance(enemy.position, target.position) > 1 and map != null:
				_move_toward(enemy, target.position, map)
				if HexGrid.hex_distance(enemy.position, target.position) <= 1:
					perform_attack(enemy, target, "enemy_claw")
			else:
				perform_attack(enemy, target, "enemy_claw")
		"demon":
			# Demons with hellfire prefer AoE if any hero is within range 2;
			# otherwise advance and attack
			if enemy.abilities.has("hellfire_aoe"):
				var in_range_heroes: Array[Combatant] = []
				for h: Combatant in visible_heroes:
					if HexGrid.is_in_range(enemy.position, h.position, 2):
						in_range_heroes.append(h)
				if not in_range_heroes.is_empty():
					perform_aoe_attack(enemy, in_range_heroes, "hellfire_aoe")
					return
			var ddist: int = HexGrid.hex_distance(enemy.position, target.position)
			if ddist > 1 and map != null:
				_move_toward(enemy, target.position, map)
			if HexGrid.hex_distance(enemy.position, target.position) <= 1:
				var ability_id: String = enemy.abilities[rng.randi_range(0, enemy.abilities.size() - 1)]
				perform_attack(enemy, target, ability_id)
			elif enemy.abilities.has("enemy_fireball") and HexGrid.is_in_range(enemy.position, target.position, 3):
				perform_attack(enemy, target, "enemy_fireball")
		_:
			# Default: attack hero with random ability
			var ability_id: String = "basic_attack"
			if not enemy.abilities.is_empty():
				ability_id = enemy.abilities[rng.randi_range(0, enemy.abilities.size() - 1)]
			perform_attack(enemy, target, ability_id)

func _move_toward(mover: Combatant, goal: Vector2i, map: DungeonMap) -> void:
	## Move one step toward goal, picking passable, unoccupied neighbor closest to goal.
	var neighbors: Array[Vector2i] = HexGrid.neighbors(mover.position)
	var best: Vector2i = mover.position
	var best_dist: int = HexGrid.hex_distance(mover.position, goal)
	for n: Vector2i in neighbors:
		if not map.is_passable(n):
			continue
		# Collision avoidance: skip hexes occupied by other living combatants
		var occupied: bool = false
		for c: Combatant in combatants:
			if c.is_alive() and c != mover and c.position == n:
				occupied = true
				break
		if occupied:
			continue
		var d: int = HexGrid.hex_distance(n, goal)
		if d < best_dist:
			best_dist = d
			best = n
	if best != mover.position:
		mover.position = best

func end_turn() -> void:
	current_turn_idx = (current_turn_idx + 1) % max(1, turn_order.size())
	_check_battle_end()

func _remove_dead_from_order() -> void:
	var new_order: Array[Combatant] = []
	for c: Combatant in turn_order:
		if c.is_alive():
			new_order.append(c)
	turn_order = new_order

func _check_battle_end() -> bool:
	if battle_over:
		return true  # already ended externally (e.g. player hero died with companion still alive)
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

func push_combatant(pusher: Combatant, pushed: Combatant, distance: int, map: DungeonMap) -> Array[Vector2i]:
	## Push 'pushed' away from 'pusher' by up to 'distance' hexes along the hex grid.
	## Returns the list of hexes traversed (caller checks for lava/wall contact).
	var dir: Vector2i = _push_direction(pusher.position, pushed.position)
	var path: Array[Vector2i] = []
	for _i: int in range(distance):
		var next: Vector2i = pushed.position + dir
		if not map.is_passable(next):
			break
		var occupied: bool = false
		for c: Combatant in combatants:
			if c.is_alive() and c != pushed and c.position == next:
				occupied = true
				break
		if occupied:
			break
		pushed.position = next
		path.append(next)
	return path

func _push_direction(from_pos: Vector2i, to_pos: Vector2i) -> Vector2i:
	## Return the HexGrid direction pointing most directly from from_pos toward to_pos.
	var best_dir: Vector2i = HexGrid.DIRECTIONS[0]
	var best_dot: float = -INF
	for d: Vector2i in HexGrid.DIRECTIONS:
		var dot: float = float((to_pos.x - from_pos.x) * d.x + (to_pos.y - from_pos.y) * d.y)
		if dot > best_dot:
			best_dot = dot
			best_dir = d
	return best_dir

func move_toward(mover: Combatant, goal: Vector2i, map: DungeonMap) -> bool:
	## Public wrapper: move mover one step toward goal. Returns true if moved.
	var old_pos: Vector2i = mover.position
	_move_toward(mover, goal, map)
	return mover.position != old_pos

func move_combatant(combatant: Combatant, to_hex: Vector2i) -> bool:
	## Move combatant to target hex. Returns true if successful.
	## Does NOT check passability — the caller (BattleScene) must validate the target.
	var from_hex: Vector2i = combatant.position
	combatant.position = to_hex
	if combatant.faction == Combatant.Faction.HERO:
		hero_moved.emit(combatant, from_hex, to_hex)
	return true

func is_combatant_frozen(combatant: Combatant) -> bool:
	for eff: Dictionary in combatant.status_effects:
		if eff.get("id", "") == "frozen":
			return true
	return false
