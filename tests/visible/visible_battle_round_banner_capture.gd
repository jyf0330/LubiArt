extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const ROUND_FONT_PATH := "res://art/images/shared/pets/info_card/fonts/fusion_pixel_zh_hans.ttf"
const STEP_TIMEOUT_MSEC := 45000

var _capture_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_capture_dir = OS.get_environment("ROUND_BANNER_CAPTURE_DIR").strip_edges()
	if _capture_dir == "":
		_fail("ROUND_BANNER_CAPTURE_DIR is required")
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)

	var game := MainScene.instantiate()
	game.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(game)
	for _frame in range(12):
		await process_frame

	var battle := game.call("get_feature_controller", &"battle") as Control
	var session := game.call("get_game_session") as RefCounted
	if battle == null or session == null:
		_fail("battle entry is unavailable")
		return
	var auto_button := battle.get_node_or_null("MapControls/AutoArrangeButton") as TextureButton
	var begin_button := battle.get_node_or_null("MapControls/AllOutButton") as TextureButton
	if auto_button == null or begin_button == null:
		_fail("battle buttons are unavailable")
		return

	for round_number in [1, 2, 3]:
		var banner := await _wait_for_round_banner(battle, round_number)
		if banner == null:
			_fail("round %d banner was not observed" % round_number)
			return
		await create_timer(0.22).timeout
		_validate_banner(banner, round_number)
		await _capture("round_%02d.png" % round_number)
		if round_number == 3:
			break

		var before_auto := int(session.call("replay_step_index"))
		auto_button.pressed.emit()
		if not await _wait_for_step(session, before_auto + 1):
			_fail("auto arrange did not advance before round %d" % (round_number + 1))
			return
		var before_action := int(session.call("replay_step_index"))
		begin_button.pressed.emit()
		Engine.time_scale = 8.0
		if not await _wait_for_step(session, before_action + 1):
			_fail("start action did not advance before round %d" % (round_number + 1))
			return

	Engine.time_scale = 1.0
	print("VISIBLE_BATTLE_ROUND_BANNER_PASS captures=%s" % _capture_dir)
	quit(0)


func _wait_for_round_banner(battle: Control, round_number: int) -> Control:
	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		var banner := battle.get_node_or_null("Board/VfxHost/RoundFeedback") as Control
		if banner != null \
				and int(banner.get_meta("round_number", -1)) == round_number \
				and (banner.get_node("Title") as Label).text == "第%d回合" % round_number:
			return banner
		await process_frame
	return null


func _wait_for_step(session: RefCounted, expected_step: int) -> bool:
	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if int(session.call("replay_step_index")) == expected_step:
			return true
		await process_frame
	return false


func _validate_banner(banner: Control, round_number: int) -> void:
	var title := banner.get_node("Title") as Label
	var subtitle := banner.get_node("Subtitle") as Label
	assert(title.text == "第%d回合" % round_number)
	assert(title.get_theme_font("font") == subtitle.get_theme_font("font"))
	assert(title.get_theme_font("font").resource_path == ROUND_FONT_PATH)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var output_path := _capture_dir.path_join(file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		_fail("could not save %s: %s" % [file_name, error_string(error)])


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	push_error("VISIBLE_BATTLE_ROUND_BANNER_FAIL: %s" % message)
	quit(1)
