extends RefCounted

const ScriptPluginRegistryScript := preload("res://core/plugins/script_plugin_registry.gd")

const HANDLER_DIRECTORY := "res://core/run/events/handlers"
const CANONICAL_OPERATION_IDS: Array[String] = [
	"add_coins",
	"add_free_refreshes",
	"duplicate_first_pet",
	"heal_hero",
	"noop",
	"queue_battle_prep_shield",
	"queue_reward_gold_multiplier",
	"queue_trap_damage_bonus",
	"refill_shop_pool",
	"select_reward_pool",
	"set_next_discount",
	"spend_coins",
	"upgrade_first_eligible_pet",
]
const EXECUTE_METHOD := &"execute"
const EXECUTE_ARITY := 4
const EXECUTE_ARGUMENT_TYPES := [
	TYPE_OBJECT,
	TYPE_DICTIONARY,
	TYPE_DICTIONARY,
	TYPE_DICTIONARY,
]
const EXECUTE_ARGUMENT_CLASSES := [&"RefCounted", &"", &"", &""]
const EXECUTE_RETURN_TYPE := TYPE_DICTIONARY
const PLUGIN_ID_RETURN_TYPE := TYPE_STRING
const PARAM_VALIDATOR_METHOD := &"_validate_params"
const PARAM_VALIDATOR_ARITY := 1
const PARAM_VALIDATOR_ARGUMENT_TYPE := TYPE_DICTIONARY
const PARAM_VALIDATOR_RETURN_TYPE := TYPE_ARRAY
const PARAM_VALIDATOR_RETURN_HINT := PROPERTY_HINT_ARRAY_TYPE
const PARAM_VALIDATOR_RETURN_HINT_STRING := "String"

var _plugins: RefCounted
var _validation_errors: Array[String] = []


func _init(
	directory: String = HANDLER_DIRECTORY,
	enforce_canonical_ids: bool = true
) -> void:
	var normalized_directory := directory.trim_suffix("/")
	_validate_plugin_id_return_types(normalized_directory)
	if not _validation_errors.is_empty():
		return
	_plugins = ScriptPluginRegistryScript.new().configure(normalized_directory)
	_validation_errors.append_array(_plugins.validation_errors())
	if not _validation_errors.is_empty():
		return
	for handler_value in _plugins.plugins():
		_validate_handler(handler_value as RefCounted)
	if _validation_errors.is_empty() and enforce_canonical_ids:
		_validate_canonical_ids()


func handler_for(operation_id: String) -> RefCounted:
	if not is_valid() or operation_id == "":
		return null
	return _plugins.plugin(operation_id) as RefCounted


func validate_params(operation_id: String, params: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var handler := handler_for(operation_id)
	if handler == null:
		return result
	var validator_result: Variant = handler.call(PARAM_VALIDATOR_METHOD, params.duplicate(true))
	if typeof(validator_result) != TYPE_ARRAY:
		result.append("Run event operation handler '%s' validator returned %s instead of Array." % [
			operation_id,
			_metadata_type_name(typeof(validator_result), &""),
		])
		return result
	for error_index in Array(validator_result).size():
		var error_value: Variant = Array(validator_result)[error_index]
		if typeof(error_value) != TYPE_STRING:
			result.append("Run event operation handler '%s' validator item %d must be a String." % [
				operation_id,
				error_index,
			])
			continue
		result.append(String(error_value))
	return result


func ids() -> Array[String]:
	var result: Array[String] = []
	if is_valid():
		result.append_array(_plugins.ids())
	return result


func is_valid() -> bool:
	return _plugins != null and _plugins.is_valid() and _validation_errors.is_empty()


func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func _validate_plugin_id_return_types(directory: String) -> void:
	if DirAccess.open(directory) == null:
		return
	var files := DirAccess.get_files_at(directory)
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".gd"):
			continue
		var script := load("%s/%s" % [directory, file_name]) as Script
		if script == null:
			continue
		var method := _script_method_metadata(script, &"plugin_id")
		if method.is_empty() or Array(method.get("args", [])).size() != 0:
			continue
		var return_metadata := Dictionary(method.get("return", {}))
		var actual_type := int(return_metadata.get("type", -1))
		var actual_class := StringName(return_metadata.get("class_name", ""))
		if actual_type == PLUGIN_ID_RETURN_TYPE and actual_class == &"":
			continue
		_validation_errors.append("Run event operation handler in '%s/%s' method plugin_id return expected %s, found %s." % [
			directory,
			file_name,
			_metadata_type_name(PLUGIN_ID_RETURN_TYPE, &""),
			_metadata_type_name(actual_type, actual_class),
		])


func _validate_handler(handler: RefCounted) -> void:
	if handler == null:
		_validation_errors.append("Run event operation handler failed to instantiate.")
		return
	var handler_id := String(handler.call(&"plugin_id"))
	_validate_method_return(handler, handler_id, &"plugin_id", PLUGIN_ID_RETURN_TYPE)
	_validate_param_validator(handler, handler_id)
	_validate_execute(handler, handler_id)
	for method_name in _script_method_names(handler):
		if method_name == &"plugin_id" or method_name == EXECUTE_METHOD or String(method_name).begins_with("_"):
			continue
		_validation_errors.append("Run event operation handler '%s' declares unknown public method '%s'." % [
			handler_id,
			String(method_name),
		])


func _validate_param_validator(handler: RefCounted, handler_id: String) -> void:
	if not handler.has_method(PARAM_VALIDATOR_METHOD):
		_validation_errors.append("Run event operation handler '%s' must declare _validate_params(params: Dictionary) -> Array." % handler_id)
		return
	var method := _method_metadata(handler, PARAM_VALIDATOR_METHOD)
	var arguments := Array(method.get("args", []))
	var signature_valid := true
	if arguments.size() != PARAM_VALIDATOR_ARITY:
		_validation_errors.append("Run event operation handler '%s' method _validate_params expected %d arguments, found %d." % [
			handler_id,
			PARAM_VALIDATOR_ARITY,
			arguments.size(),
		])
		signature_valid = false
	else:
		var argument := Dictionary(arguments[0])
		var actual_type := int(argument.get("type", -1))
		var actual_class := StringName(argument.get("class_name", ""))
		if actual_type != PARAM_VALIDATOR_ARGUMENT_TYPE or actual_class != &"":
			_validation_errors.append("Run event operation handler '%s' method _validate_params argument 0 expected %s, found %s." % [
				handler_id,
				_metadata_type_name(PARAM_VALIDATOR_ARGUMENT_TYPE, &""),
				_metadata_type_name(actual_type, actual_class),
			])
			signature_valid = false
	if _method_default_argument_count(method) > 0:
		_validation_errors.append("Run event operation handler '%s' method _validate_params must not declare default arguments." % handler_id)
		signature_valid = false
	if not _validate_method_return(handler, handler_id, PARAM_VALIDATOR_METHOD, PARAM_VALIDATOR_RETURN_TYPE):
		signature_valid = false
	else:
		var return_metadata := Dictionary(method.get("return", {}))
		var return_hint := int(return_metadata.get("hint", PROPERTY_HINT_NONE))
		var return_hint_string := String(return_metadata.get("hint_string", ""))
		if return_hint != PARAM_VALIDATOR_RETURN_HINT or return_hint_string != PARAM_VALIDATOR_RETURN_HINT_STRING:
			_validation_errors.append("Run event operation handler '%s' method _validate_params return expected Array[String], found Array[%s]." % [
				handler_id,
				return_hint_string if return_hint_string != "" else "Variant",
			])
			signature_valid = false
	if signature_valid:
		_validate_validator_items(handler, handler_id)


func _validate_execute(handler: RefCounted, handler_id: String) -> void:
	if not handler.has_method(EXECUTE_METHOD):
		_validation_errors.append("Run event operation handler '%s' must declare execute." % handler_id)
		return
	var method := _method_metadata(handler, EXECUTE_METHOD)
	var arguments := Array(method.get("args", []))
	if arguments.size() != EXECUTE_ARITY:
		_validation_errors.append("Run event operation handler '%s' method execute expected %d arguments, found %d." % [
			handler_id,
			EXECUTE_ARITY,
			arguments.size(),
		])
	else:
		for argument_index in EXECUTE_ARITY:
			var argument := Dictionary(arguments[argument_index])
			var actual_type := int(argument.get("type", -1))
			var actual_class := StringName(argument.get("class_name", ""))
			var expected_type := int(EXECUTE_ARGUMENT_TYPES[argument_index])
			var expected_class := StringName(EXECUTE_ARGUMENT_CLASSES[argument_index])
			if actual_type == expected_type and actual_class == expected_class:
				continue
			_validation_errors.append("Run event operation handler '%s' method execute argument %d expected %s, found %s." % [
				handler_id,
				argument_index,
				_metadata_type_name(expected_type, expected_class),
				_metadata_type_name(actual_type, actual_class),
			])
	if _method_default_argument_count(method) > 0:
		_validation_errors.append("Run event operation handler '%s' method execute must not declare default arguments." % handler_id)
	_validate_method_return(handler, handler_id, EXECUTE_METHOD, EXECUTE_RETURN_TYPE)


func _validate_validator_items(handler: RefCounted, handler_id: String) -> void:
	var result: Variant = handler.call(PARAM_VALIDATOR_METHOD, {})
	if typeof(result) != TYPE_ARRAY:
		return
	for item_index in Array(result).size():
		if typeof(Array(result)[item_index]) == TYPE_STRING:
			continue
		_validation_errors.append("Run event operation handler '%s' method _validate_params item %d must be a String." % [
			handler_id,
			item_index,
		])


func _validate_method_return(
	handler: RefCounted,
	handler_id: String,
	method_name: StringName,
	expected_type: int
) -> bool:
	var method := _method_metadata(handler, method_name)
	var return_metadata := Dictionary(method.get("return", {}))
	var actual_type := int(return_metadata.get("type", -1))
	var actual_class := StringName(return_metadata.get("class_name", ""))
	if actual_type == expected_type and actual_class == &"":
		return true
	_validation_errors.append("Run event operation handler '%s' method %s return expected %s, found %s." % [
		handler_id,
		String(method_name),
		_metadata_type_name(expected_type, &""),
		_metadata_type_name(actual_type, actual_class),
	])
	return false


func _validate_canonical_ids() -> void:
	var actual_ids: Array[String] = _plugins.ids()
	if actual_ids == CANONICAL_OPERATION_IDS:
		return
	for operation_id in CANONICAL_OPERATION_IDS:
		if not actual_ids.has(operation_id):
			_validation_errors.append("Run event operation registry is missing canonical operation '%s'." % operation_id)
	for operation_id in actual_ids:
		if not CANONICAL_OPERATION_IDS.has(operation_id):
			_validation_errors.append("Run event operation registry declares non-canonical operation '%s'." % operation_id)


func _method_default_argument_count(method: Dictionary) -> int:
	return Array(method.get("default_args", [])).size()


func _method_metadata(handler: RefCounted, method_name: StringName) -> Dictionary:
	return _script_method_metadata(handler.get_script() as Script, method_name)


func _script_method_metadata(script: Script, method_name: StringName) -> Dictionary:
	var current_script := script
	while current_script != null:
		for method_value in current_script.get_script_method_list():
			var method := Dictionary(method_value)
			if StringName(method.get("name", "")) == method_name:
				return method
		current_script = current_script.get_base_script()
	return {}


func _script_method_names(handler: RefCounted) -> Array[StringName]:
	var result: Array[StringName] = []
	var script := handler.get_script() as Script
	while script != null:
		for method_value in script.get_script_method_list():
			var method_name := StringName(Dictionary(method_value).get("name", ""))
			if method_name != &"" and not result.has(method_name):
				result.append(method_name)
		script = script.get_base_script()
	return result


func _metadata_type_name(type_code: int, class_name_value: StringName) -> String:
	if type_code == TYPE_OBJECT and class_name_value != &"":
		return String(class_name_value)
	if type_code < TYPE_NIL or type_code >= TYPE_MAX:
		return "unknown"
	return type_string(type_code)
