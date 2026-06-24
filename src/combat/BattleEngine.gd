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
# Run 33: a boss used its signature move. move_id is one of "rally" / "slam" /
# "pull"; affected lists the combatants touched (revived enemy, slammed heroes,
# pulled hero). BattleScene uses this for banners, quips and VFX.
signal boss_signature(boss: Combatant, move_id: String, affected: Array[Combatant])
# Run 34: Phase 3 — boss drops below PHASE_3_HP_THRESHOLD HP. Doesn't bump
# stats (that's enrage's job); it flips the boss.frenzied flag so each
# signature dispatches to an escalated variant on its next firing.
signal boss_frenzied(boss: Combatant)

var combatants: Array[Combatant] = []
var turn_order: Array[Combatant] = []
var current_turn_idx: int = 0
var turn_number: int = 0
var battle_over: bool = false
var hero_won: bool = false
var total_xp: int = 0

var rng: RandomNumberGenerator

# Critical hits — hero-favouring. Heroes (and Donut) have a chance to deal
# CRIT_MULT× damage. Enemies never crit (keeps the roguelike feel player-positive).
const CRIT_MULT: float = 2.0
var hero_crit_chance: float = 0.15
var last_attack_was_crit: bool = false

# Run 33: boss signature cadence — after using a signature, a boss waits this
# many of its own turns before the next one. 3 keeps signatures a recurring
# set-piece without dominating every boss turn.
const SIGNATURE_COOLDOWN: int = 3
# Run 34: when a boss is Frenzied (Phase 3, sub-15% HP) the cooldown shortens,
# so signatures fire more often through the final stretch of the fight.
const SIGNATURE_COOLDOWN_FRENZIED: int = 2
# Run 34: HP ratio that flips a boss into Frenzied state. Tuned below the
# enrage threshold (0.30) so Phase 2 → Phase 3 are a clear two-step escalation.
const PHASE_3_HP_THRESHOLD: float = 0.15

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
	# Critical hit roll — only for hero-side damaging attacks
	last_attack_was_crit = false
	if attacker.faction == Combatant.Faction.HERO and ability_data.get("base_damage", 0) > 0:
		if rng.randf() < hero_crit_chance:
			last_attack_was_crit = true
			dmg = int(float(dmg) * CRIT_MULT)
	var ignore_armor: bool = ability_data.get("ignore_armor", false)
	var actual: int = target.take_damage(dmg, ignore_armor)
	action_taken.emit(attacker, target, actual, ability_id)
	if not target.is_alive():
		_on_combatant_died(target)
	else:
		_check_boss_enrage(target)
		_check_boss_phase3(target)
		# Run 33: ENEMY-side status application (Plague Bite poison, Ember Claw
		# burn). Faction-gated on purpose — hero status abilities (poison_blade,
		# frost_nova, ...) are applied by BattleScene with their own duration
		# logic, and applying them here too would double-stack the status.
		if attacker.faction == Combatant.Faction.ENEMY:
			if ability_data.get("applies_poisoned", false):
				target.apply_status(StatusEffect.poisoned(
					int(ability_data.get("poison_duration", 3)),
					int(ability_data.get("poison_dpt", 5))))
			if ability_data.get("applies_burning", false):
				target.apply_status(StatusEffect.burning(
					int(ability_data.get("burn_duration", 3)),
					int(ability_data.get("burn_dpt", 4))))
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


func _check_boss_phase3(c: Combatant) -> void:
	## Run 34: flip the Frenzied flag once a boss drops below the threshold.
	## Phase 3 escalation lives inside each signature (mass rally / AoE slam /
	## mass pull) — this function only marks state and emits the signal so
	## BattleScene can play the violet glow + banner + audio sting.
	if not c.is_boss or c.frenzied:
		return
	var hp_ratio: float = float(c.hp) / float(max(1, c.max_hp))
	if hp_ratio < PHASE_3_HP_THRESHOLD:
		c.frenzied = true
		boss_frenzied.emit(c)

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
	if is_combatant_frozen(enemy) or is_combatant_stunned(enemy):
		return  # frozen / stunned enemies skip their turn (Run 47: stun added)
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

	# Run 33: bosses get a dedicated branch — signature move when off cooldown
	# and conditions allow, otherwise the exact legacy behavior (random-ability
	# attack) so base boss difficulty is unchanged.
	if enemy.is_boss:
		_boss_ai(enemy, target, visible_heroes, map)
		return

	match enemy.sprite_key:
		"golem":
			# Golems stay put, only use ranged ability if in range
			var ranged_id: String = "enemy_fireball"
			if enemy.abilities.has(ranged_id) and HexGrid.is_in_range(enemy.position, target.position, 3):
				perform_attack(enemy, target, ranged_id)
			elif not enemy.abilities.has(ranged_id):
				# Run 32: melee golem-sprite variants (Bone Colossus) are NOT
				# turrets — they lumber toward the hero and crush when adjacent.
				# Lava Golems always carry enemy_fireball, so this path never
				# fires for them and their stationary-turret behavior is intact.
				if HexGrid.hex_distance(enemy.position, target.position) > 1 and map != null:
					_move_toward(enemy, target.position, map)
				if HexGrid.hex_distance(enemy.position, target.position) <= 1 \
						and not enemy.abilities.is_empty():
					perform_attack(enemy, target, enemy.abilities[0])
			# else: ranged golem out of range — wait
		"goblin":
			# Goblins try to flank: move if not adjacent, then attack
			var dist: int = HexGrid.hex_distance(enemy.position, target.position)
			if dist > 1 and map != null:
				_move_toward(enemy, target.position, map)
			if HexGrid.hex_distance(enemy.position, target.position) <= 1:
				var ability_id: String = enemy.abilities[rng.randi_range(0, enemy.abilities.size() - 1)]
				perform_attack(enemy, target, ability_id)
		"imp":
			# Imps rush: always move toward hero, attack if adjacent.
			# Run 33: attack with the def's first ability instead of hardcoded
			# enemy_claw — regular imps still claw (their list is [enemy_claw]),
			# but the Ember Imp variant swings its burning ember_claw.
			var dist: int = HexGrid.hex_distance(enemy.position, target.position)
			if dist > 1 and map != null:
				_move_toward(enemy, target.position, map)
			if HexGrid.hex_distance(enemy.position, target.position) <= 1:
				var imp_ability: String = "enemy_claw"
				if not enemy.abilities.is_empty():
					imp_ability = enemy.abilities[0]
				perform_attack(enemy, target, imp_ability)
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

func _boss_ai(boss: Combatant, target: Combatant, visible_heroes: Array[Combatant],
		map: DungeonMap) -> void:
	## Run 33: boss turn. Tick the signature cooldown; when ready, attempt the
	## boss's signature move (consumes the turn on success). Otherwise fall back
	## to the pre-Run-33 behavior: attack the nearest hero with a random ability.
	if boss.signature_cd > 0:
		boss.signature_cd -= 1
	elif _try_boss_signature(boss, target, visible_heroes, map):
		# Run 34: Frenzied bosses fire signatures more often.
		boss.signature_cd = SIGNATURE_COOLDOWN_FRENZIED if boss.frenzied \
			else SIGNATURE_COOLDOWN
		return
	# Legacy fallback (identical to the old default branch).
	var ability_id: String = "basic_attack"
	if not boss.abilities.is_empty():
		ability_id = boss.abilities[rng.randi_range(0, boss.abilities.size() - 1)]
	perform_attack(boss, target, ability_id)


func _try_boss_signature(boss: Combatant, target: Combatant,
		visible_heroes: Array[Combatant], map: DungeonMap) -> bool:
	## Dispatch by boss identity. Returns true if a signature fired (turn spent).
	match boss.sprite_key:
		"boss_dungeon_lord":
			return _signature_rally(boss, map)
		"boss_warden":
			return _signature_ground_slam(boss, visible_heroes, map)
		"boss_abyss_keeper":
			return _signature_void_pull(boss, target, map)
	return false  # Lizard Titans etc. — no signature; duel gimmick is enough


func _signature_rally(boss: Combatant, map: DungeonMap) -> bool:
	## Dungeon Lord: once per battle, drag a fallen minion back to its feet at
	## half HP. The corpse must have a free hex to stand on (its death spot, or
	## a passable unoccupied neighbor).
	##
	## Run 34: when Frenzied, raise EVERY eligible corpse in one detonation
	## instead of just the first one. Still consumes rally_used — the upgrade
	## is breadth, not repeatability.
	if boss.rally_used:
		return false
	if boss.frenzied:
		var revived: Array[Combatant] = []
		for c: Combatant in combatants:
			if c.faction != Combatant.Faction.ENEMY or c.is_boss or c.is_alive():
				continue
			var spot: Vector2i = _free_revive_spot(c.position, map)
			if spot == Vector2i(-9999, -9999):
				continue
			c.position = spot
			c.hp = max(1, c.max_hp / 2)
			c.status_effects.clear()
			turn_order.append(c)
			revived.append(c)
		if revived.is_empty():
			return false
		boss.rally_used = true
		boss_signature.emit(boss, "rally", revived)
		return true
	for c: Combatant in combatants:
		if c.faction != Combatant.Faction.ENEMY or c.is_boss or c.is_alive():
			continue
		var spot: Vector2i = _free_revive_spot(c.position, map)
		if spot == Vector2i(-9999, -9999):
			continue  # nowhere to stand — try the next corpse
		c.position = spot
		c.hp = max(1, c.max_hp / 2)
		c.status_effects.clear()  # death cures poison; the System calls it a perk
		turn_order.append(c)
		boss.rally_used = true
		boss_signature.emit(boss, "rally", [c] as Array[Combatant])
		return true
	return false


func _free_revive_spot(origin: Vector2i, map: DungeonMap) -> Vector2i:
	## The death hex itself, or a passable unoccupied neighbor. Sentinel
	## (-9999,-9999) when nothing is free.
	var candidates: Array[Vector2i] = [origin]
	candidates.append_array(HexGrid.neighbors(origin))
	for h: Vector2i in candidates:
		if map != null and not map.is_passable(h):
			continue
		var occupied: bool = false
		for c: Combatant in combatants:
			if c.is_alive() and c.position == h:
				occupied = true
				break
		if not occupied:
			return h
	return Vector2i(-9999, -9999)


func _signature_ground_slam(boss: Combatant, visible_heroes: Array[Combatant],
		map: DungeonMap) -> bool:
	## The Warden: smash every adjacent hero and hurl them 2 hexes back.
	## Requires at least one hero in melee contact — staying spread/ranged is
	## the counterplay.
	##
	## Run 34: Frenzied slam (Tectonic Slam) widens to range 2 and pushes 3
	## hexes instead of 2. "Stay out of melee" stops being safe — the only
	## true safe zone becomes range-3+.
	var slam_range: int = 2 if boss.frenzied else 1
	var push_dist: int = 3 if boss.frenzied else 2
	var hit: Array[Combatant] = []
	for h: Combatant in visible_heroes:
		if HexGrid.hex_distance(boss.position, h.position) <= slam_range:
			hit.append(h)
	if hit.is_empty():
		return false
	var slam_data: Dictionary = Abilities.get_ability("ground_slam")
	var base: int = int(slam_data.get("base_damage", 14)) + boss.attack_bonus
	for h: Combatant in hit:
		var actual: int = h.take_damage(base)
		action_taken.emit(boss, h, actual, "ground_slam")
		if not h.is_alive():
			_on_combatant_died(h)
		elif map != null:
			push_combatant(boss, h, push_dist, map)
	boss_signature.emit(boss, "slam", hit)
	return true


func _signature_void_pull(boss: Combatant, target: Combatant, map: DungeonMap) -> bool:
	## The Abyss Keeper: fold a hero at range 2-4 into melee contact and rake
	## them on arrival (armor-ignoring). Standing far away is no longer safe;
	## standing adjacent already is the counter (the pull needs distance).
	##
	## Run 34: Frenzied pull (Void Implosion) grabs EVERY hero in range 2-4
	## at once. Heroes are folded into the boss's free neighbors in ascending
	## distance order — closest hero first, so chain pulls don't collide.
	if boss.frenzied:
		return _signature_void_pull_mass(boss, map)
	var dist: int = HexGrid.hex_distance(boss.position, target.position)
	if dist < 2 or dist > 4:
		return false
	# Land the hero on the free passable boss-neighbor nearest their old spot.
	var best: Vector2i = Vector2i(-9999, -9999)
	var best_d: int = 1 << 30
	for n: Vector2i in HexGrid.neighbors(boss.position):
		if map != null and not map.is_passable(n):
			continue
		var occupied: bool = false
		for c: Combatant in combatants:
			if c.is_alive() and c != target and c.position == n:
				occupied = true
				break
		if occupied:
			continue
		var d: int = HexGrid.hex_distance(n, target.position)
		if d < best_d:
			best_d = d
			best = n
	if best == Vector2i(-9999, -9999):
		return false  # boss is fully ringed — no landing hex
	target.position = best
	var pull_data: Dictionary = Abilities.get_ability("void_pull")
	var dmg: int = int(pull_data.get("base_damage", 10)) + boss.attack_bonus
	var actual: int = target.take_damage(dmg, true)
	action_taken.emit(boss, target, actual, "void_pull")
	if not target.is_alive():
		_on_combatant_died(target)
	boss_signature.emit(boss, "pull", [target] as Array[Combatant])
	return true


func _signature_void_pull_mass(boss: Combatant, map: DungeonMap) -> bool:
	## Run 34 Frenzied variant: pull every living hero at range 2-4 into a
	## free boss-neighbor and rake them all. Closest hero is placed first so a
	## crowded ring doesn't starve the later pulls. Returns false (and fires
	## no signature) if nobody is in pull range — Frenzied bosses must still
	## fall back to a regular attack rather than waste the turn flailing.
	var living_heroes: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.faction == Combatant.Faction.HERO and c.is_alive():
			living_heroes.append(c)
	# Process closest-first so the nearest hero claims the best landing hex.
	living_heroes.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		return HexGrid.hex_distance(boss.position, a.position) \
			< HexGrid.hex_distance(boss.position, b.position))
	var pulled: Array[Combatant] = []
	var claimed: Dictionary = {}  # hex -> true; reserves landing spots in this turn
	var pull_data: Dictionary = Abilities.get_ability("void_pull")
	var base: int = int(pull_data.get("base_damage", 10)) + boss.attack_bonus
	for hero: Combatant in living_heroes:
		var d: int = HexGrid.hex_distance(boss.position, hero.position)
		if d < 2 or d > 4:
			continue
		var landing: Vector2i = _nearest_free_neighbor(boss.position, hero, map, claimed)
		if landing == Vector2i(-9999, -9999):
			continue  # this hero stays put; ring is full
		claimed[landing] = true
		hero.position = landing
		var actual: int = hero.take_damage(base, true)
		action_taken.emit(boss, hero, actual, "void_pull")
		if not hero.is_alive():
			_on_combatant_died(hero)
		pulled.append(hero)
	if pulled.is_empty():
		return false
	boss_signature.emit(boss, "pull", pulled)
	return true


func _nearest_free_neighbor(origin: Vector2i, hero: Combatant, map: DungeonMap,
		claimed: Dictionary) -> Vector2i:
	## Pick the passable, unoccupied, unclaimed neighbor of `origin` closest to
	## the hero's current position. Sentinel (-9999,-9999) if the ring is full.
	var best: Vector2i = Vector2i(-9999, -9999)
	var best_d: int = 1 << 30
	for n: Vector2i in HexGrid.neighbors(origin):
		if claimed.has(n):
			continue
		if map != null and not map.is_passable(n):
			continue
		var occupied: bool = false
		for c: Combatant in combatants:
			if c.is_alive() and c != hero and c.position == n:
				occupied = true
				break
		if occupied:
			continue
		var d: int = HexGrid.hex_distance(n, hero.position)
		if d < best_d:
			best_d = d
			best = n
	return best


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

## Run 47: stun parallels frozen but lives on its own status id so the HUD,
## quips, and (future) cure-effects can address it distinctly. Both effects
## set `skips_turn: true` in their payload; the AI gate consults both.
func is_combatant_stunned(combatant: Combatant) -> bool:
	for eff: Dictionary in combatant.status_effects:
		if eff.get("id", "") == "stunned":
			return true
	return false
