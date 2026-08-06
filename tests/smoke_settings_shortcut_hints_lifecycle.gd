extends SceneTree

const GameScene := preload("res://art/scenes/app/game.tscn")
const PAUSE_BUTTON_ROOT := "OverlayHost/SettingsMenu/CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/"
const SHORTCUT_CHECK_PATH := "OverlayHost/SettingsMenu/StartSceneSettings/CompleteStartSceneSettingsPrefab/01_StartSceneSettingsVisual/ContentArea/ContentScroll/ContentStack/GameplaySection/ShortcutHintsCheck"
const PREFERENCES_OVERRIDE_ENV := "YSBZS_UI_PREFERENCES_PATH"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var preference_path := ProjectSettings.globalize_path(
		"user://smoke_settings_shortcut_hints_lifecycle.cfg"
	)
	OS.set_environment(PREFERENCES_OVERRIDE_ENV, preference_path)
	if FileAccess.file_exists(preference_path):
		assert(DirAccess.remove_absolute(preference_path) == OK)
	var game := GameScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame

	var battle := game.call("get_active_feature_view") as Control
	var settings_button := battle.get_node(PAUSE_BUTTON_ROOT + "Settings") as Button
	var menu := battle.get_node("OverlayHost/SettingsMenu") as Control
	menu.call("open_menu")
	settings_button.pressed.emit()
	await process_frame
	var shortcut_check := battle.get_node(SHORTCUT_CHECK_PATH) as CheckBox
	shortcut_check.button_pressed = false
	await process_frame
	assert(not bool(game.get("_button_shortcut_hints_visible")))
	assert(not (battle.get_node("MapControls/ShortcutHints") as TextureRect).visible)

	game.queue_free()
	await process_frame
	game = GameScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	battle = game.call("get_active_feature_view") as Control
	assert(battle != null)
	assert(not (battle.get_node("MapControls/ShortcutHints") as TextureRect).visible)
	assert(not bool(battle.call("are_button_shortcut_hints_visible")))
	menu = battle.get_node("OverlayHost/SettingsMenu") as Control
	settings_button = battle.get_node(PAUSE_BUTTON_ROOT + "Settings") as Button
	menu.call("open_menu")
	settings_button.pressed.emit()
	await process_frame
	shortcut_check = battle.get_node(SHORTCUT_CHECK_PATH) as CheckBox
	assert(not shortcut_check.button_pressed)

	shortcut_check.button_pressed = true
	await process_frame
	game.queue_free()
	await process_frame
	game = GameScene.instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	battle = game.call("get_active_feature_view") as Control
	assert((battle.get_node("MapControls/ShortcutHints") as TextureRect).visible)

	game.queue_free()
	await process_frame
	assert(DirAccess.remove_absolute(preference_path) == OK)
	OS.set_environment(PREFERENCES_OVERRIDE_ENV, "")

	print("SMOKE_SETTINGS_SHORTCUT_HINTS_LIFECYCLE_PASS")
	quit(0)
