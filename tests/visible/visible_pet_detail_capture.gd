extends SceneTree

const PET_DETAIL_SCENE := preload("res://art/prefabs/pet/pet_detail.tscn")
const BATTLE_BACKGROUND := preload("res://art/images/battle/map_controls/maps/grassland_morning.png")
const CAPTURE_PATH := "res://output/pet_detail_visible.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var background := TextureRect.new()
	background.texture = BATTLE_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.size = Vector2(1920.0, 1080.0)
	root.add_child(background)
	var detail := PET_DETAIL_SCENE.instantiate() as Control
	root.add_child(detail)
	await process_frame
	Input.warp_mouse(Vector2i(900, 520))
	detail.call("show_context_detail", {
		"name": "李元芳二",
		"element": "暗",
		"quality": "水晶",
		"hp": 24,
		"max_hp": 24,
		"attack": 4,
		"ap": 3,
		"max_ap": 5,
		"defense": 2,
		"shield": 3,
		"regen": 1,
		"attack_shape": {
			"offsets": [
				{"dr": 0, "dc": 1},
				{"dr": 0, "dc": 2},
				{"dr": 0, "dc": 3},
			],
		},
	})
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(CAPTURE_PATH))
	if error != OK:
		push_error("PET_DETAIL_VISIBLE_CAPTURE_FAIL: %s" % error_string(error))
		quit(1)
		return
	print("PET_DETAIL_VISIBLE_CAPTURE_PASS: %s" % CAPTURE_PATH)
	quit(0)
