extends SceneTree

const MainScene := preload("res://art/scenes/three_choice/three_choice_scene.tscn")
const PROJECTED_CAPTURE := "lubi_damage_preview_projected.png"
const CURRENT_CAPTURE := "lubi_damage_preview_current.png"
const LOOP_CAPTURE := "lubi_damage_preview_loop.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var main_instance := MainScene.instantiate()
	root.add_child(main_instance)
	for _frame in range(12):
		await process_frame
	await create_timer(0.5).timeout

	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	var session := main_instance.call("get_game_session") as RefCounted
	var auto_button := battle_view.get_node_or_null("Board/BattlePrimaryActions/AutoArrangeButton") as TextureButton if battle_view != null else null
	if battle_view == null or session == null or auto_button == null:
		_fail("battle view is unavailable")
		return

	var before_step := int(session.call("replay_step_index"))
	auto_button.pressed.emit()
	if not await _wait_for_step(session, before_step + 1):
		_fail("auto-position did not advance")
		return
	await create_timer(0.25).timeout

	var preview_pet := _first_preview_pet(battle_view)
	if preview_pet == null:
		_fail("enemy damage preview was not displayed")
		return
	var projected := Dictionary(preview_pet.call("get_damage_preview_snapshot"))
	if String(projected.get("state", "")) != "projected":
		_fail("preview did not start from projected HP")
		return
	await RenderingServer.frame_post_draw
	_save_capture(PROJECTED_CAPTURE)

	if not await _wait_for_state(preview_pet, "current", 3500):
		_fail("preview did not flash back to current HP")
		return
	await RenderingServer.frame_post_draw
	_save_capture(CURRENT_CAPTURE)

	if not await _wait_for_state(preview_pet, "projected", 2500):
		_fail("preview did not loop back to projected HP")
		return
	await RenderingServer.frame_post_draw
	_save_capture(LOOP_CAPTURE)
	print("VISIBLE_DAMAGE_PREVIEW_PASS projected=%s current=%s loop=%s" % [
		_capture_path(PROJECTED_CAPTURE),
		_capture_path(CURRENT_CAPTURE),
		_capture_path(LOOP_CAPTURE),
	])
	quit(0)


func _first_preview_pet(battle_view: Control) -> Control:
	var board_grid := battle_view.get_node("Board/BoardGrid") as Control
	for cell in board_grid.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var pet := cell.call("get_unit_node") as Control
		if pet == null or not pet.has_method("get_damage_preview_snapshot"):
			continue
		if bool(Dictionary(pet.call("get_damage_preview_snapshot")).get("active", false)):
			return pet
	return null


func _wait_for_step(session: RefCounted, expected_step: int) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if int(session.call("replay_step_index")) == expected_step:
			return true
		await process_frame
	return false


func _wait_for_state(pet: Control, expected_state: String, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		var preview := Dictionary(pet.call("get_damage_preview_snapshot"))
		if String(preview.get("state", "")) == expected_state:
			return true
		await process_frame
	return false


func _save_capture(file_name: String) -> void:
	var error := root.get_texture().get_image().save_png(_capture_path(file_name))
	if error != OK:
		_fail("could not save %s (error %d)" % [file_name, error])


func _capture_path(file_name: String) -> String:
	return OS.get_environment("TEMP").path_join(file_name)


func _fail(message: String) -> void:
	push_error("VISIBLE_DAMAGE_PREVIEW_FAIL: %s" % message)
	quit(1)
