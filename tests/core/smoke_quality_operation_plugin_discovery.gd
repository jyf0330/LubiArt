extends SceneTree

const QualityOperationRegistryScript := preload("res://core/battle/quality/quality_operation_registry.gd")

const VALID_DIRECTORY := "res://tests/fixtures/plugins/quality/valid"
const EXPECTED_HOOK_ARITIES := {
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
const EXPECTED_HOOK_ARGUMENT_TYPES := {
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
const EXPECTED_HOOK_ARGUMENT_CLASSES := {
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
const EXPECTED_HOOK_RETURN_TYPES := {
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
const INVALID_CASES := {
	"res://tests/fixtures/plugins/quality/duplicate": ["fixture_quality_duplicate", "Duplicate plugin id"],
	"res://tests/fixtures/plugins/quality/zero_hook": ["fixture_quality_zero_hook", "at least one allowed hook"],
	"res://tests/fixtures/plugins/quality/wrong_arity": ["fixture_quality_wrong_arity", "modify_hit_damage expected 3 arguments, found 2"],
	"res://tests/fixtures/plugins/quality/wrong_id_arity": ["fixture_quality_wrong_id_arity", "must declare 0 arguments, found 1"],
	"res://tests/fixtures/plugins/quality/unknown_hook": ["fixture_quality_unknown_hook", "unknown hook 'during_attack'"],
	"res://tests/fixtures/plugins/quality/wrong_arg_type": ["fixture_quality_wrong_arg_type", "modify_hit_damage argument 0 expected Dictionary, found Array"],
	"res://tests/fixtures/plugins/quality/wrong_return_type": ["fixture_quality_wrong_return_type", "modify_hit_damage return expected int, found String"],
	"res://tests/fixtures/plugins/quality/wrong_id_return": ["7", "plugin_id return expected String, found int"],
	"res://tests/fixtures/plugins/quality/missing_validator": ["fixture_quality_missing_validator", "must declare _validate_params(params: Dictionary) -> Array"],
	"res://tests/fixtures/plugins/quality/wrong_validator": ["fixture_quality_wrong_validator_arity", [
		"_validate_params expected 1 arguments, found 0",
		"_validate_params argument 0 expected Dictionary, found Array",
		"_validate_params return expected Array, found Dictionary",
	]],
}

var _failed := false


func _initialize() -> void:
	_verify_contract_constants()
	_verify_discovery_and_stable_order()
	_verify_invalid_registries_fail_closed()
	if _failed:
		quit(1)
		return
	print("SMOKE_QUALITY_OPERATION_PLUGIN_DISCOVERY_OK valid=2 invalid=10")
	quit(0)


func _verify_contract_constants() -> void:
	_expect(QualityOperationRegistryScript.HOOK_ARITIES == EXPECTED_HOOK_ARITIES, "hook arities exactly match the frozen typed operation contract")
	_expect(QualityOperationRegistryScript.HOOK_ARGUMENT_TYPES == EXPECTED_HOOK_ARGUMENT_TYPES, "hook argument types exactly match the frozen typed operation contract")
	_expect(QualityOperationRegistryScript.HOOK_ARGUMENT_CLASSES == EXPECTED_HOOK_ARGUMENT_CLASSES, "hook argument classes exactly match the frozen typed operation contract")
	_expect(QualityOperationRegistryScript.HOOK_RETURN_TYPES == EXPECTED_HOOK_RETURN_TYPES, "hook return types exactly match the frozen typed operation contract")
	_expect(QualityOperationRegistryScript.PLUGIN_ID_RETURN_TYPE == TYPE_STRING, "plugin_id return type is frozen as String")
	_expect(QualityOperationRegistryScript.PARAM_VALIDATOR_METHOD == &"_validate_params", "handler param validator method is frozen")
	_expect(QualityOperationRegistryScript.PARAM_VALIDATOR_ARITY == 1, "handler param validator arity is frozen")
	_expect(QualityOperationRegistryScript.PARAM_VALIDATOR_ARGUMENT_TYPE == TYPE_DICTIONARY, "handler param validator argument type is frozen")
	_expect(QualityOperationRegistryScript.PARAM_VALIDATOR_RETURN_TYPE == TYPE_ARRAY, "handler param validator return type is frozen")
	var expected_hooks: Array[StringName] = []
	for hook_value in EXPECTED_HOOK_ARITIES.keys():
		expected_hooks.append(StringName(hook_value))
	expected_hooks.sort()
	var actual_hooks: Array[StringName] = QualityOperationRegistryScript.ALLOWED_HOOKS.duplicate()
	actual_hooks.sort()
	_expect(actual_hooks == expected_hooks, "allowed hooks exactly match the frozen typed operation contract")


func _verify_discovery_and_stable_order() -> void:
	var registry: RefCounted = QualityOperationRegistryScript.new(VALID_DIRECTORY)
	_expect(registry.is_valid(), "fixture quality operations are discovered without registry edits")
	_expect(registry.validation_errors().is_empty(), "valid fixture registry reports no errors")
	_expect(registry.ids() == ["fixture_quality_alpha", "fixture_quality_beta"], "discovered operation IDs use stable lexical ordering")
	var alpha: RefCounted = registry.handler_for("fixture_quality_alpha")
	var beta: RefCounted = registry.handler_for("fixture_quality_beta")
	_expect(alpha != null and registry.supports(alpha, &"round_start") and registry.supports(alpha, &"profile"), "one handler may expose multiple typed hooks")
	_expect(beta != null and registry.supports(beta, &"modify_hit_damage"), "a second typed hook is discovered")
	_expect(not registry.supports(alpha, &"unknown_hook"), "unknown hook support fails closed")
	_expect(registry.handler_for("unknown") == null, "unknown operation id fails closed")
	if alpha != null:
		var unit := {}
		_expect(alpha.round_start(null, unit, {"round": 3}) == ["fixture quality alpha"] and unit == {"fixture_quality_round": 3}, "discovered round_start hook preserves typed behavior")
		_expect(alpha.profile({"fixture": "profile"}) == {"fixture": "profile"}, "profile hook preserves its typed result")
	if beta != null:
		_expect(beta.modify_hit_damage({}, 7, {"amount": 2}) == 9, "discovered damage hook preserves its typed result")


func _verify_invalid_registries_fail_closed() -> void:
	for directory_value in INVALID_CASES.keys():
		var directory := String(directory_value)
		var case := Array(INVALID_CASES[directory])
		var registry: RefCounted = QualityOperationRegistryScript.new(directory)
		_expect(not registry.is_valid(), "%s invalidates the whole registry" % directory)
		_expect(registry.ids().is_empty(), "%s exposes no partial operation IDs" % directory)
		_expect(registry.handler_for(String(case[0])) == null, "%s exposes no partial handler" % directory)
		_expect(not registry.supports(null, &"round_start"), "%s exposes no hook support" % directory)
		var error_text := "\n".join(registry.validation_errors())
		var expected_errors := Array(case[1]) if case[1] is Array else [String(case[1])]
		for expected_error_value in expected_errors:
			_expect(error_text.contains(String(expected_error_value)), "%s reports its deterministic contract error" % directory)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_QUALITY_OPERATION_PLUGIN_DISCOVERY_FAIL: %s" % label)
