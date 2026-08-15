extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

var _capture_dir := ""
var _battle: Control = null
var _snapshot := {}
var _probe: RefCounted = null
var _session: RefCounted = null


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_capture_dir = OS.get_environment("UI_OPERATION_CAPTURE_DIR").strip_edges()
	if _capture_dir == "":
		_fail("UI_OPERATION_CAPTURE_DIR is required")
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)

	_battle = BattleScene.instantiate() as Control
	root.add_child(_battle)
	await _settle(8)
	_probe = BattleSceneProbe.new(_battle)
	if not _probe.call("is_ready"):
		_fail("battle probe is unavailable")
		return
	_session = MockSession.new({"start_phase": "battle"})
	_snapshot = Dictionary(_session.call("current_snapshot"))
	_battle.call("render_snapshot", _snapshot)
	await _settle(8)
	await _stabilize()

	var difficulty_button := _battle.get_node_or_null(
		"Hud/BattleActionPanel/Margin/Content/PositionDifficultyButton"
	) as Button
	difficulty_button.set_pressed_no_signal(true)
	difficulty_button.emit_signal("toggled", true)
	await _settle(2)
	await _capture("operation_01_difficulty_easy.png")

	var collapse_button := _battle.get_node_or_null("Hud/DebugDrawerToggleButton") as Button
	if collapse_button == null:
		_fail("debug drawer collapse button is unavailable")
		return
	collapse_button.pressed.emit()
	await create_timer(0.2).timeout
	await _stabilize()
	await _capture("operation_02_direction_collapsed.png")

	var empty_cell := _first_empty_cell()
	if empty_cell == null:
		_fail("no empty battle cell is available")
		return
	var empty_grid := empty_cell.call("get_grid_position") as Vector2i
	_probe.call("hover_cell", empty_grid, true)
	await _settle(2)
	await _capture("operation_03_empty_cell_hover.png")

	_probe.call("hover_cell", empty_grid, false)
	var detail_result := Dictionary(_probe.call("open_first_pet_detail"))
	if not bool(detail_result.get("opened", false)):
		_fail("pet detail could not be opened")
		return
	_battle.call("render_snapshot", _snapshot)
	await _settle(4)
	await _stabilize()
	var detail_summary := Dictionary(_probe.call("detail_summary"))
	if not bool(detail_summary.get("visible", false)):
		_fail("selected pet did not produce a persistent detail panel")
		return
	_probe.call("hover_cell", empty_grid, true)
	_probe.call("hover_cell", empty_grid, false)
	if not bool(Dictionary(_probe.call("detail_summary")).get("visible", false)):
		_fail("selected pet detail closed after the pointer left the pet")
		return
	await _capture("operation_04_pet_detail_open.png")

	empty_cell.emit_signal("cell_selected", empty_grid.x, empty_grid.y)
	await _settle(2)
	if bool(Dictionary(_probe.call("detail_summary")).get("visible", false)):
		_fail("empty floor selection did not close the pet detail")
		return
	var board_node := _battle.get_node_or_null("Board") as Control
	if board_node != null and board_node.has_method("is_layout_grid_visible") \
			and bool(board_node.call("is_layout_grid_visible")):
		_fail("empty floor selection did not clear the local unit selection")
		return
	if not bool(Dictionary(_probe.call("open_first_pet_detail")).get("opened", false)):
		_fail("pet detail could not be reopened for the Esc check")
		return
	_battle.call("render_snapshot", _snapshot)
	await _settle(2)
	await _press_key(KEY_ESCAPE)
	if bool(Dictionary(_probe.call("detail_summary")).get("visible", false)):
		_fail("Esc did not close the pet detail")
		return
	var settings_menu := _battle.get_node_or_null("OverlayHost/SettingsMenu") as Control
	if settings_menu != null and settings_menu.visible:
		_fail("Esc opened settings while closing the pet detail")
		return

	_probe.call("clear_detail")
	var preview_case := Dictionary(_probe.call("first_player_drag_case", _snapshot))
	var preview_origin := Dictionary(preview_case.get("origin", {}))
	_session.call("submit_command", {
		"type": "SELECT_CELL",
		"x": int(preview_origin.get("x", -1)),
		"y": int(preview_origin.get("y", -1)),
		"cell": preview_origin.duplicate(true),
	})
	var preview_snapshot := Dictionary(_session.call("current_snapshot"))
	_snapshot["placement_damage_by_unit"] = Dictionary(preview_snapshot.get(
		"placement_damage_by_unit",
		{}
	)).duplicate(true)
	_battle.call("render_snapshot", _snapshot)
	var drag_result := Dictionary(_probe.call("start_first_player_drag", _snapshot))
	if not bool(drag_result.get("started", false)):
		_fail("pet drag could not be started")
		return
	var target_value := Dictionary(drag_result.get("target", {}))
	var drag_target := Vector2i(int(target_value.get("x", -1)), int(target_value.get("y", -1)))
	await _probe.call("update_drag", drag_target, _snapshot)
	await _settle(2)
	await _stabilize()
	if not bool(_probe.call("stabilize_drag_preview_for_capture", drag_target)):
		_fail("pet drag preview could not be stabilized for capture")
		return
	await _capture("operation_05_pet_drag_preview.png")

	_probe.call("cancel_drag")
	print("VISIBLE_BATTLE_REFACTOR_OPERATIONS_PASS: %s" % _capture_dir)
	quit(0)


func _first_empty_cell() -> Control:
	for child in _cell_host().get_children():
		var cell := child as Control
		if cell == null or not cell.visible or not cell.has_method("get_grid_position"):
			continue
		var raw_data = cell.get("cell_data")
		var data := Dictionary(raw_data) if raw_data is Dictionary else {}
		if cell.has_method("get_unit_node") and cell.call("get_unit_node") == null \
				and not _has_visible_elements(Dictionary(data.get("elements", {}))):
			return cell
	return null


func _has_visible_elements(elements: Dictionary) -> bool:
	for amount in elements.values():
		if int(amount) > 0:
			return true
	return false


func _cell_host() -> Control:
	return _battle.get_node_or_null("Board/CellHost") as Control


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


func _press_key(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	_battle.get_viewport().push_input(press, true)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	_battle.get_viewport().push_input(release, true)
	await process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var output_path := _capture_dir.path_join(file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		_fail("could not save %s: %s" % [file_name, error_string(error)])
		return
	print("VISIBLE_BATTLE_REFACTOR_OPERATION_SAVED: %s" % output_path)


func _fail(message: String) -> void:
	push_error("VISIBLE_BATTLE_REFACTOR_OPERATIONS_FAIL: %s" % message)
	quit(1)
