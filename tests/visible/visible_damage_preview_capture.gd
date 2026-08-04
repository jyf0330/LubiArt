extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const VISIBLE_CAPTURE := "lubi_damage_preview_visible.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var main_instance := MainScene.instantiate()
	main_instance.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(main_instance)
	for _frame in range(12):
		await process_frame
	await create_timer(0.5).timeout

	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	var session := main_instance.call("get_game_session") as RefCounted
	if battle_view == null or session == null:
		_fail("battle view is unavailable")
		return

	var drag_pair := _first_drag_pair(Dictionary(session.call("current_snapshot")))
	if drag_pair.is_empty():
		_fail("no pre-auto-arrange drag target was available")
		return
	var drag_origin := Vector2i(
		int(Dictionary(drag_pair.get("origin", {})).get("x", -1)),
		int(Dictionary(drag_pair.get("origin", {})).get("y", -1))
	)
	var drag_target := Vector2i(
		int(Dictionary(drag_pair.get("drag_target", {})).get("x", drag_origin.x)),
		int(Dictionary(drag_pair.get("drag_target", {})).get("y", drag_origin.y))
	)
	battle_view.call("_start_unit_drag", drag_origin)
	battle_view.call("_debug_update_drag_preview_position", drag_target)
	await process_frame
	var preview_pet := _preview_pet_by_unit_id(battle_view, String(drag_pair.get("target_unit_id", "")))
	if preview_pet == null:
		_fail("dragged attack range did not pin the enemy damage badge")
		return
	var visible_preview := Dictionary(preview_pet.call("get_damage_preview_snapshot"))
	if String(visible_preview.get("state", "")) != "visible" \
			or not bool(visible_preview.get("pinned", false)):
		_fail("held drag preview was not continuously visible")
		return
	await create_timer(1.25).timeout
	visible_preview = Dictionary(preview_pet.call("get_damage_preview_snapshot"))
	if String(visible_preview.get("state", "")) != "visible" \
			or not bool(visible_preview.get("pinned", false)):
		_fail("held drag preview blinked before mouse release")
		return
	await _stabilize_battle_view(battle_view)
	await RenderingServer.frame_post_draw
	_save_capture(VISIBLE_CAPTURE)

	battle_view.call("_finish_unit_drag", drag_target)
	var settled_preview := Dictionary(preview_pet.call("get_damage_preview_snapshot"))
	if not bool(settled_preview.get("pinned", false)) \
			or String(settled_preview.get("state", "")) != "visible" \
			or not is_zero_approx(float(settled_preview.get("seconds_to_switch", -1.0))):
		_fail("settled preview was not kept permanently visible")
		return
	await create_timer(1.25).timeout
	settled_preview = Dictionary(preview_pet.call("get_damage_preview_snapshot"))
	if not bool(settled_preview.get("pinned", false)) \
			or String(settled_preview.get("state", "")) != "visible":
		_fail("settled preview stopped being permanently visible")
		return
	await _stabilize_battle_view(battle_view)
	await RenderingServer.frame_post_draw
	_save_capture(VISIBLE_CAPTURE)
	print("VISIBLE_DAMAGE_PREVIEW_PASS permanent=%s" % _capture_path(VISIBLE_CAPTURE))
	quit(0)


func _stabilize_battle_view(battle_view: Control) -> void:
	var vfx_player := battle_view.get_node_or_null("Board/VfxHost")
	if vfx_player != null:
		var round_feedback := vfx_player.get_node_or_null("RoundFeedback")
		if round_feedback != null:
			round_feedback.queue_free()
	var board_grid := battle_view.get_node_or_null("Board/CellHost")
	if board_grid != null:
		for cell in board_grid.get_children():
			if not cell.has_method("get_unit_node"):
				continue
			var pet := cell.call("get_unit_node") as Control
			if pet == null:
				continue
			var animation := pet.get_node_or_null("CompleteBattleCreaturePrefab/03_AttackActions")
			if animation != null and animation.has_method("reset"):
				animation.call("reset")
	await process_frame
	await RenderingServer.frame_post_draw


func _preview_pet_by_unit_id(battle_view: Control, unit_id: String) -> Control:
	var board_grid := battle_view.get_node("Board/CellHost") as Control
	for cell in board_grid.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var pet := cell.call("get_unit_node") as Control
		if pet == null or not pet.has_method("get_unit_id"):
			continue
		if String(pet.call("get_unit_id")) == unit_id:
			return pet
	return null


func _first_drag_pair(snapshot: Dictionary) -> Dictionary:
	var board := Dictionary(snapshot.get("board", {}))
	var board_cells := Array(board.get("cells", []))
	var columns := int(board.get("width", snapshot.get("board_width", 8)))
	var rows := int(board.get("height", snapshot.get("board_height", 7)))
	var cell_by_key := {}
	for board_cell_value in board_cells:
		var board_cell := Dictionary(board_cell_value)
		cell_by_key["%d,%d" % [int(board_cell.get("x", -1)), int(board_cell.get("y", -1))]] = board_cell
	var previews := Dictionary(snapshot.get("action_preview_by_unit", {}))
	for actor_value in previews.keys():
		var actor_id := String(actor_value)
		var preview := Dictionary(previews[actor_value])
		var origin_data := Dictionary(preview.get("origin", {}))
		var origin := Vector2i(int(origin_data.get("x", -1)), int(origin_data.get("y", -1)))
		var original_target_ids := {}
		for cell_value in Array(preview.get("cells", [])):
			var cell := Dictionary(cell_value)
			var target_unit_id := String(cell.get("target_unit_id", cell.get("targetUnitId", "")))
			if target_unit_id != "":
				original_target_ids[target_unit_id] = true
		for shape_cell_value in Array(preview.get("cells", [])):
			var shape_cell := Dictionary(shape_cell_value)
			var offset := Vector2i(
				int(shape_cell.get("x", shape_cell.get("c", -1))),
				int(shape_cell.get("y", shape_cell.get("r", -1)))
			) - origin
			for target_cell_value in board_cells:
				var target_cell := Dictionary(target_cell_value)
				var target_unit_id := String(target_cell.get("unitId", target_cell.get("unit_id", "")))
				if not target_unit_id.begins_with("enemy_") or original_target_ids.has(target_unit_id):
					continue
				var target_grid := Vector2i(int(target_cell.get("x", -1)), int(target_cell.get("y", -1)))
				var candidate := target_grid - offset
				if candidate.x < 0 or candidate.y < 0 or candidate.x >= columns or candidate.y >= rows:
					continue
				var candidate_cell := Dictionary(cell_by_key.get("%d,%d" % [candidate.x, candidate.y], {}))
				var occupying_unit_id := String(candidate_cell.get("unitId", candidate_cell.get("unit_id", "")))
				if occupying_unit_id != "" and occupying_unit_id != actor_id:
					continue
				return {
					"actor_id": actor_id,
					"origin": origin_data.duplicate(true),
					"drag_target": {"x": candidate.x, "y": candidate.y},
					"target_unit_id": target_unit_id,
				}
	return {}


func _save_capture(file_name: String) -> void:
	var error := root.get_texture().get_image().save_png(_capture_path(file_name))
	if error != OK:
		_fail("could not save %s (error %d)" % [file_name, error])


func _capture_path(file_name: String) -> String:
	return OS.get_environment("TEMP").path_join(file_name)


func _fail(message: String) -> void:
	push_error("VISIBLE_DAMAGE_PREVIEW_FAIL: %s" % message)
	quit(1)
