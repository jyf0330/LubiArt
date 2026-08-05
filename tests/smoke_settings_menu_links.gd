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
	var buttons_root := "CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/"
	var operations: Array[Dictionary] = []
	menu.connect(
		"session_operation_requested",
		func(operation: StringName, arguments: Dictionary) -> void:
			operations.append({"operation": operation, "arguments": arguments.duplicate(true)})
	)

	menu.call("open_menu")
	(menu.get_node(buttons_root + "Settings") as Button).pressed.emit()
	await process_frame
	assert(menu.get_node_or_null("StartSceneSettings") != null)
	menu.call("handle_cancel")
	await process_frame
	assert(not bool(menu.call("has_active_panel")))

	(menu.get_node(buttons_root + "SaveGame") as Button).pressed.emit()
	await process_frame
	var save_dialog := menu.get_node("UISaveGame") as Control
	var save_slot := save_dialog.find_child("SaveSlot1", true, false) as Button
	save_slot.pressed.emit()
	await process_frame
	assert(operations.size() == 1)
	assert(operations[0]["operation"] == &"save")
	assert(int(Dictionary(operations[0]["arguments"]).get("slot", 0)) == 1)

	(menu.get_node(buttons_root + "LoadGame") as Button).pressed.emit()
	await process_frame
	var load_dialog := menu.get_node("UILoadGame") as Control
	var load_slot := load_dialog.find_child("SaveSlot2", true, false) as Button
	load_slot.pressed.emit()
	await process_frame
	assert(operations.size() == 2)
	assert(operations[1]["operation"] == &"load")
	assert(int(Dictionary(operations[1]["arguments"]).get("slot", 0)) == 2)

	(menu.get_node(buttons_root + "MainMenu") as Button).pressed.emit()
	await process_frame
	var main_menu := menu.get_node("StartScene") as Control
	var back_button := main_menu.get_node("CompleteStartScenePrefab/01_StartVisual/BackButton") as Control
	assert(back_button.visible)
	var start_button := main_menu.get_node("CompleteStartScenePrefab/01_StartVisual/StartGameButton") as Control
	assert(str(start_button.get("button_text")) == "继续游戏")
	start_button.emit_signal("button_pressed")
	await process_frame
	assert(not menu.visible)

	menu.call("open_menu")
	(menu.get_node(buttons_root + "Resign") as Button).pressed.emit()
	await process_frame
	var abandon_dialog := menu.get_node("UIAbandonGame") as Control
	var confirm_button := abandon_dialog.find_child("Confirm", true, false) as Button
	confirm_button.pressed.emit()
	await process_frame
	assert(menu.visible)
	var start_menu := menu.get_node("StartScene") as Control
	assert(not bool(start_menu.call("get", "_has_active_game")))
	var new_game_button := start_menu.get_node(
		"CompleteStartScenePrefab/01_StartVisual/StartGameButton"
	) as Control
	assert(str(new_game_button.get("button_text")) == "开始游戏")
	var hidden_back_button := start_menu.get_node(
		"CompleteStartScenePrefab/01_StartVisual/BackButton"
	) as Control
	assert(not hidden_back_button.visible)

	print("SMOKE_SETTINGS_MENU_LINKS_PASS")
	quit(0)
