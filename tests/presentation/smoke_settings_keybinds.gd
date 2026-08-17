extends SceneTree

const SettingsScene := preload("res://art/prefabs/menu/screens/menu_settings.tscn")
const MapControlsScene := preload("res://art/prefabs/battle/hud/battle_map_controls.tscn")
const ShortcutCatalog := preload("res://core_ui/scripts/shared/shortcut_catalog.gd")
const UiPreferencesScript := preload("res://core_ui/scripts/app/ui_preferences.gd")
const CONTENT_ROOT := "CompleteStartSceneSettingsPrefab/01_StartSceneSettingsVisual/ContentArea/ContentScroll/ContentStack/KeybindsSection/"

var _auto_arrange_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	ShortcutCatalog.load_bindings({})
	var settings := SettingsScene.instantiate() as Control
	root.add_child(settings)
	await process_frame

	var key_button := settings.get_node(CONTENT_ROOT + "AutoArrangeKeyButton") as Button
	var reset_button := settings.get_node(CONTENT_ROOT + "AutoArrangeResetButton") as Button
	key_button.pressed.emit()
	assert(key_button.text == "按下按键以设置")

	var right_mouse := InputEventMouseButton.new()
	right_mouse.button_index = MOUSE_BUTTON_RIGHT
	right_mouse.pressed = true
	settings.call("_input", right_mouse)
	assert(key_button.text == "RMB")
	assert(reset_button.visible)

	var controls := MapControlsScene.instantiate() as Control
	root.add_child(controls)
	await process_frame
	controls.connect("auto_arrange_requested", _on_auto_arrange_requested)
	assert(bool(controls.call("handle_shortcut_input", right_mouse)))
	var right_mouse_release := InputEventMouseButton.new()
	right_mouse_release.button_index = MOUSE_BUTTON_RIGHT
	right_mouse_release.pressed = false
	assert(bool(controls.call("handle_shortcut_input", right_mouse_release)))
	assert(_auto_arrange_count == 1)

	var preference_path := "user://smoke_settings_keybinds.cfg"
	OS.set_environment(UiPreferencesScript.PATH_OVERRIDE_ENV, preference_path)
	var preferences: RefCounted = UiPreferencesScript.new()
	assert(bool(preferences.call("save_shortcut_bindings", ShortcutCatalog.serialized_bindings())))
	ShortcutCatalog.load_bindings({})
	ShortcutCatalog.load_bindings(preferences.call("load_shortcut_bindings"))
	assert(ShortcutCatalog.get_binding(ShortcutCatalog.ACTION_AUTO_ARRANGE) == {
		"type": ShortcutCatalog.INPUT_MOUSE,
		"code": MOUSE_BUTTON_RIGHT,
	})

	reset_button.pressed.emit()
	assert(key_button.text == "A")
	assert(not reset_button.visible)
	ShortcutCatalog.load_bindings({})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(preference_path))
	OS.set_environment(UiPreferencesScript.PATH_OVERRIDE_ENV, "")
	print("SMOKE_SETTINGS_KEYBINDS_PASS")
	quit(0)


func _on_auto_arrange_requested() -> void:
	_auto_arrange_count += 1
