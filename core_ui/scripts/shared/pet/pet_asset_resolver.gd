extends RefCounted

var image_by_id: Dictionary = {}
var image_by_name: Dictionary = {}
var issues: Array[Dictionary] = []

var _slice_dir := ""
var _explicit_image_dir := ""
var _texture_cache: Dictionary = {}


func configure(slice_dir: String, explicit_image_dir: String = "") -> void:
	_slice_dir = slice_dir.trim_suffix("/")
	_explicit_image_dir = explicit_image_dir.trim_suffix("/")


func load_map(path: String) -> bool:
	image_by_id = {}
	image_by_name = {}
	issues = []
	if path == "" or not FileAccess.file_exists(path):
		_add_issue("error", "pet_map_missing", path, "宠物图片映射文件不存在")
		return false
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	if error != OK:
		_add_issue(
			"error",
			"pet_map_invalid_json",
			path,
			"宠物图片映射 JSON 解析失败：第 %d 行 %s" % [parser.get_error_line(), parser.get_error_message()]
		)
		return false
	if typeof(parser.data) != TYPE_DICTIONARY:
		_add_issue("error", "pet_map_invalid_root", path, "宠物图片映射根节点必须是对象")
		return false
	var data := Dictionary(parser.data)
	var by_pet_id := Dictionary(data.get("by_pet_id", {}))
	if by_pet_id.is_empty():
		by_pet_id = data
	for raw_pet_id in by_pet_id.keys():
		var pet_id := String(raw_pet_id).strip_edges()
		if pet_id == "by_name":
			continue
		var resolved_path := _resolve_map_path(by_pet_id[raw_pet_id])
		if pet_id == "" or resolved_path == "":
			_add_issue("warning", "pet_map_invalid_entry", pet_id, "宠物映射条目缺少有效 ID 或路径")
			continue
		image_by_id[pet_id] = resolved_path
	for raw_name in Dictionary(data.get("by_name", {})).keys():
		var pet_name := String(raw_name).strip_edges()
		var resolved_path := _resolve_map_path(Dictionary(data.get("by_name", {}))[raw_name])
		if pet_name == "" or resolved_path == "":
			_add_issue("warning", "pet_name_map_invalid_entry", pet_name, "宠物名称映射条目缺少有效名称或路径")
			continue
		image_by_name[pet_name] = resolved_path
	_validate_declared_paths()
	return not has_errors()


func texture_for(record: Dictionary) -> Texture2D:
	return load_texture(path_for(record))


func path_for(record: Dictionary) -> String:
	var explicit_path := _explicit_image_path(record)
	if explicit_path != "" and ResourceLoader.exists(explicit_path):
		return explicit_path
	var pet_id := canonical_id(record)
	if pet_id != "" and image_by_id.has(pet_id):
		return String(image_by_id[pet_id])
	for key in ["name", "displayName", "unitName"]:
		var pet_name := String(record.get(key, "")).strip_edges()
		if pet_name != "" and image_by_name.has(pet_name):
			return String(image_by_name[pet_name])
	return ""


func canonical_id(record: Dictionary) -> String:
	for key in ["pet_id", "petId", "source_pet_id", "sourcePetId", "unitId", "unit_id", "id"]:
		var value := String(record.get(key, "")).strip_edges()
		if value != "" and image_by_id.has(value):
			return value
	return ""


func load_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
	if texture != null:
		_texture_cache[path] = texture
	return texture


func has_errors() -> bool:
	for issue in issues:
		if String(issue.get("severity", "")) == "error":
			return true
	return false


func clear_texture_cache() -> void:
	_texture_cache.clear()


func _resolve_map_path(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING:
			var text := String(value).strip_edges()
			if text == "":
				return ""
			if text.begins_with("res://"):
				return text
			if _slice_dir == "":
				return ""
			if text.get_extension() == "":
				return "%s/%s.png" % [_slice_dir, text]
			return "%s/%s" % [_slice_dir, text.get_file()]
	return ""


func _explicit_image_path(record: Dictionary) -> String:
	for key in ["image", "image_path", "sprite", "sprite_path", "icon", "icon_path"]:
		var raw := String(record.get(key, "")).strip_edges()
		if raw == "":
			continue
		if raw.begins_with("res://"):
			return raw
		if _explicit_image_dir == "":
			continue
		if raw.get_extension() == "":
			raw = "%s.png" % raw
		return "%s/%s" % [_explicit_image_dir, raw.get_file()]
	return ""


func _validate_declared_paths() -> void:
	for pet_id in image_by_id.keys():
		var path := String(image_by_id[pet_id])
		if not ResourceLoader.exists(path):
			_add_issue("error", "pet_texture_missing", String(pet_id), "宠物图片不存在：%s" % path, path)
	for pet_name in image_by_name.keys():
		var path := String(image_by_name[pet_name])
		if not ResourceLoader.exists(path):
			_add_issue("error", "pet_name_texture_missing", String(pet_name), "宠物名称图片不存在：%s" % path, path)


func _add_issue(severity: String, code: String, key: String, message: String, path: String = "") -> void:
	issues.append({
		"severity": severity,
		"code": code,
		"key": key,
		"message": message,
		"path": path,
	})
