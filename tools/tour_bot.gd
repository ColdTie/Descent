extends Node
## TEMPORARY dev-only tour bot — auto-plays through the game's screens and
## saves viewport screenshots to user://tour/. NOT shipped; registered as a
## temporary autoload only while auditing UI. Driven entirely by find-button-
## by-text + pressed.emit() so it doesn't depend on pixel coordinates.

var _step: int = 0
var _shots: int = 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tour"))
	_run_tour()

func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_shots += 1
	var path: String = "user://tour/%02d_%s.png" % [_shots, tag]
	img.save_png(path)
	print("TOURBOT shot: ", path)

func _find_button(root: Node, contains: String) -> Button:
	if root is Button and (root as Button).text.to_upper().contains(contains.to_upper()):
		return root as Button
	for c: Node in root.get_children():
		var b: Button = _find_button(c, contains)
		if b != null:
			return b
	return null

func _press(contains: String) -> bool:
	var b: Button = _find_button(get_tree().root, contains)
	if b == null:
		print("TOURBOT: no button containing '", contains, "'")
		return false
	print("TOURBOT pressing: ", b.text)
	b.pressed.emit()
	return true

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _battle_scene() -> Node:
	var main: Node = get_tree().root.get_node_or_null("Main")
	if main == null:
		return null
	for c: Node in main.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).contains("BattleScene"):
			return c
	return null

func _kill_all_enemies() -> void:
	var bs: Node = _battle_scene()
	if bs == null:
		return
	var engine: Object = bs.get("_engine")
	if engine == null:
		return
	var hero: Object = bs.get("_hero")
	for c: Object in engine.get("combatants"):
		if c.get("faction") != hero.get("faction") and c.call("is_alive"):
			c.call("take_damage", 99999, true)
			engine.emit_signal("combatant_died", c)
	engine.call("_check_battle_end")

func _run_tour() -> void:
	await _wait(2.0)
	await _shot("title")
	_press("BEGIN")
	if _find_button(get_tree().root, "NEW RUN") != null:
		_press("NEW RUN")
	await _wait(1.2)
	await _shot("class_select")
	_press("SELECT")
	await _wait(0.6)
	_press("DESCEND INTO HELL")
	await _wait(3.0)
	await _shot("battle_floor1")
	# Let enemy turns play out visually.
	await _wait(5.0)
	await _shot("battle_later")
	_kill_all_enemies()
	await _wait(3.0)
	await _shot("victory")
	_press("DESCEND")
	await _wait(1.5)
	await _shot("after_victory")  # loot or levelup
	_press("TAKE IT")
	await _wait(1.0)
	await _shot("after_pick")
	_press("CONTINUE")
	await _wait(1.5)
	await _shot("shop_or_floor2")
	if _find_button(get_tree().root, "LEAVE") != null:
		_press("LEAVE")
		await _wait(2.5)
		await _shot("floor2")
	# Pause menu peek
	var bs2: Node = _battle_scene()
	if bs2 != null:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.pressed = true
		Input.parse_input_event(ev)
		await _wait(0.8)
		await _shot("pause_menu")
		var ev2 := InputEventKey.new()
		ev2.keycode = KEY_ESCAPE
		ev2.pressed = true
		Input.parse_input_event(ev2)
	# Fast-forward to floor 3 (first boss) to see boss UI: clear floor 2.
	await _wait(1.0)
	_kill_all_enemies()
	await _wait(3.0)
	_press("DESCEND")
	await _wait(1.5)
	_press("TAKE IT")
	await _wait(0.8)
	_press("CONTINUE")
	await _wait(1.5)
	if _find_button(get_tree().root, "LEAVE") != null:
		_press("LEAVE")
	await _wait(3.0)
	await _shot("floor3_boss")
	await _wait(4.0)
	await _shot("floor3_boss_later")
	print("TOURBOT done — ", _shots, " shots")
	get_tree().quit(0)
