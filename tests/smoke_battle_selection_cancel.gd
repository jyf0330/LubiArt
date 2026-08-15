extends SceneTree

const GameScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

const OUTSIDE_BOARD_BLANK_POINT := Vector2(200.0, 500.0)

var _main: Control = null
var _battle: Control = null
var _session: RefCounted = null
var _probe: RefCounted = null


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_main = GameScene.instantiate() as Control
	_main.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(_main)
	await _settle(10)
	_battle = _main.call("get_feature_controller", &"battle") as Control
	_session = _main.call("get_game_session") as RefCounted
	if _battle == null or _session == null:
		_fail("app battle feature did not initialize")
		return
	_probe = BattleSceneProbe.new(_battle)
	if not bool(_probe.call("is_ready")):
		_fail("battle probe is unavailable")
		return

	var drag_case := Dictionary(_probe.call(
		"first_player_drag_case",
		_session.call("current_snapshot")
	))
	var origin_value := Dictionary(drag_case.get("origin", {}))
	var origin := Vector2i(
		int(origin_value.get("x", -1)),
		int(origin_value.get("y", -1))
	)
	var empty := _first_empty_floor()
	if origin.x < 0 or empty.x < 0:
		_fail("selection cancel test could not resolve a unit and empty floor")
		return

	await _click_cell(origin)
	if _selected_unit_id() == "":
		_fail("player unit click did not select a unit")
		return
	var board := _battle.get_node_or_null("Board") as Control
	if board == null or not board.has_method("current_selected_unit_id") \
			or String(board.call("current_selected_unit_id")) == "":
		_fail("board did not retain the selected unit presentation state")
		return
	if not bool(Dictionary(_probe.call("detail_summary")).get("visible", false)):
		_fail("player unit click did not open the persistent detail")
		return

	var info_card := _battle.get_node_or_null(
		"OverlayHost/BattlePetDetailPanel/Panel/SpriteInfoCard"
	) as Control
	if info_card == null or info_card.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("battle pet info card does not block blank-area click-through")
		return
	await _click_viewport_point(info_card.global_position + Vector2(200.0, 100.0))
	if _selected_unit_id() == "":
		_fail("clicking inside the pet info card cancelled the selected unit")
		return
	if not bool(Dictionary(_probe.call("detail_summary")).get("visible", false)):
		_fail("clicking inside the pet info card closed the persistent detail")
		return

	await _click_cell(origin)
	if _selected_unit_id() != "":
		_fail("second click on the selected player unit did not toggle selection off")
		return
	if bool(Dictionary(_probe.call("detail_summary")).get("visible", false)):
		_fail("second click on the selected player unit did not close the pet detail")
		return

	await _click_cell(origin)
	if _selected_unit_id() == "":
		_fail("player unit could not be reselected before empty-floor cancel")
		return

	await _click_cell(empty)
	if _selected_unit_id() != "":
		_fail("one empty-floor click did not cancel the authoritative selection")
		return
	if bool(Dictionary(_probe.call("detail_summary")).get("visible", false)):
		_fail("one empty-floor click did not close the pet detail")
		return

	await _click_cell(origin)
	if _selected_unit_id() == "":
		_fail("player unit could not be reselected before outside-area cancel")
		return
	await _click_viewport_point(OUTSIDE_BOARD_BLANK_POINT)
	if _selected_unit_id() != "":
		_fail("one click on blank space outside the grid did not cancel selection")
		return
	if bool(Dictionary(_probe.call("detail_summary")).get("visible", false)):
		_fail("outside-grid blank click did not close the pet detail")
		return

	print("SMOKE_BATTLE_SELECTION_CANCEL_PASS")
	quit(0)


func _click_cell(grid: Vector2i) -> void:
	var cell := _probe.call("cell_at", grid) as Control
	if cell == null:
		_fail("cell is unavailable at %s" % grid)
		return
	await _click_viewport_point(cell.get_global_rect().get_center())


func _click_viewport_point(point: Vector2) -> void:
	Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	_battle.get_viewport().push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.global_position = point
	press.pressed = true
	_battle.get_viewport().push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = point
	release.global_position = point
	release.pressed = false
	_battle.get_viewport().push_input(release, true)
	await _settle(6)


func _first_empty_floor() -> Vector2i:
	var cell_host := _battle.get_node_or_null("Board/CellHost") as Control
	if cell_host == null:
		return Vector2i(-1, -1)
	for child in cell_host.get_children():
		var cell := child as Control
		if cell == null or not cell.visible or not cell.has_method("get_grid_position"):
			continue
		var raw_data = cell.get("cell_data")
		var data := Dictionary(raw_data) if raw_data is Dictionary else {}
		var unit_id := String(data.get("unitId", data.get("unit_id", "")))
		if unit_id != "" or _has_visible_elements(Dictionary(data.get("elements", {}))):
			continue
		return cell.call("get_grid_position") as Vector2i
	return Vector2i(-1, -1)


func _has_visible_elements(elements: Dictionary) -> bool:
	for amount in elements.values():
		if int(amount) > 0:
			return true
	return false


func _selected_unit_id() -> String:
	var snapshot := Dictionary(_session.call("current_snapshot"))
	return String(snapshot.get("selected_unit_id", snapshot.get("selectedUnitId", "")))


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	push_error("SMOKE_BATTLE_SELECTION_CANCEL_FAIL: %s" % message)
	quit(1)
