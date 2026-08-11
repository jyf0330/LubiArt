extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var output_path := OS.get_environment("HERO_CORNER_CAPTURE_OUTPUT").strip_edges()
	if output_path == "":
		push_error("VISIBLE_HERO_CORNER_CAPTURE_FAIL: HERO_CORNER_CAPTURE_OUTPUT is required")
		quit(1)
		return
	var main_instance := MainScene.instantiate()
	main_instance.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(main_instance)
	for _frame in range(24):
		await process_frame
	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	var session := main_instance.call("get_game_session") as RefCounted
	var response := Dictionary(session.call("submit_command", {
		"type": "AUTO_POSITION_HEROES",
	})) if session != null else {}
	if not bool(response.get("accepted", false)):
		push_error("VISIBLE_HERO_CORNER_CAPTURE_FAIL: auto arrange was not accepted")
		quit(1)
		return
	for _frame in range(12):
		await process_frame
	var snapshot := Dictionary(session.call("current_snapshot")) if session != null else {}
	var board_width := int(snapshot.get("boardWidth", snapshot.get("board_width", 8)))
	var board_height := int(snapshot.get("boardHeight", snapshot.get("board_height", 7)))
	if not _verify_corner_hero(
		battle_view,
		Vector2i(0, board_height - 1),
		"player_hero",
		"hero_wukong.png"
	):
		quit(1)
		return
	if not _verify_corner_hero(
		battle_view,
		Vector2i(board_width - 1, 0),
		"enemy_boss",
		"hero_spider.png"
	):
		quit(1)
		return
	var save_error := root.get_texture().get_image().save_png(output_path)
	if save_error != OK:
		push_error("VISIBLE_HERO_CORNER_CAPTURE_FAIL: %s" % error_string(save_error))
		quit(1)
		return
	print("VISIBLE_HERO_CORNER_CAPTURE_PASS: %s" % output_path)
	quit(0)


func _verify_corner_hero(
	battle_view: Control,
	expected_grid: Vector2i,
	expected_unit_id: String,
	expected_texture_suffix: String
) -> bool:
	if battle_view == null:
		push_error("VISIBLE_HERO_CORNER_CAPTURE_FAIL: battle view is unavailable")
		return false
	var cell_host := battle_view.get_node_or_null("Board/CellHost") as Control
	if cell_host == null:
		push_error("VISIBLE_HERO_CORNER_CAPTURE_FAIL: cell host is unavailable")
		return false
	for cell_value in cell_host.get_children():
		var cell := cell_value as Control
		if cell == null or not cell.has_method("get_grid_position"):
			continue
		if Vector2i(cell.call("get_grid_position")) != expected_grid:
			continue
		var cell_data := Dictionary(cell.get("cell_data"))
		var unit_id := String(cell_data.get("unitId", cell_data.get("unit_id", "")))
		var unit := cell.call("get_unit_node") as Control
		var texture_resource := unit.call("get_display_texture") as Texture2D if unit != null else null
		var texture_path := texture_resource.resource_path if texture_resource != null else ""
		if unit_id != expected_unit_id or not texture_path.ends_with(expected_texture_suffix):
			push_error(
				"VISIBLE_HERO_CORNER_CAPTURE_FAIL: grid=%s unit=%s texture=%s" % [
					expected_grid,
					unit_id,
					texture_path,
				]
			)
			return false
		print("VISIBLE_HERO_CORNER_VERIFIED: grid=%s unit=%s texture=%s" % [
			expected_grid,
			unit_id,
			texture_path,
		])
		return true
	push_error("VISIBLE_HERO_CORNER_CAPTURE_FAIL: grid %s is unavailable" % expected_grid)
	return false
