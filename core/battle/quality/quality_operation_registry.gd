extends RefCounted

const ScriptPluginRegistryScript := preload("res://core/plugins/script_plugin_registry.gd")

const HANDLER_DIRECTORY := "res://core/battle/quality/operations"
const ALLOWED_HOOKS: Array[StringName] = [
	&"round_start",
	&"element_application_count",
	&"element_layers",
	&"before_attack",
	&"modify_hit_damage",
	&"before_hit",
	&"after_hit",
	&"after_attack",
	&"mutate_shape",
	&"attack_option_for_target",
	&"sort_targets",
	&"trace_enter",
	&"trace_round_start",
	&"trace_element_application_count",
	&"profile",
]
const HOOK_ARITIES := {
	"round_start": 3,
	"element_application_count": 4,
	"element_layers": 4,
	"before_attack": 4,
	"modify_hit_damage": 3,
	"before_hit": 5,
	"after_hit": 4,
	"after_attack": 5,
	"mutate_shape": 7,
	"attack_option_for_target": 4,
	"sort_targets": 3,
	"trace_enter": 4,
	"trace_round_start": 4,
	"trace_element_application_count": 3,
	"profile": 1,
}
const HOOK_ARGUMENT_TYPES := {
	"round_start": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"element_application_count": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_INT, TYPE_DICTIONARY],
	"element_layers": [TYPE_DICTIONARY, TYPE_STRING, TYPE_INT, TYPE_DICTIONARY],
	"before_attack": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"modify_hit_damage": [TYPE_DICTIONARY, TYPE_INT, TYPE_DICTIONARY],
	"before_hit": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_STRING, TYPE_DICTIONARY],
	"after_hit": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_attack": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_ARRAY, TYPE_DICTIONARY],
	"mutate_shape": [TYPE_DICTIONARY, TYPE_STRING, TYPE_ARRAY, TYPE_INT, TYPE_INT, TYPE_STRING, TYPE_DICTIONARY],
	"attack_option_for_target": [TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"sort_targets": [TYPE_ARRAY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"trace_enter": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"trace_round_start": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_ARRAY, TYPE_DICTIONARY],
	"trace_element_application_count": [TYPE_ARRAY, TYPE_INT, TYPE_DICTIONARY],
	"profile": [TYPE_DICTIONARY],
}
const HOOK_ARGUMENT_CLASSES := {
	"round_start": [&"RefCounted", &"", &""],
	"element_application_count": [&"RefCounted", &"", &"", &""],
	"element_layers": [&"", &"", &"", &""],
	"before_attack": [&"RefCounted", &"", &"", &""],
	"modify_hit_damage": [&"", &"", &""],
	"before_hit": [&"RefCounted", &"", &"", &"", &""],
	"after_hit": [&"RefCounted", &"", &"", &""],
	"after_attack": [&"RefCounted", &"", &"", &"", &""],
	"mutate_shape": [&"", &"", &"", &"", &"", &"", &""],
	"attack_option_for_target": [&"", &"", &"", &""],
	"sort_targets": [&"", &"", &""],
	"trace_enter": [&"RefCounted", &"", &"", &""],
	"trace_round_start": [&"RefCounted", &"", &"", &""],
	"trace_element_application_count": [&"", &"", &""],
	"profile": [&""],
}
const HOOK_RETURN_TYPES := {
	"round_start": TYPE_ARRAY,
	"element_application_count": TYPE_INT,
	"element_layers": TYPE_INT,
	"before_attack": TYPE_ARRAY,
	"modify_hit_damage": TYPE_INT,
	"before_hit": TYPE_ARRAY,
	"after_hit": TYPE_ARRAY,
	"after_attack": TYPE_ARRAY,
	"mutate_shape": TYPE_ARRAY,
	"attack_option_for_target": TYPE_DICTIONARY,
	"sort_targets": TYPE_ARRAY,
	"trace_enter": TYPE_STRING,
	"trace_round_start": TYPE_ARRAY,
	"trace_element_application_count": TYPE_INT,
	"profile": TYPE_DICTIONARY,
}
const PLUGIN_ID_RETURN_TYPE := TYPE_STRING
const PARAM_VALIDATOR_METHOD := &"_validate_params"
const PARAM_VALIDATOR_ARITY := 1
const PARAM_VALIDATOR_ARGUMENT_TYPE := TYPE_DICTIONARY
const PARAM_VALIDATOR_RETURN_TYPE := TYPE_ARRAY

var _plugins: RefCounted
var _validation_errors: Array[String] = []


func _init(directory: String = HANDLER_DIRECTORY) -> void:
	_validate_plugin_id_return_types(directory)
	if not _validation_errors.is_empty():
		return
	_plugins = ScriptPluginRegistryScript.new().configure(directory)
	_validation_errors.append_array(_plugins.validation_errors())
	if not _validation_errors.is_empty():
		return
	for handler_value in _plugins.plugins():
		_validate_handler(handler_value as RefCounted)


func handler_for(operation_id: String) -> RefCounted:
	if not is_valid() or operation_id == "":
		return null
	return _plugins.plugin(operation_id) as RefCounted


func supports(handler: RefCounted, hook: StringName) -> bool:
	return is_valid() and handler != null and ALLOWED_HOOKS.has(hook) and handler.has_method(hook)


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
	var normalized_directory := directory.trim_suffix("/")
	if DirAccess.open(normalized_directory) == null:
		return
	var files := DirAccess.get_files_at(normalized_directory)
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".gd"):
			continue
		var script := load("%s/%s" % [normalized_directory, file_name]) as Script
		if script == null:
			continue
		var method := _script_method_metadata(script, &"plugin_id")
		if method.is_empty():
			continue
		if Array(method.get("args", [])).size() != 0:
			continue
		var return_metadata := Dictionary(method.get("return", {}))
		var actual_type := int(return_metadata.get("type", -1))
		var actual_class := StringName(return_metadata.get("class_name", ""))
		if actual_type == PLUGIN_ID_RETURN_TYPE and actual_class == &"":
			continue
		_validation_errors.append("Quality operation handler in '%s/%s' method plugin_id return expected %s, found %s." % [
			normalized_directory,
			file_name,
			_metadata_type_name(PLUGIN_ID_RETURN_TYPE, &""),
			_metadata_type_name(actual_type, actual_class),
		])


func _validate_handler(handler: RefCounted) -> void:
	if handler == null:
		_validation_errors.append("Quality operation handler failed to instantiate.")
		return
	var handler_id := String(handler.call(&"plugin_id"))
	_validate_method_return(handler, handler_id, &"plugin_id", PLUGIN_ID_RETURN_TYPE)
	_validate_param_validator(handler, handler_id)
	var supported_count := 0
	for hook in ALLOWED_HOOKS:
		if not handler.has_method(hook):
			continue
		supported_count += 1
		var actual_arity := _method_argument_count(handler, hook)
		var expected_arity := int(HOOK_ARITIES.get(String(hook), -1))
		if actual_arity != expected_arity:
			_validation_errors.append("Quality operation handler '%s' hook %s expected %d arguments, found %d." % [
				handler_id,
				String(hook),
				expected_arity,
				actual_arity,
			])
			continue
		_validate_hook_signature(handler, handler_id, hook)
	if supported_count <= 0:
		_validation_errors.append("Quality operation handler '%s' must declare at least one allowed hook." % handler_id)
	for method_name in _script_method_names(handler):
		if method_name == &"plugin_id" or ALLOWED_HOOKS.has(method_name) or String(method_name).begins_with("_"):
			continue
		_validation_errors.append("Quality operation handler '%s' declares unknown hook '%s'." % [handler_id, String(method_name)])


func _validate_param_validator(handler: RefCounted, handler_id: String) -> void:
	if not handler.has_method(PARAM_VALIDATOR_METHOD):
		_validation_errors.append("Quality operation handler '%s' must declare _validate_params(params: Dictionary) -> Array." % handler_id)
		return
	var method := _method_metadata(handler, PARAM_VALIDATOR_METHOD)
	var arguments := Array(method.get("args", []))
	if arguments.size() != PARAM_VALIDATOR_ARITY:
		_validation_errors.append("Quality operation handler '%s' method _validate_params expected %d arguments, found %d." % [
			handler_id,
			PARAM_VALIDATOR_ARITY,
			arguments.size(),
		])
	else:
		var argument := Dictionary(arguments[0])
		var actual_type := int(argument.get("type", -1))
		var actual_class := StringName(argument.get("class_name", ""))
		if actual_type != PARAM_VALIDATOR_ARGUMENT_TYPE or actual_class != &"":
			_validation_errors.append("Quality operation handler '%s' method _validate_params argument 0 expected %s, found %s." % [
				handler_id,
				_metadata_type_name(PARAM_VALIDATOR_ARGUMENT_TYPE, &""),
				_metadata_type_name(actual_type, actual_class),
			])
	_validate_method_return(
		handler,
		handler_id,
		PARAM_VALIDATOR_METHOD,
		PARAM_VALIDATOR_RETURN_TYPE
	)


func _validate_hook_signature(handler: RefCounted, handler_id: String, hook: StringName) -> void:
	var method := _method_metadata(handler, hook)
	var arguments := Array(method.get("args", []))
	var expected_types := Array(HOOK_ARGUMENT_TYPES.get(String(hook), []))
	var expected_classes := Array(HOOK_ARGUMENT_CLASSES.get(String(hook), []))
	for argument_index in expected_types.size():
		var argument := Dictionary(arguments[argument_index])
		var actual_type := int(argument.get("type", -1))
		var expected_type := int(expected_types[argument_index])
		var actual_class := StringName(argument.get("class_name", ""))
		var expected_class := StringName(expected_classes[argument_index])
		if actual_type == expected_type and actual_class == expected_class:
			continue
		_validation_errors.append("Quality operation handler '%s' hook %s argument %d expected %s, found %s." % [
			handler_id,
			String(hook),
			argument_index,
			_metadata_type_name(expected_type, expected_class),
			_metadata_type_name(actual_type, actual_class),
		])
	_validate_method_return(handler, handler_id, hook, int(HOOK_RETURN_TYPES.get(String(hook), -1)))


func _validate_method_return(
	handler: RefCounted,
	handler_id: String,
	method_name: StringName,
	expected_type: int
) -> void:
	var method := _method_metadata(handler, method_name)
	var return_metadata := Dictionary(method.get("return", {}))
	var actual_type := int(return_metadata.get("type", -1))
	var actual_class := StringName(return_metadata.get("class_name", ""))
	if actual_type == expected_type and actual_class == &"":
		return
	_validation_errors.append("Quality operation handler '%s' method %s return expected %s, found %s." % [
		handler_id,
		String(method_name),
		_metadata_type_name(expected_type, &""),
		_metadata_type_name(actual_type, actual_class),
	])


func _metadata_type_name(type_code: int, class_name_value: StringName) -> String:
	if type_code == TYPE_OBJECT and class_name_value != &"":
		return String(class_name_value)
	if type_code < TYPE_NIL or type_code >= TYPE_MAX:
		return "unknown"
	return type_string(type_code)


func _method_argument_count(handler: RefCounted, method_name: StringName) -> int:
	return Array(_method_metadata(handler, method_name).get("args", [])).size()


func _method_metadata(handler: RefCounted, method_name: StringName) -> Dictionary:
	for method_value in handler.get_method_list():
		var method := Dictionary(method_value)
		if StringName(method.get("name", "")) == method_name:
			return method
	return {}


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
