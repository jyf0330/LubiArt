extends SceneTree

const GAME_SCENE := preload("res://art/scenes/app/game.tscn")

var _failed := false
var _output_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("YSBZS_VISIBLE_OUTPUT")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://output/validation/global_save_load_hotkey")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var game := GAME_SCENE.instantiate() as Control
	_set_mock_route_if_supported(game)
	root.add_child(game)
	await _settle()
	await _capture("01_route_default_hidden.png")

	await _press_h()
	var menu := game.get_node_or_null("GlobalSettingsMenu") as Control
	_expect(menu != null, "route H mounts the global menu")
	await _capture("02_route_h_open.png")

	var buttons_root := "CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/"
	(menu.get_node(buttons_root + "SaveGame") as Button).pressed.emit()
	await _settle()
	_expect(menu.get_node_or_null("UISaveGame") != null, "existing save dialog is mounted dynamically")
	await _capture("03_save_dialog.png")

	menu.call("handle_cancel")
	(menu.get_node(buttons_root + "LoadGame") as Button).pressed.emit()
	await _settle()
	_expect(menu.get_node_or_null("UILoadGame") != null, "existing load dialog is mounted dynamically")
	await _capture("04_load_dialog.png")

	await _press_h()
	await process_frame
	_expect(game.get_node_or_null("GlobalSettingsMenu") == null, "second H hides and releases the menu")
	await _capture("05_route_h_closed.png")

	game.queue_free()
	await process_frame
	print("VISIBLE_GLOBAL_SAVE_LOAD_HOTKEY_%s:%s" % ["FAIL" if _failed else "OK", _output_dir])
	quit(1 if _failed else 0)


func _press_h() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_H
	press.physical_keycode = KEY_H
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_H
	release.physical_keycode = KEY_H
	release.pressed = false
	Input.parse_input_event(release)
	await _settle()


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.15).timeout


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := _output_dir.path_join(file_name)
	var error := image.save_png(path)
	_expect(error == OK, "capture saved: %s" % path)


func _set_mock_route_if_supported(game: Control) -> void:
	for property in game.get_property_list():
		if String(property.get("name", "")) == "mock_start_phase":
			game.set("mock_start_phase", "route")
			return


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("VISIBLE_GLOBAL_SAVE_LOAD_HOTKEY_FAIL: %s" % message)
