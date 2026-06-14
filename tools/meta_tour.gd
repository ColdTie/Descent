extends Node
## TEMPORARY dev-only one-shot — click META on the title screen and screenshot
## the MetaScreen so the new Run 36 surface can be visually audited. Mirrors
## tools/tour_bot.gd's find-button-by-text pattern.

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tour"))
	_run()

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
		print("META-TOUR: no button containing '", contains, "'"); return false
	print("META-TOUR pressing: ", b.text)
	b.pressed.emit()
	return true

func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "user://tour/meta_%s.png" % tag
	img.save_png(path)
	print("META-TOUR shot: ", path)

func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	await _shot("title")
	_press("META")
	await get_tree().create_timer(1.0).timeout
	await _shot("screen")
	# Click BUY on Iron Blood to test purchase flow visually.
	_press("BUY")
	await get_tree().create_timer(0.6).timeout
	await _shot("after_buy")
	get_tree().quit(0)
