## TurnManager — initiative order, player input, goblin AI, win/lose detection.
extends Node
class_name TurnManager

# ── Dependencies (injected via setup()) ──────────────────────────────────────

var grid: Grid
var all_units: Array[Unit]
var status_label: Label

# ── Turn order ────────────────────────────────────────────────────────────────

var turn_order: Array[Unit] = []
var _turn_idx:    int  = 0
var _active:      Unit = null

# ── Per-turn bookkeeping ──────────────────────────────────────────────────────

var _move_spent:   bool = false
var _action_spent: bool = false
var _battle_over:  bool = false

var _move_cells:   Array[Vector2i] = []
var _attack_cells: Array[Vector2i] = []

# ── Signals ───────────────────────────────────────────────────────────────────

signal battle_ended(player_won: bool)

# ── Public API ────────────────────────────────────────────────────────────────

func setup(g: Grid, units: Array[Unit], label: Label) -> void:
	grid         = g
	all_units    = units
	status_label = label
	for u: Unit in all_units:
		u.died.connect(_on_unit_died.bind(u))
	_roll_initiative()
	_start_next_turn()


func end_player_turn() -> void:
	if _battle_over or _active == null or not _active.is_player:
		return
	_advance_turn()

# ── Initiative ────────────────────────────────────────────────────────────────

func _roll_initiative() -> void:
	var pairs: Array = []
	for u: Unit in all_units:
		var roll: int = GameRng.d20()
		pairs.append([roll, u])
		print("Initiative %d — %s" % [roll, u.unit_name])

	pairs.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] > b[0]
		return a[1].is_player      # player wins ties
	)
	turn_order.clear()
	for p: Array in pairs:
		turn_order.append(p[1] as Unit)
	_turn_idx = 0

# ── Turn loop ─────────────────────────────────────────────────────────────────

func _start_next_turn() -> void:
	if _battle_over or turn_order.is_empty():
		return
	_active       = turn_order[_turn_idx]
	_move_spent   = false
	_action_spent = false
	_active.set_active(true)
	if _active.is_player:
		_begin_player_turn()
	else:
		_begin_enemy_turn()


func _advance_turn() -> void:
	if _active != null:
		_active.set_active(false)
	grid.clear_highlights()
	_move_cells   = []
	_attack_cells = []
	if turn_order.is_empty():
		return
	_turn_idx = (_turn_idx + 1) % turn_order.size()
	_start_next_turn()

# ── Player turn ───────────────────────────────────────────────────────────────

func _begin_player_turn() -> void:
	_update_player_highlights()
	_set_status("Your turn — %s\n[click blue=move  red=attack]" % _active.unit_name)


func _update_player_highlights() -> void:
	_move_cells = []
	if not _move_spent:
		_move_cells = grid.get_reachable_cells(_active.grid_cell, _active.move_range, _active)

	_attack_cells = []
	if not _action_spent:
		var weapon: Weapon = _active.get_attack_weapon()
		if weapon != null:
			for u: Unit in all_units:
				if u.is_player:
					continue
				if grid.cell_distance(_active.grid_cell, u.grid_cell) <= weapon.weapon_range:
					_attack_cells.append(u.grid_cell)

	grid.set_move_highlights(_move_cells)
	grid.set_attack_highlights(_attack_cells)


func _handle_player_click(cell: Vector2i) -> void:
	if _battle_over or _active == null or not _active.is_player:
		return
	# Attack first (click on a highlighted enemy cell).
	if not _action_spent and cell in _attack_cells:
		var target: Unit = grid.get_occupant(cell) as Unit
		if target != null:
			_execute_player_attack(target)
			return
	# Move (click on a highlighted movement cell).
	if not _move_spent and cell in _move_cells:
		_execute_player_move(cell)


func _execute_player_move(dest: Vector2i) -> void:
	_move_unit(_active, dest)
	_move_spent = true
	_update_player_highlights()
	_set_status("Your turn — %s\nmoved to %s" % [_active.unit_name, dest])


func _execute_player_attack(target: Unit) -> void:
	_do_attack(_active, target)
	_action_spent = true
	_update_player_highlights()

# ── Enemy turn — goblin AI ────────────────────────────────────────────────────

func _begin_enemy_turn() -> void:
	_set_status("%s is thinking…" % _active.unit_name)
	# Defer one frame so the label updates before we start the async work.
	call_deferred("_run_goblin_ai", _active)


## Async goblin AI: find nearest player → move if needed → attack if in range.
func _run_goblin_ai(goblin: Unit) -> void:
	# Wait a moment so the player can see it's the goblin's turn.
	await get_tree().create_timer(0.45).timeout

	# Guard: goblin might have died (shouldn't happen but be safe).
	if not goblin.is_alive or _battle_over:
		return

	var target: Unit = _find_nearest_player(goblin)
	if target == null:
		_advance_turn()
		return

	var weapon: Weapon = goblin.get_attack_weapon()
	if weapon == null:
		_advance_turn()
		return

	# ── Step 1: move toward target if not already in range ────────────────────
	var dist: int = grid.cell_distance(goblin.grid_cell, target.grid_cell)
	if dist > weapon.weapon_range:
		_goblin_move_toward(goblin, target)
		dist = grid.cell_distance(goblin.grid_cell, target.grid_cell)

	# ── Step 2: attack if now in range ────────────────────────────────────────
	if dist <= weapon.weapon_range:
		_do_attack(goblin, target)
		# Brief pause after the attack so the player can read the status.
		await get_tree().create_timer(0.40).timeout

	# ── Hand off ──────────────────────────────────────────────────────────────
	if not _battle_over:
		_advance_turn()


## Find the living player unit closest to [param from] by A* path length.
func _find_nearest_player(from: Unit) -> Unit:
	var best: Unit    = null
	var best_d: int   = 99999
	for u: Unit in all_units:
		if not u.is_player:
			continue
		var path: Array[Vector2i] = grid.get_path(from.grid_cell, u.grid_cell)
		# path includes start cell; length = path.size()-1 steps.
		var d: int = (path.size() - 1) if not path.is_empty() else 99999
		if d < best_d:
			best_d = d
			best   = u
	return best


## Move [param goblin] step-by-step along the A* path toward [param target],
## up to its move_range, stopping before occupied cells.
func _goblin_move_toward(goblin: Unit, target: Unit) -> void:
	# get_path gives wall-only A* path including both start and goal.
	var path: Array[Vector2i] = grid.get_path(goblin.grid_cell, target.grid_cell)
	if path.size() < 2:
		return   # No path, or already adjacent.

	var current: Vector2i = goblin.grid_cell
	var steps:   int      = 0

	for i: int in range(1, path.size()):
		if steps >= goblin.move_range:
			break
		var next_cell: Vector2i = path[i]
		# Never step onto the target's cell or any occupied cell.
		if grid.is_occupied(next_cell):
			break
		# Advance occupancy one step at a time.
		grid.clear_occupied(current)
		current = next_cell
		grid.set_occupied(current, goblin)
		steps += 1

	if steps > 0:
		goblin.grid_cell = current
		goblin.position  = grid.position + grid.cell_to_world(current)
		_set_status("%s moves → %s" % [goblin.unit_name, current])

# ── Shared attack logic ───────────────────────────────────────────────────────

func _do_attack(attacker: Unit, defender: Unit) -> void:
	var weapon: Weapon = attacker.get_attack_weapon()
	var result: Dictionary = CombatResolver.resolve_attack(
		weapon.to_hit, weapon.damage_dice, defender.defense, defender.hp, GameRng)

	if result.hit:
		defender.take_damage(result.damage)
		System.announce(&"hit", {
			"attacker": attacker.unit_name,
			"defender": defender.unit_name,
			"damage":   result.damage,
		})
		if defender.is_player:
			System.announce(&"carl_hurt", {
				"damage": result.damage,
				"hp":     defender.hp,
			})
	else:
		System.announce(&"miss", {
			"attacker": attacker.unit_name,
			"defender": defender.unit_name,
		})

	_set_status("%s → %s  roll %d  %s" % [
		attacker.unit_name,
		defender.unit_name,
		result.roll,
		"HIT  (%d dmg)" % result.damage if result.hit else "MISS",
	])


## Teleport [param unit] to [param dest], updating grid occupancy.
func _move_unit(unit: Unit, dest: Vector2i) -> void:
	grid.clear_occupied(unit.grid_cell)
	unit.grid_cell = dest
	unit.position  = grid.position + grid.cell_to_world(dest)
	grid.set_occupied(dest, unit)

# ── Death handling ────────────────────────────────────────────────────────────

func _on_unit_died(unit: Unit) -> void:
	System.announce(&"kill", {"defender": unit.unit_name})
	all_units.erase(unit)

	var dead_idx: int = turn_order.find(unit)
	if dead_idx != -1:
		turn_order.erase(unit)
		if dead_idx < _turn_idx:
			_turn_idx -= 1
		if _turn_idx >= turn_order.size() and not turn_order.is_empty():
			_turn_idx = 0

	grid.clear_occupied(unit.grid_cell)
	unit.queue_free()
	_check_battle_over()


func _check_battle_over() -> void:
	var players: int = 0
	var enemies: int = 0
	for u: Unit in all_units:
		if u.is_player: players += 1
		else:           enemies += 1
	if   enemies == 0: _end_battle(true)
	elif players == 0: _end_battle(false)


func _end_battle(player_won: bool) -> void:
	_battle_over = true
	grid.clear_highlights()
	if _active != null:
		_active.set_active(false)
	var ev := &"victory" if player_won else &"defeat"
	System.announce(ev, {})
	_set_status("═══ BATTLE OVER ═══\n%s" % ("VICTORY!" if player_won else "DEFEAT."))
	battle_ended.emit(player_won)

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _battle_over or _active == null or not _active.is_player:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var cell: Vector2i = grid.world_to_cell(grid.get_local_mouse_position())
			_handle_player_click(cell)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
	print("[Turn] %s" % text.replace("\n", " | "))
