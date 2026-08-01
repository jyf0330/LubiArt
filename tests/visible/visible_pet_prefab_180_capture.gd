extends SceneTree

const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var backdrop := ColorRect.new()
	backdrop.color = Color("30343b")
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pet := BattleUnitScene.instantiate() as Control
	pet.size = Vector2(180.0, 180.0)
	pet.position = Vector2(600.0, 180.0)
	backdrop.add_child(pet)
	await process_frame
	pet.call("set_unit_data", {"unitId": "gold_prefab_preview", "hp": 30, "shield": 10, "atk": 10, "damage_cap": 17}, "player", null)
	await process_frame
	pet.call("_layout_children")
	pet.scale = Vector2(4.0, 4.0)
	for _frame in range(8):
		await process_frame
	var output_path := ProjectSettings.globalize_path("res://output/pet_prefab_gold_180.png")
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("VISIBLE_PET_PREFAB_180_CAPTURE_FAIL: %s" % error_string(error))
		quit(1)
		return
	print("VISIBLE_PET_PREFAB_180_CAPTURE_PASS: %s" % output_path)
	quit(0)
