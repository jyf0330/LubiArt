extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const STEP_TIMEOUT_SECONDS := 45.0

var _output_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	_output_dir = OS.get_environment("LUBIART_ELEMENT_TILE_CAPTURE_DIR")
	if _output_dir == "":
		_fail("LUBIART_ELEMENT_TILE_CAPTURE_DIR is required")
		return
	var error := DirAccess.make_dir_recursive_absolute(_output_dir)
	if error != OK:
		_fail("could not create capture directory: %s" % error_string(error))
		return
	call_deferred("_run")


func _run() -> void:
	var main_instance := MainScene.instantiate()
	main_instance.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(main_instance)
	await _settle(10, 1.0)

	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	var session := main_instance.call("get_game_session") as RefCounted
	if battle_view == null or session == null:
		_fail("main battle view or session is unavailable")
		return
	var auto_button := battle_view.get_node_or_null("MapControls/AutoArrangeButton") as TextureButton
	var begin_button := battle_view.get_node_or_null("MapControls/AllOutButton") as TextureButton
	if auto_button == null or begin_button == null:
		_fail("the two battle buttons are unavailable")
		return

	await _capture("00_initial.png")
	for cycle in range(1, 4):
		if not await _press_and_wait_step(auto_button, session):
			_fail("auto-position did not advance cycle %d" % cycle)
			return
		await _settle(3, 0.2)
		await _capture("%02d_auto.png" % cycle)

		var before_action_step := int(session.call("replay_step_index"))
		begin_button.pressed.emit()
		if not await _wait_for_step(session, before_action_step + 1):
			_fail("start-action did not advance cycle %d" % cycle)
			return
		if not await _wait_for_vfx(battle_view):
			_fail("battle VFX did not settle after cycle %d" % cycle)
			return
		await _settle(3, 0.2)
		await _capture("%02d_action.png" % cycle)

	print("VISIBLE_ELEMENT_TILE_REPLAY_CAPTURE_PASS dir=%s" % _output_dir)
	quit()


func _press_and_wait_step(button: TextureButton, session: RefCounted) -> bool:
	var before_step := int(session.call("replay_step_index"))
	button.pressed.emit()
	return await _wait_for_step(session, before_step + 1)


func _wait_for_step(session: RefCounted, expected_step: int) -> bool:
	var deadline := Time.get_ticks_msec() + int(STEP_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if int(session.call("replay_step_index")) == expected_step:
			return true
		await process_frame
	return false


func _wait_for_vfx(battle_view: Control) -> bool:
	var deadline := Time.get_ticks_msec() + int(STEP_TIMEOUT_SECONDS * 1000.0)
	var observed_lock := false
	while Time.get_ticks_msec() < deadline:
		var locked := bool(battle_view.call("is_battle_input_locked"))
		observed_lock = observed_lock or locked
		if observed_lock and not locked:
			return true
		await process_frame
	return false


func _settle(frames: int, seconds: float) -> void:
	for _frame in range(frames):
		await process_frame
	if seconds > 0.0:
		await create_timer(seconds).timeout


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(_output_dir.path_join(file_name))
	if error != OK:
		_fail("could not save %s: %s" % [file_name, error_string(error)])


func _fail(message: String) -> void:
	push_error("VISIBLE_ELEMENT_TILE_REPLAY_CAPTURE_FAIL: %s" % message)
	quit(1)
