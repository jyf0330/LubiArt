extends RefCounted

const DEFERRED_OPERATIONS := ["attach_unique"]


func assemble(packages: Array) -> Dictionary:
	var data := {}
	var errors: Array[String] = []
	var deferred: Array = []
	for package_value in packages:
		var package := Dictionary(package_value)
		for operation_value in Array(package.get("operations", [])):
			var operation := Dictionary(operation_value)
			if DEFERRED_OPERATIONS.has(String(operation.get("op", ""))):
				deferred.append({"package": package, "operation": operation})
			else:
				_apply(data, operation, String(package.get("package_id", "")), errors)
	for item_value in deferred:
		var item := Dictionary(item_value)
		_apply(data, Dictionary(item.get("operation", {})), String(Dictionary(item.get("package", {})).get("package_id", "")), errors)
	if errors.is_empty():
		data["_content_manifest"] = _assembly_manifest(packages)
	return {"ok": errors.is_empty(), "data": data if errors.is_empty() else {}, "errors": errors}


func _apply(data: Dictionary, operation: Dictionary, package_id: String, errors: Array[String]) -> void:
	var operation_id := String(operation.get("op", ""))
	match operation_id:
		"set": _set_value(data, operation, package_id, errors)
		"append": _append_value(data, operation, package_id, errors)
		"append_to": _append_to_entity(data, operation, package_id, errors, false)
		"attach_unique": _append_to_entity(data, operation, package_id, errors, true)
		"replace": _replace_value(data, operation, package_id, errors)


func _set_value(data: Dictionary, operation: Dictionary, package_id: String, errors: Array[String]) -> void:
	var path := _string_path(Array(operation.get("path", [])))
	var parent: Variant = _value_at(data, path.slice(0, -1))
	var key := path[-1]
	if not parent is Dictionary:
		errors.append("MISSING_PARENT:%s:%s" % [package_id, "/".join(path)])
		return
	if Dictionary(parent).has(key):
		errors.append("DUPLICATE_PATH:%s:%s" % [package_id, "/".join(path)])
		return
	Dictionary(parent)[key] = _copy(operation.get("value"))


func _replace_value(data: Dictionary, operation: Dictionary, package_id: String, errors: Array[String]) -> void:
	var path := _string_path(Array(operation.get("path", [])))
	var parent: Variant = _value_at(data, path.slice(0, -1))
	var key := path[-1]
	if not parent is Dictionary or not Dictionary(parent).has(key):
		errors.append("MISSING_REPLACE_TARGET:%s:%s" % [package_id, "/".join(path)])
		return
	Dictionary(parent)[key] = _copy(operation.get("value"))


func _append_value(data: Dictionary, operation: Dictionary, package_id: String, errors: Array[String]) -> void:
	var path := _string_path(Array(operation.get("path", [])))
	var target: Variant = _value_at(data, path)
	if not target is Array:
		errors.append("MISSING_ARRAY:%s:%s" % [package_id, "/".join(path)])
		return
	Array(target).append(_copy(operation.get("value")))


func _append_to_entity(data: Dictionary, operation: Dictionary, package_id: String, errors: Array[String], unique: bool) -> void:
	var path := _string_path(Array(operation.get("path", [])))
	var collection: Variant = _value_at(data, path)
	if not collection is Array:
		errors.append("MISSING_COLLECTION:%s:%s" % [package_id, "/".join(path)])
		return
	var entity := _find_entity(Array(collection), operation)
	if entity.is_empty():
		errors.append("MISSING_ATTACHMENT_TARGET:%s:%s" % [package_id, String(operation.get("match_value", ""))])
		return
	var field := String(operation.get("field", ""))
	var values: Variant = entity.get(field, [])
	if not values is Array:
		errors.append("INVALID_ATTACHMENT_FIELD:%s:%s" % [package_id, field])
		return
	var value: Variant = _copy(operation.get("value"))
	if not unique or not Array(values).has(value):
		Array(values).append(value)
	entity[field] = values


func _find_entity(collection: Array, operation: Dictionary) -> Dictionary:
	if operation.has("match_index"):
		var index := int(operation.get("match_index", -1))
		return Dictionary(collection[index]) if index >= 0 and index < collection.size() and collection[index] is Dictionary else {}
	var key := String(operation.get("match_key", ""))
	var expected: Variant = operation.get("match_value")
	for value in collection:
		if value is Dictionary and Dictionary(value).get(key) == expected:
			return Dictionary(value)
	return {}


func _value_at(data: Dictionary, path: Array[String]) -> Variant:
	var current: Variant = data
	for segment in path:
		if not current is Dictionary or not Dictionary(current).has(segment):
			return null
		current = Dictionary(current)[segment]
	return current


func _string_path(path: Array) -> Array[String]:
	var result: Array[String] = []
	for value in path:
		result.append(String(value))
	return result


func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


func _assembly_manifest(packages: Array) -> Dictionary:
	var entries: Array = []
	for index in range(packages.size()):
		var package := Dictionary(packages[index])
		entries.append({
			"packageId": String(package.get("package_id", "")),
			"version": String(package.get("version", "0.0.0")),
			"assemblyOrder": index,
			"affectsGameplay": bool(package.get("affects_gameplay", true)),
			"dependencies": Array(package.get("dependencies", [])).duplicate(true),
			"capabilities": Array(package.get("capabilities", [])).duplicate(),
		})
	return {
		"schema": "ysbzs.content-assembly.v1",
		"packages": entries,
	}
