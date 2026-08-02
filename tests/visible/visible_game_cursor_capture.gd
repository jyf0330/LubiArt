extends SceneTree

const OUTPUT_DIR := "res://output"
const MockSession := preload("res://session/mock_game_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene := load("res://art/scenes/app/game.tscn") as PackedScene
	if scene == null:
		_fail("could not load main scene")
		return
	var instance := scene.instantiate()
	instance.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(instance)
	for _index in range(8):
		await process_frame
	await create_timer(0.8).timeout
	var cursor := instance.get_node_or_null("GameCursor")
	if cursor == null:
		_fail("game cursor prefab is missing")
		return
	Input.warp_mouse(Vector2(960.0, 540.0))
	await process_frame

	cursor.call("reset_interaction")
	await _capture("game_cursor_pointer_1920x1080.png")
	var battle := instance.call("get_feature_controller", &"battle") as Control
	var pet_cell := _first_draggable_pet_cell(battle)
	if pet_cell == null:
		_fail("could not find a draggable pet for cursor interaction")
		return
	var pet_point := _opaque_pet_point(pet_cell)
	if pet_point.x < 0.0:
		_fail("could not find an opaque pet pixel for cursor interaction")
		return
	Input.warp_mouse(Vector2i(pet_point))
	await process_frame
	var pet_grid := pet_cell.call("get_grid_position") as Vector2i
	battle.call("_on_cell_hovered", pet_grid.x, pet_grid.y)
	battle.call("_refresh_cursor_hover_state")
	if StringName(cursor.call("debug_state")) != &"pet_hover":
		_fail("pet hover did not switch to the open hand")
		return
	await _capture("game_cursor_hand_open_1920x1080.png")
	battle.call("_start_unit_drag", pet_grid)
	if StringName(cursor.call("debug_state")) != &"grabbing":
		_fail("pet drag did not switch to the grabbing hand")
		return
	await _capture("game_cursor_hand_grab_1920x1080.png")
	Input.warp_mouse(Vector2i(pet_point))
	await process_frame
	var preview_grid := pet_grid + Vector2i(1 if pet_grid.x < 7 else -1, 0)
	battle.call("_debug_update_drag_preview_position", preview_grid)
	battle.call("_finish_unit_drag", pet_grid)
	if StringName(cursor.call("debug_state")) != &"pet_hover":
		_fail("releasing the pet did not restore the open hand (state=%s, hovered=%s, hit=%s)" % [
			String(cursor.call("debug_state")),
			str(battle.get("_hovered_grid")),
			"%s mouse=%s expected=%s unit=%s" % [
				str(battle.call("_mouse_is_over_draggable_pet", pet_cell)),
				str(root.get_viewport().get_mouse_position()),
				str(pet_point),
				str(pet_cell.call("get_unit_node")),
			],
		])
		return
	cursor.call("set_loading_source", &"visible_capture", true)
	await create_timer(1.4).timeout
	await _capture("game_cursor_hourglass_1920x1080.png")
	cursor.call("set_loading_source", &"visible_capture", false)
	cursor.call("reset_interaction")
	instance.queue_free()
	await process_frame
	print("VISIBLE_GAME_CURSOR_CAPTURE_PASS")
	quit()


func _first_draggable_pet_cell(battle: Control) -> Control:
	if battle == null:
		return null
	var board_grid := battle.get_node_or_null("Board/BoardGrid")
	if board_grid == null:
		return null
	for value in board_grid.get_children():
		var cell := value as Control
		if cell != null and cell.visible and bool(battle.call("_cell_has_draggable_player_unit", cell)):
			return cell
	return null


func _opaque_pet_point(cell: Control) -> Vector2:
	var unit := cell.call("get_unit_node") as Control
	if unit == null:
		return Vector2(-1.0, -1.0)
	var art := unit.get_node_or_null("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
	if art == null or art.texture == null:
		return Vector2(-1.0, -1.0)
	var image := art.texture.get_image()
	if image == null or image.is_empty():
		return Vector2(-1.0, -1.0)
	var image_center := Vector2(image.get_width(), image.get_height()) * 0.5
	var best_pixel := Vector2i(-1, -1)
	var best_distance := INF
	var used_rect := image.get_used_rect()
	for y in range(used_rect.position.y, used_rect.end.y):
		for x in range(used_rect.position.x, used_rect.end.x):
			if image.get_pixel(x, y).a < 0.08:
				continue
			var distance := Vector2(x, y).distance_squared_to(image_center)
			if distance < best_distance:
				best_distance = distance
				best_pixel = Vector2i(x, y)
	if best_pixel.x < 0:
		return Vector2(-1.0, -1.0)
	var texture_size := art.texture.get_size()
	var fit_scale := minf(art.size.x / texture_size.x, art.size.y / texture_size.y)
	var drawn_size := texture_size * fit_scale
	var drawn_origin := (art.size - drawn_size) * 0.5
	var local_point := drawn_origin + (Vector2(best_pixel) + Vector2(0.5, 0.5)) / texture_size * drawn_size
	return art.get_global_transform_with_canvas() * local_point


func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
	if error != OK:
		_fail("could not save %s" % file_name)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
