extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

var _battle: Control = null
var _board: Control = null
var _probe: RefCounted = null
var _commands: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MainScene.instantiate() as Control
	main.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(main)
	await _settle(12)
	_battle = main.call("get_feature_controller", &"battle") as Control
	if _battle == null:
		_fail("battle feature is unavailable")
		return
	_board = _battle.get_node_or_null("Board") as Control
	_probe = BattleSceneProbe.new(_battle)
	if _board == null or not bool(_probe.call("is_ready")):
		_fail("battle board or probe is unavailable")
		return
	_battle.command_requested.connect(_on_command_requested)

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

	player_cell.emit_signal("cell_selected", player_grid.x, player_grid.y)
	await _settle(3)
	if String(_board.call("current_authoritative_selected_unit_id")) != player_id:
		_fail("planning selection did not establish the authoritative pre-combat case")
		return
	_commands.clear()
	_battle.call("_set_battle_input_locked", true)
	player_cell.emit_signal("cell_selected", player_grid.x, player_grid.y)
	await _settle(2)
	_assert_inspection(player_id, "locked player inspection")
	if not _commands.is_empty():
		_fail("locked player inspection emitted a gameplay command")
		return

	var locked_drag := Dictionary(_probe.call("start_drag", player_grid, target_grid))
	await _settle(2)
	if bool(locked_drag.get("started", false)):
		_fail("a player pet could be dragged while combat input was locked")
		return
	_assert_inspection(player_id, "locked drag attempt")

	enemy_cell.emit_signal("cell_selected", enemy_grid.x, enemy_grid.y)
	await _settle(2)
	_assert_inspection(enemy_id, "locked enemy inspection")
	if not _commands.is_empty():
		_fail("locked enemy inspection emitted a gameplay command")
		return

	enemy_cell.emit_signal("cell_selected", enemy_grid.x, enemy_grid.y)
	await _settle(2)
	_assert_cleared("second locked click")

	player_cell.emit_signal("cell_selected", player_grid.x, player_grid.y)
	await _settle(2)
	empty_cell.emit_signal("cell_selected", empty_grid.x, empty_grid.y)
	await _settle(2)
	_assert_cleared("locked empty-floor click")
	if not _commands.is_empty():
		_fail("locked inspection cancellation emitted a gameplay command")
		return

	_battle.call("_set_battle_input_locked", false)
	var unlocked_drag := Dictionary(_probe.call("start_drag", player_grid, target_grid))
	if not bool(unlocked_drag.get("started", false)):
		_fail("planning drag no longer starts after combat input unlocks")
		return
	_probe.call("cancel_drag")

	print("SMOKE_BATTLE_COMBAT_INSPECTION_PASS")
	quit(0)


func _assert_inspection(expected_unit_id: String, label: String) -> void:
	var detail := Dictionary(_probe.call("detail_summary"))
	var overlay := _battle.get_node_or_null("OverlayHost")
	var active_detail_unit_id := String(overlay.get("_active_detail_unit_id")) if overlay != null else ""
	if String(_board.call("current_selected_unit_id")) != expected_unit_id:
		_fail("%s did not update the selected unit" % label)
		return
	if not bool(detail.get("visible", false)) or active_detail_unit_id != expected_unit_id:
		_fail("%s did not show the matching pet info card" % label)
		return
	if bool(_board.call("is_layout_grid_visible")):
		_fail("%s exposed planning grid visuals during combat" % label)


func _assert_cleared(label: String) -> void:
	var detail := Dictionary(_probe.call("detail_summary"))
	if String(_board.call("current_selected_unit_id")) != "" or bool(detail.get("visible", false)):
		_fail("%s did not clear the local inspection" % label)


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


func _on_command_requested(command: Dictionary) -> void:
	_commands.append(command.duplicate(true))


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	push_error("SMOKE_BATTLE_COMBAT_INSPECTION_FAIL: %s" % message)
	quit(1)
