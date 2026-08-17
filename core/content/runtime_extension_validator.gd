extends RefCounted

## Shape-only validation for data-driven runtime extension fields. Domain
## registries still own semantic handler, hook, and parameter validation.


func validate(content: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	_validate_value(content, "content", errors)
	return errors


func _validate_value(value: Variant, path: String, errors: Array[String]) -> void:
	if value is Array:
		for index in range(Array(value).size()):
			_validate_value(Array(value)[index], "%s[%d]" % [path, index], errors)
		return
	if not value is Dictionary:
		return
	var dictionary := Dictionary(value)
	if dictionary.has("runtime_handler"):
		_validate_runtime_handler(dictionary.get("runtime_handler"), "%s.runtime_handler" % path, errors)
	if dictionary.has("runtime_operations"):
		_validate_identifier(dictionary.get("id", null), "%s.id" % path, "RUNTIME_OPERATION_OWNER_ID_INVALID", errors)
		_validate_operations(dictionary.get("runtime_operations"), "%s.runtime_operations" % path, true, errors)
	if dictionary.has("event_operations"):
		_validate_operations(dictionary.get("event_operations"), "%s.event_operations" % path, false, errors)
	if dictionary.has("event_triggers"):
		_validate_event_triggers(dictionary.get("event_triggers"), "%s.event_triggers" % path, errors)
	for key_value in dictionary.keys():
		_validate_value(dictionary[key_value], "%s.%s" % [path, String(key_value)], errors)


func _validate_runtime_handler(value: Variant, path: String, errors: Array[String]) -> void:
	if typeof(value) != TYPE_STRING:
		errors.append("RUNTIME_HANDLER_INVALID:%s" % path)
		return
	var handler_id := String(value)
	if handler_id == "" or handler_id != handler_id.strip_edges():
		errors.append("RUNTIME_HANDLER_INVALID:%s" % path)
		return
	if _looks_like_script_path(handler_id):
		errors.append("RUNTIME_HANDLER_SCRIPT_PATH_FORBIDDEN:%s" % path)


func _validate_operations(value: Variant, path: String, quality: bool, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("RUNTIME_OPERATIONS_INVALID:%s" % path)
		return
	var seen_ids := {}
	for index in range(Array(value).size()):
		var item_path := "%s[%d]" % [path, index]
		var operation_value: Variant = Array(value)[index]
		if not operation_value is Dictionary:
			errors.append("RUNTIME_OPERATION_INVALID:%s" % item_path)
			continue
		var operation := Dictionary(operation_value)
		var required := ["id", "operation", "priority", "params"]
		if quality:
			required.insert(1, "hook")
		for key in required:
			if not operation.has(key):
				errors.append("RUNTIME_OPERATION_MISSING_%s:%s" % [String(key).to_upper(), item_path])
		var operation_id_value: Variant = operation.get("id", null)
		var operation_id := String(operation_id_value).strip_edges() if typeof(operation_id_value) == TYPE_STRING else ""
		if typeof(operation_id_value) != TYPE_STRING \
				or operation_id == "" \
				or operation_id != String(operation_id_value):
			errors.append("RUNTIME_OPERATION_ID_INVALID:%s" % item_path)
		elif seen_ids.has(operation_id):
			errors.append("RUNTIME_OPERATION_ID_DUPLICATE:%s:%s" % [path, operation_id])
		else:
			seen_ids[operation_id] = true
		for string_key in (["hook"] if quality else []) + ["operation"]:
			var selector_value: Variant = operation.get(string_key, null)
			var selector := String(selector_value) if typeof(selector_value) == TYPE_STRING else ""
			if typeof(selector_value) != TYPE_STRING \
					or selector == "" \
					or selector != selector.strip_edges():
				errors.append("RUNTIME_OPERATION_%s_INVALID:%s" % [String(string_key).to_upper(), item_path])
		if not _is_integral_number(operation.get("priority", null)):
			errors.append("RUNTIME_OPERATION_PRIORITY_INVALID:%s" % item_path)
		if not operation.get("params", null) is Dictionary \
			or not _is_json_compatible(operation.get("params")):
			errors.append("RUNTIME_OPERATION_PARAMS_INVALID:%s" % item_path)
		elif _contains_script_path(operation.get("params")):
			errors.append("RUNTIME_OPERATION_SCRIPT_PATH_FORBIDDEN:%s" % item_path)
		if operation.has("contexts") and not _valid_string_array(operation.get("contexts")):
			errors.append("RUNTIME_OPERATION_CONTEXTS_INVALID:%s" % item_path)


func _valid_string_array(value: Variant) -> bool:
	if not value is Array or Array(value).is_empty():
		return false
	var seen := {}
	for item in Array(value):
		if typeof(item) != TYPE_STRING or String(item).strip_edges() == "" or seen.has(String(item)):
			return false
		seen[String(item)] = true
	return true


func _validate_event_triggers(value: Variant, path: String, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("RUNTIME_EVENT_TRIGGERS_INVALID:%s" % path)
		return
	var seen_ids := {}
	for index in range(Array(value).size()):
		var item_path := "%s[%d]" % [path, index]
		var trigger_value: Variant = Array(value)[index]
		if not trigger_value is Dictionary:
			errors.append("RUNTIME_EVENT_TRIGGER_INVALID:%s" % item_path)
			continue
		var trigger := Dictionary(trigger_value)
		for required_key in ["id", "hook", "priority", "conditions", "condition_label"]:
			if not trigger.has(required_key):
				errors.append("RUNTIME_EVENT_TRIGGER_MISSING_%s:%s" % [String(required_key).to_upper(), item_path])
		var trigger_id_value: Variant = trigger.get("id", null)
		var trigger_id := String(trigger_id_value).strip_edges() if typeof(trigger_id_value) == TYPE_STRING else ""
		if typeof(trigger_id_value) != TYPE_STRING \
				or trigger_id == "" \
				or trigger_id != String(trigger_id_value):
			errors.append("RUNTIME_EVENT_TRIGGER_ID_INVALID:%s" % item_path)
		elif seen_ids.has(trigger_id):
			errors.append("RUNTIME_EVENT_TRIGGER_ID_DUPLICATE:%s:%s" % [path, trigger_id])
		else:
			seen_ids[trigger_id] = true
		for string_key in ["hook", "condition_label"]:
			var selector_value: Variant = trigger.get(string_key, null)
			var selector := String(selector_value) if typeof(selector_value) == TYPE_STRING else ""
			if typeof(selector_value) != TYPE_STRING \
					or selector == "" \
					or selector != selector.strip_edges():
				errors.append("RUNTIME_EVENT_TRIGGER_%s_INVALID:%s" % [String(string_key).to_upper(), item_path])
		if not _is_integral_number(trigger.get("priority", null)):
			errors.append("RUNTIME_EVENT_TRIGGER_PRIORITY_INVALID:%s" % item_path)
		var conditions_value: Variant = trigger.get("conditions", null)
		if not conditions_value is Dictionary \
				or Dictionary(conditions_value).size() != 1 \
				or not Dictionary(conditions_value).has("result_codes") \
				or not _valid_string_array(Dictionary(conditions_value).get("result_codes")) \
				or not _is_json_compatible(conditions_value):
			errors.append("RUNTIME_EVENT_TRIGGER_CONDITIONS_INVALID:%s" % item_path)
		elif _contains_script_path(conditions_value):
			errors.append("RUNTIME_EVENT_TRIGGER_SCRIPT_PATH_FORBIDDEN:%s" % item_path)


func _validate_identifier(value: Variant, path: String, error_code: String, errors: Array[String]) -> void:
	if typeof(value) != TYPE_STRING:
		errors.append("%s:%s" % [error_code, path])
		return
	var identifier := String(value)
	if identifier == "" or identifier != identifier.strip_edges():
		errors.append("%s:%s" % [error_code, path])


func _contains_script_path(value: Variant) -> bool:
	if typeof(value) == TYPE_STRING:
		return _looks_like_script_path(String(value))
	if value is Array:
		for item in Array(value):
			if _contains_script_path(item):
				return true
	elif value is Dictionary:
		for item in Dictionary(value).values():
			if _contains_script_path(item):
				return true
	return false


func _looks_like_script_path(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	return normalized.begins_with("res://") \
			or normalized.begins_with("user://") \
			or normalized.begins_with("uid://") \
			or normalized.ends_with(".gd") \
			or normalized.ends_with(".gdc")


func _is_integral_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floor(float(value))


func _is_json_compatible(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_ARRAY:
			for item in Array(value):
				if not _is_json_compatible(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key_value in Dictionary(value).keys():
				if typeof(key_value) != TYPE_STRING or not _is_json_compatible(Dictionary(value)[key_value]):
					return false
			return true
	return false
