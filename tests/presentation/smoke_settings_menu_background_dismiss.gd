extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame

	var menu := battle.get_node("OverlayHost/SettingsMenu") as Control
	menu.call("open_menu")
	await process_frame
	assert(menu.visible)

	await _click(menu.get_viewport(), Vector2(80.0, 80.0))
	assert(not menu.visible)

	menu.call("open_menu")
	await process_frame
	await _click(menu.get_viewport(), Vector2(690.0, 155.0))
	assert(menu.visible)

	print("SMOKE_SETTINGS_MENU_BACKGROUND_DISMISS_PASS")
	quit(0)


func _click(viewport: Viewport, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.global_position = position
	press.pressed = true
	viewport.push_input(press, true)
	await process_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.global_position = position
	release.pressed = false
	viewport.push_input(release, true)
	await process_frame
