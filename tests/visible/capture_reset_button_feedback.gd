extends SceneTree

const PREFAB := preload("res://art/prefabs/battle/hud/battle_map_controls.tscn")
const OUTPUT_DIR := "res://output/validation/reset_button_feedback"

var _prefab: Control
var _samples: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var background := TextureRect.new()
	background.size = Vector2(1920.0, 1080.0)
	background.texture = preload("res://art/images/battle/map_controls/maps/grassland_morning.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(background)
	_prefab = PREFAB.instantiate() as Control
	_prefab.position = Vector2(1621.0, 295.0)
	root.add_child(_prefab)
	await process_frame
	await process_frame
	await _capture_mouse_operation("01_reset_mouse_quick", _prefab.get_node("ResetButton") as TextureButton, false)
	await _capture_key_operation("02_reset_key_r_quick", KEY_R, _prefab.get_node("ResetButton") as TextureButton, false)
	await _capture_mouse_operation("03_reset_mouse_hold", _prefab.get_node("ResetButton") as TextureButton, true)
	await _capture_key_operation("04_reset_key_r_hold", KEY_R, _prefab.get_node("ResetButton") as TextureButton, true)
	await _capture_mouse_operation("05_auto_mouse_quick_control", _prefab.get_node("AutoArrangeButton") as TextureButton, false)
	var file := FileAccess.open(OUTPUT_DIR.path_join("samples.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples": _samples}, "\t") + "\n")
	file.close()
	print("RESET_BUTTON_FEEDBACK_VISIBLE_CAPTURE_PASS")
	quit(0)


func _capture_mouse_operation(name: String, button: TextureButton, hold: bool) -> void:
	await _capture("%s_before.png" % name)
	_dispatch_button_signal(button, true)
	if hold:
		await create_timer(0.09).timeout
	else:
		_dispatch_button_signal(button, false)
		await create_timer(0.03).timeout
	_samples.append({"name": name, "feedback_scale": [button.scale.x, button.scale.y], "down_connections": button.button_down.get_connections().size(), "up_connections": button.button_up.get_connections().size()})
	await _capture("%s_feedback.png" % name)
	if hold:
		_dispatch_button_signal(button, false)
	await create_timer(0.12).timeout
	await _capture("%s_after.png" % name)


func _capture_key_operation(name: String, keycode: int, button: TextureButton, hold: bool) -> void:
	await _capture("%s_before.png" % name)
	_dispatch_key(keycode, true)
	if hold:
		await create_timer(0.09).timeout
	else:
		_dispatch_key(keycode, false)
		await create_timer(0.03).timeout
	_samples.append({"name": name, "feedback_scale": [button.scale.x, button.scale.y], "down_connections": button.button_down.get_connections().size(), "up_connections": button.button_up.get_connections().size()})
	await _capture("%s_feedback.png" % name)
	if hold:
		_dispatch_key(keycode, false)
	await create_timer(0.12).timeout
	await _capture("%s_after.png" % name)


func _dispatch_button_signal(button: TextureButton, pressed: bool) -> void:
	if pressed:
		button.button_down.emit()
	else:
		button.button_up.emit()
		button.pressed.emit()


func _dispatch_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	_prefab._unhandled_key_input(event)


func _capture(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	assert(image.save_png(OUTPUT_DIR.path_join(file_name)) == OK)
