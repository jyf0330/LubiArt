extends SceneTree

const PREFAB := preload("res://art/prefabs/battle/hud/battle_map_controls.tscn")
const BACKGROUND := preload("res://art/images/battle/map_controls/maps/grassland_morning.png")
const OUTPUT_PATH := "res://output/validation/battle_map_controls/aligned_controls_1920x1080.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var background := TextureRect.new()
	background.size = Vector2(1920.0, 1080.0)
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(background)
	root.add_child(PREFAB.instantiate())
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	assert(image.save_png(OUTPUT_PATH) == OK)
	print("BATTLE_CONTROLS_ALIGNMENT_CAPTURE_PASS")
	quit(0)
