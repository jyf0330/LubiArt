extends SceneTree

const MainScene := preload("res://art/scenes/three_choice/three_choice_scene.tscn")
const FRAME_COUNT := 8
const CAPTURE_SIZE := Vector2i(420, 420)


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

	var pet := _find_unshielded_pet(battle_view)
	if pet == null:
		_fail("could not find an unshielded battle pet")
		return
	var current := Dictionary(pet.call("get_dynamic_stat_snapshot"))
	var current_hp := maxi(2, int(current.get("hp", 20)))
	pet.call("play_damage_feedback", {
		"finalDamage": 1,
		"shieldDamage": 0,
		"hpDamage": 1,
		"shieldFrom": 0,
		"shieldTo": 0,
		"hpTo": current_hp - 1,
	}, Vector2.RIGHT)

	var output_dir := ProjectSettings.globalize_path("res://output/hit_reaction_godot_frames")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var pet_center := pet.get_global_transform_with_canvas() * (pet.size * 0.5)
	for frame_index in range(FRAME_COUNT):
		await RenderingServer.frame_post_draw
		var viewport_image := root.get_texture().get_image()
		if frame_index == 2:
			viewport_image.save_png(ProjectSettings.globalize_path("res://output/hit_reaction_godot_preview_1920x1080.png"))
		var crop_rect := _centered_crop_rect(pet_center, viewport_image.get_size())
		var cropped := viewport_image.get_region(crop_rect)
		var frame_path := output_dir.path_join("hit_reaction_godot_frame_%03d.png" % (frame_index + 1))
		if cropped.save_png(frame_path) != OK:
			_fail("could not save capture frame %d" % (frame_index + 1))
			return
		await create_timer(0.06, true, false, true).timeout

	print("VISIBLE_HIT_REACTION_PASS: %s" % output_dir)
	quit(0)


func _find_unshielded_pet(battle_view: Control) -> Control:
	var board_grid := battle_view.get_node("Board/BoardGrid") as Control
	var candidates: Array[Control] = []
	for cell in board_grid.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var pet := cell.call("get_unit_node") as Control
		if pet == null or not pet.has_method("get_dynamic_stat_snapshot"):
			continue
		if int(Dictionary(pet.call("get_dynamic_stat_snapshot")).get("shield", 0)) <= 0:
			candidates.append(pet)
	for pet in candidates:
		var pet_data := Dictionary(pet.get("cell_data"))
		var unit_name := String(pet_data.get("unitName", pet_data.get("name", "")))
		if unit_name != "棉悠悠":
			return pet
	return candidates[0] if not candidates.is_empty() else null


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
	push_error("VISIBLE_HIT_REACTION_FAIL: %s" % message)
	quit(1)
