extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await _settle(6)
	var session := MockSession.new({"start_phase": "battle"})
	var snapshot := Dictionary(session.call("current_snapshot"))
	battle.call("render_snapshot", snapshot)
	await _settle(6)

	var board := battle.get_node("Board") as Control
	assert(not bool(board.call("is_layout_grid_visible")))
	_assert_cells_match(board, false)

	var probe := BattleSceneProbe.new(battle)
	var drag_case := Dictionary(probe.call("first_player_drag_case", snapshot))
	assert(not drag_case.is_empty())
	var origin_data := Dictionary(drag_case.get("origin", {}))
	var target_data := Dictionary(drag_case.get("target", {}))
	var origin := Vector2i(int(origin_data.get("x", -1)), int(origin_data.get("y", -1)))
	var target := Vector2i(int(target_data.get("x", -1)), int(target_data.get("y", -1)))
	var started := Dictionary(probe.call("start_drag", origin, target))
	assert(bool(started.get("started", false)))
	assert(bool(board.call("is_layout_grid_visible")))
	_assert_cells_match(board, true)
	probe.call("cancel_drag")
	await _settle(2)
	# Pointer-down now owns an immediate local selection, so canceling movement
	# keeps the grid visible until the authoritative selection snapshot arrives.
	assert(bool(board.call("is_layout_grid_visible")))
	_assert_cells_match(board, true)
	battle.call("render_selection_snapshot", snapshot)
	await _settle(2)
	assert(not bool(board.call("is_layout_grid_visible")))

	var selected_snapshot := snapshot.duplicate(true)
	selected_snapshot["selected_unit_id"] = String(drag_case.get("unitId", ""))
	battle.call("render_snapshot", selected_snapshot)
	await _settle(2)
	assert(bool(board.call("is_layout_grid_visible")))
	_assert_cells_match(board, true)

	board.call("set_input_locked", true)
	assert(not bool(board.call("is_layout_grid_visible")))
	_assert_cells_match(board, false)
	board.call("set_input_locked", false)
	assert(bool(board.call("is_layout_grid_visible")))

	battle.call("render_snapshot", snapshot)
	await _settle(2)
	assert(not bool(board.call("is_layout_grid_visible")))
	_assert_cells_match(board, false)

	print("BATTLE_GRID_VISIBILITY_SMOKE_PASS")
	quit(0)


func _assert_cells_match(board: Control, expected: bool) -> void:
	var cell_host := board.get_node("CellHost")
	assert(cell_host.get_child_count() == 64)
	for child in cell_host.get_children():
		var cell := child as Control
		if cell == null or not cell.visible:
			continue
		assert(cell.has_method("are_grid_visuals_visible"))
		assert(bool(cell.call("are_grid_visuals_visible")) == expected)


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame
