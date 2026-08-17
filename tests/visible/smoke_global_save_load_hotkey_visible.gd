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

	await _press_j()
	var route_view := game.get_node("ThreeChoiceScene") as Control
	var run_tools := route_view.get_node_or_null("RunTools") as Control
	_expect(run_tools != null and run_tools.visible, "route J opens the code-generated quick toolbar")
	_expect(game.get_node_or_null("GlobalSettingsMenu") == null, "route J leaves the formal menu unmounted")
	await _capture("02_route_j_quick_toolbar.png")

	var save_button := run_tools.find_child("SaveButton", true, false) as Button
	var load_button := run_tools.find_child("LoadButton", true, false) as Button
	_expect(save_button != null and load_button != null, "quick toolbar exposes slot 1 save/load buttons")
	if save_button != null:
		save_button.pressed.emit()
	await _settle()
	await _capture("03_quick_save_complete.png")

	if load_button != null:
		load_button.pressed.emit()
	await _settle()
	await _capture("04_quick_load_complete.png")

	await _press_j()
	await process_frame
	_expect(run_tools != null and not run_tools.visible, "second J hides the quick toolbar")
	await _capture("05_route_j_closed.png")

	game.queue_free()
	await process_frame
	print("VISIBLE_GLOBAL_SAVE_LOAD_HOTKEY_%s:%s" % ["FAIL" if _failed else "OK", _output_dir])
	quit(1 if _failed else 0)


func _press_j() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_J
	press.physical_keycode = KEY_J
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_J
	release.physical_keycode = KEY_J
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
