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
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var output_path := OS.get_environment("SETTINGS_MENU_OUTPUT").strip_edges()
	if output_path == "":
		push_error("VISIBLE_SETTINGS_MENU_CAPTURE_FAIL: SETTINGS_MENU_OUTPUT is required")
		quit(1)
		return
	var save_error := root.get_texture().get_image().save_png(output_path)
	if save_error != OK:
		push_error("VISIBLE_SETTINGS_MENU_CAPTURE_FAIL: %s" % error_string(save_error))
		quit(1)
		return
	print("VISIBLE_SETTINGS_MENU_CAPTURE_PASS: %s" % output_path)
	quit(0)
