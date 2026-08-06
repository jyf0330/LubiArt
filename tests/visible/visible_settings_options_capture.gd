extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const OUTPUT_DIR := "res://output/validation/settings_options"
const PAUSE_BUTTON_ROOT := "CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/"
const SETTINGS_VISUAL_ROOT := "StartSceneSettings/CompleteStartSceneSettingsPrefab/01_StartSceneSettingsVisual/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame

	var menu := battle.get_node("OverlayHost/SettingsMenu") as Control
	menu.call("open_menu")
	var settings_button := menu.get_node(PAUSE_BUTTON_ROOT + "Settings") as Button
	settings_button.pressed.emit()
	await process_frame
	await process_frame

	var category_names := ["audio", "graphics", "gameplay", "keybinds", "accessibility", "support"]
	for category_index in range(category_names.size()):
		var tab := menu.get_node(
			SETTINGS_VISUAL_ROOT + "LeftButtonArea/Buttons/Option%02d" % (category_index + 1)
		) as Button
		tab.pressed.emit()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var output_path := "%s/%02d_%s.png" % [OUTPUT_DIR, category_index + 1, category_names[category_index]]
		var save_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output_path))
		if save_error != OK:
			push_error("VISIBLE_SETTINGS_OPTIONS_CAPTURE_FAIL: %s" % error_string(save_error))
			quit(1)
			return

	var graphics_tab := menu.get_node(
		SETTINGS_VISUAL_ROOT + "LeftButtonArea/Buttons/Option02"
	) as Button
	graphics_tab.pressed.emit()
	await process_frame
	await process_frame
	var resolution_option := menu.get_node(
		SETTINGS_VISUAL_ROOT
		+ "ContentArea/ContentScroll/ContentStack/GraphicsSection/ResolutionOption"
	) as OptionButton
	resolution_option.show_popup()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var popup_output_path := OUTPUT_DIR + "/07_graphics_resolution_open.png"
	var popup_save_error := root.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(popup_output_path)
	)
	if popup_save_error != OK:
		push_error("VISIBLE_SETTINGS_OPTIONS_CAPTURE_FAIL: %s" % error_string(popup_save_error))
		quit(1)
		return

	print("VISIBLE_SETTINGS_OPTIONS_CAPTURE_PASS")
	quit(0)
