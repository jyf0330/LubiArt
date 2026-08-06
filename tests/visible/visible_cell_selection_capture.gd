extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const CAPTURE_PATH := "res://output/battle_cell_selection_1920x1080.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var main_instance := MainScene.instantiate()
	main_instance.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(main_instance)
	for _frame in range(16):
		await process_frame
	await create_timer(0.25).timeout

	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	if battle_view == null:
		_fail("battle view is unavailable")
		return
	var board_grid := battle_view.get_node_or_null("Board/CellHost") as Control
	if board_grid == null:
		_fail("board grid is unavailable")
		return

	var selected_cell: Control = null
	var hover_cell: Control = null
	for cell_value in board_grid.get_children():
		var cell := cell_value as Control
		if cell == null or not cell.visible or not cell.has_method("get_unit_node"):
			continue
		if cell.call("get_unit_node") == null and (selected_cell == null or cell.position.y > selected_cell.position.y):
			selected_cell = cell
		elif hover_cell == null and cell.call("get_unit_node") == null:
			hover_cell = cell
	if selected_cell == null or hover_cell == null:
		_fail("could not find two distinct empty cells")
		return

	var drag_origin: Control = null
	var occupied_target: Control = null
	for cell_value in board_grid.get_children():
		var cell := cell_value as Control
		if cell == null or not cell.visible:
			continue
		var unit_id := _cell_unit_id(cell)
		if drag_origin == null and unit_id != "" and bool(cell.call("has_player_unit")):
			drag_origin = cell
		elif occupied_target == null and unit_id != "":
			occupied_target = cell
	if drag_origin == null or occupied_target == null:
		_fail("could not find drag source and occupied target")
		return

	var dragged_unit_id := _cell_unit_id(drag_origin)
	var occupied_unit_id := _cell_unit_id(occupied_target)
	var drag_origin_grid := drag_origin.call("get_grid_position") as Vector2i
	var selected_grid := selected_cell.call("get_grid_position") as Vector2i
	var occupied_grid := occupied_target.call("get_grid_position") as Vector2i
	var hover_grid := hover_cell.call("get_grid_position") as Vector2i
	if _visible_attack_highlight_count(board_grid) != 0:
		_fail("attack cells are visible before a unit is dragged")
		return
	battle_view.call("_start_unit_drag", drag_origin_grid)
	battle_view.call("_debug_update_drag_preview_position", selected_grid)
	if _visible_attack_highlight_count(board_grid) == 0:
		_fail("current unit attack cells are missing during drag")
		return
	battle_view.call("_finish_unit_drag", selected_grid)
	await create_timer(0.2).timeout
	if _cell_unit_id(drag_origin) != "" or _cell_unit_id(selected_cell) != dragged_unit_id:
		_fail("unit did not settle on the empty cell")
		return
	if _visible_attack_highlight_count(board_grid) != 0:
		_fail("attack cells remained visible after a successful drop")
		return
	battle_view.call("_start_unit_drag", selected_grid)
	battle_view.call("_debug_update_drag_preview_position", occupied_grid)
	if bool(occupied_target.call("is_hover_highlight_visible")):
		_fail("occupied cell is shown as a valid drag target")
		return
	battle_view.call("_finish_unit_drag", occupied_grid)
	await create_timer(0.2).timeout
	if _cell_unit_id(selected_cell) != dragged_unit_id or _cell_unit_id(occupied_target) != occupied_unit_id:
		_fail("occupied-cell drop did not return the dragged unit")
		return
	if _visible_attack_highlight_count(board_grid) != 0:
		_fail("attack cells remained visible after a rejected drop")
		return
	battle_view.call("_on_cell_unhovered", hover_grid.x, hover_grid.y)
	battle_view.call("_on_cell_hovered", hover_grid.x, hover_grid.y)
	await process_frame
	await RenderingServer.frame_post_draw

	var hover_highlight := hover_cell.get_node_or_null("HoverHighlight") as Polygon2D
	var unit_host := battle_view.get_node_or_null("Board/UnitHost") as Control
	if hover_highlight == null or unit_host == null:
		_fail("interaction or unit layers are missing from battle scene")
		return
	if selected_cell.get_node_or_null("SelectedFrame") != null:
		_fail("obsolete selection frame is still present")
		return
	if not hover_highlight.visible:
		_fail("hover layer is not visible")
		return

	var absolute_path := ProjectSettings.globalize_path(CAPTURE_PATH)
	var error := root.get_texture().get_image().save_png(absolute_path)
	if error != OK:
		_fail("could not save capture (error %d)" % error)
		return
	battle_view.call("_on_cell_unhovered", hover_grid.x, hover_grid.y)
	await process_frame
	if hover_highlight.visible:
		_fail("mouse exit must clear the blue hover")
		return
	print("VISIBLE_CELL_SELECTION_PASS %s" % absolute_path)
	quit(0)


func _fail(message: String) -> void:
	push_error("VISIBLE_CELL_SELECTION_FAIL: %s" % message)
	quit(1)


func _cell_unit_id(cell: Control) -> String:
	var data := Dictionary(cell.get("cell_data"))
	return String(data.get("unitId", data.get("unit_id", "")))


func _visible_attack_highlight_count(board_grid: Control) -> int:
	var count := 0
	for cell_value in board_grid.get_children():
		var cell := cell_value as Control
		if cell == null or not cell.visible:
			continue
		var border := cell.get_node_or_null("AttackHighlightBorder") as Line2D
		if border != null and border.visible:
			count += 1
	return count
