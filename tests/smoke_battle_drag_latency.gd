extends SceneTree

const GameScene := preload("res://art/scenes/app/game.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

var _main: Control = null
var _battle: Control = null
var _session: RefCounted = null
var _commands: Array[Dictionary] = []


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_main = GameScene.instantiate() as Control
	_main.call("set_game_session", MockSession.new({"start_phase": "battle"}))
	root.add_child(_main)
	for _frame in range(8):
		await process_frame
	_battle = _main.call("get_feature_controller", &"battle") as Control
	_session = _main.call("get_game_session") as RefCounted
	if _battle == null or _session == null:
		_fail("app battle feature did not initialize")
		return
	var probe := BattleSceneProbe.new(_battle)
	if not bool(probe.call("is_ready")):
		_fail("battle probe is unavailable")
		return
	_battle.command_requested.connect(_on_command_requested)

	var drag_case := Dictionary(probe.call("first_player_drag_case", _session.call("current_snapshot")))
	if drag_case.is_empty():
		_fail("no player drag case is available")
		return
	var origin_data := Dictionary(drag_case.get("origin", {}))
	var origin := Vector2i(int(origin_data.get("x", -1)), int(origin_data.get("y", -1)))
	var target := _first_empty_target(origin)
	var unit_id := String(drag_case.get("unitId", ""))
	var rendered_cell_count_before_selection := int(probe.call("rendered_cell_count"))
	if target.x < 0:
		_fail("no empty drop target is available")
		return
	var pointer_down_started_usec := Time.get_ticks_usec()
	var started := Dictionary(probe.call("start_drag", origin, target))
	var pointer_down_msec := float(Time.get_ticks_usec() - pointer_down_started_usec) / 1000.0
	if not bool(started.get("started", false)):
		_fail("drag preview was not created synchronously")
		return
	var origin_unit := (probe.call("cell_at", origin) as Control).call("get_unit_node") as Control
	var local_selection_frame := origin_unit.get_node_or_null(
		"CompleteBattleCreaturePrefab/01_UnitVisual/SelectionFrame"
	) as TextureRect
	if local_selection_frame == null or not local_selection_frame.visible:
		_fail("selection highlight was not visible locally on pointer-down")
		return
	if pointer_down_msec >= 250.0:
		_fail("local pointer-down presentation exceeded 250ms: %.2fms" % pointer_down_msec)
		return
	if not _commands.is_empty():
		_fail("SELECT_CELL was emitted before the local selection frame was drawn")
		return
	await _next_presented_frame()
	if _commands.size() != 1 or String(_commands[0].get("type", "")) != "SELECT_CELL":
		_fail("queued SELECT_CELL was not delivered after the local draw")
		return
	await process_frame
	if String(_session.call("current_snapshot").get("selected_unit_id", "")) != unit_id:
		_fail("authoritative selection did not reconcile after the local highlight")
		return
	if int(probe.call("rendered_cell_count")) != rendered_cell_count_before_selection:
		_fail("SELECT_CELL rerendered the full board instead of using the light path")
		return

	await probe.call("update_drag", target, _session.call("current_snapshot"))
	var dragged_preview := _battle.get_node_or_null("Board/UnitHost/BattleUnitDragPreview") as Control
	var target_cell := probe.call("cell_at", target) as Control
	if dragged_preview == null or target_cell == null:
		_fail("drag settle sample could not resolve its preview or target cell")
		return
	# Release away from the cell anchor so the settle curve has a measurable
	# distance. This represents the ordinary case where the pointer is not at the
	# exact same within-cell offset at mouse-up as it was at mouse-down.
	dragged_preview.position = target_cell.position + Vector2(72.0, 0.0)
	var settle_start := dragged_preview.position
	probe.call("finish_drag", target)
	if _commands.size() != 1:
		_fail("MOVE_HERO blocked pointer-up instead of being queued")
		return
	if _cell_unit_id(probe.call("cell_at", target) as Control) != unit_id:
		_fail("local drop projection was not visible immediately")
		return
	if _battle.get_node_or_null("Board/UnitHost/BattleUnitDragPreview") == null:
		_fail("drop settle preview did not start before command submission")
		return
	var settle_tween := _battle.get_node("Board").get("_drag_interaction").get("_drop_settle_tween") as Tween
	if settle_tween == null:
		_fail("drop settle tween was not created")
		return
	settle_tween.custom_step(1.0 / 60.0)
	var first_frame_distance := dragged_preview.position.distance_to(settle_start)
	var total_settle_distance := settle_start.distance_to(target_cell.position)
	if first_frame_distance <= 0.0 or first_frame_distance >= total_settle_distance * 0.25:
		_fail(
			"drop settle first frame snapped %.2fpx of %.2fpx instead of easing smoothly"
			% [first_frame_distance, total_settle_distance]
		)
		return
	await _next_presented_frame()
	if _commands.size() != 2 or String(_commands[1].get("type", "")) != "MOVE_HERO":
		_fail("queued MOVE_HERO was not delivered after the settle frame")
		return
	await create_timer(0.22).timeout
	await process_frame
	if _battle.get_node_or_null("Board/UnitHost/BattleUnitDragPreview") != null:
		_fail("drop settle preview was not released")
		return

	print("SMOKE_BATTLE_DRAG_LATENCY_PASS local_pointer_down_ms=%.2f" % pointer_down_msec)
	quit(0)


func _on_command_requested(command: Dictionary) -> void:
	_commands.append(command.duplicate(true))


func _next_presented_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await process_frame
	else:
		await RenderingServer.frame_post_draw


func _cell_unit_id(cell: Control) -> String:
	if cell == null or not (cell.get("cell_data") is Dictionary):
		return ""
	var data := Dictionary(cell.get("cell_data"))
	return String(data.get("unitId", data.get("unit_id", "")))


func _first_empty_target(origin: Vector2i) -> Vector2i:
	var cell_host := _battle.get_node_or_null("Board/CellHost")
	if cell_host == null:
		return Vector2i(-1, -1)
	for child in cell_host.get_children():
		var cell := child as Control
		if cell == null or not cell.visible or not cell.has_method("get_grid_position"):
			continue
		var grid := cell.call("get_grid_position") as Vector2i
		if grid != origin and _cell_unit_id(cell) == "":
			return grid
	return Vector2i(-1, -1)


func _fail(message: String) -> void:
	push_error("SMOKE_BATTLE_DRAG_LATENCY_FAIL: %s" % message)
	quit(1)
