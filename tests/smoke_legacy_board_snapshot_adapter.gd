extends SceneTree

const MockSession := preload("res://session/mock_game_session.gd")


func _initialize() -> void:
	var session := MockSession.new({"start_phase": "battle"})
	var snapshot := Dictionary(session.call("current_snapshot"))
	var board := Dictionary(snapshot.get("board", {}))
	assert(int(board.get("width", 0)) == 8)
	assert(int(board.get("height", 0)) == 8)
	assert(Array(board.get("cells", [])).size() == 64)
	assert(int(snapshot.get("board_width", 0)) == 8)
	assert(int(snapshot.get("board_height", 0)) == 8)
	assert(_unit_grid(board, "player_hero") == Vector2i(0, 7))
	assert(_unit_grid(board, "enemy_boss") == Vector2i(7, 0))
	assert(_row_is_empty(board, 4))
	var response := Dictionary(session.call("submit_command", {
		"type": "AUTO_POSITION_HEROES",
	}))
	assert(bool(response.get("accepted", false)))
	snapshot = Dictionary(session.call("current_snapshot"))
	board = Dictionary(snapshot.get("board", {}))
	assert(int(board.get("width", 0)) == 8)
	assert(int(board.get("height", 0)) == 8)
	assert(Array(board.get("cells", [])).size() == 64)
	assert(_unit_grid(board, "player_hero") == Vector2i(0, 7))
	assert(_unit_grid(board, "enemy_boss") == Vector2i(7, 0))
	print("SMOKE_LEGACY_BOARD_SNAPSHOT_ADAPTER_PASS")
	quit(0)


func _unit_grid(board: Dictionary, unit_id: String) -> Vector2i:
	for value in Array(board.get("cells", [])):
		var cell := Dictionary(value)
		if String(cell.get("unitId", cell.get("unit_id", ""))) == unit_id:
			return Vector2i(
				int(cell.get("x", cell.get("c", -1))),
				int(cell.get("y", cell.get("r", -1)))
			)
	return Vector2i(-1, -1)


func _row_is_empty(board: Dictionary, row: int) -> bool:
	var count := 0
	for value in Array(board.get("cells", [])):
		var cell := Dictionary(value)
		if int(cell.get("y", cell.get("r", -1))) != row:
			continue
		count += 1
		if String(cell.get("unitId", cell.get("unit_id", ""))) != "":
			return false
	return count == 8
