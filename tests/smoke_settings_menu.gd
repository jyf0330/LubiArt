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
	assert(menu != null)
	assert(not menu.visible)

	var cancel_event := InputEventKey.new()
	cancel_event.keycode = KEY_ESCAPE
	cancel_event.pressed = true
	battle.call("_input", cancel_event)
	assert(menu.visible)

	battle.call("_input", cancel_event)
	assert(not menu.visible)

	menu.call("open_menu")
	var continue_button := menu.get_node(
		"CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/Continue"
	) as Button
	continue_button.pressed.emit()
	assert(not menu.visible)

	print("SMOKE_SETTINGS_MENU_PASS")
	quit(0)
