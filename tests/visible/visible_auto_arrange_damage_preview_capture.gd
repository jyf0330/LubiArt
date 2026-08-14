extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const CAPTURE_NAME := "lubi_auto_arrange_damage_preview.png"
const POST_ACTION_CAPTURE_NAME := "lubi_post_action_health_colors.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var main_instance := MainScene.instantiate()
	main_instance.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(main_instance)
	for _frame in range(12):
		await process_frame
	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	if battle_view == null:
		_fail("battle view is unavailable")
		return
	var auto_arrange := battle_view.get_node_or_null("MapControls/AutoArrangeButton") as TextureButton
	if auto_arrange == null:
		_fail("auto-arrange button is unavailable")
		return
	auto_arrange.pressed.emit()
	for _frame in range(8):
		await process_frame

	var session := main_instance.call("get_game_session") as RefCounted
	var snapshot := Dictionary(session.call("current_snapshot"))
	var previews := Dictionary(snapshot.get(
		"placement_damage_by_unit",
		snapshot.get("placementDamageByUnit", {})
	))
	if previews.size() < 4:
		_fail("expected all available placement previews, got %d" % previews.size())
		return
	var red_segments := 0
	var shielded_preview_targets := 0
	var board_grid := battle_view.get_node("Board/CellHost") as Control
	for cell in board_grid.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var pet := cell.call("get_unit_node") as Control
		if pet == null or not pet.has_method("get_unit_id"):
			continue
		var unit_id := String(pet.call("get_unit_id"))
		if not previews.has(unit_id):
			continue
		var preview_state := Dictionary(pet.call("get_damage_preview_snapshot"))
		var red_segment := pet.get_node_or_null(
			"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/IncomingDamagePreview"
		) as Control
		var shield_segment := pet.get_node_or_null(
			"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Shield"
		) as Control
		if int(Dictionary(pet.get("cell_data")).get("shield", 0)) > 0:
			shielded_preview_targets += 1
		if not bool(preview_state.get("active", false)) \
				or int(preview_state.get("projected_hp", -1)) >= int(preview_state.get("current_hp", 0)) \
				or red_segment == null or not red_segment.visible or red_segment.size.x <= 0.0:
			_fail("%s has no visible red damage segment: %s" % [unit_id, preview_state])
			return
		if shield_segment != null and shield_segment.visible:
			_fail("%s still shows its shield during damage preview" % unit_id)
			return
		red_segments += 1
	if red_segments != previews.size():
		_fail("visible red segment count does not match all available previews")
		return
	if shielded_preview_targets <= 0:
		_fail("capture has no shielded preview target for regression coverage")
		return
	await RenderingServer.frame_post_draw
	var capture_path := OS.get_environment("TEMP").path_join(CAPTURE_NAME)
	var error := root.get_texture().get_image().save_png(capture_path)
	if error != OK:
		_fail("could not save capture (error %d)" % error)
		return
	var all_out := battle_view.get_node_or_null("MapControls/AllOutButton") as TextureButton
	if all_out == null:
		_fail("all-out button is unavailable")
		return
	all_out.pressed.emit()
	for _frame in range(2):
		await process_frame
	var restored_shields := 0
	for cell in board_grid.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var pet := cell.call("get_unit_node") as Control
		if pet == null or not pet.has_method("get_damage_preview_snapshot"):
			continue
		var preview_state := Dictionary(pet.call("get_damage_preview_snapshot"))
		var red_segment := pet.get_node_or_null(
			"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/IncomingDamagePreview"
		) as Control
		if bool(preview_state.get("active", false)) \
				or (red_segment != null and red_segment.visible):
			_fail("damage preview remained visible after combat started: %s" % preview_state)
			return
		var shield_segment := pet.get_node_or_null(
			"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Shield"
		) as Control
		if int(Dictionary(pet.get("cell_data")).get("shield", 0)) > 0 \
				and shield_segment != null and shield_segment.visible:
			restored_shields += 1
	if restored_shields <= 0:
		_fail("normal shield presentation was not restored after preview cleanup")
		return
	await RenderingServer.frame_post_draw
	var post_action_capture_path := OS.get_environment("TEMP").path_join(POST_ACTION_CAPTURE_NAME)
	error = root.get_texture().get_image().save_png(post_action_capture_path)
	if error != OK:
		_fail("could not save post-action capture (error %d)" % error)
		return
	print("VISIBLE_AUTO_ARRANGE_DAMAGE_PREVIEW_PASS red_segments=%d capture=%s post_action=%s" % [
		red_segments,
		capture_path,
		post_action_capture_path,
	])
	quit(0)


func _fail(message: String) -> void:
	push_error("VISIBLE_AUTO_ARRANGE_DAMAGE_PREVIEW_FAIL: %s" % message)
	quit(1)
