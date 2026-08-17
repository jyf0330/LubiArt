extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const SessionFactoryScript := preload("res://session/session_factory.gd")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")
const WINDOW_SIZE := Vector2i(1920, 1080)
const RUN_SEED := "ysbzs-test-play-20260715-v1"

var _output_dir := ""
var _battle: Control = null
var _session: RefCounted = null
var _probe: RefCounted = null
var _snapshot: Dictionary = {}
var _captures: Array = []
var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = _argument_value("--output-dir=")
	_expect(_output_dir != "", "output directory is required")
	if _failed:
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_output_dir)
	DisplayServer.window_set_size(WINDOW_SIZE)
	root.size = WINDOW_SIZE

	var creation := Dictionary(SessionFactoryScript.create_local_result({
		"run_seed": RUN_SEED,
		"command_scope": "developer",
	}))
	_expect(bool(creation.get("ok", false)), "formal LocalGameSession initializes")
	_session = creation.get("session") as RefCounted
	_expect(_session != null and bool(_session.call("connect_session")), "formal session connects")
	if _failed:
		_finish()
		return
	var start := Dictionary(_session.call("submit_command", {"type": "START_BATTLE"}))
	_expect(bool(start.get("accepted", false)), "formal START_BATTLE is accepted")
	_snapshot = Dictionary(_session.call("current_snapshot")).duplicate(true)
	_expect(String(_snapshot.get("phase", "")) == "battle", "formal snapshot enters battle")

	_battle = BattleScene.instantiate() as Control
	root.add_child(_battle)
	await _settle(24)
	_probe = BattleSceneProbe.new(_battle)
	_expect(bool(_probe.call("is_ready")), "formal battle probe is ready")
	_battle.call("render_snapshot", _snapshot)
	await _settle(24)
	if _failed:
		_finish()
		return

	await _capture("01_battle_entry", "战斗入口稳定态", {"phase": "battle"})

	var drag_case := Dictionary(_probe.call("first_player_drag_case", _snapshot))
	_expect(not drag_case.is_empty(), "formal player pet has a drag case")
	var origin_value := Dictionary(drag_case.get("origin", {}))
	var origin := Vector2i(int(origin_value.get("x", -1)), int(origin_value.get("y", -1)))
	_expect(bool(_probe.call("hover_cell", origin, true)), "formal player pet hover is emitted")
	await _settle(6)
	await _capture("02_player_pet_hover", "悬停我方第一只宠物", {"grid": _grid_dict(origin), "hovered": true})

	var detail := Dictionary(_probe.call("open_first_pet_detail"))
	_battle.call("render_snapshot", _snapshot)
	await _settle(8)
	_expect(bool(detail.get("opened", false)), "formal pet detail opens")
	await _capture("03_player_pet_detail", "选中我方宠物并打开详情", {"detail": _probe.call("detail_summary")})

	var empty_cell := _first_empty_cell()
	_expect(empty_cell != null, "formal battle has an empty floor cell")
	if empty_cell != null:
		var empty_grid := empty_cell.call("get_grid_position") as Vector2i
		empty_cell.emit_signal("cell_selected", empty_grid.x, empty_grid.y)
		await _settle(6)
		await _capture("04_empty_floor_click", "点击空地并关闭详情", {"grid": _grid_dict(empty_grid), "detail": _probe.call("detail_summary")})

	var drag := Dictionary(_probe.call("start_first_player_drag", _snapshot))
	_expect(bool(drag.get("started", false)), "formal pet drag starts")
	var target_value := Dictionary(drag.get("target", {}))
	var target := Vector2i(int(target_value.get("x", -1)), int(target_value.get("y", -1)))
	await _probe.call("update_drag", target, _snapshot)
	await _settle(4)
	_expect(bool(_probe.call("stabilize_drag_preview_for_capture", target)), "formal drag preview stabilizes")
	await _capture("05_drag_preview", "拖拽摆位预览", {
		"drag": _probe.call("drag_summary", _snapshot),
		"detail": _probe.call("detail_summary"),
	})

	_probe.call("cancel_drag")
	var board := _battle.get_node_or_null("Board") as Control
	if board != null:
		board.set_process(true)
	_battle.call("render_snapshot", _snapshot)
	await _settle(36)
	await _capture("06_drag_cancelled", "取消拖拽并恢复规划态", {
		"drag": _probe.call("drag_summary", _snapshot),
		"detail": _probe.call("detail_summary"),
	})

	var auto_button := _battle.get_node_or_null("Hud/BattlePrimaryActions/AutoArrangeButton") as BaseButton
	_expect(auto_button != null, "formal auto-arrange button exists")
	if auto_button != null:
		await _move_mouse(auto_button.get_global_rect().get_center())
		await _settle(6)
		await _capture("07_auto_arrange_hover", "自动布置按钮悬停", {"button": str(auto_button.get_path()), "hovered": true})

	var auto_response := Dictionary(_session.call("submit_command", {"type": "AUTO_POSITION_HEROES"}))
	_expect(bool(auto_response.get("accepted", false)), "formal auto-arrange command is accepted")
	_snapshot = Dictionary(_session.call("current_snapshot")).duplicate(true)
	_battle.call("render_snapshot", _snapshot)
	await _settle(18)
	await _capture("08_auto_arrange_complete", "自动布置完成", {"command": "AUTO_POSITION_HEROES"})

	var begin_button := _battle.get_node_or_null("Hud/BattlePrimaryActions/BeginTurnButton") as BaseButton
	_expect(begin_button != null, "formal begin-action button exists")
	if begin_button != null:
		begin_button.set_pressed_no_signal(true)
		await _settle(4)
		await _capture("09_begin_action_pressed", "开始行动按钮按下", {"button": str(begin_button.get_path()), "pressed": true})
		begin_button.set_pressed_no_signal(false)

	var round_response := Dictionary(_session.call("submit_command", {"type": "RUN_COMBAT_ROUND"}))
	_expect(bool(round_response.get("accepted", false)), "formal first combat round is accepted")
	_snapshot = Dictionary(_session.call("current_snapshot")).duplicate(true)
	_battle.call("render_snapshot", _snapshot)
	await _settle(90)
	await _capture("10_first_round_complete", "第一回合演出完成", {"command": "RUN_COMBAT_ROUND"})
	_finish()


func _first_empty_cell() -> Control:
	var host := _battle.get_node_or_null("Board/CellHost")
	if host == null:
		return null
	for child in host.get_children():
		var cell := child as Control
		if cell == null or not cell.visible or not cell.has_method("get_grid_position"):
			continue
		if cell.has_method("get_unit_node") and cell.call("get_unit_node") == null:
			return cell
	return null


func _capture(name: String, operation: String, interaction: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	var file_name := name + ".png"
	var path := _output_dir.path_join(file_name)
	var error := root.get_texture().get_image().save_png(path)
	_expect(error == OK, "save %s" % file_name)
	_captures.append({
		"step": _captures.size() + 1,
		"name": name,
		"operation": operation,
		"file": file_name,
		"stateVersion": int(_snapshot.get("stateVersion", -1)),
		"stateHash": String(_snapshot.get("stateHash", "")),
		"phase": String(_snapshot.get("phase", "")),
		"battleRound": int(_snapshot.get("battle_round", 0)),
		"interaction": interaction.duplicate(true),
	})


func _move_mouse(position: Vector2) -> void:
	Input.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _finish() -> void:
	if not _failed:
		_expect(_captures.size() == 10, "exactly ten formal screenshots are captured")
	var manifest := {
		"schemaVersion": 1,
		"side": "formal",
		"project": "godot-latest",
		"session": "LocalGameSession",
		"runSeed": RUN_SEED,
		"captureCount": _captures.size(),
		"captures": _captures,
	}
	var file := FileAccess.open(_output_dir.path_join("capture_manifest.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	print("FORMAL_BATTLE_OPERATION_PARITY_%s count=%d output=%s" % ["FAIL" if _failed else "PASS", _captures.size(), _output_dir])
	quit(1 if _failed else 0)


func _argument_value(prefix: String) -> String:
	for arg_value in OS.get_cmdline_user_args():
		var arg := String(arg_value)
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix).strip_edges()
	return ""


func _grid_dict(grid: Vector2i) -> Dictionary:
	return {"x": grid.x, "y": grid.y}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FORMAL_BATTLE_OPERATION_PARITY_FAIL: %s" % message)
