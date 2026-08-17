extends SceneTree

const RegistryScript := preload("res://core/battle/quality/quality_effect_registry.gd")
const LegacyCatalogScript := preload("res://core/battle/quality/legacy_quality_runtime_catalog.gd")

const INVALID_PLUGIN_DIRECTORY := "res://tests/fixtures/plugins/quality/zero_hook"

var _failed := false


func _initialize() -> void:
	var inert: QualityEffectRegistry = RegistryScript.new(INVALID_PLUGIN_DIRECTORY)
	_expect(not inert.is_configured(), "invalid plugin registry leaves first construction inert")
	_expect(not inert.validation_errors().is_empty(), "invalid first construction exposes stable errors")
	_expect(inert.effect_for_id("S01").effect_id == "", "inert registry exposes no partial legacy table")

	var registry: QualityEffectRegistry = RegistryScript.new()
	_expect(not registry.is_configured(), "valid registry remains inert before explicit content binding")
	var legacy_prepared := registry.prepare_configuration(
		LegacyCatalogScript.upgrades(),
		0,
		RegistryScript.PERSISTED_SNAPSHOT
	)
	_expect(bool(legacy_prepared.get("ok", false)), "legacy fixture configuration prepares explicitly")
	registry.commit_configuration(Dictionary(legacy_prepared.get("candidate", {})))
	_expect(registry.is_configured(), "legacy fixture configuration becomes last-good after commit")
	var original := registry.effect_for_id("G03")
	var original_damage := original.modify_hit_damage({"damage": 5, "core_cell": true})
	var candidate_source := [{
		"id": "fixture_atomic",
		"runtime_operations": [
			_operation("fixture.multiply", "modify_hit_damage", "damage_multiply_when", 100, {"when": {}, "value": 2}),
			_operation("fixture.add", "modify_hit_damage", "damage_add_when", 200, {"when": {}, "value": 1}),
		],
	}]
	var prepared := registry.prepare_configuration(candidate_source, 1, &"current_assembly")
	_expect(bool(prepared.get("ok", false)), "valid candidate prepares")
	var first_candidate := Dictionary(prepared.get("candidate", {})).duplicate()
	var replayed_candidate := first_candidate.duplicate()
	var caller_upgrade := Dictionary(candidate_source[0])
	var caller_operations := Array(caller_upgrade.get("runtime_operations", []))
	var caller_operation := Dictionary(caller_operations[0])
	var caller_params := Dictionary(caller_operation.get("params", {}))
	caller_params["value"] = 99
	caller_operation["params"] = caller_params
	caller_operations[0] = caller_operation
	caller_upgrade["runtime_operations"] = caller_operations
	candidate_source[0] = caller_upgrade
	_expect(registry.effect_for_id("G03") == original, "prepare preserves the exact active strategy object")
	_expect(registry.effect_for_id("G03").modify_hit_damage({"damage": 5, "core_cell": true}) == original_damage, "prepare cannot mutate active behavior")
	registry.commit_configuration(first_candidate)
	_expect(registry.effect_for_id("fixture_atomic").modify_hit_damage({"damage": 5}) == 11, "candidate is detached from caller-owned input")
	first_candidate["token"] = RefCounted.new()
	first_candidate["effects"] = {"forged": "mutation"}
	_expect(registry.effect_for_id("fixture_atomic").modify_hit_damage({"damage": 5}) == 11, "post-commit candidate mutation cannot reach active strategy")
	caller_params["value"] = -100
	_expect(registry.effect_for_id("fixture_atomic").modify_hit_damage({"damage": 5}) == 11, "post-commit caller mutation cannot reach active strategy")

	var stale_prepared := registry.prepare_configuration([{
		"id": "fixture_stale",
		"runtime_operations": [_operation("fixture.stale", "modify_hit_damage", "damage_add_when", 100, {"when": {}, "value": 3})],
	}], 1, &"current_assembly")
	_expect(bool(stale_prepared.get("ok", false)), "discarded candidate initially prepares")
	var second_prepared := registry.prepare_configuration([{
		"id": "fixture_second",
		"runtime_operations": [_operation("fixture.second", "modify_hit_damage", "damage_add_when", 100, {"when": {}, "value": 7})],
	}], 1, &"current_assembly")
	_expect(bool(second_prepared.get("ok", false)), "second valid candidate prepares")
	registry.commit_configuration(Dictionary(stale_prepared.get("candidate", {})))
	_expect(registry.effect_for_id("fixture_atomic").modify_hit_damage({"damage": 5}) == 11, "new prepare invalidates an older uncommitted token")
	registry.commit_configuration(Dictionary(second_prepared.get("candidate", {})))
	_expect(registry.effect_for_id("fixture_second").modify_hit_damage({"damage": 5}) == 12, "second candidate becomes last-good")
	registry.commit_configuration(replayed_candidate)
	_expect(registry.effect_for_id("fixture_second").modify_hit_damage({"damage": 5}) == 12, "consumed token cannot replay an older candidate")

	var failed := registry.prepare_configuration([{
		"id": "fixture_bad",
		"runtime_operations": [_operation("fixture.bad", "profile", "missing_operation", 100, {})],
	}], 1, &"current_assembly")
	_expect(not bool(failed.get("ok", false)), "bad rebind fails")
	_expect(registry.effect_for_id("fixture_second").modify_hit_damage({"damage": 5}) == 12, "bad rebind preserves last-good table")
	registry.commit_configuration({"not_effects": {}})
	_expect(registry.effect_for_id("fixture_second").modify_hit_damage({"damage": 5}) == 12, "malformed commit cannot replace last-good")
	registry.commit_configuration({"token": RefCounted.new()})
	_expect(registry.effect_for_id("fixture_second").modify_hit_damage({"damage": 5}) == 12, "foreign token cannot replace last-good")
	registry.commit_configuration({
		"effects": {"bad": "not-a-strategy"},
		"runtime_schema_version": 1,
		"source_kind": &"current_assembly",
	})
	_expect(registry.effect_for_id("fixture_second").modify_hit_damage({"damage": 5}) == 12, "forged effect table cannot replace last-good")
	_expect(not bool(registry.prepare_configuration(candidate_source, 0, &"current_assembly").get("ok", false)), "old runtime schema cannot masquerade as modern")
	_expect(not bool(registry.prepare_configuration(candidate_source, 1, &"").get("ok", false)), "empty source kind fails before commit")

	_verify_single_registry_wiring()
	if _failed:
		quit(1)
		return
	print("SMOKE_QUALITY_REGISTRY_ATOMIC_CONFIGURE_OK")
	quit(0)


func _verify_single_registry_wiring() -> void:
	var source := FileAccess.get_file_as_string("res://core/composition/core_composition.gd")
	_expect(source.contains("quality_runtime_service.call(&\"configure\", quality_effect_registry)"), "runtime keeps the composed registry object")
	_expect(source.contains("battle_query_projector.call("), "battle query remains a configured consumer")
	_expect(source.contains("auto_position_evaluator.call("), "auto-position remains a configured consumer")
	_expect(source.count("quality_effect_registry,") >= 2, "query and evaluator receive the same registry variable")
	var state_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	_expect(state_source.contains("_core_composition.quality_effect_registry"), "state keeps the composed registry reference")
	_expect(not source.contains("quality_effect_registry = QualityEffectRegistryScript.new()"), "binding never replaces registry outside composition construction")


func _operation(
	id: String,
	hook: String,
	operation: String,
	priority: int,
	params: Dictionary
) -> Dictionary:
	return {
		"id": id,
		"hook": hook,
		"operation": operation,
		"priority": priority,
		"params": params,
	}


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_QUALITY_REGISTRY_ATOMIC_CONFIGURE_FAIL: %s" % label)
