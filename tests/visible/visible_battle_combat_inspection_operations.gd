extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")
const IDLE_LOOP_MS := 1600

var _capture_dir := ""
var _battle: Control = null
var _board: Control = null
var _probe: RefCounted = null
var _report := {}


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_capture_dir = OS.get_environment("COMBAT_INSPECTION_CAPTURE_DIR").strip_edges()
	if _capture_dir == "":
		_fail("COMBAT_INSPECTION_CAPTURE_DIR is required")
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)

	var main := MainScene.instantiate() as Control
	main.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(main)
	await _settle(16)
	_battle = main.call("get_feature_controller", &"battle") as Control
	if _battle == null:
		_fail("battle feature is unavailable")
		return
	_board = _battle.get_node_or_null("Board") as Control
	_probe = BattleSceneProbe.new(_battle)
	if _board == null or not bool(_probe.call("is_ready")):
		_fail("battle board or probe is unavailable")
		return

	var player_case := Dictionary(_probe.call("first_player_drag_case"))
	var enemy_cell := _first_pet_cell(["enemy", "monster"])
	var empty_cell := _first_empty_cell()
	if player_case.is_empty() or enemy_cell == null or empty_cell == null:
		_fail("player, enemy, or empty-cell case is unavailable")
		return
	var origin_value := Dictionary(player_case.get("origin", {}))
	var target_value := Dictionary(player_case.get("target", {}))
	var player_grid := Vector2i(int(origin_value.get("x", -1)), int(origin_value.get("y", -1)))
	var target_grid := Vector2i(int(target_value.get("x", -1)), int(target_value.get("y", -1)))
	var player_cell := _probe.call("cell_at", player_grid) as Control
	var enemy_grid := enemy_cell.call("get_grid_position") as Vector2i
	var empty_grid := empty_cell.call("get_grid_position") as Vector2i
	var player_id := _unit_id(player_cell)
	var enemy_id := _unit_id(enemy_cell)

	_battle.call("_set_battle_input_locked", true)
	await _settle(2)
	await _capture("operation_01_combat_locked_idle.png")

	player_cell.emit_signal("cell_selected", player_grid.x, player_grid.y)
	await _settle(2)
	_report["player_selection"] = _state_summary()
	_report["player_selection"]["expected_unit_id"] = player_id
	await _capture("operation_02_combat_player_selected.png")

	var locked_drag := Dictionary(_probe.call("start_drag", player_grid, target_grid))
	await _settle(2)
	_report["locked_drag_attempt"] = _state_summary()
	_report["locked_drag_attempt"]["drag_started"] = bool(locked_drag.get("started", false))
	await _capture("operation_03_combat_drag_blocked.png")

	enemy_cell.emit_signal("cell_selected", enemy_grid.x, enemy_grid.y)
	await _settle(2)
	_report["enemy_selection"] = _state_summary()
	_report["enemy_selection"]["expected_unit_id"] = enemy_id
	await _capture("operation_04_combat_enemy_selected.png")

	empty_cell.emit_signal("cell_selected", empty_grid.x, empty_grid.y)
	await _settle(2)
	_report["empty_floor_cancel"] = _state_summary()
	await _capture("operation_05_combat_empty_floor_cancel.png")

	_battle.call("_set_battle_input_locked", false)
	await _settle(2)
	var unlocked_case := Dictionary(_probe.call("first_player_drag_case"))
	var unlocked_origin_value := Dictionary(unlocked_case.get("origin", {}))
	var unlocked_target_value := Dictionary(unlocked_case.get("target", {}))
	var unlocked_origin := Vector2i(
		int(unlocked_origin_value.get("x", -1)),
		int(unlocked_origin_value.get("y", -1))
	)
	var unlocked_target := Vector2i(
		int(unlocked_target_value.get("x", -1)),
		int(unlocked_target_value.get("y", -1))
	)
	var unlocked_drag := Dictionary(_probe.call("start_drag", unlocked_origin, unlocked_target))
	await _settle(2)
	_report["unlocked_drag"] = _state_summary()
	_report["unlocked_drag"]["drag_started"] = bool(unlocked_drag.get("started", false))
	await _capture("operation_06_planning_drag_regression.png")
	_probe.call("cancel_drag")

	var report_path := _capture_dir.path_join("operation_report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		_fail("could not write operation report")
		return
	file.store_string(JSON.stringify(_report, "  "))
	file.close()
	print("VISIBLE_BATTLE_COMBAT_INSPECTION_OPERATIONS_PASS: %s" % _capture_dir)
	quit(0)


func _state_summary() -> Dictionary:
	var detail := Dictionary(_probe.call("detail_summary"))
	var overlay := _battle.get_node_or_null("OverlayHost")
	var active_detail_unit_id := String(overlay.get("_active_detail_unit_id")) if overlay != null else ""
	return {
		"input_locked": bool(_battle.call("is_battle_input_locked")),
		"selected_unit_id": String(_board.call("current_selected_unit_id")),
		"detail_visible": bool(detail.get("visible", false)),
		"detail_unit_id": active_detail_unit_id,
		"layout_grid_visible": bool(_board.call("is_layout_grid_visible")),
	}


func _first_pet_cell(sides: Array[String]) -> Control:
	var host := _battle.get_node_or_null("Board/CellHost")
	if host == null:
		return null
	for child in host.get_children():
		var cell := child as Control
		if cell == null or not cell.visible:
			continue
		var data := _cell_data(cell)
		if _unit_id(cell) == "" or _is_hero(data):
			continue
		if String(data.get("side", data.get("unitSide", ""))) in sides:
			return cell
	return null


func _first_empty_cell() -> Control:
	var host := _battle.get_node_or_null("Board/CellHost")
	if host == null:
		return null
	for child in host.get_children():
		var cell := child as Control
		if cell == null or not cell.visible:
			continue
		var data := _cell_data(cell)
		var elements_value = data.get("elements", {})
		var has_elements := false
		if elements_value is Dictionary:
			for amount in Dictionary(elements_value).values():
				has_elements = has_elements or int(amount) > 0
		if _unit_id(cell) == "" and not has_elements:
			return cell
	return null


func _unit_id(cell: Control) -> String:
	var data := _cell_data(cell)
	return String(data.get("unitId", data.get("unit_id", "")))


func _cell_data(cell: Control) -> Dictionary:
	if cell == null:
		return {}
	var value = cell.get("cell_data")
	return Dictionary(value) if value is Dictionary else {}


func _is_hero(data: Dictionary) -> bool:
	var unit_id := String(data.get("unitId", data.get("unit_id", "")))
	var unit_type := String(data.get("type", data.get("unitType", data.get("unit_type", "")))).to_lower()
	var side := String(data.get("side", data.get("unitSide", "")))
	return unit_type == "hero" or unit_id in ["player_hero", "enemy_hero"] \
		or side in ["hero_leader", "player_leader", "enemy_leader", "boss"]


func _capture(file_name: String) -> void:
	await _wait_for_idle_phase()
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(_capture_dir.path_join(file_name))
	if error != OK:
		_fail("could not save %s: %s" % [file_name, error_string(error)])


func _wait_for_idle_phase() -> void:
	var deadline := Time.get_ticks_msec() + IDLE_LOOP_MS * 2
	while Time.get_ticks_msec() < deadline:
		if Time.get_ticks_msec() % IDLE_LOOP_MS < 24:
			await process_frame
			return
		await process_frame


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	push_error("VISIBLE_BATTLE_COMBAT_INSPECTION_OPERATIONS_FAIL: %s" % message)
	quit(1)
