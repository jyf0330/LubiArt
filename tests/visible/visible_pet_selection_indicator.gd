extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const CAPTURE_PATH := "res://output/pet_selection_indicator_1920x1080.png"


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
	var board_grid: Control = null
	if battle_view != null:
		board_grid = battle_view.get_node_or_null("Board/CellHost") as Control
	if board_grid == null:
		_fail("battle board is unavailable")
		return

	var player_cells: Array[Control] = []
	for cell_value in board_grid.get_children():
		var cell := cell_value as Control
		if cell != null and cell.visible and cell.has_method("has_player_unit") \
				and bool(cell.call("has_player_unit")):
			player_cells.append(cell)
	if player_cells.size() < 2:
		_fail("two selectable player units are required")
		return

	_select_cell(player_cells[0])
	await _settle()
	var first_frame := _selection_frame(player_cells[0])
	var second_frame := _selection_frame(player_cells[1])
	if not _is_valid_visible_ring(first_frame):
		_fail("the selected unit has no visible yellow foot ring")
		return
	if second_frame.visible:
		_fail("an unselected unit is highlighted")
		return
	if not _tracks_shadow(first_frame, _unit_shadow(player_cells[0])):
		_fail("selection ring does not track the selected unit foot shadow")
		return

	_select_cell(player_cells[1])
	await _settle()
	if first_frame.visible or not _is_valid_visible_ring(second_frame):
		_fail("selection highlight did not switch to the newly selected unit")
		return
	if not _tracks_shadow(second_frame, _unit_shadow(player_cells[1])):
		_fail("switched selection ring does not track the new unit foot shadow")
		return

	await RenderingServer.frame_post_draw
	var absolute_path := ProjectSettings.globalize_path(CAPTURE_PATH)
	var error := root.get_texture().get_image().save_png(absolute_path)
	if error != OK:
		_fail("could not save capture (error %d)" % error)
		return
	print("VISIBLE_PET_SELECTION_INDICATOR_PASS %s" % absolute_path)
	quit(0)


func _select_cell(cell: Control) -> void:
	var grid := cell.call("get_grid_position") as Vector2i
	cell.emit_signal("cell_selected", grid.x, grid.y)


func _settle() -> void:
	for _frame in range(4):
		await process_frame
	await create_timer(0.08).timeout


func _selection_frame(cell: Control) -> TextureRect:
	var unit := cell.call("get_unit_node") as Control
	return unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/SelectionFrame") as TextureRect


func _unit_shadow(cell: Control) -> TextureRect:
	var unit := cell.call("get_unit_node") as Control
	return unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Shadow") as TextureRect


func _is_valid_visible_ring(frame: TextureRect) -> bool:
	if frame == null or not frame.visible or frame.texture == null:
		return false
	var shader_material := frame.material as ShaderMaterial
	if shader_material == null:
		return false
	var color: Color = shader_material.get_shader_parameter("ring_color")
	return color.r > 0.9 and color.g > 0.6 and color.b < 0.2


func _tracks_shadow(frame: TextureRect, shadow: TextureRect) -> bool:
	if frame == null or shadow == null:
		return false
	return frame.get_rect().encloses(shadow.get_rect()) \
		and frame.get_rect().get_center().distance_to(shadow.get_rect().get_center()) <= 1.0


func _fail(message: String) -> void:
	push_error("VISIBLE_PET_SELECTION_INDICATOR_FAIL: %s" % message)
	quit(1)
