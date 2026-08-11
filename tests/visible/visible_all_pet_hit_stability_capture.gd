extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const CAPTURE_SIZE := Vector2i(220, 220)


class TextureAssets:
	extends RefCounted

	var texture_resource: Texture2D


	func _init(value: Texture2D) -> void:
		texture_resource = value


	func texture_for_unit(_data: Dictionary, _side: String) -> Dictionary:
		return {"texture": texture_resource, "missing": {}}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var main_instance := MainScene.instantiate()
	root.add_child(main_instance)
	for _frame in range(12):
		await process_frame
	await create_timer(0.5).timeout

	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	var session := main_instance.call("get_game_session") as RefCounted
	var auto_button := battle_view.get_node_or_null("MapControls/AutoArrangeButton") as TextureButton if battle_view != null else null
	if battle_view == null or session == null or auto_button == null:
		_fail("battle view is unavailable")
		return
	var before_step := int(session.call("replay_step_index"))
	auto_button.pressed.emit()
	if not await _wait_for_step(session, before_step + 1):
		_fail("auto-position did not advance")
		return
	await create_timer(0.25).timeout

	var pet := _find_battle_pet(battle_view)
	if pet == null:
		_fail("could not find a battle pet")
		return
	var texture_paths := _battle_unit_texture_paths()
	var output_dir := ProjectSettings.globalize_path("res://output/all_pet_hit_stability")
	DirAccess.make_dir_recursive_absolute(output_dir)
	for index in range(texture_paths.size()):
		var texture_path := texture_paths[index]
		var texture_resource := load(texture_path) as Texture2D
		if texture_resource == null:
			_fail("could not load %s" % texture_path)
			return
		var data := Dictionary(pet.get("cell_data")).duplicate(true)
		data["unitId"] = "hit_stability_%03d" % index
		data["unitName"] = texture_path.get_file().get_basename()
		data["hp"] = 20
		data["shield"] = 0
		pet.call("set_unit_data", data, "enemy", TextureAssets.new(texture_resource))
		await process_frame
		await RenderingServer.frame_post_draw
		if not _capture_pet(pet, output_dir, "baseline_unit_%03d_%s.png" % [index + 1, _safe_slug(texture_path)]):
			return
		pet.call("play_damage_feedback", {
			"finalDamage": 2,
			"shieldDamage": 0,
			"hpDamage": 2,
			"shieldFrom": 0,
			"shieldTo": 0,
			"hpTo": 18,
		}, Vector2(1.0, -1.0))
		var slug := _safe_slug(texture_path)
		if slug in ["pet_style_006_shadow_rock_wolf", "pet_style_007_rock_claw"]:
			for frame_index in range(8):
				await RenderingServer.frame_post_draw
				if not _capture_pet(pet, output_dir, "sequence_%s_frame_%03d.png" % [slug, frame_index + 1]):
					return
				if frame_index == 3 and not _capture_pet(pet, output_dir, "impact_unit_%03d_%s.png" % [index + 1, slug]):
					return
				await create_timer(0.06, true, false, true).timeout
		else:
			await create_timer(0.195, true, false, true).timeout
			await RenderingServer.frame_post_draw
			if not _capture_pet(pet, output_dir, "impact_unit_%03d_%s.png" % [index + 1, slug]):
				return

	print("VISIBLE_ALL_PET_HIT_STABILITY_PASS textures=%d output=%s" % [texture_paths.size(), output_dir])
	quit(0)


func _find_battle_pet(battle_view: Control) -> Control:
	var board_grid := battle_view.get_node("Board/CellHost") as Control
	for cell in board_grid.get_children():
		if cell.has_method("get_unit_node"):
			var pet := cell.call("get_unit_node") as Control
			if pet != null:
				return pet
	return null


func _battle_unit_texture_paths() -> Array[String]:
	var lookup: Dictionary = {}
	var sheet_manifest := _load_manifest("res://art/manifests/shared/pets/sheets/pet_sheet_manifest.json")
	for image_value in Array(sheet_manifest.get("images", [])):
		_add_texture_path(String(Dictionary(image_value).get("path", "")), lookup)
	var pet_id_map := _load_manifest("res://art/manifests/shared/pets/sheets/pet_id_map.json")
	for section_name in ["by_pet_id", "by_name"]:
		for path_value in Dictionary(pet_id_map.get(section_name, {})).values():
			_add_texture_path(String(path_value), lookup)
	var metrics := _load_manifest("res://art/manifests/shared/pets/sheets/pet_battle_visual_metrics.json")
	for path_value in Dictionary(metrics.get("by_texture_path", {})).keys():
		_add_texture_path(String(path_value), lookup)
	var animations := _load_manifest("res://art/manifests/shared/pets/animations/pet_frame_animation_manifest.json")
	for path_value in Dictionary(animations.get("by_texture_path", {})).keys():
		_add_texture_path(String(path_value), lookup)
	for path_value in Dictionary(animations.get("aliases", {})).keys():
		_add_texture_path(String(path_value), lookup)
	var enemy_map := _load_manifest("res://art/manifests/battle/enemy_image_map.json")
	for path_value in enemy_map.values():
		_add_texture_path(String(path_value), lookup)
	var paths: Array[String] = []
	for path_value in lookup.keys():
		var path := String(path_value)
		if ResourceLoader.exists(path):
			paths.append(path)
	paths.sort()
	return paths


func _load_manifest(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return Dictionary(parsed) if parsed is Dictionary else {}


func _add_texture_path(path: String, lookup: Dictionary) -> void:
	if path.begins_with("res://") and path.ends_with(".png"):
		lookup[path] = true


func _safe_slug(path: String) -> String:
	return path.get_file().get_basename().to_lower().replace(" ", "_")


func _capture_pet(pet: Control, output_dir: String, file_name: String) -> bool:
	var viewport_image := root.get_texture().get_image()
	var pet_center := pet.get_global_transform_with_canvas() * (pet.size * 0.5)
	var cropped := viewport_image.get_region(_centered_crop_rect(pet_center, viewport_image.get_size()))
	var output_path := output_dir.path_join(file_name)
	if cropped.save_png(output_path) != OK:
		_fail("could not save %s" % output_path)
		return false
	return true


func _centered_crop_rect(center: Vector2, image_size: Vector2i) -> Rect2i:
	var top_left := Vector2i(roundi(center.x - CAPTURE_SIZE.x * 0.5), roundi(center.y - CAPTURE_SIZE.y * 0.5))
	top_left.x = clampi(top_left.x, 0, maxi(0, image_size.x - CAPTURE_SIZE.x))
	top_left.y = clampi(top_left.y, 0, maxi(0, image_size.y - CAPTURE_SIZE.y))
	return Rect2i(top_left, CAPTURE_SIZE)


func _wait_for_step(session: RefCounted, expected_step: int) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if int(session.call("replay_step_index")) == expected_step:
			return true
		await process_frame
	return false


func _fail(message: String) -> void:
	push_error("VISIBLE_ALL_PET_HIT_STABILITY_FAIL: %s" % message)
	quit(1)
