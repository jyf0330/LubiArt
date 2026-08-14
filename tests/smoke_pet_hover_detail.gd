extends SceneTree

const DragInteractionScript := preload("res://core_ui/scripts/battle/controllers/battle_board_drag_interaction.gd")


class FakeUnit:
	extends Control

	var battle_stats_hovered := false
	var battle_stats_hover_changes: Array[bool] = []

	func contains_art_point(_viewport_point: Vector2) -> bool:
		return true

	func get_unit_id() -> String:
		return "pet_hover_test"

	func set_battle_stats_pointer_hovered(hovered: bool) -> void:
		battle_stats_hovered = hovered
		battle_stats_hover_changes.append(hovered)


class FakeCell:
	extends Control

	var cell_data := {
		"x": 2,
		"y": 1,
		"unitId": "pet_hover_test",
		"side": "enemy",
		"type": "pet",
	}
	var unit := FakeUnit.new()
	var hovered := false

	func _init() -> void:
		add_child(unit)

	func get_unit_node() -> Control:
		return unit

	func has_player_unit() -> bool:
		return String(cell_data.get("side", "")) == "player"

	func set_hovered(value: bool) -> void:
		hovered = value


class FakeBoard:
	extends Control

	var cells := {}
	var local_selection_ids: Array[String] = []

	func _cell_at(x: int, y: int) -> Control:
		return cells.get(Vector2i(x, y)) as Control

	func _cell_data_at_grid(grid: Vector2i) -> Dictionary:
		var cell := cells.get(grid) as FakeCell
		return cell.cell_data if cell != null else {}

	func _cell_data_for_cell(cell: Node) -> Dictionary:
		return (cell as FakeCell).cell_data

	func _set_cell_hovered(grid: Vector2i, value: bool) -> void:
		var cell := cells.get(grid) as FakeCell
		if cell != null:
			cell.set_hovered(value)

	func _is_visible_board_cell(x: int, y: int) -> bool:
		return cells.has(Vector2i(x, y))

	func show_local_unit_selection(unit_id: String) -> void:
		local_selection_ids.append(unit_id)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var board := FakeBoard.new()
	root.add_child(board)
	var board_grid := Control.new()
	var unit_host := Control.new()
	board.add_child(board_grid)
	board.add_child(unit_host)
	var grid := Vector2i(2, 1)
	var cell := FakeCell.new()
	board.add_child(cell)
	board.cells[grid] = cell

	var interaction: RefCounted = DragInteractionScript.new()
	interaction.call("configure", board, board_grid, unit_host, null, null)
	var detail_events: Array[Dictionary] = []
	var command_events: Array[Dictionary] = []
	interaction.cell_detail_requested.connect(func(event_grid: Vector2i, unit_id: String) -> void:
		detail_events.append({"grid": event_grid, "unitId": unit_id})
	)
	interaction.command_requested.connect(func(command: Dictionary) -> void:
		command_events.append(command.duplicate(true))
	)

	interaction.call("on_cell_hovered", grid)
	assert(detail_events.is_empty())
	assert(cell.unit.battle_stats_hovered)
	interaction.call("on_cell_unhovered", grid)
	assert(detail_events.is_empty())
	assert(not cell.unit.battle_stats_hovered)
	assert(cell.unit.battle_stats_hover_changes == [true, false])

	detail_events.clear()
	interaction.call("on_cell_selected", grid)
	assert(detail_events.size() == 1)
	assert(detail_events[0]["grid"] == grid)
	assert(String(detail_events[0]["unitId"]) == "pet_hover_test")
	assert(command_events.is_empty())

	detail_events.clear()
	cell.cell_data["side"] = "player"
	interaction.call("on_cell_selected", grid)
	assert(detail_events.size() == 1)
	assert(detail_events[0]["grid"] == grid)
	assert(String(detail_events[0]["unitId"]) == "pet_hover_test")
	assert(command_events.size() == 1)
	assert(String(command_events[0].get("type", "")) == "SELECT_CELL")
	interaction.call("on_cell_hovered", grid)
	interaction.call("on_cell_unhovered", grid)
	assert(detail_events.size() == 1)

	var empty_grid := Vector2i(3, 1)
	var empty_cell := FakeCell.new()
	empty_cell.cell_data = {
		"x": empty_grid.x,
		"y": empty_grid.y,
		"unitId": "",
		"side": "",
		"type": "floor",
	}
	board.add_child(empty_cell)
	board.cells[empty_grid] = empty_cell
	detail_events.clear()
	command_events.clear()
	interaction.call("on_cell_selected", empty_grid)
	assert(detail_events.size() == 1)
	assert(detail_events[0]["grid"] == Vector2i(-1, -1))
	assert(String(detail_events[0]["unitId"]) == "")
	assert(command_events.size() == 1)
	assert(String(command_events[0].get("type", "")) == "SELECT_CELL")
	assert(int(command_events[0].get("x", -1)) == empty_grid.x)
	assert(int(command_events[0].get("y", -1)) == empty_grid.y)
	assert(board.local_selection_ids == [""])
	print("PET_SELECTION_DETAIL_SMOKE_PASS")
	quit(0)
