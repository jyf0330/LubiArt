extends SceneTree

const MANIFEST_PATH := "res://art/manifests/shop/screen_shop_godot_v1_manifest.json"
const FORMAL_CHARACTER_MAP_PATH := "res://art/manifests/route/shop/characters/shop_character_map.json"
const EXPECTED_PNG_COUNT := 6
const EXPECTED_FORMAL_OFFER_CAPACITY := 10

var failures := 0


func _initialize() -> void:
	var manifest := _read_json_dictionary(MANIFEST_PATH)
	var source := Dictionary(manifest.get("source", {}))
	var boundary := Dictionary(manifest.get("runtime_boundary", {}))
	var files := Array(manifest.get("files", []))
	var ids := {}
	var paths := {}
	var png_count := 0
	var source_count := 0

	_expect(String(manifest.get("schema", "")) == "ysbzs.shop-screen-art-handoff.v1", "shop screen handoff uses the formal schema")
	_expect(String(source.get("archive_sha256", "")) == "16aa3dbdf394ba46b763ff1b9befa73d14ae1f6a843e56ea069522a79ed6cffc", "manifest records the audited source archive")
	_expect(String(source.get("source_head", "")) == "6f12b0c363315b398f2d9702dc62221f2b560dd5", "manifest records the Mock source head")
	_expect(not bool(boundary.get("fixed_mock_offer_count_imported", true)), "fixed five-slot Mock behavior is not imported")
	_expect(not bool(boundary.get("mock_merchant_map_imported", true)), "empty Mock merchant mapping is not imported")
	_expect(int(boundary.get("formal_offer_capacity_preserved", -1)) == EXPECTED_FORMAL_OFFER_CAPACITY, "formal ten-offer capacity remains explicit")
	_expect(String(boundary.get("formal_merchant_mapping", "")) == FORMAL_CHARACTER_MAP_PATH, "formal merchant identity remains on the 33-character map")
	_expect(FileAccess.file_exists(FORMAL_CHARACTER_MAP_PATH), "formal merchant map remains available")

	for value in files:
		var entry := Dictionary(value)
		var asset_id := String(entry.get("id", ""))
		var path := String(entry.get("path", ""))
		_expect(asset_id != "", "every handoff file has a stable id")
		_expect(path != "" and _is_ascii(path), "every handoff file uses an ASCII project path: %s" % path)
		_expect(not ids.has(asset_id), "handoff file ids are unique: %s" % asset_id)
		_expect(not paths.has(path), "handoff file paths are unique: %s" % path)
		ids[asset_id] = true
		paths[path] = true
		_expect(FileAccess.file_exists(path), "handoff file exists: %s" % path)
		_expect(FileAccess.get_sha256(path) == String(entry.get("sha256", "")), "handoff file keeps the audited content hash: %s" % path)
		if path.ends_with(".psd"):
			source_count += 1
			_expect(String(entry.get("importer", "")) == "external_source_only", "editable PSD stays outside the runtime import boundary")
			_expect(not FileAccess.file_exists(path + ".import"), "editable PSD does not keep a sidecar for the absent Mock-only importer")
			continue
		png_count += 1
		_expect(path.ends_with(".png"), "runtime handoff assets are PNG files: %s" % path)
		_expect(FileAccess.file_exists(path + ".import"), "PNG keeps deterministic import settings: %s" % path)
		var texture := load(path) as Texture2D
		_expect(texture != null, "PNG imports as Texture2D: %s" % path)
		if texture == null:
			continue
		var image := texture.get_image()
		_expect(image != null, "imported texture exposes image data: %s" % path)
		if image == null:
			continue
		var expected_size := Array(entry.get("size", []))
		_expect(expected_size.size() == 2, "PNG manifest records width and height: %s" % path)
		if expected_size.size() == 2:
			_expect(image.get_width() == int(expected_size[0]) and image.get_height() == int(expected_size[1]), "PNG dimensions match the delivery manifest: %s" % path)
		var alpha_policy := String(entry.get("alpha_policy", ""))
		if alpha_policy == "transparent_required":
			_expect(image.detect_alpha() != Image.ALPHA_NONE, "layer asset has real transparency: %s" % path)
		elif alpha_policy == "opaque_rgba":
			_expect(image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH], "opaque background retains an RGBA canvas: %s" % path)
		else:
			_expect(false, "PNG declares a supported alpha policy: %s" % path)

	_expect(png_count == EXPECTED_PNG_COUNT, "handoff contains exactly six audited runtime PNGs")
	_expect(source_count == 1, "handoff contains exactly one editable source PSD")
	_expect(files.size() == EXPECTED_PNG_COUNT + source_count, "manifest has no missing or ghost outputs")

	if failures > 0:
		push_error("SMOKE_SHOP_SCREEN_ART_HANDOFF_FAILED count=%d" % failures)
		quit(1)
		return
	print("SMOKE_SHOP_SCREEN_ART_HANDOFF_OK png=%d psd=%d formal_offer_capacity=%d" % [png_count, source_count, EXPECTED_FORMAL_OFFER_CAPACITY])
	quit(0)


func _read_json_dictionary(path: String) -> Dictionary:
	_expect(FileAccess.file_exists(path), "required JSON exists: %s" % path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "required JSON parses as a dictionary: %s" % path)
	return Dictionary(parsed) if typeof(parsed) == TYPE_DICTIONARY else {}


func _is_ascii(value: String) -> bool:
	for index in range(value.length()):
		if value.unicode_at(index) > 127:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
