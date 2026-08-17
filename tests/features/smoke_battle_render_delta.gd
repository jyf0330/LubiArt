extends SceneTree

const YsbzsStateScript := preload("res://core/state/game_state.gd")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://art/scenes/battle/battle_art_scene.tscn")
	_expect(packed != null, "battle UI scene loads")
	if packed == null:
		quit(1)
		return
	var battle := packed.instantiate()
	root.add_child(battle)
	await process_frame
	var probe := BattleSceneProbe.new(battle)

	var state = YsbzsStateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "fixture starts battle")
	var snap: Dictionary = state.snapshot()
	battle.call("render_snapshot", snap)
	var expected_cell_count := int(Dictionary(snap.get("board", {})).get("cellCount", 0))
	_expect(probe.rendered_cell_count() == expected_cell_count, "first snapshot renders all configured cells")

	battle.call("render_snapshot", snap)
	_expect(probe.rendered_cell_count() == 0, "identical snapshot rebuilds no cells")

	var changed_snap := snap.duplicate(true)
	var cells := Array(Dictionary(changed_snap.get("board", {})).get("cells", []))
	_expect(not cells.is_empty(), "snapshot includes board cells")
	if not cells.is_empty():
		var changed_cell := Dictionary(cells[0])
		changed_cell["elements"] = {"火": 1}
		cells[0] = changed_cell
		battle.call("render_snapshot", changed_snap)
		_expect(probe.rendered_cell_count() == 1, "single-cell element change rebuilds exactly one cell")

	var board := battle.get_node_or_null("Board") as Control
	_expect(board != null and not board.is_processing(), "battle board is idle without an active drag")
	battle.call("render_snapshot", snap)
	var drag_case: Dictionary = Dictionary(probe.start_first_player_drag(snap))
	_expect(bool(drag_case.get("started", false)), "fixture starts a real battle-unit drag")
	_expect(board != null and board.is_processing(), "drag preview enables per-frame processing")
	probe.cancel_drag()
	_expect(board != null and not board.is_processing(), "finishing drag disables per-frame processing")

	battle.queue_free()
	if _failed:
		quit(1)
		return
	print("SMOKE_BATTLE_RENDER_DELTA_OK first=%d identical=0 changed=1" % (YsbzsStateScript.BOARD_WIDTH * YsbzsStateScript.BOARD_HEIGHT))
	quit()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_BATTLE_RENDER_DELTA_FAIL: %s" % message)
