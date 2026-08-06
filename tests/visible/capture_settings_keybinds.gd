extends SceneTree

const SettingsScene := preload("res://art/prefabs/menu/screens/menu_settings.tscn")
const OUTPUT_PATH := "res://output/validation/settings_keybinds_actual_1920x1080.png"
const VISUAL_ROOT := "CompleteStartSceneSettingsPrefab/01_StartSceneSettingsVisual/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var settings := SettingsScene.instantiate() as Control
	root.add_child(settings)
	await process_frame
	settings.call("open")
	var keybind_tab := settings.get_node(VISUAL_ROOT + "LeftButtonArea/Buttons/Option04") as Button
	keybind_tab.pressed.emit()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := root.get_texture().get_image().save_png(absolute_path)
	if error != OK:
		push_error("CAPTURE_SETTINGS_KEYBINDS_FAIL: %s" % error_string(error))
		quit(1)
		return
	print("CAPTURE_SETTINGS_KEYBINDS_PASS")
	quit(0)
