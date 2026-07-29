extends SceneTree

const DEBUG_SCENE := preload("res://art/scenes/sprite_info_card_debug/sprite_info_card_debug_scene.tscn")


func _initialize() -> void:
	root.title = "SpriteInfoCard Standalone Debug QA"
	root.size = Vector2i(1920, 1080)
	root.min_size = Vector2i(1280, 720)
	call_deferred("_build_preview")


func _build_preview() -> void:
	var debug_scene := DEBUG_SCENE.instantiate() as Control
	root.add_child(debug_scene)
	var panel := debug_scene.get_node("SpriteInfoCardDebugPanel") as PanelContainer
	await process_frame
	panel.call("debug_cycle_pet_name")
	panel.call("debug_cycle_pet_name")
	panel.call("debug_select_element", 6)
	panel.call("debug_select_quality", 3)
	panel.call("debug_set_trait_lock_visible", false)
	panel.call("debug_select_trait", 5)
	panel.call("debug_set_values", {
		"hp": 31,
		"max_hp": 40,
		"attack": 9,
		"ap": 6,
		"max_ap": 8,
		"defense": 7,
		"shield": 5,
		"regen": 4,
	})
	for frame in range(5):
		await process_frame
	var output_dir := ProjectSettings.globalize_path("res://output/validation")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join("sprite_info_card_standalone_debug_panel.png")
	var save_error := root.get_texture().get_image().save_png(output_path)
	assert(save_error == OK)
	print("SPRITE_INFO_CARD_STANDALONE_DEBUG_VISIBLE_PASS: %s" % output_path)
	quit(0)
