extends SceneTree

const PetScene := preload("res://art/prefabs/pet/pet.tscn")
const CAPTURE_PATH := "pet_frame_animation_runtime"
const PETS := [
	{
		"name": "SPR_002",
		"texture": "res://art/images/shared/pets/sheets/slices/pet_style_002_gold_shell.png",
	},
	{
		"name": "SPR_007",
		"texture": "res://art/images/shared/pets/sheets/slices/pet_style_007_rock_claw.png",
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var stage := Control.new()
	stage.size = Vector2(1280.0, 720.0)
	root.add_child(stage)
	var background := ColorRect.new()
	background.size = stage.size
	background.color = Color("202124")
	stage.add_child(background)
	var pets: Array[Control] = []
	for index in range(PETS.size()):
		var pet := PetScene.instantiate() as Control
		pet.position = Vector2(500.0 + index * 390.0, 190.0)
		pet.size = Vector2(280.0, 280.0)
		stage.add_child(pet)
		var texture_resource := load(String(PETS[index]["texture"])) as Texture2D
		pet.call("set_collection_data", {"id": String(PETS[index]["name"])}, texture_resource)
		pets.append(pet)
	for _frame in range(8):
		await process_frame
	var output_dir := OS.get_environment("TEMP").path_join(CAPTURE_PATH)
	DirAccess.make_dir_recursive_absolute(output_dir)
	for sample in range(6):
		if not await _capture(output_dir.path_join("idle_%02d.png" % (sample + 1))):
			return
		await create_timer(0.36).timeout
	print("VISIBLE_PET_FRAME_ANIMATIONS_PASS output=%s" % output_dir)
	quit(0)


func _capture(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var viewport_image := root.get_texture().get_image()
	if viewport_image.save_png(path) != OK:
		push_error("VISIBLE_PET_FRAME_ANIMATIONS_FAIL could not save %s" % path)
		quit(1)
		return false
	return true
