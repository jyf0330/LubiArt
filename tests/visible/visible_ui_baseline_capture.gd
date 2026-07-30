extends SceneTree

const BATTLE_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var battle_scene := BATTLE_SCENE.instantiate() as Control
	root.add_child(battle_scene)
	for _frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var output_path := OS.get_environment("UI_BASELINE_OUTPUT").strip_edges()
	if output_path == "":
		push_error("VISIBLE_UI_BASELINE_CAPTURE_FAIL: UI_BASELINE_OUTPUT is required")
		quit(1)
		return
	var save_error := root.get_texture().get_image().save_png(output_path)
	if save_error != OK:
		push_error("VISIBLE_UI_BASELINE_CAPTURE_FAIL: %s" % error_string(save_error))
		quit(1)
		return
	print("VISIBLE_UI_BASELINE_CAPTURE_PASS: %s" % output_path)
	quit(0)
