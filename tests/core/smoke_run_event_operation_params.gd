extends SceneTree

const RegistryScript := preload("res://core/run/events/run_event_operation_registry.gd")

var _failed := false


func _initialize() -> void:
	var registry: RefCounted = RegistryScript.new()
	_expect(registry.is_valid(), "production registry is available for semantic validation")
	_verify(registry, "noop", [{}], [{"unknown": true}, {"__reserved": true}])
	for operation_id in ["spend_coins", "add_coins", "heal_hero"]:
		_verify(registry, operation_id, [{"amount": 0}, {"amount": 7}], [
			{}, {"amount": -1}, {"amount": 1.0}, {"amount": 1, "unknown": true},
		])
	for operation_id in ["queue_battle_prep_shield", "queue_trap_damage_bonus"]:
		_verify(registry, operation_id, [{"amount": 0}, {"amount": 2}], [
			{}, {"amount": -1}, {"amount": "2"}, {"amount": 1, "__reserved": true},
		])
	_verify(registry, "queue_reward_gold_multiplier", [{"percent": 0}, {"percent": 99}], [
		{}, {"percent": -1}, {"percent": 100}, {"percent": 90.0}, {"percent": 90, "unknown": true},
	])
	_verify(registry, "add_free_refreshes", [{"amount": 1}, {"amount": 4}], [
		{}, {"amount": 0}, {"amount": -1}, {"amount": true},
	])
	_verify(registry, "set_next_discount", [{"percent": 1}, {"percent": 100}], [
		{}, {"percent": 0}, {"percent": 101}, {"percent": "50"},
	])
	for operation_id in ["upgrade_first_eligible_pet", "duplicate_first_pet"]:
		_verify(registry, operation_id, [{}], [{"target": 0}, {"__authority": true}])
	_verify(registry, "refill_shop_pool", [
		{"pool_id": "pool_a", "minimum_slots": 3},
		{"pool_id": "pool_unknown_but_allowed", "minimum_slots": 10},
	], [
		{},
		{"pool_id": "", "minimum_slots": 3},
		{"pool_id": "pool", "minimum_slots": 2},
		{"pool_id": "pool", "minimum_slots": 11},
		{"pool_id": 7, "minimum_slots": 3},
		{"pool_id": "pool", "minimum_slots": 3.0},
		{"pool_id": "pool", "minimum_slots": 3, "unknown": true},
	])
	_verify(registry, "select_reward_pool", [{"pool_id": "reward_a"}], [
		{}, {"pool_id": ""}, {"pool_id": 1}, {"pool_id": "reward", "__reserved": true},
	])
	if _failed:
		quit(1)
		return
	print("SMOKE_RUN_EVENT_OPERATION_PARAMS_OK operations=13")
	quit(0)


func _verify(registry: RefCounted, operation_id: String, valid_cases: Array, invalid_cases: Array) -> void:
	for params_value in valid_cases:
		var errors_value: Variant = registry.validate_params(operation_id, Dictionary(params_value))
		_expect(errors_value is Array and Array(errors_value).is_empty(), "%s accepts %s" % [operation_id, str(params_value)])
	for params_value in invalid_cases:
		var errors_value: Variant = registry.validate_params(operation_id, Dictionary(params_value))
		_expect(errors_value is Array and not Array(errors_value).is_empty(), "%s rejects %s" % [operation_id, str(params_value)])
		if errors_value is Array:
			for error_value in Array(errors_value):
				_expect(typeof(error_value) == TYPE_STRING and String(error_value).strip_edges() != "", "%s returns non-empty String errors" % operation_id)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_RUN_EVENT_OPERATION_PARAMS_FAIL: %s" % label)
