extends SceneTree

const ArtistFlowAssetRegistryScript := preload("res://core_ui/scripts/artist_flow/controllers/artist_flow_asset_registry.gd")
const GENERATION_MANIFEST_PATH := "res://art/manifests/route/shop/characters/shop_character_generation_manifest.json"
const CHARACTER_MAP_PATH := "res://art/manifests/route/shop/characters/shop_character_map.json"

var failures := 0


func _initialize() -> void:
	var manifest := _read_json_dictionary(GENERATION_MANIFEST_PATH)
	var character_map := _read_json_dictionary(CHARACTER_MAP_PATH)
	var targets := Array(manifest.get("targets", []))
	var style_contract := Dictionary(manifest.get("style_contract", {}))
	var character_ids := {}
	var node_ids := {}
	var output_paths := {}
	var approved_hashes := {}
	var generated_count := 0
	var approved_count := 0
	var registry := ArtistFlowAssetRegistryScript.new()
	registry.reload()

	_expect(String(manifest.get("schema", "")) == "ysbzs.shop-character-generation-manifest.v1", "shop character manifest uses the formal schema")
	_expect(String(style_contract.get("id", "")) == "ysbzs-route-chibi-pixel-v1", "shop characters declare the canonical route pixel style")
	_expect(not Array(style_contract.get("required", [])).is_empty(), "shop character style contract declares required traits")
	_expect(not Array(style_contract.get("forbidden", [])).is_empty(), "shop character style contract declares forbidden traits")
	_expect(targets.size() == 33, "shop character manifest covers all 33 formal shop nodes")

	for value in targets:
		var target := Dictionary(value)
		var character_id := String(target.get("character_id", ""))
		var node_id := String(target.get("node_id", ""))
		var shop_name := String(target.get("name", ""))
		var output_path := String(target.get("output_path", ""))
		_expect(character_id.begins_with("shop_character_"), "target has a canonical character_id: %s" % character_id)
		_expect(node_id != "", "target has a formal shop node_id: %s" % character_id)
		_expect(shop_name != "", "target has a player-readable shop name: %s" % character_id)
		_expect(not character_ids.has(character_id), "character_id is unique: %s" % character_id)
		_expect(not node_ids.has(node_id), "shop node_id is unique: %s" % node_id)
		_expect(not output_paths.has(output_path), "generated output path is unique: %s" % output_path)
		character_ids[character_id] = true
		node_ids[node_id] = true
		output_paths[output_path] = true
		_expect(output_path.begins_with("res://art/images/route/shop/characters/generated/"), "target uses the reusable generated directory: %s" % character_id)

		var file_state := String(Dictionary(target.get("file", {})).get("state", "missing"))
		if file_state != "missing":
			generated_count += 1
		if String(target.get("review_status", "pending")) != "approved":
			continue
		approved_count += 1
		_expect(file_state == "generated", "approved shop character is generated: %s" % character_id)
		_expect(FileAccess.file_exists(output_path), "approved shop character image exists: %s" % character_id)
		_expect(String(character_map.get(character_id, "")) == output_path, "character_id maps to approved image: %s" % character_id)
		_expect(String(character_map.get(node_id, "")) == output_path, "node_id maps to approved image: %s" % node_id)
		_expect(String(character_map.get(shop_name, "")) == output_path, "shop name maps to approved image: %s" % shop_name)
		var node_texture := registry.call("_shop_character_texture", {"nodeId": node_id}) as Texture2D
		var name_texture := registry.call("_shop_character_texture", {"name": shop_name}) as Texture2D
		_expect(node_texture != null and node_texture.resource_path == output_path, "runtime registry resolves node_id to approved image: %s" % node_id)
		_expect(name_texture != null and name_texture.resource_path == output_path, "runtime registry resolves shop name to approved image: %s" % shop_name)
		var texture := load(output_path) as Texture2D
		_expect(texture != null, "approved shop character imports as Texture2D: %s" % character_id)
		if texture == null:
			continue
		var image := texture.get_image()
		_expect(image != null and image.get_width() >= 256 and image.get_height() >= 256, "approved shop character has reusable source resolution: %s" % character_id)
		if image == null:
			continue
		_expect(image.detect_alpha() != Image.ALPHA_NONE, "approved shop character has alpha: %s" % character_id)
		_expect(image.get_pixel(0, 0).a <= 0.01, "approved shop character has a transparent outer corner: %s" % character_id)
		var used_rect := image.get_used_rect()
		_expect(used_rect.size.x > 0 and used_rect.size.y > 0, "approved shop character has a visible subject: %s" % character_id)
		_expect(used_rect.position.x > 0 and used_rect.position.y > 0, "approved shop character does not touch the top or left canvas edge: %s" % character_id)
		_expect(used_rect.end.x < image.get_width() and used_rect.end.y < image.get_height(), "approved shop character does not touch the bottom or right canvas edge: %s" % character_id)
		var digest := FileAccess.get_sha256(output_path)
		_expect(digest != "", "approved shop character has a content digest: %s" % character_id)
		_expect(not approved_hashes.has(digest), "approved shop character content is unique: %s" % character_id)
		approved_hashes[digest] = character_id

	_expect(int(manifest.get("target_count", -1)) == targets.size(), "manifest target_count matches targets")
	_expect(int(manifest.get("generated_count", -1)) == generated_count, "manifest generated_count matches files")
	_expect(int(manifest.get("approved_count", -1)) == approved_count, "manifest approved_count matches reviews")
	_expect(int(manifest.get("pending_count", -1)) == targets.size() - approved_count, "manifest pending_count matches reviews")

	if failures > 0:
		push_error("SMOKE_SHOP_CHARACTER_IMAGES_FAILED count=%d" % failures)
		quit(1)
		return
	print(
		"SMOKE_SHOP_CHARACTER_IMAGES_OK targets=%d generated=%d approved=%d pending=%d" % [
			targets.size(),
			generated_count,
			approved_count,
			targets.size() - approved_count,
		]
	)
	quit(0)


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
