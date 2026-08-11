extends SceneTree

const PetScene := preload("res://art/prefabs/pet/pet.tscn")
const SOURCE_PATH := "res://art/images/shared/pets/sheets/slices/pet_style_014_horned_wing_dragon.png"
const MAP_PATH := "res://art/images/battle/map_controls/maps/grassland_morning.png"
const OUTPUT_DIR := "res://output/visible_horned_wing_dragon_prefab"


class TestAssets extends RefCounted:
	var texture_resource: Texture2D

	func _init(texture: Texture2D) -> void:
		texture_resource = texture

	func texture_for_unit(_data: Dictionary, _side: String) -> Dictionary:
		return {"texture": texture_resource, "missing": {}}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var stage := Control.new()
	stage.size = Vector2(1920.0, 1080.0)
	root.add_child(stage)

	var background := TextureRect.new()
	background.size = stage.size
	background.texture = load(MAP_PATH) as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stage.add_child(background)

	var pet := PetScene.instantiate() as Control
	pet.position = Vector2(750.0, 430.0)
	pet.size = Vector2(180.0, 180.0)
	stage.add_child(pet)
	var source_texture := load(SOURCE_PATH) as Texture2D
	var assets := TestAssets.new(source_texture)
	pet.call("set_unit_data", {
		"id": "horned_wing_dragon",
		"unitId": "horned_wing_dragon",
		"image": SOURCE_PATH,
		"name": "Horned Wing Dragon",
		"hp": 10,
		"max_hp": 10,
		"atk": 3,
		"shield": 0,
	}, "player", assets)
	for _frame in range(12):
		await process_frame

	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)
	for sample in range(1):
		await process_frame
		if not _save_capture(output_dir.path_join("idle_%02d.png" % (sample + 1))):
			return
		await create_timer(0.3).timeout

	var start_position := pet.global_position
	pet.call("play_grid_movement", start_position, start_position + Vector2(240.0, 0.0), 1.6)
	for sample in range(3):
		await process_frame
		if not _save_capture(output_dir.path_join("move_%02d.png" % (sample + 1))):
			return
		await create_timer(0.2).timeout
	print("VISIBLE_HORNED_WING_DRAGON_PREFAB_PASS output=%s" % output_dir)
	quit(0)


func _save_capture(path: String) -> bool:
	var image := root.get_texture().get_image()
	if image.save_png(path) != OK:
		push_error("VISIBLE_HORNED_WING_DRAGON_PREFAB_FAIL could not save %s" % path)
		quit(1)
		return false
	return true
