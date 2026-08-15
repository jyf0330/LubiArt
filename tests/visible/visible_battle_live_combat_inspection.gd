extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

var _capture_path := ""


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_capture_path = OS.get_environment("LIVE_COMBAT_INSPECTION_CAPTURE").strip_edges()
	if _capture_path == "":
		_fail("LIVE_COMBAT_INSPECTION_CAPTURE is required")
		return
	DirAccess.make_dir_recursive_absolute(_capture_path.get_base_dir())

	var main := MainScene.instantiate() as Control
	var session := MockSession.new({"start_phase": "battle"})
	main.call("set_game_session", session)
	root.add_child(main)
	await _settle(16)
	var battle := main.call("get_feature_controller", &"battle") as Control
	if battle == null:
		_fail("battle feature is unavailable")
		return
	var probe := BattleSceneProbe.new(battle)
	var auto_button := battle.get_node_or_null("MapControls/AutoArrangeButton") as TextureButton
	var begin_button := battle.get_node_or_null("MapControls/AllOutButton") as TextureButton
	if not bool(probe.call("is_ready")) or auto_button == null or begin_button == null:
		_fail("battle controls or probe are unavailable")
		return

	var before_auto_step := int(session.call("replay_step_index"))
	auto_button.pressed.emit()
	if not await _wait_for_step(session, before_auto_step + 1):
		_fail("auto arrange did not advance the replay")
		return
	await _settle(4)
	var before_action_step := int(session.call("replay_step_index"))
	begin_button.pressed.emit()
	if not await _wait_for_step(session, before_action_step + 1):
		_fail("combat round did not advance the replay")
		return
	if not await _wait_for_lock(battle):
		_fail("combat presentation never locked gameplay input")
		return

	var player_case := Dictionary(probe.call("first_player_drag_case"))
	if player_case.is_empty():
		_fail("no player pet is available during combat")
		return
	var origin_value := Dictionary(player_case.get("origin", {}))
	var target_value := Dictionary(player_case.get("target", {}))
	var origin := Vector2i(int(origin_value.get("x", -1)), int(origin_value.get("y", -1)))
	var target := Vector2i(int(target_value.get("x", -1)), int(target_value.get("y", -1)))
	var player_cell := probe.call("cell_at", origin) as Control
	var player_id := _unit_id(player_cell)
	if player_cell == null or player_id == "":
		_fail("player pet cell is unavailable during combat")
		return
	player_cell.emit_signal("cell_selected", origin.x, origin.y)
	await _settle(3)
	var board := battle.get_node_or_null("Board") as Control
	var overlay := battle.get_node_or_null("OverlayHost")
	var detail := Dictionary(probe.call("detail_summary"))
	if board == null or String(board.call("current_selected_unit_id")) != player_id \
			or overlay == null or String(overlay.get("_active_detail_unit_id")) != player_id \
			or not bool(detail.get("visible", false)):
		_fail("live combat click did not select the pet and show its info card")
		return
	var drag_attempt := Dictionary(probe.call("start_drag", origin, target))
	if bool(drag_attempt.get("started", false)):
		_fail("live combat click unexpectedly started a pet drag")
		return
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(_capture_path)
	if error != OK:
		_fail("could not save live combat capture: %s" % error_string(error))
		return
	print("VISIBLE_BATTLE_LIVE_COMBAT_INSPECTION_PASS: %s" % _capture_path)
	quit(0)


func _wait_for_step(session: RefCounted, expected_step: int) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if int(session.call("replay_step_index")) == expected_step:
			return true
		await process_frame
	return false


func _wait_for_lock(battle: Control) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if bool(battle.call("is_battle_input_locked")):
			return true
		await process_frame
	return false


func _unit_id(cell: Control) -> String:
	if cell == null:
		return ""
	var value = cell.get("cell_data")
	var data := Dictionary(value) if value is Dictionary else {}
	return String(data.get("unitId", data.get("unit_id", "")))


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	push_error("VISIBLE_BATTLE_LIVE_COMBAT_INSPECTION_FAIL: %s" % message)
	quit(1)
