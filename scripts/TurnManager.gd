## TurnManager — initiative order, player input, goblin AI, win/lose, tweens.
## Milestone 8: position tweens for move + attack, death-fade on kill.
extends Node
class_name TurnManager

# ── Dependencies ──────────────────────────────────────────────────────────────

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

## True while a tween animation is playing.  Blocks player input.
var _animating:    bool = false

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
	if _battle_over or _animating or _active == null or not _active.is_player:
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
		return a[1].is_player
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
	if _battle_over or _animating or _active == null or not _active.is_player:
		return
	if not _action_spent and cell in _attack_cells:
		var target: Unit = grid.get_occupant(cell) as Unit
		if target != null:
			_player_attack_async(target)
			return
	if not _move_spent and cell in _move_cells:
		_player_move_async(cell)


## Async player move: update state immediately, then tween.
func _player_move_async(dest: Vector2i) -> void:
	_animating = true
	grid.clear_highlights()

	# Update logical state before tween so occupancy is consistent.
	grid.clear_occupied(_active.grid_cell)
	_active.grid_cell = dest
	grid.set_occupied(dest, _active)
	_move_spent = true

	await _tween_move(_active, dest)
	_animating = false

	if not _battle_over:
		_update_player_highlights()
		_set_status("Your turn — %s\nmoved to %s" % [_active.unit_name, dest])


## Async player attack: tween jab, then resolve.
func _player_attack_async(target: Unit) -> void:
	_animating = true
	grid.clear_highlights()

	await _tween_jab(_active, target)
	_do_attack(_active, target)
	_action_spent = true
	_animating = false

	if not _battle_over:
		_update_player_highlights()

# ── Enemy turn — goblin AI ────────────────────────────────────────────────────

func _begin_enemy_turn() -> void:
	_set_status("%s is thinking…" % _active.unit_name)
	call_deferred("_run_goblin_ai", _active)


func _run_goblin_ai(goblin: Unit) -> void:
	await get_tree().create_timer(0.40).timeout
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

	# Move toward target if out of range.
	var dist: int = grid.cell_distance(goblin.grid_cell, target.grid_cell)
	if dist > weapon.weapon_range:
		await _goblin_move_toward(goblin, target)
		dist = grid.cell_distance(goblin.grid_cell, target.grid_cell)

	# Attack if now in range.
	if dist <= weapon.weapon_range and goblin.is_alive and not _battle_over:
		await _tween_jab(goblin, target)
		_do_attack(goblin, target)
		if not _battle_over:
			await get_tree().create_timer(0.30).timeout

	if not _battle_over:
		_advance_turn()


func _find_nearest_player(from: Unit) -> Unit:
	var best: Unit  = null
	var best_d: int = 99999
	for u: Unit in all_units:
		if not u.is_player:
			continue
		var path: Array[Vector2i] = grid.get_path(from.grid_cell, u.grid_cell)
		var d: int = (path.size() - 1) if not path.is_empty() else 99999
		if d < best_d:
			best_d = d
			best   = u
	return best


## Move goblin along A* path (walls only) up to its move budget.
## Clears+sets occupancy step-by-step, then tweens to final position.
func _goblin_move_toward(goblin: Unit, target: Unit) -> void:
	var path: Array[Vector2i] = grid.get_path(goblin.grid_cell, target.grid_cell)
	if path.size() < 2:
		return

	var current: Vector2i = goblin.grid_cell
	var steps:   int      = 0

	for i: int in range(1, path.size()):
		if steps >= goblin.move_range:
			break
		var next_cell: Vector2i = path[i]
		if grid.is_occupied(next_cell):
			break
		grid.clear_occupied(current)
		current = next_cell
		grid.set_occupied(current, goblin)
		steps += 1

	if steps > 0:
		goblin.grid_cell = current
		await _tween_move(goblin, current)
		_set_status("%s moves" % goblin.unit_name)

# ── Tweens ────────────────────────────────────────────────────────────────────

## Smooth position tween to cell [param dest].
func _tween_move(unit: Unit, dest: Vector2i) -> void:
	var dest_pos: Vector2 = grid.position + grid.cell_to_world(dest)
	var tween: Tween = unit.create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(unit, "position", dest_pos, 0.20)
	await tween.finished


## Quick forward-and-back jab toward [param target].
func _tween_jab(attacker: Unit, target: Unit) -> void:
	var start_pos: Vector2 = attacker.position
	var toward:    Vector2 = start_pos.lerp(target.position, 0.36)
	var tween: Tween = attacker.create_tween()
	tween.tween_property(attacker, "position", toward,    0.08)
	tween.tween_property(attacker, "position", start_pos, 0.12)
	await tween.finished

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
		attacker.unit_name, defender.unit_name, result.roll,
		"HIT  (%d dmg)" % result.damage if result.hit else "MISS",
	])

# ── Death handling ────────────────────────────────────────────────────────────

func _on_unit_died(unit: Unit) -> void:
	System.announce(&"kill", {"defender": unit.unit_name})

	# Remove from tracking arrays before the fade tween starts.
	all_units.erase(unit)
	var dead_idx: int = turn_order.find(unit)
	if dead_idx != -1:
		turn_order.erase(unit)
		if dead_idx < _turn_idx:
			_turn_idx -= 1
		if _turn_idx >= turn_order.size() and not turn_order.is_empty():
			_turn_idx = 0

	grid.clear_occupied(unit.grid_cell)
	_check_battle_over()

	# Fade out then free — the unit stays alive visually for 0.35 s.
	var tween: Tween = unit.create_tween()
	tween.tween_property(unit, "modulate:a", 0.0, 0.35)
	tween.tween_callback(unit.queue_free)


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
	System.announce(&"victory" if player_won else &"defeat", {})
	_set_status("═══ BATTLE OVER ═══\n%s" % ("VICTORY!" if player_won else "DEFEAT."))
	battle_ended.emit(player_won)

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _battle_over or _animating or _active == null or not _active.is_player:
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
