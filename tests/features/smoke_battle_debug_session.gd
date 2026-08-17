extends SceneTree

const BattleDebugScene := preload("res://art/scenes/debug/battle_debug.tscn")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var debug_view := BattleDebugScene.instantiate() as Control
	root.add_child(debug_view)
	for _frame in range(6):
		await process_frame
	var session := debug_view.get("game_session") as RefCounted
	var game_view := debug_view.get("game_view") as Control
	var setup_panel := debug_view.get("setup_panel") as Control
	_expect(session != null, "battle debug owns a GameSession instead of a State")
	_expect(game_view != null and game_view.call("get_game_session") == session, "battle debug injects the same Session into the formal game view")
	_expect(setup_panel != null and int(setup_panel.call("catalog_count")) == 369, "authored debug panel reads the current content catalog through Session")
	if session != null:
		var snapshot := Dictionary(session.call("current_snapshot"))
		_expect(String(snapshot.get("phase", "")) == "route", "debug harness waits for authored panel intent before battle")
	if setup_panel != null:
		setup_panel.get_node("PanelMargin/Panel/VBox/Actions/StartButton").emit_signal("pressed")
		for _frame in range(6):
			await process_frame
		var started_snapshot := Dictionary(session.call("current_snapshot"))
		_expect(String(started_snapshot.get("phase", "")) == "battle", "configured debug enters battle through public developer Command")
		_expect(String(started_snapshot.get("run_seed", "")) == "ysbzs-debug-first-battle-v1", "panel seed reaches the authoritative Session")
		_expect(setup_panel.get_node("ReopenButton").visible, "battle keeps the authored reconfigure entry visible above the formal battle layer")
		var player_count := 0
		var enemy_count := 0
		for unit_value in Array(started_snapshot.get("units", [])):
			var unit := Dictionary(unit_value)
			player_count += 1 if String(unit.get("side", "")) == "player" else 0
			enemy_count += 1 if String(unit.get("side", "")) == "enemy" else 0
		_expect(player_count == 4 and enemy_count == 4, "configured debug battle contains all eight selected pets")
		setup_panel.get_node("ReopenButton").emit_signal("pressed")
		for _frame in range(3):
			await process_frame
		_expect(String(Dictionary(session.call("current_snapshot")).get("phase", "")) == "battle", "reconfigure replaces the developer Session without mutating the prior battle Session")
		var reopened_session := debug_view.get("game_session") as RefCounted
		_expect(reopened_session != session, "reconfigure creates a fresh developer Session")
		_expect(String(Dictionary(reopened_session.call("current_snapshot")).get("phase", "")) == "route", "reconfigure returns the authored panel to a clean route state")
	debug_view.queue_free()
	await process_frame
	if failed:
		quit(1)
		return
	print("SMOKE_BATTLE_DEBUG_SESSION_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
