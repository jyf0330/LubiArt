extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const STEP_TIMEOUT_SECONDS := 45.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_instance := MainScene.instantiate()
	main_instance.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(main_instance)
	for _frame in range(8):
		await process_frame
	await create_timer(1.0).timeout

	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	var session := main_instance.call("get_game_session") as RefCounted
	if battle_view == null or session == null:
		_fail("main battle view or session is unavailable")
		return
	var auto_button := battle_view.get_node_or_null("Board/BattlePrimaryActions/AutoArrangeButton") as TextureButton
	var begin_button := battle_view.get_node_or_null("Board/BattlePrimaryActions/BeginTurnButton") as TextureButton
	if auto_button == null or begin_button == null:
		_fail("the two battle buttons are unavailable")
		return

	var cycles := 0
	while String(Dictionary(session.call("current_snapshot")).get("phase", "")) == "battle":
		var before_auto_step := int(session.call("replay_step_index"))
		auto_button.pressed.emit()
		if not await _wait_for_step(session, before_auto_step + 1):
			_fail("auto-position did not advance capture step %d" % (before_auto_step + 1))
			return
		await create_timer(0.35).timeout

		var before_action_step := int(session.call("replay_step_index"))
		begin_button.pressed.emit()
		if not await _wait_for_step(session, before_action_step + 1):
			_fail("start-action did not advance capture step %d" % (before_action_step + 1))
			return
		if not await _wait_for_vfx(battle_view):
			_fail("battle VFX did not settle after capture step %d" % (before_action_step + 1))
			return
		cycles += 1

	var final_snapshot := Dictionary(session.call("current_snapshot"))
	if String(final_snapshot.get("phase", "")) != "battle_end":
		_fail("capture replay stopped outside battle_end")
		return
	if int(session.call("replay_step_index")) != int(session.call("replay_step_count")):
		_fail("capture replay stopped before the final step")
		return
	print("VISIBLE_FORMAL_CAPTURE_REPLAY_PASS cycles=%d steps=%d stateVersion=%d stateHash=%s" % [
		cycles,
		int(session.call("replay_step_index")),
		int(final_snapshot.get("stateVersion", -1)),
		String(final_snapshot.get("stateHash", "")),
	])


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


func _fail(message: String) -> void:
	push_error("VISIBLE_FORMAL_CAPTURE_REPLAY_FAIL: %s" % message)
	quit(1)
