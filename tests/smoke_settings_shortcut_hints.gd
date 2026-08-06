extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const PAUSE_BUTTON_ROOT := "CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/"
const SHORTCUT_CHECK_PATH := "StartSceneSettings/CompleteStartSceneSettingsPrefab/01_StartSceneSettingsVisual/ContentArea/ContentScroll/ContentStack/GameplaySection/ShortcutHintsCheck"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame

	var map_controls := battle.get_node("MapControls") as Control
	var shortcut_hints := map_controls.get_node("ShortcutHints") as TextureRect
	var menu := battle.get_node("OverlayHost/SettingsMenu") as Control
	var settings_button := menu.get_node(PAUSE_BUTTON_ROOT + "Settings") as Button
	assert(battle.get_node_or_null("ShortcutHintDebugButton") == null)
	assert(shortcut_hints.visible)
	assert(bool(battle.call("are_button_shortcut_hints_visible")))

	menu.call("open_menu")
	settings_button.pressed.emit()
	await process_frame
	var shortcut_check := menu.get_node(SHORTCUT_CHECK_PATH) as CheckBox
	assert(shortcut_check.button_pressed)
	shortcut_check.button_pressed = false
	await process_frame
	assert(not shortcut_hints.visible)
	assert(not bool(battle.call("are_button_shortcut_hints_visible")))
	assert(not bool(menu.call("are_button_shortcut_hints_visible")))

	menu.call("handle_cancel")
	await process_frame
	assert(not menu.visible)
	assert(not menu.call("has_active_panel"))
	menu.call("open_menu")
	settings_button.pressed.emit()
	await process_frame
	shortcut_check = menu.get_node(SHORTCUT_CHECK_PATH) as CheckBox
	assert(not shortcut_check.button_pressed)
	shortcut_check.button_pressed = true
	await process_frame
	assert(shortcut_hints.visible)
	assert(bool(battle.call("are_button_shortcut_hints_visible")))
	var settings_panel := menu.get_node("StartSceneSettings") as Control
	settings_panel.call("close")
	await process_frame
	assert(not menu.visible)
	assert(not menu.call("has_active_panel"))

	print("SMOKE_SETTINGS_SHORTCUT_HINTS_PASS")
	quit(0)
