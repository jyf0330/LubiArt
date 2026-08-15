extends SceneTree

const PetAnimationScript := preload("res://core_ui/scripts/shared/pet/pet_animation.gd")
const PetScene := preload("res://art/prefabs/pet/pet.tscn")
const BattleAssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const SOURCE_PATH := "res://art/images/shared/pets/sheets/slices/pet_style_005_earth_slime.png"
const FACING_MANIFEST_PATH := "res://art/manifests/shared/pets/sheets/pet_battle_visual_metrics.json"
const PET_IMAGE_MAP_PATH := "res://art/manifests/shared/pets/sheets/pet_id_map.json"
const ENEMY_IMAGE_MAP_PATH := "res://art/manifests/battle/enemy_image_map.json"
const BATTLE_ASSET_MANIFEST_PATH := "res://art/manifests/battle/battle_asset_manifest.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _verify_facing_manifest_coverage():
		return
	var source_texture := load(SOURCE_PATH) as Texture2D
	if source_texture == null:
		_fail("missing source texture")
		return
	var view := Control.new()
	view.size = Vector2(200.0, 200.0)
	root.add_child(view)
	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.size = view.size
	sprite.texture = source_texture
	view.add_child(sprite)
	var animation = PetAnimationScript.new()
	view.add_child(animation)
	animation.configure(view)
	animation.play_sprite_idle(
		sprite,
		source_texture,
		Vector2(100.0, 190.0),
		SOURCE_PATH,
		true,
		false,
		1.0,
		true,
		1.0
	)
	await process_frame
	await process_frame

	animation.play_sprite_attack(Vector2.LEFT)
	await process_frame
	await process_frame
	var player_snapshot := Dictionary(animation.get_frame_animation_snapshot())
	if sprite.scale.x <= 0.0 \
			or int(player_snapshot.get("horizontal_facing", 0)) != 1 \
			or int(player_snapshot.get("authored_horizontal_facing", 0)) != 1 \
			or not bool(player_snapshot.get("horizontal_facing_locked", false)):
		_fail("player faction did not stay locked facing right")
		return

	animation.play_sprite_attack(Vector2.LEFT)
	await process_frame
	await process_frame
	if sprite.scale.x <= 0.0:
		_fail("player attack direction overrode the faction facing")
		return

	animation.reset()
	animation.play_sprite_idle(
		sprite,
		source_texture,
		Vector2(100.0, 190.0),
		SOURCE_PATH,
		true,
		false,
		-1.0,
		true,
		1.0
	)
	animation.play_sprite_attack(Vector2.RIGHT)
	await process_frame
	await process_frame
	var enemy_snapshot := Dictionary(animation.get_frame_animation_snapshot())
	if sprite.scale.x >= 0.0 \
			or int(enemy_snapshot.get("horizontal_facing", 0)) != -1 \
			or int(enemy_snapshot.get("authored_horizontal_facing", 0)) != 1 \
			or not bool(enemy_snapshot.get("horizontal_facing_locked", false)):
		_fail("enemy faction did not stay locked facing left")
		return

	animation.reset()
	if sprite.scale.x <= 0.0:
		_fail("reset did not restore the authored sprite orientation")
		return

	view.queue_free()
	await process_frame
	if not await _verify_prefab_faction("player", true, "pal_001", "player_right_source", 1):
		return
	if not await _verify_prefab_faction("enemy", false, "pal_001", "enemy_r01_001", 1):
		return
	if not await _verify_prefab_faction("enemy", false, "pal_042", "enemy_r01_002", -1):
		return
	if not await _verify_prefab_faction("player", true, "pal_057", "player_left_source", -1):
		return
	if not await _verify_prefab_faction("enemy", false, "pal_006", "enemy_r02_003", -1):
		return
	for current_player_case in [
		["pal_002", "player_gold_mascot", -1],
		["pal_011", "player_gold_shell", -1],
		["pal_028", "player_azure_thunder_owl", 1],
		["pal_030", "player_crystal_shell", -1],
	]:
		if not await _verify_prefab_faction(
			"player",
			true,
			String(current_player_case[0]),
			String(current_player_case[1]),
			int(current_player_case[2])
		):
			return
	print("SMOKE_PET_DIRECTIONAL_FACING_PASS")
	quit(0)


func _verify_prefab_faction(
	side: String,
	expects_right: bool,
	pet_id: String,
	unit_id: String,
	authored_facing: int,
	expects_static: bool = false
) -> bool:
	var pet := PetScene.instantiate() as Control
	pet.size = Vector2(150.0, 132.0)
	root.add_child(pet)
	await process_frame
	var assets := BattleAssetRegistryScript.new()
	pet.call("set_unit_data", {
		"unitId": unit_id,
		"pet_id": pet_id,
		"name": "Directional Facing Test",
		"hp": 10,
		"atk": 2,
	}, side, assets)
	await process_frame
	await process_frame
	var sprite := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
	var animation := pet.get_node("CompleteBattleCreaturePrefab/03_AttackActions")
	var marker := pet.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/EnemyMarker_Optional") as Control
	animation.call("play_sprite_attack", Vector2.LEFT if expects_right else Vector2.RIGHT)
	await process_frame
	await process_frame
	var snapshot := Dictionary(animation.call("get_frame_animation_snapshot"))
	if expects_static and not Dictionary(snapshot.get("actions", {})).is_empty():
		pet.queue_free()
		_fail("%s prefab unexpectedly loaded an unapproved frame animation" % side)
		return false
	var expected_mirror := 1 if (1 if expects_right else -1) == authored_facing else -1
	var correct_sign := sprite.scale.x > 0.0 if expected_mirror > 0 else sprite.scale.x < 0.0
	if not correct_sign \
			or int(snapshot.get("horizontal_facing", 0)) != (1 if expects_right else -1) \
			or int(snapshot.get("authored_horizontal_facing", 0)) != authored_facing \
			or not bool(snapshot.get("horizontal_facing_locked", false)):
		pet.queue_free()
		_fail("%s prefab did not keep its faction-facing lock" % side)
		return false
	if marker.visible:
		pet.queue_free()
		_fail("legacy enemy marker is still visible for %s" % side)
		return false
	pet.queue_free()
	await process_frame
	return true


func _verify_facing_manifest_coverage() -> bool:
	var facing_manifest := _read_json_dictionary(FACING_MANIFEST_PATH)
	var facing_by_path := Dictionary(facing_manifest.get("by_texture_path", {}))
	var referenced_paths: Dictionary = {}
	var pet_image_map := _read_json_dictionary(PET_IMAGE_MAP_PATH)
	for section_name in ["by_pet_id", "by_name"]:
		for path_value in Dictionary(pet_image_map.get(section_name, {})).values():
			referenced_paths[String(path_value)] = true
	for path_value in _read_json_dictionary(ENEMY_IMAGE_MAP_PATH).values():
		referenced_paths[String(path_value)] = true
	var battle_assets := _read_json_dictionary(BATTLE_ASSET_MANIFEST_PATH)
	for section_name in ["leaders", "fallback_units"]:
		for path_value in Dictionary(battle_assets.get(section_name, {})).values():
			referenced_paths[String(path_value)] = true
	for path_value in referenced_paths.keys():
		var path := String(path_value)
		var metrics := Dictionary(facing_by_path.get(path, {}))
		var authored_facing := String(metrics.get("authored_horizontal_facing", ""))
		if authored_facing not in ["left", "right", "neutral"]:
			_fail("missing authored facing metadata for referenced sprite: %s" % path)
			return false
	return true


func _read_json_dictionary(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return Dictionary(parsed) if parsed is Dictionary else {}


func _fail(message: String) -> void:
	push_error("SMOKE_PET_DIRECTIONAL_FACING_FAIL: %s" % message)
	quit(1)
