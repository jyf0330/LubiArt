extends RefCounted

const SCHEMA := "ysbzs.content-package.v1"
const SemanticVersionScript := preload("res://persistence/semantic_version.gd")
const ALLOWED_OPERATIONS := ["set", "append", "append_to", "attach_unique", "replace"]
const ALLOWED_CAPABILITIES := ["content.override"]


func validate(package: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var source := String(package.get("_source_path", "unknown"))
	if String(package.get("schema", "")) != SCHEMA:
		errors.append("INVALID_SCHEMA:%s" % source)
	if String(package.get("package_id", "")).strip_edges() == "":
		errors.append("MISSING_PACKAGE_ID:%s" % source)
	_validate_manifest(package, source, errors)
	var operations: Variant = package.get("operations", [])
	if not operations is Array or Array(operations).is_empty():
		errors.append("MISSING_OPERATIONS:%s" % source)
		return errors
	for index in range(Array(operations).size()):
		_validate_operation(Dictionary(Array(operations)[index]), package, source, index, errors)
	return errors


func _validate_manifest(package: Dictionary, source: String, errors: Array[String]) -> void:
	var version := String(package.get("version", "0.0.0"))
	if not bool(SemanticVersionScript.parse(version).get("ok", false)):
		errors.append("INVALID_PACKAGE_VERSION:%s:%s" % [source, version])
	var minimum_game_version := String(package.get("min_game_version", ""))
	if minimum_game_version != "" and not bool(SemanticVersionScript.parse(minimum_game_version).get("ok", false)):
		errors.append("INVALID_MIN_GAME_VERSION:%s:%s" % [source, minimum_game_version])
	for key in ["load_after", "conflicts"]:
		var values: Variant = package.get(key, [])
		if not values is Array:
			errors.append("INVALID_%s:%s" % [key.to_upper(), source])
			continue
		var seen := {}
		for value in Array(values):
			var package_id := String(value).strip_edges()
			if package_id == "" or seen.has(package_id):
				errors.append("INVALID_%s_ENTRY:%s" % [key.to_upper(), source])
				continue
			seen[package_id] = true
	var capabilities: Variant = package.get("capabilities", [])
	if not capabilities is Array:
		errors.append("INVALID_CAPABILITIES:%s" % source)
	else:
		for capability_value in Array(capabilities):
			var capability := String(capability_value)
			if not ALLOWED_CAPABILITIES.has(capability):
				errors.append("UNKNOWN_CAPABILITY:%s:%s" % [capability, source])
	var dependencies: Variant = package.get("dependencies", [])
	if not dependencies is Array:
		errors.append("INVALID_DEPENDENCIES:%s" % source)
	else:
		var dependency_ids := {}
		for dependency_value in Array(dependencies):
			if not dependency_value is Dictionary:
				errors.append("INVALID_DEPENDENCY:%s" % source)
				continue
			var dependency := Dictionary(dependency_value)
			var dependency_id := String(dependency.get("id", "")).strip_edges()
			if dependency_id == "" or dependency_ids.has(dependency_id):
				errors.append("INVALID_DEPENDENCY_ID:%s" % source)
				continue
			dependency_ids[dependency_id] = true
			var min_version := String(dependency.get("min_version", ""))
			if min_version != "" and not bool(SemanticVersionScript.parse(min_version).get("ok", false)):
				errors.append("INVALID_DEPENDENCY_VERSION:%s:%s" % [source, dependency_id])


func _validate_operation(operation: Dictionary, package: Dictionary, source: String, index: int, errors: Array[String]) -> void:
	var operation_id := String(operation.get("op", ""))
	var label := "%s#%d" % [source, index]
	if not ALLOWED_OPERATIONS.has(operation_id):
		errors.append("UNKNOWN_OPERATION:%s:%s" % [operation_id, label])
		return
	var path: Variant = operation.get("path", [])
	if not path is Array or Array(path).is_empty():
		errors.append("INVALID_PATH:%s" % label)
		return
	for segment in Array(path):
		if String(segment).strip_edges() == "":
			errors.append("INVALID_PATH_SEGMENT:%s" % label)
		if String(segment) == "_content_manifest":
			errors.append("RESERVED_PATH:%s" % label)
	if ["set", "append", "attach_unique", "replace"].has(operation_id) and not operation.has("value"):
		errors.append("MISSING_VALUE:%s" % label)
	if operation_id == "replace" and not Array(package.get("capabilities", [])).has("content.override"):
		errors.append("OVERRIDE_CAPABILITY_REQUIRED:%s" % label)
	if operation_id == "append_to":
		_require_keys(operation, ["match_key", "match_value", "field", "value"], label, errors)
	if operation_id == "attach_unique":
		_require_keys(operation, ["match_key", "match_value", "field", "value"], label, errors)


func _require_keys(value: Dictionary, keys: Array, label: String, errors: Array[String]) -> void:
	for key in keys:
		if not value.has(key):
			errors.append("MISSING_%s:%s" % [String(key).to_upper(), label])
			continue
		var raw_value: Variant = value.get(key)
		if raw_value == null or (raw_value is String and raw_value.strip_edges() == ""):
			errors.append("MISSING_%s:%s" % [String(key).to_upper(), label])
