extends SceneTree

const MainScene := preload("res://art/scenes/three_choice/three_choice_scene.tscn")
const EARTH_SLIME_TEXTURE_PATH := "res://art/images/shared/pets/sheets/slices/pet_style_005_earth_slime.png"
const CAPTURE_SIZE := Vector2i(360, 360)


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

	var pet := _find_earth_slime(battle_view)
	if pet == null:
		_fail("earth slime is unavailable in the replay snapshot")
		return

	var original_center := pet.get_global_transform_with_canvas() * (pet.size * 0.5)
	var idle_dir := _capture_dir("idle")
	if not await _capture_frames(idle_dir, "earth_slime_idle", original_center, 36, 0.06):
		return

	pet.call("play_attack_translation", original_center + Vector2(110.0, 0.0), 0.46, 0.12, 0.06, 0.16)
	var attack_dir := _capture_dir("attack")
	if not await _capture_frames(attack_dir, "earth_slime_attack", original_center + Vector2(25.0, 0.0), 18, 0.03):
		return
	await create_timer(0.12).timeout

	var movement_origin := pet.global_position
	pet.call("play_grid_movement", movement_origin, movement_origin + Vector2(-72.0, 0.0), 0.42)
	var move_dir := _capture_dir("move")
	if not await _capture_frames(move_dir, "earth_slime_move", original_center + Vector2(-36.0, 0.0), 20, 0.03):
		return

	print("VISIBLE_EARTH_SLIME_ANIMATIONS_PASS idle=%s attack=%s move=%s" % [idle_dir, attack_dir, move_dir])
	quit(0)


func _capture_frames(
	output_dir: String,
	file_prefix: String,
	crop_center: Vector2,
	frame_count: int,
	frame_interval: float
) -> bool:
	DirAccess.make_dir_recursive_absolute(output_dir)
	for frame_index in range(frame_count):
		await RenderingServer.frame_post_draw
		var viewport_image := root.get_texture().get_image()
		var crop_rect := _centered_crop_rect(crop_center, viewport_image.get_size())
		var cropped := viewport_image.get_region(crop_rect)
		var frame_path := output_dir.path_join("%s_frame_%03d.png" % [file_prefix, frame_index + 1])
		if cropped.save_png(frame_path) != OK:
			_fail("could not save %s frame %d" % [file_prefix, frame_index + 1])
			return false
		await create_timer(frame_interval, true, false, true).timeout
	return true


func _capture_dir(animation_name: String) -> String:
	return OS.get_environment("TEMP").path_join("lubi_earth_slime_%s_frames" % animation_name)


func _find_earth_slime(battle_view: Control) -> Control:
	var board_grid := battle_view.get_node("Board/BoardGrid") as Control
	for cell in board_grid.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var pet := cell.call("get_unit_node") as Control
		if pet == null or not pet.has_method("get_display_texture"):
			continue
		var texture_resource := pet.call("get_display_texture") as Texture2D
		if texture_resource != null and texture_resource.resource_path == EARTH_SLIME_TEXTURE_PATH:
			return pet
	return null


func _centered_crop_rect(center: Vector2, image_size: Vector2i) -> Rect2i:
	var top_left := Vector2i(roundi(center.x - CAPTURE_SIZE.x * 0.5), roundi(center.y - CAPTURE_SIZE.y * 0.5))
	top_left.x = clampi(top_left.x, 0, maxi(0, image_size.x - CAPTURE_SIZE.x))
	top_left.y = clampi(top_left.y, 0, maxi(0, image_size.y - CAPTURE_SIZE.y))
	return Rect2i(top_left, CAPTURE_SIZE)


func _wait_for_step(session: RefCounted, expected_step: int) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if int(session.call("replay_step_index")) == expected_step:
			return true
		await process_frame
	return false


func _fail(message: String) -> void:
	push_error("VISIBLE_EARTH_SLIME_IDLE_FAIL: %s" % message)
	quit(1)
