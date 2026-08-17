extends SceneTree

const AssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const PetAssetResolverScript := preload("res://core_ui/scripts/shared/pet/pet_asset_resolver.gd")
const ArtistAssetRegistryScript := preload("res://core_ui/scripts/artist_flow/controllers/artist_flow_asset_registry.gd")
const GameDataRepositoryScript := preload("res://persistence/game_data_repository.gd")
const CONTENT_ROOT := "res://data/content"

var failures := 0


func _initialize() -> void:
	var registry = AssetRegistryScript.new()
	_test_manifest_and_diagnostics(registry)
	_test_shared_pet_resolution(registry)
	_test_invalid_map_diagnostics()
	_test_visual_aliases(registry)
	_test_missing_mapping_identity(registry)
	if failures > 0:
		push_error("SMOKE_ASSET_REGISTRY_FAILED count=%d" % failures)
		quit(1)
		return
	var report := Dictionary(registry.validate_registry())
	var stats := Dictionary(report.get("stats", {}))
	print(
		"SMOKE_ASSET_REGISTRY_OK runtime=%d mapped_pets=%d catalog_pets=%d missing_pets=%d enemy_keys=%d" % [
			int(stats.get("runtime_asset_paths", 0)),
			int(stats.get("mapped_player_pet_ids", 0)),
			int(stats.get("catalog_player_pet_ids", 0)),
			int(stats.get("missing_player_pet_ids", 0)),
			int(stats.get("mapped_enemy_keys", 0)),
		]
	)
	quit(0)


func _test_manifest_and_diagnostics(registry) -> void:
	_expect(registry.manifest_has_required_assets(), "manifest v2 and all runtime assets are valid")
	var report := Dictionary(registry.validate_registry())
	_expect(bool(report.get("ok", false)), "registry diagnostics contain no errors")
	_expect(Array(report.get("errors", [])).is_empty(), "registry diagnostics expose an empty error list")
	var stats := Dictionary(report.get("stats", {}))
	var catalog_ids := _catalog_pet_ids()
	var expected_missing := _missing_catalog_ids(registry, catalog_ids)
	_expect(int(stats.get("mapped_player_pet_ids", 0)) == registry.pet_image_by_id.size(), "mapped coverage matches the art-source registry")
	_expect(int(stats.get("catalog_player_pet_ids", 0)) == catalog_ids.size(), "coverage reads every current catalog pet")
	_expect(int(stats.get("missing_player_pet_ids", 0)) == expected_missing.size(), "coverage derives pending art mappings from current content")
	var missing_ids := Array(report.get("missing_player_pet_ids", []))
	_expect(missing_ids == expected_missing, "coverage reports the exact current missing pet IDs")
	_expect(_has_issue_code(Array(report.get("warnings", [])), "player_pet_coverage_incomplete"), "incomplete art coverage is an explicit warning")


func _test_shared_pet_resolution(registry) -> void:
	var resolver = PetAssetResolverScript.new()
	resolver.configure("res://art/images/shared/pets/sheets/slices", "res://art/images/shared/pets/sheets/slices")
	_expect(resolver.load_map("res://art/manifests/shared/pets/sheets/pet_id_map.json"), "shared resolver loads the confirmed pet map")
	var expected := "res://art/images/shared/pets/generated/pal_001.png"
	var explicit_legacy_path := "res://art/images/shared/pets/sheets/slices/pal_001.png"
	_expect(String(resolver.path_for({"pet_id": "pal_001"})) == expected, "shared resolver resolves canonical pet_id")
	_expect(String(resolver.path_for({"source_pet_id": "pal_001"})) == expected, "shared resolver resolves source_pet_id")
	_expect(String(resolver.path_for({"image": "pal_001.png"})) == explicit_legacy_path, "shared resolver preserves explicit image compatibility inside the legacy slice directory")
	var texture := resolver.texture_for({"pet_id": "pal_001"}) as Texture2D
	_expect(texture != null and texture.resource_path == expected, "shared resolver loads the declared texture")
	var battle_texture := Dictionary(registry.texture_for_unit({"pet_id": "pal_001"}, "player"))
	_expect((battle_texture.get("texture") as Texture2D).resource_path == expected, "battle registry uses the shared resolver")
	var artist_registry = ArtistAssetRegistryScript.new()
	artist_registry.reload()
	var artist_texture := artist_registry.pet_texture({"pet_id": "pal_001"}) as Texture2D
	_expect(artist_texture != null and artist_texture.resource_path == expected, "artist UI uses the same shared resolver")


func _test_invalid_map_diagnostics() -> void:
	var invalid_json_path := "user://smoke_asset_registry_invalid.json"
	var invalid_file := FileAccess.open(invalid_json_path, FileAccess.WRITE)
	invalid_file.store_string("{ invalid")
	invalid_file.close()
	var resolver = PetAssetResolverScript.new()
	resolver.configure("res://art/images/shared/pets/sheets/slices")
	_expect(not resolver.load_map(invalid_json_path), "invalid JSON is rejected")
	_expect(_has_issue_code(Array(resolver.issues), "pet_map_invalid_json"), "invalid JSON exposes a parse diagnostic")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_json_path))

	var missing_path_map := "user://smoke_asset_registry_missing_path.json"
	var missing_file := FileAccess.open(missing_path_map, FileAccess.WRITE)
	missing_file.store_string('{"pal_001":"res://art/images/does_not_exist.png"}')
	missing_file.close()
	_expect(not resolver.load_map(missing_path_map), "map entries with missing resources are rejected")
	_expect(_has_issue_code(Array(resolver.issues), "pet_texture_missing"), "missing texture exposes its own diagnostic")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(missing_path_map))


func _test_visual_aliases(registry) -> void:
	var expected := {
		"无": "wind",
		"火": "fire",
		"水": "water",
		"草": "wind",
		"雷": "wind",
		"冰": "water",
		"地": "earth",
		"暗": "earth",
		"龙": "fire",
	}
	for element in expected.keys():
		_expect(String(registry._visual_fallback_element(element)) == String(expected[element]), "%s visual alias is data-driven" % element)


func _test_missing_mapping_identity(registry) -> void:
	var missing_id := String(_missing_catalog_ids(registry, _catalog_pet_ids()).front())
	var result := Dictionary(registry.texture_for_unit({
		"pet_id": missing_id,
		"unitId": "player_pet_runtime_7",
		"name": "未交付宠物",
	}, "player"))
	var missing := Dictionary(result.get("missing", {}))
	_expect(result.get("texture") != null, "missing pet art retains a non-destructive fallback")
	_expect(String(missing.get("id", "")) == missing_id, "missing record uses canonical asset identity")
	_expect(String(missing.get("instance_id", "")) == "player_pet_runtime_7", "missing record preserves runtime instance context")
	_expect(String(missing.get("key", "")) == "player_pet_image:%s" % missing_id, "missing records deduplicate by asset identity")


func _catalog_pet_ids() -> Array[String]:
	var data := Dictionary(GameDataRepositoryScript.new().read_content_pack(CONTENT_ROOT))
	var result: Array[String] = []
	for value in Array(Dictionary(data.get("economy", {})).get("shop_items", [])):
		var item := Dictionary(value)
		var pet_id := String(item.get("pet_id", item.get("id", "")))
		if pet_id.begins_with("pal_") and not result.has(pet_id):
			result.append(pet_id)
	result.sort()
	return result


func _missing_catalog_ids(registry, catalog_ids: Array[String]) -> Array:
	var result := []
	for pet_id in catalog_ids:
		if not registry.pet_image_by_id.has(pet_id):
			result.append(pet_id)
	return result


func _has_issue_code(issues: Array, code: String) -> bool:
	for issue in issues:
		if String(Dictionary(issue).get("code", "")) == code:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
