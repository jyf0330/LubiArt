extends SceneTree

const GAME_SCENE := preload("res://art/scenes/app/game.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_game := GAME_SCENE.instantiate() as Control
	route_game.set("mock_start_phase", "route")
	root.add_child(route_game)
	await process_frame
	await process_frame
	_expect(route_game.get_node_or_null("GlobalSettingsMenu") == null, "route starts without a menu instance")
	await _press_h()
	var route_menu := route_game.get_node_or_null("GlobalSettingsMenu") as Control
	_expect(route_menu != null and route_menu.visible, "H mounts and opens the route menu")
	await _press_h()
	await process_frame
	_expect(route_game.get_node_or_null("GlobalSettingsMenu") == null, "second H releases the route menu")
	route_game.queue_free()
	await process_frame

	var battle_game := GAME_SCENE.instantiate() as Control
	root.add_child(battle_game)
	await process_frame
	await process_frame
	var battle := battle_game.call("get_active_feature_view") as Control
	var battle_menu := battle.get_node_or_null("OverlayHost/SettingsMenu") as Control if battle != null else null
	_expect(battle_menu != null and not battle_menu.visible, "authored battle menu is hidden by default")
	await _press_h()
	_expect(battle_menu != null and battle_menu.visible, "H opens the authored battle menu")
	_expect(battle_game.get_node_or_null("GlobalSettingsMenu") == null, "battle does not mount a duplicate menu")
	await _press_h()
	_expect(battle_menu != null and not battle_menu.visible, "second H hides the authored battle menu")

	battle_game.queue_free()
	await process_frame
	if not _failed:
		print("SMOKE_GLOBAL_SAVE_LOAD_HOTKEY_OK")
	quit(1 if _failed else 0)


func _press_h() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_H
	press.physical_keycode = KEY_H
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_H
	release.physical_keycode = KEY_H
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_GLOBAL_SAVE_LOAD_HOTKEY_FAIL: %s" % message)
