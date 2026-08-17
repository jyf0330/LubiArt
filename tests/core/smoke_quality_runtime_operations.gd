extends SceneTree

const RegistryScript := preload("res://core/battle/quality/quality_effect_registry.gd")
const LegacyCatalogScript := preload("res://core/battle/quality/legacy_quality_runtime_catalog.gd")

var _failed := false


func _initialize() -> void:
	var registry: QualityEffectRegistry = RegistryScript.new()
	var legacy_prepared := registry.prepare_configuration(
		LegacyCatalogScript.upgrades(),
		0,
		RegistryScript.PERSISTED_SNAPSHOT
	)
	_expect(bool(legacy_prepared.get("ok", false)), "legacy fixture configuration prepares explicitly")
	registry.commit_configuration(Dictionary(legacy_prepared.get("candidate", {})))
	_expect(registry.is_configured(), "legacy fixture configuration commits explicitly")
	_expect(registry.is_configured(), "legacy bootstrap configures atomically")
	_expect(registry.validation_errors().is_empty(), "legacy bootstrap has no validation errors")
	_expect(registry.registered_effect_ids().size() == 68, "legacy bootstrap contains exactly 68 effects")
	for effect_id in registry.registered_effect_ids():
		var operations := registry.effect_for_id(effect_id).runtime_operations()
		_expect(not operations.is_empty(), "%s has at least one typed operation" % effect_id)
		_expect(_is_stably_sorted(operations), "%s operations use the frozen stable order" % effect_id)

	var old_golden := registry.effect_for_id("G03").modify_hit_damage({"damage": 5, "core_cell": true})
	var prepared := registry.prepare_configuration([{
		"id": "fixture_quality",
		"runtime_operations": [
			_operation("fixture.add", "modify_hit_damage", "damage_add_when", 200, {"when": {}, "value": 1}),
			_operation("fixture.multiply", "modify_hit_damage", "damage_multiply_when", 100, {"when": {}, "value": 2}),
		],
	}], 1, &"current_assembly")
	_expect(bool(prepared.get("ok", false)), "detached modern candidate validates")
	_expect(registry.effect_for_id("fixture_quality").effect_id == "", "prepare does not partially publish candidate")
	_expect(registry.effect_for_id("G03").modify_hit_damage({"damage": 5, "core_cell": true}) == old_golden, "prepare leaves active bootstrap unchanged")
	registry.commit_configuration(Dictionary(prepared.get("candidate", {})))
	_expect(registry.effect_for_id("fixture_quality").modify_hit_damage({"damage": 5}) == 11, "priority order executes multiply before add")
	var local_ids := registry.prepare_configuration([
		{"id": "local_a", "runtime_operations": [_operation("shared.local", "profile", "boolean_profile", 100, {"preview_damage": false})]},
		{"id": "local_b", "runtime_operations": [_operation("shared.local", "profile", "boolean_profile", 100, {"preview_damage": false})]},
	], 1, &"current_assembly")
	_expect(bool(local_ids.get("ok", false)), "operation ids are unique within each upgrade rather than globally")
	var semantic_defaults := registry.prepare_configuration([
		{"id": "negative_add", "runtime_operations": [_operation("negative.add", "modify_hit_damage", "damage_add_when", 100, {"value": -2})]},
		{"id": "zero_multiply", "runtime_operations": [_operation("zero.multiply", "modify_hit_damage", "damage_multiply_when", 100, {"value": 0})]},
		{"id": "zero_scale", "runtime_operations": [_operation("zero.scale", "modify_hit_damage", "damage_scale_ceil_when", 100, {"numerator": 0, "denominator": 1})]},
		{"id": "trace_defaults", "runtime_operations": [_operation("trace.defaults", "after_attack", "fire_trace", 100, {})]},
		{"id": "mode_without_aliases", "runtime_operations": [_operation("mode.without_aliases", "profile", "mode_profile", 100, {"options": ["攻"]})]},
	], 1, &"current_assembly")
	_expect(bool(semantic_defaults.get("ok", false)), "handler-supported defaults, zero ranges, and negative damage delta validate")

	_verify_invalid_candidate(registry, [{
		"id": "unknown_operation",
		"runtime_operations": [_operation("unknown.op", "modify_hit_damage", "missing_handler", 100, {})],
	}], "unknown operation")
	_verify_invalid_candidate(registry, [{
		"id": "unknown_hook",
		"runtime_operations": [_operation("unknown.hook", "during_attack", "damage_add_when", 100, {})],
	}], "unknown hook")
	_verify_invalid_candidate(registry, [{
		"id": "duplicate_operation",
		"runtime_operations": [
			_operation("duplicate.id", "profile", "boolean_profile", 100, {"preview_damage": false}),
			_operation("duplicate.id", "profile", "boolean_profile", 100, {"preview_damage": false}),
		],
	}], "duplicate operation id")
	_verify_invalid_candidate(registry, [{
		"id": "bad_params",
		"runtime_operations": [_operation("bad.params", "profile", "boolean_profile", 100, {"bad": Vector2i.ONE})],
	}], "non JSON params")
	_verify_invalid_candidate(registry, [{
		"id": "damage_wrong_type",
		"runtime_operations": [_operation("damage.wrong_type", "modify_hit_damage", "damage_add_when", 100, {"when": [], "value": 1})],
	}], "damage wrong-type params")
	_verify_invalid_candidate(registry, [{
		"id": "damage_bad_range",
		"runtime_operations": [_operation("damage.bad_range", "modify_hit_damage", "damage_add_when", 100, {"when": {}, "value": 0})],
	}], "damage non-positive params")
	_verify_invalid_candidate(registry, [{
		"id": "damage_unknown_key",
		"runtime_operations": [_operation("damage.unknown_key", "modify_hit_damage", "damage_add_when", 100, {"when": {}, "value": 1, "extra": true})],
	}], "damage unknown-key params")
	_verify_invalid_candidate(registry, [{
		"id": "damage_missing_required",
		"runtime_operations": [_operation("damage.missing_required", "modify_hit_damage", "damage_add_when", 100, {"when": {}})],
	}], "damage missing required params")
	_verify_invalid_candidate(registry, [{
		"id": "damage_unknown_fact",
		"runtime_operations": [_operation("damage.unknown_fact", "modify_hit_damage", "damage_add_when", 100, {"when": {"never_projected": true}, "value": 1})],
	}], "damage unknown condition fact")
	_verify_invalid_candidate(registry, [{
		"id": "damage_wrong_fact_type",
		"runtime_operations": [_operation("damage.wrong_fact_type", "modify_hit_damage", "damage_add_when", 100, {"when": {"target_count": "1"}, "value": 1})],
	}], "damage wrong condition fact type")
	_verify_invalid_candidate(registry, [{
		"id": "damage_non_integer_range_fact",
		"runtime_operations": [_operation("damage.non_integer_range_fact", "modify_hit_damage", "damage_add_when", 100, {"when": {"core_cell_min": 1}, "value": 1})],
	}], "damage range suffix on non-integer fact")
	_verify_invalid_candidate(registry, [{
		"id": "mode_wrong_type",
		"runtime_operations": [_operation("mode.wrong_type", "profile", "mode_profile", 100, {"options": "攻", "aliases": {}})],
	}], "mode wrong-type params")
	_verify_invalid_candidate(registry, [{
		"id": "mode_bad_range",
		"runtime_operations": [_operation("mode.bad_range", "profile", "mode_profile", 100, {"options": [], "aliases": {}})],
	}], "mode empty options")
	_verify_invalid_candidate(registry, [{
		"id": "mode_unknown_key",
		"runtime_operations": [_operation("mode.unknown_key", "profile", "mode_profile", 100, {"options": ["攻"], "aliases": {"攻": []}, "extra": true})],
	}], "mode unknown-key params")
	_verify_invalid_candidate(registry, [{
		"id": "trace_wrong_type",
		"runtime_operations": [_operation("trace.wrong_type", "after_attack", "fire_trace", 100, {"duration": "1", "persistent": false})],
	}], "trace wrong-type params")
	_verify_invalid_candidate(registry, [{
		"id": "trace_bad_range",
		"runtime_operations": [_operation("trace.bad_range", "after_attack", "fire_trace", 100, {"duration": 0, "persistent": false})],
	}], "trace non-positive duration")
	_verify_invalid_candidate(registry, [{
		"id": "trace_unknown_key",
		"runtime_operations": [_operation("trace.unknown_key", "after_attack", "fire_trace", 100, {"duration": 1, "persistent": false, "extra": true})],
	}], "trace unknown-key params")
	_verify_invalid_candidate(registry, [{
		"id": "trace_reserved_marker_current",
		"runtime_operations": [_operation("trace.reserved.current", "after_attack", "fire_trace", 100, {"__legacy_state_schema": true})],
	}], "trace reserved legacy marker in current candidate")
	_verify_invalid_candidate(registry, [{
		"id": "trace_reserved_marker_persisted",
		"runtime_operations": [_operation("trace.reserved.persisted", "after_attack", "fire_trace", 100, {"__legacy_state_schema": true})],
	}], "trace reserved legacy marker in persisted candidate", &"persisted_snapshot")
	_verify_invalid_candidate(registry, [{
		"id": "shape_wrong_type",
		"runtime_operations": [_operation("shape.wrong_type", "mutate_shape", "shape_reverse", 100, [])],
	}], "shape non-dictionary params")
	_verify_invalid_candidate(registry, [{
		"id": "shape_unknown_key",
		"runtime_operations": [_operation("shape.unknown_key", "mutate_shape", "shape_reverse", 100, {"amount": 1})],
	}], "shape unknown-key params")
	_verify_invalid_candidate(registry, [{
		"id": "zero_operations",
		"runtime_operations": [],
	}], "zero operation effect")

	if _failed:
		quit(1)
		return
	print("SMOKE_QUALITY_RUNTIME_OPERATIONS_OK effects=68")
	quit(0)


func _verify_invalid_candidate(
	registry: QualityEffectRegistry,
	upgrades: Array,
	label: String,
	source_kind: StringName = &"current_assembly"
) -> void:
	var before := registry.effect_for_id("fixture_quality").modify_hit_damage({"damage": 5})
	var prepared := registry.prepare_configuration(upgrades, 1, source_kind)
	_expect(not bool(prepared.get("ok", false)), "%s fails closed" % label)
	_expect(Dictionary(prepared.get("candidate", {})).is_empty(), "%s exposes no partial candidate" % label)
	_expect(registry.effect_for_id("fixture_quality").modify_hit_damage({"damage": 5}) == before, "%s preserves last-good" % label)


func _operation(
	id: String,
	hook: String,
	operation: String,
	priority: int,
	params: Variant
) -> Dictionary:
	return {
		"id": id,
		"hook": hook,
		"operation": operation,
		"priority": priority,
		"params": params,
	}


func _is_stably_sorted(operations: Array) -> bool:
	for index in range(1, operations.size()):
		var previous := Dictionary(operations[index - 1])
		var current := Dictionary(operations[index])
		if _sort_key(previous) > _sort_key(current):
			return false
	return true


func _sort_key(operation: Dictionary) -> String:
	return "%012d:%012d:%012d:%s" % [
		int(operation.get("priority", 0)),
		int(operation.get("source_index", 0)),
		int(operation.get("operation_index", 0)),
		String(operation.get("id", "")),
	]


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_QUALITY_RUNTIME_OPERATIONS_FAIL: %s" % label)
