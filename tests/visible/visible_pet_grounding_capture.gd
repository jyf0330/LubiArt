extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var main_instance := MainScene.instantiate()
	root.add_child(main_instance)
	for _frame in range(12):
		await process_frame
	await create_timer(1.0).timeout
	var output_path := OS.get_environment("TEMP").path_join("lubi_pet_grounding_visible.png")
	var image := root.get_texture().get_image()
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("VISIBLE_PET_GROUNDING_CAPTURE_FAIL: %s" % error_string(save_error))
		quit(1)
		return
	print("VISIBLE_PET_GROUNDING_CAPTURE_PASS: %s" % output_path)
	quit(0)
