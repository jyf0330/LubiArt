extends SceneTree

const RegistryScript := preload("res://core/run/events/run_event_operation_registry.gd")

const VALID_DIRECTORY := "res://tests/fixtures/plugins/run_event/valid"
const EXPECTED_CANONICAL_IDS := [
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
const INVALID_CASES := {
	"res://tests/fixtures/plugins/run_event/duplicate": ["fixture_run_event_duplicate", "Duplicate plugin id"],
	"res://tests/fixtures/plugins/run_event/zero_execute": ["fixture_run_event_zero_execute", "must declare execute"],
	"res://tests/fixtures/plugins/run_event/missing_id": ["", "missing plugin_id"],
	"res://tests/fixtures/plugins/run_event/wrong_execute_arity": ["fixture_run_event_wrong_execute_arity", "execute expected 4 arguments, found 3"],
	"res://tests/fixtures/plugins/run_event/wrong_arg_type": ["fixture_run_event_wrong_arg_type", "execute argument 0 expected RefCounted, found Dictionary"],
	"res://tests/fixtures/plugins/run_event/wrong_return_type": ["fixture_run_event_wrong_return_type", "execute return expected Dictionary, found Array"],
	"res://tests/fixtures/plugins/run_event/wrong_id_arity": ["fixture_run_event_wrong_id_arity", "must declare 0 arguments, found 1"],
	"res://tests/fixtures/plugins/run_event/wrong_id_return": ["7", "plugin_id return expected String, found int"],
	"res://tests/fixtures/plugins/run_event/missing_validator": ["fixture_run_event_missing_validator", "must declare _validate_params(params: Dictionary) -> Array"],
	"res://tests/fixtures/plugins/run_event/wrong_validator": ["fixture_run_event_wrong_validator_arity", [
		"_validate_params expected 1 arguments, found 0",
		"_validate_params argument 0 expected Dictionary, found Array",
		"_validate_params return expected Array, found Dictionary",
	]],
	"res://tests/fixtures/plugins/run_event/wrong_validator_element_type": ["fixture_run_event_wrong_validator_element_type", "return expected Array[String], found Array[int]"],
	"res://tests/fixtures/plugins/run_event/unknown_hook": ["fixture_run_event_unknown_hook", "unknown public method 'during_event'"],
}

var _failed := false


func _initialize() -> void:
	_verify_frozen_contract()
	_verify_production_discovery()
	_verify_fixture_discovery()
	_verify_invalid_registries_fail_closed()
	if _failed:
		quit(1)
		return
	print("SMOKE_RUN_EVENT_OPERATION_PLUGIN_DISCOVERY_OK production=13 valid=2 invalid=12")
	quit(0)


func _verify_frozen_contract() -> void:
	_expect(RegistryScript.CANONICAL_OPERATION_IDS == EXPECTED_CANONICAL_IDS, "canonical operation IDs exactly match E0")
	_expect(RegistryScript.EXECUTE_ARITY == 4, "execute arity is frozen")
	_expect(RegistryScript.EXECUTE_ARGUMENT_TYPES == [TYPE_OBJECT, TYPE_DICTIONARY, TYPE_DICTIONARY, TYPE_DICTIONARY], "execute argument types are frozen")
	_expect(RegistryScript.EXECUTE_ARGUMENT_CLASSES == [&"RefCounted", &"", &"", &""], "execute argument classes are frozen")
	_expect(RegistryScript.EXECUTE_RETURN_TYPE == TYPE_DICTIONARY, "execute return is Dictionary")
	_expect(RegistryScript.PLUGIN_ID_RETURN_TYPE == TYPE_STRING, "plugin_id return is String")
	_expect(RegistryScript.PARAM_VALIDATOR_METHOD == &"_validate_params", "private validator method is frozen")
	_expect(RegistryScript.PARAM_VALIDATOR_ARITY == 1, "private validator arity is frozen")
	_expect(RegistryScript.PARAM_VALIDATOR_ARGUMENT_TYPE == TYPE_DICTIONARY, "private validator argument is Dictionary")
	_expect(RegistryScript.PARAM_VALIDATOR_RETURN_TYPE == TYPE_ARRAY, "private validator return is Array")
	_expect(RegistryScript.PARAM_VALIDATOR_RETURN_HINT == PROPERTY_HINT_ARRAY_TYPE, "private validator return carries an array element hint")
	_expect(RegistryScript.PARAM_VALIDATOR_RETURN_HINT_STRING == "String", "private validator return is exactly Array[String]")


func _verify_production_discovery() -> void:
	var registry: RefCounted = RegistryScript.new()
	_expect(registry.is_valid(), "production run-event operation registry is valid")
	_expect(registry.validation_errors().is_empty(), "production registry has no validation errors")
	_expect(registry.ids() == EXPECTED_CANONICAL_IDS, "production discovers exactly the 13 canonical operations")
	for operation_id in EXPECTED_CANONICAL_IDS:
		_expect(registry.handler_for(operation_id) != null, "%s resolves without registry edits" % operation_id)
	_expect(registry.handler_for("unknown") == null, "unknown operation fails closed")


func _verify_fixture_discovery() -> void:
	var registry: RefCounted = RegistryScript.new(VALID_DIRECTORY, false)
	_expect(registry.is_valid(), "valid fixtures are discovered")
	_expect(registry.ids() == ["fixture_run_event_alpha", "fixture_run_event_beta"], "fixture IDs use lexical order")
	_expect(registry.validate_params("fixture_run_event_alpha", {}) == [], "registry calls the private params validator")
	_expect(not registry.validate_params("fixture_run_event_alpha", {"unknown": true}).is_empty(), "fixture semantic params reject unknown keys")
	var handler: RefCounted = registry.handler_for("fixture_run_event_beta")
	if handler != null:
		_expect(handler.execute(null, {}, {}, {}) == {"ok": true, "code": "fixture_beta"}, "discovered fixture executes")


func _verify_invalid_registries_fail_closed() -> void:
	for directory_value in INVALID_CASES.keys():
		var directory := String(directory_value)
		var case := Array(INVALID_CASES[directory])
		var registry: RefCounted = RegistryScript.new(directory, false)
		_expect(not registry.is_valid(), "%s invalidates the whole registry" % directory)
		_expect(registry.ids().is_empty(), "%s exposes no partial IDs" % directory)
		_expect(registry.handler_for(String(case[0])) == null, "%s exposes no partial handler" % directory)
		_expect(registry.validate_params(String(case[0]), {}).is_empty(), "%s exposes no validator execution" % directory)
		var error_text := "\n".join(registry.validation_errors())
		var expected_errors := Array(case[1]) if case[1] is Array else [String(case[1])]
		for expected_error_value in expected_errors:
			_expect(error_text.contains(String(expected_error_value)), "%s reports its deterministic contract error" % directory)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_RUN_EVENT_OPERATION_PLUGIN_DISCOVERY_FAIL: %s" % label)
