extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MockSession := preload("res://session/mock_game_session.gd")

var _capture_dir := ""
var _battle: Control = null
var _snapshot := {}


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
	_snapshot = Dictionary(MockSession.new({"start_phase": "battle"}).call("current_snapshot"))
	_battle.call("render_snapshot", _snapshot)
	await _settle(8)
	await _stabilize()

	_battle.call("_on_position_difficulty_toggled", true)
	await _settle(2)
	await _capture("operation_01_difficulty_easy.png")

	var drawer := _battle.get_node_or_null("Hud/AttackDirectionDrawer") as Control
	var collapse_button := drawer.get_node_or_null("CollapseButton") as TextureButton if drawer != null else null
	if collapse_button == null:
		_fail("direction drawer collapse button is unavailable")
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
	_battle.call("_on_cell_hovered", empty_grid.x, empty_grid.y)
	await _settle(2)
	await _capture("operation_03_empty_cell_hover.png")

	_battle.call("_on_cell_unhovered", empty_grid.x, empty_grid.y)
	var detail_result := Dictionary(_battle.call("debug_open_first_pet_detail"))
	if not bool(detail_result.get("opened", false)):
		_fail("pet detail could not be opened")
		return
	_battle.call("render_snapshot", _snapshot)
	await _settle(4)
	await _stabilize()
	await _capture("operation_04_pet_detail_open.png")

	_battle.call("_clear_active_detail")
	var drag_result := Dictionary(_battle.call("debug_start_first_player_drag_to_empty"))
	if not bool(drag_result.get("started", false)):
		_fail("pet drag could not be started")
		return
	_battle.call("debug_update_drag_preview_to_target", Dictionary(drag_result.get("target", {})))
	await _settle(2)
	await _stabilize()
	await _capture("operation_05_pet_drag_preview.png")

	_battle.call("debug_cancel_active_drag")
	print("VISIBLE_BATTLE_REFACTOR_OPERATIONS_PASS: %s" % _capture_dir)
	quit(0)


func _first_empty_cell() -> Control:
	for child in _cell_host().get_children():
		var cell := child as Control
		if cell == null or not cell.visible or not cell.has_method("get_grid_position"):
			continue
		if cell.has_method("get_unit_node") and cell.call("get_unit_node") == null:
			return cell
	return null


func _cell_host() -> Control:
	return _battle.get_node_or_null("Board/CellHost") as Control


func _stabilize() -> void:
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
	print("VISIBLE_BATTLE_REFACTOR_OPERATION_SAVED: %s" % output_path)


func _fail(message: String) -> void:
	push_error("VISIBLE_BATTLE_REFACTOR_OPERATIONS_FAIL: %s" % message)
	quit(1)
