extends SceneTree

const GameDataRepositoryScript := preload("res://persistence/game_data_repository.gd")
const CONTENT_ROOT := "res://data/content"
const GENERATION_MANIFEST_PATH := "res://art/manifests/shared/pets/pet_image_generation_manifest.json"
const PET_MAP_PATH := "res://art/manifests/shared/pets/sheets/pet_id_map.json"

var failures := 0


func _initialize() -> void:
	var manifest := _read_json_dictionary(GENERATION_MANIFEST_PATH)
	var pet_map := Dictionary(_read_json_dictionary(PET_MAP_PATH).get("by_pet_id", {}))
	var targets := Array(manifest.get("targets", []))
	var catalog_ids := _catalog_pet_ids()
	var target_ids: Array[String] = []
	var output_paths := {}
	var approved_hashes := {}
	var style_contract := Dictionary(manifest.get("style_contract", {}))
	var style_audit := Dictionary(manifest.get("style_audit", {}))
	var needs_style_regeneration := Array(style_audit.get("needs_regeneration_ids", []))
	var generated_count := 0
	var approved_count := 0

	_expect(String(manifest.get("schema", "")) == "ysbzs.pet-image-generation-manifest.v2", "generation manifest uses the style-gated v2 schema")
	_expect(String(style_contract.get("id", "")) == "ysbzs-chibi-pixel-v1", "manifest declares the canonical chibi-pixel style contract")
	_expect(String(style_audit.get("contract_version", "")) == String(style_contract.get("id", "")), "style audit uses the canonical style contract")
	_expect(not Array(style_contract.get("required", [])).is_empty(), "style contract declares required visual traits")
	_expect(not Array(style_contract.get("forbidden", [])).is_empty(), "style contract declares forbidden visual traits")

	for value in targets:
		var target := Dictionary(value)
		var pet_id := String(target.get("pet_id", ""))
		var output_path := String(target.get("output_path", ""))
		_expect(pet_id.begins_with("pal_"), "generation target has a canonical pet_id")
		_expect(not target_ids.has(pet_id), "generation target pet_id is unique: %s" % pet_id)
		target_ids.append(pet_id)
		_expect(output_path.begins_with("res://art/images/shared/pets/generated/"), "target uses the formal generated directory: %s" % pet_id)
		_expect(not output_paths.has(output_path), "generation output path is unique: %s" % output_path)
		output_paths[output_path] = pet_id

		var file_state := String(Dictionary(target.get("file", {})).get("state", "missing"))
		if file_state != "missing":
			generated_count += 1
		if needs_style_regeneration.has(pet_id):
			_expect(not pet_map.has(pet_id), "style-rejected draft is not exposed through the runtime map: %s" % pet_id)
			continue
		if String(target.get("review_status", "pending")) != "approved":
			continue
		approved_count += 1
		_expect(FileAccess.file_exists(output_path), "approved pet image exists: %s" % pet_id)
		_expect(String(pet_map.get(pet_id, "")) == output_path, "approved pet image is the canonical runtime mapping: %s" % pet_id)
		var texture := load(output_path) as Texture2D
		_expect(texture != null, "approved pet image imports as Texture2D: %s" % pet_id)
		if texture == null:
			continue
		var image := texture.get_image()
		_expect(image != null and image.get_width() >= 256 and image.get_height() >= 256, "approved pet image has reusable source resolution: %s" % pet_id)
		if image == null:
			continue
		_expect(image.detect_alpha() != Image.ALPHA_NONE, "approved pet image has alpha: %s" % pet_id)
		_expect(image.get_pixel(0, 0).a <= 0.01, "approved pet image has a transparent outer corner: %s" % pet_id)
		var digest := FileAccess.get_sha256(output_path)
		_expect(digest != "", "approved pet image has a content digest: %s" % pet_id)
		_expect(not approved_hashes.has(digest), "approved pet image content is unique: %s" % pet_id)
		approved_hashes[digest] = pet_id

	target_ids.sort()
	for value in needs_style_regeneration:
		_expect(target_ids.has(String(value)), "style-regeneration ID belongs to the planner catalog: %s" % String(value))
	_expect(target_ids == catalog_ids, "generation targets match every current planner-exported catalog pet")
	_expect(int(manifest.get("target_count", -1)) == targets.size(), "manifest target_count matches targets")
	_expect(int(manifest.get("generated_count", -1)) == generated_count, "manifest generated_count matches files")
	_expect(int(manifest.get("approved_count", -1)) == approved_count, "manifest approved_count matches reviews")
	_expect(int(manifest.get("pending_count", -1)) == targets.size() - approved_count, "manifest pending_count matches reviews")

	if failures > 0:
		push_error("SMOKE_ALL_PLANNER_PET_IMAGES_FAILED count=%d" % failures)
		quit(1)
		return
	print(
		"SMOKE_ALL_PLANNER_PET_IMAGES_OK targets=%d generated=%d approved=%d pending=%d" % [
			targets.size(),
			generated_count,
			approved_count,
			targets.size() - approved_count,
		]
	)
	quit(0)


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


func _read_json_dictionary(path: String) -> Dictionary:
	_expect(FileAccess.file_exists(path), "required JSON exists: %s" % path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "required JSON parses as a dictionary: %s" % path)
	return Dictionary(parsed) if typeof(parsed) == TYPE_DICTIONARY else {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
