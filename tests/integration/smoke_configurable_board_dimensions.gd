extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")
const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_default_dimensions()
	for dimensions in [Vector2i(8, 8), Vector2i(8, 7), Vector2i(6, 6)]:
		await _verify_dimensions(dimensions)
	await _verify_legacy_save_dimensions()
	await _verify_legacy_replay_dimensions()
	await _verify_ui_reuses_authored_pool()
	if failed:
		quit(1)
		return
	print("SMOKE_CONFIGURABLE_BOARD_DIMENSIONS_OK sizes=8x8,8x7,6x6")
	quit(0)


func _verify_default_dimensions() -> void:
	var state: RefCounted = StateScript.new()
	var dimensions := state.call("board_dimensions") as Vector2i
	_expect(dimensions == Vector2i(8, 7), "new runs default to 8x7")
	state.call("start_battle")
	var board := Dictionary(Dictionary(state.call("snapshot")).get("board", {}))
	_expect(int(board.get("width", 0)) == 8 and int(board.get("height", 0)) == 7, "default battle snapshot is 8x7")
	_expect(Array(board.get("cells", [])).size() == 56, "default battle emits 56 cells")
	await process_frame


func _verify_dimensions(dimensions: Vector2i) -> void:
	var state: RefCounted = StateScript.new()
	_expect(bool(state.call("set_board_dimensions", dimensions.x, dimensions.y)), "%s accepts dimensions" % _label(dimensions))
	state.call("start_battle")
	var snap: Dictionary = state.call("snapshot")
	var board := Dictionary(snap.get("board", {}))
	var cells := Array(board.get("cells", []))
	_expect(int(board.get("width", 0)) == dimensions.x, "%s snapshot width" % _label(dimensions))
	_expect(int(board.get("height", 0)) == dimensions.y, "%s snapshot height" % _label(dimensions))
	_expect(int(board.get("cellCount", 0)) == dimensions.x * dimensions.y, "%s snapshot cell count field" % _label(dimensions))
	_expect(cells.size() == dimensions.x * dimensions.y, "%s emits every board cell" % _label(dimensions))
	_expect(_unique_in_bounds_cell_count(cells, dimensions) == cells.size(), "%s cells are unique and in bounds" % _label(dimensions))
	_expect(bool(state.call("_inside", dimensions.x - 1, dimensions.y - 1)), "%s accepts its last playable cell" % _label(dimensions))
	_expect(not bool(state.call("_inside", dimensions.x, dimensions.y - 1)), "%s rejects the first column outside width" % _label(dimensions))
	_expect(not bool(state.call("_inside", dimensions.x - 1, dimensions.y)), "%s rejects the first row outside height" % _label(dimensions))
	var leaders := Dictionary(snap.get("leaders", {}))
	var player_leader := Dictionary(leaders.get("player", {}))
	var enemy_leader := Dictionary(leaders.get("enemy", {}))
	_expect(Vector2i(int(player_leader.get("x", -1)), int(player_leader.get("y", -1))) == Vector2i(0, dimensions.y - 1), "%s player leader uses bottom-left corner" % _label(dimensions))
	_expect(Vector2i(int(enemy_leader.get("x", -1)), int(enemy_leader.get("y", -1))) == Vector2i(dimensions.x - 1, 0), "%s enemy leader uses top-right corner" % _label(dimensions))
	var player_spawn_region: Array[Vector2i] = BoardDimensionsScript.side_spawn_region_cells(dimensions, true, 3)
	var enemy_spawn_region: Array[Vector2i] = BoardDimensionsScript.side_spawn_region_cells(dimensions, false, 3)
	var first_player_id := ""
	for unit_value in Array(snap.get("units", [])):
		var unit := Dictionary(unit_value)
		if int(unit.get("hp", 0)) <= 0:
			continue
		var unit_cell := Vector2i(int(unit.get("x", -1)), int(unit.get("y", -1)))
		_expect(_inside(dimensions, unit_cell.x, unit_cell.y), "%s keeps %s in bounds" % [_label(dimensions), String(unit.get("id", "unit"))])
		if String(unit.get("side", "")) == StateScript.PLAYER:
			if first_player_id == "":
				first_player_id = String(unit.get("id", ""))
			_expect(player_spawn_region.has(unit_cell), "%s player pet %s starts inside the player 3x3 region" % [_label(dimensions), String(unit.get("id", "unit"))])
		else:
			_expect(enemy_spawn_region.has(unit_cell), "%s enemy pet %s starts inside the enemy 3x3 region" % [_label(dimensions), String(unit.get("id", "unit"))])
	_expect(first_player_id != "" and bool(state.call("select_unit", first_player_id)), "%s can select a real player pet" % _label(dimensions))
	_expect(not bool(state.call("select_cell", dimensions.x, dimensions.y - 1)), "%s public cell command rejects the first column outside width" % _label(dimensions))
	_expect(not bool(state.call("select_cell", dimensions.x - 1, dimensions.y)), "%s public cell command rejects the first row outside height" % _label(dimensions))
	for side in [StateScript.PLAYER, StateScript.ENEMY]:
		var reset_units := Array(state.call("_reset_side_pets", side))
		var expected_region := player_spawn_region if side == StateScript.PLAYER else enemy_spawn_region
		var leader_cell := Vector2i(0, dimensions.y - 1) if side == StateScript.PLAYER else Vector2i(dimensions.x - 1, 0)
		for unit_value in reset_units:
			var unit := Dictionary(unit_value)
			var unit_cell := Vector2i(int(unit.get("x", -1)), int(unit.get("y", -1)))
			_expect(expected_region.has(unit_cell), "%s %s reset pet %s stays inside its 3x3 region" % [_label(dimensions), side, String(unit.get("id", "unit"))])
			_expect(unit_cell != leader_cell, "%s %s reset pet does not cover its leader" % [_label(dimensions), side])
	_expect(bool(state.call("auto_position_heroes")), "%s auto position runs on configured board" % _label(dimensions))
	_expect(not bool(state.call("set_board_dimensions", dimensions.x, maxi(1, dimensions.y - 1))), "%s rejects resizing an active battle" % _label(dimensions))
	var document := Dictionary(state.call("save_document", "dimension-smoke"))
	var restored: RefCounted = StateScript.new()
	_expect(bool(restored.call("load_document", document)), "%s save document reloads" % _label(dimensions))
	var restored_board := Dictionary(Dictionary(restored.call("snapshot")).get("board", {}))
	_expect(int(restored_board.get("width", 0)) == dimensions.x and int(restored_board.get("height", 0)) == dimensions.y, "%s save preserves dimensions" % _label(dimensions))
	var battle := BattleUiScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	battle.call("render_snapshot", snap)
	await process_frame
	var probe := BattleSceneProbe.new(battle)
	var ui_dimensions := Dictionary(probe.board_summary())
	_expect(int(ui_dimensions.get("width", 0)) == dimensions.x, "%s UI width follows snapshot" % _label(dimensions))
	_expect(int(ui_dimensions.get("height", 0)) == dimensions.y, "%s UI height follows snapshot" % _label(dimensions))
	_expect(int(ui_dimensions.get("activeCellCount", 0)) == dimensions.x * dimensions.y, "%s UI active cell count" % _label(dimensions))
	_expect(_visible_board_cell_count(battle) == dimensions.x * dimensions.y, "%s UI hides cells outside dimensions" % _label(dimensions))
	_expect(_inactive_board_cells_ignore_mouse(battle, dimensions.x * dimensions.y), "%s authored cells outside dimensions ignore input" % _label(dimensions))
	var last_cell := probe.cell_at(Vector2i(dimensions.x - 1, dimensions.y - 1))
	_expect(last_cell != null and last_cell.visible, "%s exposes its last active cell" % _label(dimensions))
	var last_center := last_cell.position + last_cell.size * 0.5 if last_cell != null else Vector2.ZERO
	_expect(last_cell != null and bool(last_cell.call("contains_board_point", last_center)), "%s authored hit geometry contains the last cell center" % _label(dimensions))
	var drag_start := Dictionary(probe.start_first_player_drag(snap))
	_expect(bool(drag_start.get("started", false)), "%s starts a real unit drag preview" % _label(dimensions))
	if bool(drag_start.get("started", false)):
		var target_value := Dictionary(drag_start.get("target", {}))
		var target := Vector2i(int(target_value.get("x", -1)), int(target_value.get("y", -1)))
		var drag_preview := Dictionary(await probe.update_drag(target, snap))
		_expect(bool(drag_preview.get("dragging", false)), "%s keeps the real drag preview active at the selected target" % _label(dimensions))
		probe.cancel_drag()
	battle.queue_free()
	await process_frame


func _verify_legacy_save_dimensions() -> void:
	var source: RefCounted = StateScript.new()
	source.call("set_board_dimensions", 8, 8)
	source.call("start_battle")
	var document := Dictionary(source.call("save_document", "legacy-dimension-smoke"))
	document["schema"] = StateScript.LEGACY_SAVE_SCHEMA
	var saved := Dictionary(document.get("state", {}))
	for key in ["board_width", "board_height", "boardWidth", "boardHeight"]:
		saved.erase(key)
	var restored: RefCounted = StateScript.new()
	_expect(bool(restored.call("load_document", document)), "legacy save without dimensions reloads")
	var restored_board := Dictionary(Dictionary(restored.call("snapshot")).get("board", {}))
	_expect(int(restored_board.get("width", 0)) == 8 and int(restored_board.get("height", 0)) == 8, "legacy save without dimensions stays 8x8")
	_expect(Array(restored_board.get("cells", [])).size() == 64, "legacy 8x8 save keeps 64 cells")
	await process_frame


func _verify_legacy_replay_dimensions() -> void:
	var source: RefCounted = StateScript.new()
	source.call("set_board_dimensions", 8, 8)
	var replay := Dictionary(source.call("replay_document"))
	var initial := Dictionary(replay.get("initial", {}))
	var options := Dictionary(initial.get("options", {}))
	options.erase("boardWidth")
	options.erase("boardHeight")
	replay["checksum"] = source.call("_replay_checksum", replay)
	var verified := Dictionary(source.call("verify_replay_document", replay))
	_expect(bool(verified.get("ok", false)), "legacy replay without dimensions verifies as 8x8")
	await process_frame


func _verify_ui_reuses_authored_pool() -> void:
	var battle := BattleUiScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	var probe := BattleSceneProbe.new(battle)
	var pool_size := -1
	for dimensions in [Vector2i(8, 8), Vector2i(8, 7), Vector2i(6, 6), Vector2i(8, 8)]:
		var state: RefCounted = StateScript.new()
		state.call("set_board_dimensions", dimensions.x, dimensions.y)
		state.call("start_battle")
		battle.call("render_snapshot", state.call("snapshot"))
		await process_frame
		var summary := Dictionary(probe.board_summary())
		var current_pool_size := int(summary.get("poolCellCount", 0))
		if pool_size < 0:
			pool_size = current_pool_size
		_expect(current_pool_size == pool_size, "%s reuses stable authored cell pool" % _label(dimensions))
		_expect(int(summary.get("activeCellCount", 0)) == dimensions.x * dimensions.y, "%s relayout keeps correct active count" % _label(dimensions))
	battle.queue_free()
	await process_frame


func _visible_board_cell_count(battle: Control) -> int:
	var count := 0
	var board_grid := battle.get_node_or_null("Board/CellHost")
	if board_grid == null:
		return 0
	for child in board_grid.get_children():
		if child is Control and child.has_method("setup_grid_position") and child.visible:
			count += 1
	return count


func _inactive_board_cells_ignore_mouse(battle: Control, active_count: int) -> bool:
	var board_grid := battle.get_node_or_null("Board/CellHost")
	if board_grid == null:
		return false
	for index in range(active_count, board_grid.get_child_count()):
		var cell := board_grid.get_child(index) as Control
		if cell != null and (cell.visible or cell.mouse_filter != Control.MOUSE_FILTER_IGNORE):
			return false
	return true


func _unique_in_bounds_cell_count(cells: Array, dimensions: Vector2i) -> int:
	var keys := {}
	for value in cells:
		var cell := Dictionary(value)
		var x := int(cell.get("x", -1))
		var y := int(cell.get("y", -1))
		if not _inside(dimensions, x, y):
			continue
		keys["%d,%d" % [x, y]] = true
	return keys.size()


func _inside(dimensions: Vector2i, x: int, y: int) -> bool:
	return x >= 0 and x < dimensions.x and y >= 0 and y < dimensions.y


func _label(dimensions: Vector2i) -> String:
	return "%dx%d" % [dimensions.x, dimensions.y]


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_CONFIGURABLE_BOARD_DIMENSIONS_FAIL: %s" % message)
