class_name BattleEngine
## Pure rules engine for one battle encounter.
## No Node dependency — driven by BattleScene for visuals.
## All randomness routes through the rng parameter for testability.

signal turn_started(combatant: Combatant)
signal action_taken(attacker: Combatant, target: Combatant, damage: int, ability_id: String)
signal combatant_died(combatant: Combatant)
signal battle_ended(hero_won: bool, xp_earned: int)
signal status_ticked(combatant: Combatant, damage: int)
signal entity_moved(combatant: Combatant, from_hex: Vector2i, to_hex: Vector2i)

var combatants: Array[Combatant] = []
var turn_order: Array[Combatant] = []
var current_turn_idx: int = 0
var turn_number: int = 0
var battle_over: bool = false
var hero_won: bool = false
var total_xp: int = 0

## Set by begin_turn() — true if the active combatant's turn should be skipped (frozen).
var active_turn_skipped: bool = false

var rng: RandomNumberGenerator
var map: DungeonMap = null  # Optional: used for enemy pathfinding

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

## Provide the dungeon map so enemies can pathfind.
func setup_map(p_map: DungeonMap) -> void:
	map = p_map

## ─── Turn Management ─────────────────────────────────────────────────────────

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

	# Detect skip-turn statuses BEFORE ticking so N duration = N skipped turns.
	active_turn_skipped = false
	for eff: Dictionary in active.status_effects:
		if eff.get("skip_turn", false):
			active_turn_skipped = true
			break

	# Tick status effects each turn
	var status_dmg: int = active.tick_statuses()
	if status_dmg > 0:
		status_ticked.emit(active, status_dmg)

	if not active.is_alive():
		_on_combatant_died(active)
		current_turn_idx = (current_turn_idx + 1) % max(1, turn_order.size())
		return begin_turn()

	turn_started.emit(active)
	return active

func end_turn() -> void:
	current_turn_idx = (current_turn_idx + 1) % max(1, turn_order.size())
	_check_battle_end()

## ─── Attack Resolution ───────────────────────────────────────────────────────

func perform_attack(attacker: Combatant, target: Combatant, ability_id: String = "basic_attack") -> int:
	## Deals damage to one target. Returns actual damage dealt.
	var abl: Dictionary = Abilities.get_ability(ability_id)
	var ignore_armor: bool = abl.get("ignore_armor", false)
	var dmg: int = _calculate_damage(attacker, ability_id)
	var actual: int = target.take_damage(dmg, ignore_armor)
	# Consume vanish buff after first hit
	if attacker.has_status("vanished"):
		attacker.remove_status("vanished")
	action_taken.emit(attacker, target, actual, ability_id)
	if not target.is_alive():
		_on_combatant_died(target)
	return actual

func _calculate_damage(attacker: Combatant, ability_id: String) -> int:
	## Returns raw pre-armor damage. Armor is applied in take_damage().
	var ability_data: Dictionary = Abilities.get_ability(ability_id)
	var base: int = ability_data.get("base_damage", 10)
	var atk_bonus: int = attacker.stats.get("attack", 0)
	var variance: float = rng.randf_range(0.8, 1.2)
	# Vanish: 3× multiplier on next hit
	var multiplier: float = 1.0
	for eff: Dictionary in attacker.status_effects:
		if eff.get("id", "") == "vanished":
			multiplier = eff.get("damage_multiplier", 3.0)
			break
	return max(1, int(float(base + atk_bonus) * variance * multiplier))

## ─── Ability Dispatch ─────────────────────────────────────────────────────────

func perform_ability(attacker: Combatant, ability_id: String, primary_target: Combatant = null) -> void:
	## Routes to the appropriate ability handler.
	match ability_id:
		"fireball":
			if primary_target != null:
				_do_fireball(attacker, primary_target.position)
		"frost_nova":
			_do_frost_nova(attacker)
		"taunt":
			_do_taunt(attacker)
		"vanish":
			_do_vanish(attacker)
		_:
			# Default: single-target attack
			if primary_target != null:
				perform_attack(attacker, primary_target, ability_id)
	_check_battle_end()

func _do_fireball(attacker: Combatant, center: Vector2i) -> void:
	## Hits all enemies within radius 2 of center hex.
	var targets: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.faction == Combatant.Faction.ENEMY and c.is_alive():
			if HexGrid.hex_distance(center, c.position) <= 2:
				targets.append(c)
	for t: Combatant in targets:
		var dmg: int = _calculate_damage(attacker, "fireball")
		var actual: int = t.take_damage(dmg)
		action_taken.emit(attacker, t, actual, "fireball")
		if not t.is_alive():
			_on_combatant_died(t)

func _do_frost_nova(attacker: Combatant) -> void:
	## Freezes and damages all enemies adjacent to attacker.
	var adj: Array[Vector2i] = HexGrid.neighbors(attacker.position)
	for c: Combatant in combatants:
		if c.faction == Combatant.Faction.ENEMY and c.is_alive():
			if adj.has(c.position):
				var dmg: int = _calculate_damage(attacker, "frost_nova")
				var actual: int = c.take_damage(dmg)
				action_taken.emit(attacker, c, actual, "frost_nova")
				if c.is_alive():
					c.apply_status(StatusEffect.frozen(2))
				else:
					_on_combatant_died(c)

func _do_taunt(attacker: Combatant) -> void:
	## Grants fortified (+5 armor) for 3 turns.
	attacker.apply_status(StatusEffect.fortified(3, 5))
	action_taken.emit(attacker, attacker, 0, "taunt")

func _do_vanish(attacker: Combatant) -> void:
	## Applies vanished buff — next attack deals 3× damage.
	attacker.apply_status(StatusEffect.vanished())
	action_taken.emit(attacker, attacker, 0, "vanish")

## ─── Enemy AI ─────────────────────────────────────────────────────────────────

func enemy_ai_action(enemy: Combatant) -> void:
	var heroes: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.faction == Combatant.Faction.HERO and c.is_alive():
			heroes.append(c)
	if heroes.is_empty():
		return
	var hero: Combatant = heroes[0]

	# Pick ability
	var ability_id: String = "basic_attack"
	if not enemy.abilities.is_empty():
		# Prefer ranged ability if hero is out of melee range
		var dist: int = HexGrid.hex_distance(enemy.position, hero.position)
		for abl_id: String in enemy.abilities:
			var abl_data: Dictionary = Abilities.get_ability(abl_id)
			if abl_data.get("range", 1) >= dist:
				ability_id = abl_id
				break
		if ability_id == "basic_attack":
			ability_id = enemy.abilities[rng.randi_range(0, enemy.abilities.size() - 1)]

	var abl: Dictionary = Abilities.get_ability(ability_id)
	var attack_range: int = abl.get("range", 1)
	var dist_to_hero: int = HexGrid.hex_distance(enemy.position, hero.position)

	# Move toward hero if out of attack range
	if dist_to_hero > attack_range and map != null:
		_move_toward(enemy, hero.position)
		# Recalculate distance after move
		dist_to_hero = HexGrid.hex_distance(enemy.position, hero.position)

	# Attack if in range now
	if dist_to_hero <= attack_range:
		perform_ability(enemy, ability_id, hero)

func _move_toward(mover: Combatant, dest: Vector2i) -> void:
	## Step one hex toward dest, avoiding walls/lava and other combatants.
	var neighbors: Array[Vector2i] = HexGrid.neighbors(mover.position)
	var best_hex: Vector2i = mover.position
	var best_dist: int = HexGrid.hex_distance(mover.position, dest)

	# Collect occupied hexes
	var occupied: Array[Vector2i] = []
	for c: Combatant in combatants:
		if c.is_alive() and c != mover:
			occupied.append(c.position)

	for n: Vector2i in neighbors:
		if map != null and not map.is_passable(n):
			continue
		if occupied.has(n):
			continue
		var d: int = HexGrid.hex_distance(n, dest)
		if d < best_dist:
			best_dist = d
			best_hex = n

	if best_hex != mover.position:
		var old_pos: Vector2i = mover.position
		mover.position = best_hex
		entity_moved.emit(mover, old_pos, best_hex)

## ─── Battle End ───────────────────────────────────────────────────────────────

func _remove_dead_from_order() -> void:
	var alive: Array[Combatant] = []
	for c: Combatant in turn_order:
		if c.is_alive():
			alive.append(c)
	turn_order = alive

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
	combatant_died.emit(c)
