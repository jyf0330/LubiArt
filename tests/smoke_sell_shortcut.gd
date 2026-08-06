extends SceneTree

const GameScene := preload("res://art/scenes/app/game.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GameScene.instantiate() as Control
	game.set("mock_start_phase", "route")
	root.add_child(game)
	for _frame in range(10):
		await process_frame
	var view := game.call("get_three_choice_view") as Control
	var session := game.call("get_game_session") as RefCounted
	_expect(view != null and session != null, "route UI and offline session are available")
	if view == null or session == null:
		await _finish(game)
		return

	var before := Dictionary(session.call("current_snapshot"))
	var before_roster := Array(before.get("roster", []))
	_expect(not before_roster.is_empty(), "route snapshot provides a sellable party target")
	if before_roster.is_empty():
		await _finish(game)
		return

	view.call("_set_hovered_storage_target", &"party", 0)
	await _press_key(KEY_E)
	for _frame in range(6):
		await process_frame
	var after_sale := Dictionary(session.call("current_snapshot"))
	var after_sale_count := Array(after_sale.get("roster", [])).size()
	_expect(after_sale_count == before_roster.size() - 1, "E sells the explicitly hovered party item")

	await _press_key(KEY_E)
	for _frame in range(3):
		await process_frame
	var after_no_target := Dictionary(session.call("current_snapshot"))
	_expect(Array(after_no_target.get("roster", [])).size() == after_sale_count, "E does nothing after the explicit sell target is cleared")
	await _finish(game)


func _press_key(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _finish(game: Control) -> void:
	game.queue_free()
	await process_frame
	if not _failed:
		print("SMOKE_SELL_SHORTCUT_OK")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_SELL_SHORTCUT_FAIL: %s" % message)
