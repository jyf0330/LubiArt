extends RefCounted

const ScriptPluginRegistryScript := preload("res://core/plugins/script_plugin_registry.gd")

const HANDLER_DIRECTORY := "res://core/battle/mechanics/handlers"
const ALLOWED_HOOKS: Array[StringName] = [
	&"on_battle_start",
	&"before_damage",
	&"after_damage",
	&"after_hit",
	&"after_cross_damage",
	&"attacker_after_hit",
	&"after_element",
	&"on_death",
	&"on_shield_break",
	&"after_ally_death",
	&"after_kill",
	&"after_action",
	&"battle_end",
	&"round_start",
	&"round_end",
	&"project_element_settlement",
	&"project_trap_entry",
	&"project_threat_redirect",
	&"project_death_preview",
]

# The damage/element arities follow the live Service inputs. This keeps
# DamageProps semantic and passes element, direction, target and cell explicitly.
const HOOK_ARITIES := {
	"on_battle_start": 3,
	"before_damage": 7,
	"after_damage": 6,
	"after_hit": 6,
	"after_cross_damage": 7,
	"attacker_after_hit": 7,
	"after_element": 7,
	"on_death": 4,
	"on_shield_break": 4,
	"after_ally_death": 4,
	"after_kill": 4,
	"after_action": 3,
	"battle_end": 5,
	"round_start": 4,
	"round_end": 4,
	"project_element_settlement": 3,
	"project_trap_entry": 3,
	"project_threat_redirect": 3,
	"project_death_preview": 3,
}
const HOOK_ARGUMENT_TYPES := {
	"on_battle_start": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"before_damage": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_INT, TYPE_STRING, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_damage": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_INT, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_hit": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_INT, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_cross_damage": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_INT, TYPE_STRING, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"attacker_after_hit": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_INT, TYPE_STRING, TYPE_STRING, TYPE_DICTIONARY],
	"after_element": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_STRING, TYPE_INT, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"on_death": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"on_shield_break": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_ally_death": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_kill": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"after_action": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"battle_end": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_BOOL, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"round_start": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_STRING, TYPE_DICTIONARY],
	"round_end": [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_STRING, TYPE_DICTIONARY],
	"project_element_settlement": [TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"project_trap_entry": [TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"project_threat_redirect": [TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
	"project_death_preview": [TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY],
}
const HOOK_ARGUMENT_CLASSES := {
	"on_battle_start": [&"RefCounted", &"", &""],
	"before_damage": [&"RefCounted", &"", &"", &"", &"", &"", &""],
	"after_damage": [&"RefCounted", &"", &"", &"", &"", &""],
	"after_hit": [&"RefCounted", &"", &"", &"", &"", &""],
	"after_cross_damage": [&"RefCounted", &"", &"", &"", &"", &"", &""],
	"attacker_after_hit": [&"RefCounted", &"", &"", &"", &"", &"", &""],
	"after_element": [&"RefCounted", &"", &"", &"", &"", &"", &""],
	"on_death": [&"RefCounted", &"", &"", &""],
	"on_shield_break": [&"RefCounted", &"", &"", &""],
	"after_ally_death": [&"RefCounted", &"", &"", &""],
	"after_kill": [&"RefCounted", &"", &"", &""],
	"after_action": [&"RefCounted", &"", &""],
	"battle_end": [&"RefCounted", &"", &"", &"", &""],
	"round_start": [&"RefCounted", &"", &"", &""],
	"round_end": [&"RefCounted", &"", &"", &""],
	"project_element_settlement": [&"", &"", &""],
	"project_trap_entry": [&"", &"", &""],
	"project_threat_redirect": [&"", &"", &""],
	"project_death_preview": [&"", &"", &""],
}
const HOOK_RETURN_TYPES := {
	"on_battle_start": TYPE_ARRAY,
	"before_damage": TYPE_DICTIONARY,
	"after_damage": TYPE_ARRAY,
	"after_hit": TYPE_ARRAY,
	"after_cross_damage": TYPE_ARRAY,
	"attacker_after_hit": TYPE_ARRAY,
	"after_element": TYPE_ARRAY,
	"on_death": TYPE_ARRAY,
	"on_shield_break": TYPE_ARRAY,
	"after_ally_death": TYPE_ARRAY,
	"after_kill": TYPE_ARRAY,
	"after_action": TYPE_ARRAY,
	"battle_end": TYPE_DICTIONARY,
	"round_start": TYPE_ARRAY,
	"round_end": TYPE_ARRAY,
	"project_element_settlement": TYPE_DICTIONARY,
	"project_trap_entry": TYPE_DICTIONARY,
	"project_threat_redirect": TYPE_DICTIONARY,
	"project_death_preview": TYPE_DICTIONARY,
}
const PLUGIN_ID_ARITY := 0
const PLUGIN_ID_RETURN_TYPE := TYPE_STRING

var _plugins: RefCounted
var _validation_errors: Array[String] = []


func _init(directory: String = HANDLER_DIRECTORY) -> void:
	_validate_plugin_id_signatures(directory)
	if not _validation_errors.is_empty():
		return
	_plugins = ScriptPluginRegistryScript.new().configure(directory)
	_validation_errors.append_array(_plugins.validation_errors())
	if not _validation_errors.is_empty():
		return
	for handler_value in _plugins.plugins():
		_validate_handler(handler_value as RefCounted)


func handler_for(mechanism_id: String, mechanism: Dictionary) -> RefCounted:
	if not is_valid():
		return null
	var handler_id := String(mechanism.get("runtime_handler", mechanism_id))
	if handler_id == "":
		return null
	return _plugins.plugin(handler_id) as RefCounted


func supports(handler: RefCounted, hook: StringName) -> bool:
	return is_valid() and handler != null and ALLOWED_HOOKS.has(hook) and handler.has_method(hook)


func is_valid() -> bool:
	return _plugins != null and _plugins.is_valid() and _validation_errors.is_empty()


func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func _validate_handler(handler: RefCounted) -> void:
	if handler == null:
		_validation_errors.append("Mechanic handler failed to instantiate.")
		return
	var handler_id := String(handler.call(&"plugin_id"))
	_validate_method_return(handler, handler_id, &"plugin_id", PLUGIN_ID_RETURN_TYPE)
	var supported_count := 0
	for hook in ALLOWED_HOOKS:
		if not handler.has_method(hook):
			continue
		supported_count += 1
		var actual_arity := _method_argument_count(handler, hook)
		var expected_arity := int(HOOK_ARITIES.get(String(hook), -1))
		if actual_arity != expected_arity:
			_validation_errors.append("Mechanic handler '%s' hook %s expected %d arguments, found %d." % [
				handler_id,
				String(hook),
				expected_arity,
				actual_arity,
			])
			continue
		_validate_hook_signature(handler, handler_id, hook)
	if supported_count <= 0:
		_validation_errors.append("Mechanic handler '%s' must declare at least one allowed hook." % handler_id)
	for method_name in _script_method_names(handler):
		if method_name == &"plugin_id" or ALLOWED_HOOKS.has(method_name) or String(method_name).begins_with("_"):
			continue
		_validation_errors.append("Mechanic handler '%s' declares unknown hook '%s'." % [handler_id, String(method_name)])


func _validate_plugin_id_signatures(directory: String) -> void:
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
		var actual_arity := Array(method.get("args", [])).size()
		if actual_arity != PLUGIN_ID_ARITY:
			_validation_errors.append("Mechanic handler in '%s/%s' method plugin_id expected %d arguments, found %d." % [
				normalized_directory,
				file_name,
				PLUGIN_ID_ARITY,
				actual_arity,
			])
			continue
		var return_metadata := Dictionary(method.get("return", {}))
		var actual_type := int(return_metadata.get("type", -1))
		var actual_class := StringName(return_metadata.get("class_name", ""))
		if actual_type == PLUGIN_ID_RETURN_TYPE and actual_class == &"":
			continue
		_validation_errors.append("Mechanic handler in '%s/%s' method plugin_id return expected %s, found %s." % [
			normalized_directory,
			file_name,
			_metadata_type_name(PLUGIN_ID_RETURN_TYPE, &""),
			_metadata_type_name(actual_type, actual_class),
		])


func _validate_hook_signature(handler: RefCounted, handler_id: String, hook: StringName) -> void:
	var method := _method_metadata(handler, hook)
	var arguments := Array(method.get("args", []))
	var expected_types := Array(HOOK_ARGUMENT_TYPES.get(String(hook), []))
	var expected_classes := Array(HOOK_ARGUMENT_CLASSES.get(String(hook), []))
	for argument_index in expected_types.size():
		var argument := Dictionary(arguments[argument_index])
		var actual_type := int(argument.get("type", -1))
		var actual_class := StringName(argument.get("class_name", ""))
		var expected_type := int(expected_types[argument_index])
		var expected_class := StringName(expected_classes[argument_index])
		if actual_type == expected_type and actual_class == expected_class:
			continue
		_validation_errors.append("Mechanic handler '%s' hook %s argument %d expected %s, found %s." % [
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
	_validation_errors.append("Mechanic handler '%s' method %s return expected %s, found %s." % [
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
