extends RefCounted

const MANIFEST_PATH := "res://art/manifests/battle/battle_asset_manifest.json"
const SUPPORTED_MANIFEST_VERSION := 2
const DEFAULT_RUNTIME_SECTIONS := ["background", "buttons", "frames", "leaders", "fallback_units", "effects"]
const PetAssetResolverScript := preload("res://core_ui/scripts/shared/pet/pet_asset_resolver.gd")

var manifest: Dictionary = {}
var pet_image_by_id: Dictionary = {}
var pet_image_by_name: Dictionary = {}
var enemy_image_by_key: Dictionary = {}
var _texture_cache: Dictionary = {}
var _load_issues: Array[Dictionary] = []
var _pet_resolver: RefCounted = null


func _init() -> void:
	_pet_resolver = PetAssetResolverScript.new()
	_load_manifest()
	_load_pet_image_map()
	_load_enemy_image_map()


func frame_texture(side: String) -> Texture2D:
	var frames := Dictionary(manifest.get("frames", {}))
	var key := "player" if _is_player_side(side) else "enemy"
	return _load_texture_if_exists(String(frames.get(key, "")))


func hover_frame_texture() -> Texture2D:
	var frames := Dictionary(manifest.get("frames", {}))
	return _load_texture_if_exists(String(frames.get("hover", "")))


func texture_for_unit(data: Dictionary, side: String) -> Dictionary:
	if _is_player_side(side):
		if side == "hero_leader":
			return {"texture": _leader_texture("player"), "missing": {}}
		var pet_texture := _pet_texture(data)
		if pet_texture != null:
			return {"texture": pet_texture, "missing": {}}
		return {
			"texture": fallback_texture("fire"),
			"missing": _missing_record("player_pet_image", data)
		}

	if side == "boss":
		return {"texture": _leader_texture("enemy"), "missing": {}}

	var enemy_texture := _enemy_texture(data)
	if enemy_texture != null:
		return {"texture": enemy_texture, "missing": {}}

	var unit_name := String(data.get("name", "")).to_lower()
	if unit_name.contains("boss") or unit_name.contains("王") or unit_name.contains("首领"):
		return {"texture": fallback_texture("boss"), "missing": {}}

	var elements := Dictionary(data.get("elements", {}))
	for element in ["neutral", "fire", "water", "grass", "electric", "ice", "ground", "dark", "dragon"]:
		if int(elements.get(element, 0)) > 0:
			var missing := _missing_record("enemy_image_mapping", data)
			return {"texture": fallback_texture(element), "missing": missing}
	var affinity := String(data.get("element", data.get("main_element", "")))
	if affinity != "":
		return {
			"texture": fallback_texture(affinity),
			"missing": _missing_record("enemy_image_mapping", data)
		}

	return {
		"texture": fallback_texture("water"),
		"missing": _missing_record("enemy_image_mapping", data)
	}


func fallback_texture(element: String) -> Texture2D:
	var fallback_units := Dictionary(manifest.get("fallback_units", {}))
	return _load_texture_if_exists(String(fallback_units.get(_visual_fallback_element(element), "")))


func projectile_texture(element: String) -> Texture2D:
	var effects := Dictionary(manifest.get("effects", {}))
	var bullets := Dictionary(effects.get("bullets", {}))
	var fallback := _visual_fallback_element(element)
	return _load_texture_if_exists(String(bullets.get(fallback, bullets.get("fire", ""))))


func buff_ring_texture(element: String) -> Texture2D:
	var effects := Dictionary(manifest.get("effects", {}))
	var rings := Dictionary(effects.get("buff_rings", {}))
	return _load_texture_if_exists(String(rings.get(_visual_fallback_element(element), "")))


func _visual_fallback_element(element: String) -> String:
	var normalized := element.strip_edges().to_lower()
	var aliases := Dictionary(manifest.get("element_visual_aliases", {}))
	return String(aliases.get(normalized, aliases.get(element.strip_edges(), "fire")))


func death_mark_texture(side: String) -> Texture2D:
	var effects := Dictionary(manifest.get("effects", {}))
	var death_marks := Dictionary(effects.get("death_marks", {}))
	var key := "player" if _is_player_side(side) else "enemy"
	return _load_texture_if_exists(String(death_marks.get(key, "")))


func attack_order_marker_texture(dot_count: int) -> Texture2D:
	var effects := Dictionary(manifest.get("effects", {}))
	var markers := Dictionary(effects.get("attack_order", {}))
	var key := "one"
	if dot_count == 2:
		key = "two"
	elif dot_count >= 3:
		key = "three"
	return _load_texture_if_exists(String(markers.get(key, "")))


func round_banner_texture() -> Texture2D:
	var images := Dictionary(manifest.get("background", {}))
	var path := String(images.get("round_banner", ""))
	if path == "":
		path = "res://art/images/battle/runtime/images/round_banner_blank.png"
	return _load_texture_if_exists(path)


func monster_bite_frames() -> Array:
	var effects := Dictionary(manifest.get("effects", {}))
	var bite := Dictionary(effects.get("monster_bite", {}))
	var frames: Array = []
	for value in Array(bite.get("frames", [])):
		var texture := _load_texture_if_exists(String(value))
		if texture != null:
			frames.append(texture)
	return frames


func monster_bite_frame_durations() -> Array:
	var effects := Dictionary(manifest.get("effects", {}))
	var bite := Dictionary(effects.get("monster_bite", {}))
	return Array(bite.get("frame_durations", [0.083, 0.067, 0.033, 0.1, 0.067])).duplicate(true)


func all_declared_runtime_assets_exist() -> bool:
	for path in _declared_runtime_asset_paths():
		if path.begins_with("res://") and not _manifest_path_exists(path):
			return false
	return true


func manifest_has_required_assets() -> bool:
	return int(manifest.get("version", 0)) == SUPPORTED_MANIFEST_VERSION \
		and _path_exists("background", "battle") \
		and _path_exists("buttons", "auto_arrange") \
		and _path_exists("buttons", "begin_turn") \
		and _path_exists("frames", "player") \
		and _path_exists("frames", "enemy") \
		and _path_exists("frames", "hover") \
		and all_declared_runtime_assets_exist() \
		and not _has_error_issues(validate_registry())


func validate_registry() -> Dictionary:
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	for issue in _load_issues:
		_append_issue_by_severity(issue, errors, warnings)
	if int(manifest.get("version", 0)) != SUPPORTED_MANIFEST_VERSION:
		errors.append(_issue("error", "unsupported_manifest_version", str(manifest.get("version", 0)), "资源清单版本不受支持"))
	for required in [
		["background", "battle"],
		["buttons", "auto_arrange"],
		["buttons", "begin_turn"],
		["frames", "player"],
		["frames", "enemy"],
		["frames", "hover"],
	]:
		var section := String(required[0])
		var key := String(required[1])
		if not _path_exists(section, key):
			errors.append(_issue("error", "required_asset_missing", "%s.%s" % [section, key], "必需运行资源缺失"))
	for path in _declared_runtime_asset_paths():
		if not _manifest_path_exists(path):
			errors.append(_issue("error", "runtime_asset_missing", path, "运行资源不存在", path))
	if _pet_resolver != null:
		for issue in Array(_pet_resolver.get("issues")):
			_append_issue_by_severity(Dictionary(issue), errors, warnings)
	for key in enemy_image_by_key.keys():
		var path := String(enemy_image_by_key[key])
		if not ResourceLoader.exists(path):
			errors.append(_issue("error", "enemy_texture_missing", String(key), "敌方图片不存在", path))
	var coverage_settings := Dictionary(manifest.get("coverage", {}))
	var catalog_path := String(coverage_settings.get("player_pet_catalog", ""))
	if catalog_path == "" or not FileAccess.file_exists(catalog_path):
		errors.append(_issue("error", "player_pet_catalog_missing", catalog_path, "宠物目录文件不存在", catalog_path))
	var coverage := _catalog_coverage()
	var missing_pet_ids := Array(coverage.get("missing_player_pet_ids", []))
	if not missing_pet_ids.is_empty():
		warnings.append(_issue(
			"warning",
			"player_pet_coverage_incomplete",
			str(missing_pet_ids.size()),
			"宠物图片映射缺少 %d 个目录 ID：%s" % [missing_pet_ids.size(), ", ".join(missing_pet_ids)]
		))
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"stats": {
			"runtime_asset_paths": _declared_runtime_asset_paths().size(),
			"mapped_player_pet_ids": pet_image_by_id.size(),
			"mapped_player_pet_names": pet_image_by_name.size(),
			"mapped_enemy_keys": enemy_image_by_key.size(),
			"catalog_player_pet_ids": int(coverage.get("catalog_player_pet_ids", 0)),
			"missing_player_pet_ids": missing_pet_ids.size(),
		},
		"missing_player_pet_ids": missing_pet_ids,
	}


func _load_manifest() -> void:
	manifest = {}
	_load_issues = []
	if not FileAccess.file_exists(MANIFEST_PATH):
		_load_issues.append(_issue("error", "manifest_missing", MANIFEST_PATH, "战斗资源清单不存在", MANIFEST_PATH))
		return
	manifest = _load_json_dictionary(MANIFEST_PATH, "manifest")


func _load_pet_image_map() -> void:
	pet_image_by_id = {}
	pet_image_by_name = {}
	var external_maps := Dictionary(manifest.get("external_maps", {}))
	var path := String(external_maps.get("player_pet_images", ""))
	if _pet_resolver == null:
		return
	var pet_settings := Dictionary(manifest.get("pet_assets", {}))
	_pet_resolver.call("configure", String(pet_settings.get("slice_dir", "")), String(pet_settings.get("explicit_image_dir", "")))
	_pet_resolver.call("load_map", path)
	pet_image_by_id = Dictionary(_pet_resolver.get("image_by_id"))
	pet_image_by_name = Dictionary(_pet_resolver.get("image_by_name"))


func _load_enemy_image_map() -> void:
	enemy_image_by_key = {}
	var external_maps := Dictionary(manifest.get("external_maps", {}))
	var path := String(external_maps.get("enemy_unit_images", ""))
	if path == "":
		return
	enemy_image_by_key = _load_json_dictionary(path, "enemy_map")


func _leader_texture(key: String) -> Texture2D:
	var leaders := Dictionary(manifest.get("leaders", {}))
	return _load_texture_if_exists(String(leaders.get(key, "")))


func _pet_texture(record: Dictionary) -> Texture2D:
	if _pet_resolver == null:
		return null
	return _pet_resolver.call("texture_for", record) as Texture2D


func _enemy_texture(record: Dictionary) -> Texture2D:
	for key in _enemy_image_keys(record):
		if enemy_image_by_key.has(key):
			var texture := _load_texture_if_exists(String(enemy_image_by_key[key]))
			if texture != null:
				return texture
	return null


func _enemy_image_keys(record: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for field in ["enemyId", "enemy_id", "unitId", "unit_id", "id", "source_pet_id", "sourcePetId", "source_monster_template_id", "sourceMonsterTemplateId", "template_id", "templateId", "unitName", "name"]:
		var value := String(record.get(field, "")).strip_edges()
		if value == "":
			continue
		if not keys.has(value):
			keys.append(value)
		if value.ends_with(":monster_template"):
			var short_value := value.trim_suffix(":monster_template")
			if short_value != "" and not keys.has(short_value):
				keys.append(short_value)
		elif value.begins_with("pal_"):
			var template_value := "%s:monster_template" % value
			if not keys.has(template_value):
				keys.append(template_value)
	return keys


func _pet_id(record: Dictionary) -> String:
	if _pet_resolver == null:
		return ""
	return String(_pet_resolver.call("canonical_id", record))


func _load_texture_if_exists(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
	if texture != null:
		_texture_cache[path] = texture
	return texture


func _path_exists(section: String, key: String) -> bool:
	var group := Dictionary(manifest.get(section, {}))
	var path := String(group.get(key, ""))
	return path != "" and _manifest_path_exists(path)


func _manifest_path_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func _collect_manifest_paths(value) -> Array[String]:
	var paths: Array[String] = []
	if value is Dictionary:
		for nested in Dictionary(value).values():
			paths.append_array(_collect_manifest_paths(nested))
	elif value is Array:
		for nested in Array(value):
			paths.append_array(_collect_manifest_paths(nested))
	elif typeof(value) == TYPE_STRING:
		var path := String(value)
		if path.begins_with("res://"):
			paths.append(path)
	return paths


func _declared_runtime_asset_paths() -> Array[String]:
	var paths: Array[String] = []
	var sections := Array(manifest.get("runtime_sections", DEFAULT_RUNTIME_SECTIONS))
	for section in sections:
		paths.append_array(_collect_manifest_paths(manifest.get(String(section), {})))
	var unique: Array[String] = []
	for path in paths:
		if not unique.has(path):
			unique.append(path)
	return unique


func _catalog_coverage() -> Dictionary:
	var coverage_settings := Dictionary(manifest.get("coverage", {}))
	var catalog_path := String(coverage_settings.get("player_pet_catalog", ""))
	var catalog := _load_json_dictionary(catalog_path, "player_pet_catalog", false)
	var economy := Dictionary(catalog.get("economy", {}))
	var expected_ids: Array[String] = []
	for value in Array(economy.get("shop_items", [])):
		var row := Dictionary(value)
		var pet_id := String(row.get("pet_id", row.get("id", ""))).strip_edges()
		if pet_id.begins_with("pal_") and not expected_ids.has(pet_id):
			expected_ids.append(pet_id)
	expected_ids.sort()
	var missing_ids: Array[String] = []
	for pet_id in expected_ids:
		if not pet_image_by_id.has(pet_id):
			missing_ids.append(pet_id)
	return {
		"catalog_player_pet_ids": expected_ids.size(),
		"missing_player_pet_ids": missing_ids,
	}


func _load_json_dictionary(path: String, kind: String, record_issue: bool = true) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		if record_issue:
			_load_issues.append(_issue("error", "%s_missing" % kind, path, "JSON 文件不存在", path))
		return {}
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	if error != OK:
		if record_issue:
			_load_issues.append(_issue(
				"error",
				"%s_invalid_json" % kind,
				path,
				"JSON 解析失败：第 %d 行 %s" % [parser.get_error_line(), parser.get_error_message()],
				path
			))
		return {}
	if typeof(parser.data) != TYPE_DICTIONARY:
		if record_issue:
			_load_issues.append(_issue("error", "%s_invalid_root" % kind, path, "JSON 根节点必须是对象", path))
		return {}
	return Dictionary(parser.data)


func _append_issue_by_severity(issue: Dictionary, errors: Array[Dictionary], warnings: Array[Dictionary]) -> void:
	if String(issue.get("severity", "")) == "error":
		errors.append(issue)
	else:
		warnings.append(issue)


func _has_error_issues(report: Dictionary) -> bool:
	return not Array(report.get("errors", [])).is_empty()


func _issue(severity: String, code: String, key: String, message: String, path: String = "") -> Dictionary:
	return {
		"severity": severity,
		"code": code,
		"key": key,
		"message": message,
		"path": path,
	}


func _missing_record(kind: String, record: Dictionary) -> Dictionary:
	var asset_id := _pet_id(record) if kind == "player_pet_image" else _first_record_value(record, ["source_monster_template_id", "sourceMonsterTemplateId", "template_id", "templateId", "enemyId", "enemy_id", "id"])
	var instance_id := _first_record_value(record, ["unitId", "unit_id", "id"])
	if asset_id == "":
		asset_id = _first_record_value(record, ["pet_id", "petId", "source_pet_id", "sourcePetId", "name", "unitName"])
	return {
		"kind": kind,
		"key": "%s:%s" % [kind, asset_id],
		"id": asset_id,
		"instance_id": instance_id,
		"name": String(record.get("unitName", record.get("name", "")))
	}


func _first_record_value(record: Dictionary, keys: Array) -> String:
	for key in keys:
		var value := String(record.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


func _is_player_side(side: String) -> bool:
	return side == "player" or side == "hero_leader"
