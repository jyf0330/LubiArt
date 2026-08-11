extends SceneTree

const PetScene := preload("res://art/prefabs/pet/pet.tscn")
const DIRECTIONS: Array[Vector2] = [
	Vector2.LEFT,
	Vector2.RIGHT,
	Vector2.UP,
	Vector2.DOWN,
	Vector2(-1.0, -1.0),
	Vector2(1.0, -1.0),
	Vector2(-1.0, 1.0),
	Vector2(1.0, 1.0),
]
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
	var texture_paths := _battle_unit_texture_paths()
	assert(not texture_paths.is_empty())
	var checked_cases := 0
	for texture_path in texture_paths:
		var texture_resource := load(texture_path) as Texture2D
		assert(texture_resource != null)
		for side in ["player", "enemy"]:
			var pet := PetScene.instantiate() as Control
			root.add_child(pet)
			pet.size = Vector2(180.0, 180.0)
			var assets := TextureAssets.new(texture_resource)
			pet.call("set_unit_data", _unit_data(texture_path, 0), side, assets)
			await process_frame
			var reaction := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/HitReactionPlayer")
			var shield_effect := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/ShieldHitEffectPlayer")
			for direction in DIRECTIONS:
				var baseline := _geometry_snapshot(pet)
				pet.call("play_damage_feedback", _damage_payload(0), direction)
				for frame_index in range(8):
					reaction.call("_apply_step", frame_index)
					_assert_geometry_equal(baseline, _geometry_snapshot(pet), texture_path, side, "hp", direction, frame_index)
				checked_cases += 1
				reaction.call("reset")

			pet.call("set_unit_data", _unit_data(texture_path, 3), side, assets)
			await process_frame
			var shield_baseline := _geometry_snapshot(pet)
			pet.call("play_damage_feedback", _damage_payload(3), Vector2.UP)
			_assert_geometry_equal(shield_baseline, _geometry_snapshot(pet), texture_path, side, "shield", Vector2.UP, 0)
			checked_cases += 1
			shield_effect.call("reset")
			pet.queue_free()
			await process_frame
	print("ALL_PET_HIT_STABILITY_PASS textures=%d cases=%d" % [texture_paths.size(), checked_cases])
	quit(0)


func _unit_data(texture_path: String, shield: int) -> Dictionary:
	return {
		"unitId": texture_path.get_file().get_basename(),
		"unitName": texture_path.get_file().get_basename(),
		"hp": 20,
		"shield": shield,
		"atk": 5,
	}


func _damage_payload(shield_before: int) -> Dictionary:
	return {
		"finalDamage": 2,
		"shieldDamage": 2 if shield_before > 0 else 0,
		"hpDamage": 0 if shield_before > 0 else 2,
		"shieldFrom": shield_before,
		"shieldTo": maxi(0, shield_before - 2),
		"hpTo": 20 if shield_before > 0 else 18,
	}


func _geometry_snapshot(pet: Control) -> Dictionary:
	var visual := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual") as Control
	var sprite := visual.get_node("CreatureArt") as TextureRect
	var shadow := visual.get_node("Shadow") as Control
	var frame := visual.get_node("SelectionFrame") as Control
	var stats := visual.get_node("Stats") as Control
	return {
		"pet_position": pet.position,
		"pet_scale": pet.scale,
		"visual_position": visual.position,
		"visual_scale": visual.scale,
		"sprite_position": sprite.position,
		"sprite_scale": sprite.scale,
		"sprite_pivot": sprite.pivot_offset,
		"sprite_rotation": sprite.rotation,
		"shadow_position": shadow.position,
		"shadow_scale": shadow.scale,
		"frame_position": frame.position,
		"frame_scale": frame.scale,
		"stats_position": stats.position,
		"stats_scale": stats.scale,
	}


func _assert_geometry_equal(
	expected: Dictionary,
	actual: Dictionary,
	texture_path: String,
	side: String,
	damage_kind: String,
	direction: Vector2,
	frame_index: int
) -> void:
	for key in expected.keys():
		var expected_value: Variant = expected[key]
		var actual_value: Variant = actual.get(key)
		var matches := false
		if expected_value is Vector2 and actual_value is Vector2:
			matches = Vector2(actual_value).is_equal_approx(Vector2(expected_value))
		elif typeof(expected_value) == TYPE_FLOAT and typeof(actual_value) == TYPE_FLOAT:
			matches = is_equal_approx(float(actual_value), float(expected_value))
		else:
			matches = actual_value == expected_value
		assert(matches, "Hit geometry changed: texture=%s side=%s kind=%s direction=%s frame=%d property=%s expected=%s actual=%s" % [
			texture_path,
			side,
			damage_kind,
			direction,
			frame_index,
			key,
			expected_value,
			actual_value,
		])


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
	assert(parsed is Dictionary, "Could not parse %s" % path)
	return Dictionary(parsed)


func _add_texture_path(path: String, lookup: Dictionary) -> void:
	if path.begins_with("res://") and path.ends_with(".png"):
		lookup[path] = true
