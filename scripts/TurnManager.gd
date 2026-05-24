## TurnManager — drives initiative order, player input, and (stubbed) enemy AI.
## Milestone 5: full player turn (move + attack + end turn).
## Milestone 6: replace _run_enemy_turn stub with real goblin AI.
## Milestone 7: win/lose banners and full narration log wiring.
extends Node
class_name TurnManager

# ── Dependencies (injected via setup()) ──────────────────────────────────────

var grid: Grid
var all_units: Array[Unit]     ## All living units; shrinks on death.
var status_label: Label

# ── Turn order ────────────────────────────────────────────────────────────────

## Living units in initiative order (highest first).
var turn_order: Array[Unit] = []

## Index of the unit whose turn it currently is.
var _turn_idx: int = 0

## The unit currently acting.
var _active: Unit = null

# ── Per-turn state ────────────────────────────────────────────────────────────

var _move_spent:   bool = false
var _action_spent: bool = false
var _battle_over:  bool = false

## Cached reachable / attackable cells for the active player unit.
var _move_cells:   Array[Vector2i] = []
var _attack_cells: Array[Vector2i] = []

# ── Signals ───────────────────────────────────────────────────────────────────

signal battle_ended(player_won: bool)

# ── Public API ────────────────────────────────────────────────────────────────

## Called by BattleScene after spawning units.
func setup(g: Grid, units: Array[Unit], label: Label) -> void:
	grid   = g
	all_units = units
	status_label = label
	# Connect death signals for all units.
	for u: Unit in all_units:
		u.died.connect(_on_unit_died.bind(u))
	_roll_initiative()
	_start_next_turn()


## Called by the End Turn button.
func end_player_turn() -> void:
	if _battle_over or _active == null or not _active.is_player:
		return
	_advance_turn()

# ── Initiative ────────────────────────────────────────────────────────────────

func _roll_initiative() -> void:
	# Pair each unit with its initiative roll.
	var pairs: Array = []
	for u: Unit in all_units:
		var roll: int = GameRng.d20()
		pairs.append([roll, u])
		print("Initiative %d — %s" % [roll, u.unit_name])

	# Sort descending; on ties, player units go first.
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

	_active = turn_order[_turn_idx]
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
	_set_status("Your turn — %s\n[click blue=move, red=attack]" % _active.unit_name)


func _update_player_highlights() -> void:
	# Movement highlight: only if not yet moved.
	_move_cells = []
	if not _move_spent:
		_move_cells = grid.get_reachable_cells(_active.grid_cell, _active.move_range, _active)

	# Attack highlight: only if not yet acted.
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


## Handle a left-click on [param cell] during the player's turn.
func _handle_player_click(cell: Vector2i) -> void:
	if _battle_over or _active == null or not _active.is_player:
		return

	# ── Try attack ────────────────────────────────────────────────────────────
	if not _action_spent and cell in _attack_cells:
		var target: Unit = grid.get_occupant(cell) as Unit
		if target != null:
			_player_attack(target)
			return

	# ── Try move ──────────────────────────────────────────────────────────────
	if not _move_spent and cell in _move_cells:
		_player_move(cell)
		return


func _player_move(dest: Vector2i) -> void:
	var from: Vector2i = _active.grid_cell
	grid.clear_occupied(from)
	_active.grid_cell = dest
	_active.position  = grid.position + grid.cell_to_world(dest)
	grid.set_occupied(dest, _active)

	_move_spent = true
	_update_player_highlights()
	_set_status("Your turn — %s\nmoved to %s" % [_active.unit_name, dest])


func _player_attack(target: Unit) -> void:
	var weapon: Weapon = _active.get_attack_weapon()
	var result: Dictionary = CombatResolver.resolve_attack(
		weapon.to_hit, weapon.damage_dice, target.defense, target.hp, GameRng)

	if result.hit:
		target.take_damage(result.damage)
		System.announce(&"hit", {
			"attacker": _active.unit_name,
			"defender": target.unit_name,
			"damage":   result.damage,
		})
	else:
		System.announce(&"miss", {
			"attacker": _active.unit_name,
			"defender": target.unit_name,
		})

	_action_spent = true
	_update_player_highlights()
	_set_status("Your turn — %s\nattacked %s (roll %d)" % [
		_active.unit_name, target.unit_name, result.roll])

# ── Enemy turn (stub for M5 — replaced in M6) ────────────────────────────────

func _begin_enemy_turn() -> void:
	_set_status("%s thinking…" % _active.unit_name)
	# Defer so the status label updates before we block the frame.
	call_deferred("_enemy_turn_deferred")


func _enemy_turn_deferred() -> void:
	# M5 stub: enemies just pass their turn.
	# M6 will replace this with actual goblin AI.
	await get_tree().create_timer(0.4).timeout
	_advance_turn()

# ── Death handling ────────────────────────────────────────────────────────────

func _on_unit_died(unit: Unit) -> void:
	System.announce(&"kill", {"defender": unit.unit_name})

	# Remove from all_units and turn_order.
	all_units.erase(unit)
	var dead_idx: int = turn_order.find(unit)
	if dead_idx != -1:
		turn_order.erase(unit)
		# Keep _turn_idx valid after the erasure.
		if dead_idx < _turn_idx:
			_turn_idx -= 1
		if _turn_idx >= turn_order.size():
			_turn_idx = 0

	# Remove from grid.
	grid.clear_occupied(unit.grid_cell)
	unit.queue_free()

	_check_battle_over()


func _check_battle_over() -> void:
	var players_alive: int = 0
	var enemies_alive: int = 0
	for u: Unit in all_units:
		if u.is_player:
			players_alive += 1
		else:
			enemies_alive += 1

	if enemies_alive == 0:
		_end_battle(true)
	elif players_alive == 0:
		_end_battle(false)


func _end_battle(player_won: bool) -> void:
	_battle_over = true
	grid.clear_highlights()
	if _active != null:
		_active.set_active(false)
	var event := &"victory" if player_won else &"defeat"
	System.announce(event, {})
	_set_status("BATTLE OVER!\n%s" % ("VICTORY!" if player_won else "DEFEAT."))
	battle_ended.emit(player_won)

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _battle_over or _active == null or not _active.is_player:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Convert viewport click → Grid local space → cell.
			var cell: Vector2i = grid.world_to_cell(grid.get_local_mouse_position())
			_handle_player_click(cell)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
	print("[TurnManager] %s" % text.replace("\n", " | "))
