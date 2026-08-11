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
	if target.x < 0:
		_fail("no empty drop target is available")
		return
	var started := Dictionary(probe.call("start_drag", origin, target))
	if not bool(started.get("started", false)):
		_fail("drag preview was not created synchronously")
		return
	if not _commands.is_empty():
		_fail("SELECT_CELL blocked pointer-down instead of being queued")
		return
	await process_frame
	if _commands.size() != 1 or String(_commands[0].get("type", "")) != "SELECT_CELL":
		_fail("queued SELECT_CELL was not delivered on the next frame")
		return

	await probe.call("update_drag", target, _session.call("current_snapshot"))
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
	await process_frame
	if _commands.size() != 2 or String(_commands[1].get("type", "")) != "MOVE_HERO":
		_fail("queued MOVE_HERO was not delivered on the next frame")
		return
	await create_timer(0.22).timeout
	await process_frame
	if _battle.get_node_or_null("Board/UnitHost/BattleUnitDragPreview") != null:
		_fail("drop settle preview was not released")
		return

	print("SMOKE_BATTLE_DRAG_LATENCY_PASS")
	quit(0)


func _on_command_requested(command: Dictionary) -> void:
	_commands.append(command.duplicate(true))


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
