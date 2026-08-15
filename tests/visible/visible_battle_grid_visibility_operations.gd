extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

var _capture_dir := ""
var _battle: Control = null
var _probe: RefCounted = null
var _session: RefCounted = null


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_capture_dir = OS.get_environment("GRID_VIS_CAPTURE_DIR").strip_edges()
	if _capture_dir == "":
		_fail("GRID_VIS_CAPTURE_DIR is required")
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)

	var main := MainScene.instantiate() as Control
	_session = MockSession.new({"start_phase": "battle"})
	main.call("set_game_session", _session)
	root.add_child(main)
	await _settle(16)
	_battle = main.call("get_feature_controller", &"battle") as Control
	if _battle == null:
		_fail("battle feature is unavailable")
		return
	_probe = BattleSceneProbe.new(_battle)
	if not _probe.call("is_ready"):
		_fail("battle probe is unavailable")
		return
	var snapshot := Dictionary(_session.call("current_snapshot"))
	_battle.call("render_snapshot", snapshot)
	await _settle(8)
	await _stabilize()
	await _capture("operation_01_idle.png")

	var drag_case := Dictionary(_probe.call("first_player_drag_case", snapshot))
	if drag_case.is_empty():
		_fail("no player unit is available")
		return
	var origin_data := Dictionary(drag_case.get("origin", {}))
	var target_data := Dictionary(drag_case.get("target", {}))
	var origin := Vector2i(int(origin_data.get("x", -1)), int(origin_data.get("y", -1)))
	var target := Vector2i(int(target_data.get("x", -1)), int(target_data.get("y", -1)))

	var empty_cell := _first_empty_cell()
	if empty_cell == null:
		_fail("no empty cell is available")
		return
	var empty_grid := empty_cell.call("get_grid_position") as Vector2i
	_probe.call("hover_cell", empty_grid, true)
	await _settle(2)
	await _capture("operation_02_empty_hover.png")
	_probe.call("hover_cell", empty_grid, false)

	_session.call("submit_command", {"type": "SELECT_CELL", "x": origin.x, "y": origin.y})
	snapshot = Dictionary(_session.call("current_snapshot"))
	_battle.call("render_snapshot", snapshot)
	await _settle(4)
	await _stabilize()
	await _capture("operation_03_unit_selected.png")

	var started := Dictionary(_probe.call("start_drag", origin, target))
	if not bool(started.get("started", false)):
		_fail("drag could not be started")
		return
	await _probe.call("update_drag", target, snapshot)
	await _settle(2)
	await _stabilize()
	if not bool(_probe.call("stabilize_drag_preview_for_capture", target)):
		_fail("drag preview could not be stabilized")
		return
	await _capture("operation_04_unit_dragging.png")

	_probe.call("cancel_drag")
	await _settle(3)
	var board := _battle.get_node_or_null("Board")
	if board == null:
		_fail("battle board is unavailable")
		return
	board.call("set_input_locked", true)
	await _settle(2)
	await _capture("operation_05_layout_locked.png")

	print("VISIBLE_BATTLE_GRID_VISIBILITY_OPERATIONS_PASS: %s" % _capture_dir)
	quit(0)


func _first_empty_cell() -> Control:
	var cell_host := _battle.get_node_or_null("Board/CellHost")
	if cell_host == null:
		return null
	for child in cell_host.get_children():
		var cell := child as Control
		if cell == null or not cell.visible or not cell.has_method("get_unit_node"):
			continue
		if cell.call("get_unit_node") == null:
			return cell
	return null


func _stabilize() -> void:
	var map_controls := _battle.get_node_or_null("MapControls")
	if map_controls != null:
		map_controls.call("_mark_player_activity")
		map_controls.call("_hide_all_out_highlight")
	var vfx_host := _battle.get_node_or_null("Board/VfxHost")
	if vfx_host != null:
		var round_feedback := vfx_host.get_node_or_null("RoundFeedback")
		if round_feedback != null:
			round_feedback.queue_free()
	for node in _all_descendants(_battle):
		if node.name == &"03_AttackActions" and node.has_method("reset"):
			node.call("reset")
		if node.has_method("set_attack_highlight_blinking"):
			node.call("set_attack_highlight_blinking", false)
	await _settle(2)
	await RenderingServer.frame_post_draw


func _all_descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var output_path := _capture_dir.path_join(file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		_fail("could not save %s: %s" % [file_name, error_string(error)])
		return
	print("VISIBLE_BATTLE_GRID_VISIBILITY_OPERATION_SAVED: %s" % output_path)


func _fail(message: String) -> void:
	push_error("VISIBLE_BATTLE_GRID_VISIBILITY_OPERATIONS_FAIL: %s" % message)
	quit(1)
