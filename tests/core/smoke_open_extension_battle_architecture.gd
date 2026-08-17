extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const ScriptPluginRegistryScript := preload("res://core/plugins/script_plugin_registry.gd")
const EffectInterpreterScript := preload("res://core/effects/effect_interpreter.gd")
const ConditionEvaluatorScript := preload("res://core/effects/condition_evaluator.gd")
const StatResolverScript := preload("res://core/stats/stat_resolver.gd")
const StatusServiceScript := preload("res://core/effects/status_service.gd")

var failed := false


class FakeHookPort extends RefCounted:
	var calls: Array = []

	func apply_heal(context: Dictionary, effect: Dictionary) -> void:
		calls.append({"context": context, "effect": effect})

	func log(_message: String) -> void:
		pass


func _initialize() -> void:
	_verify_file_only_plugins()
	_verify_central_interpreters_are_open()
	_verify_modifier_and_hook_pipeline()
	_verify_authoritative_stat_reads_and_round_hooks()
	if failed:
		quit(1)
		return
	print("SMOKE_OPEN_EXTENSION_BATTLE_ARCHITECTURE_OK")
	quit(0)


func _verify_file_only_plugins() -> void:
	var fixture_registry := ScriptPluginRegistryScript.new().configure("res://tests/fixtures/plugins")
	_expect(fixture_registry.ids() == ["example_extension"], "a new script file is discovered without editing a central registry")
	var effects := EffectInterpreterScript.new().supported_types()
	for effect_id in ["physical_damage", "apply_element_layer", "heal", "grant_shield", "apply_status", "remove_status", "modify_stat"]:
		_expect(effects.has(effect_id), "effect handler is discovered: %s" % effect_id)
	var conditions := ConditionEvaluatorScript.new().supported_types()
	for condition_id in ["all", "any", "not", "unit_has_tag", "stat_compare", "roll_permille_lte"]:
		_expect(conditions.has(condition_id), "condition handler is discovered: %s" % condition_id)
	var operations := StatResolverScript.new().supported_operations()
	_expect(operations == ["clamp_max", "clamp_min", "flat_add", "multiplier", "override", "percent_add"], "stat operations are directory plugins")
	var state := StateScript.new()
	var composition: RefCounted = state.get("_core_composition")
	var targets: Array[String] = composition.effect_target_resolver.supported_types()
	for target_id in ["self", "targets", "enemies", "all", "allies", "all_enemies"]:
		_expect(targets.has(target_id), "target selector is discovered: %s" % target_id)


func _verify_central_interpreters_are_open() -> void:
	var effect_source := FileAccess.get_file_as_string("res://core/effects/effect_interpreter.gd")
	var condition_source := FileAccess.get_file_as_string("res://core/effects/condition_evaluator.gd")
	_expect(not effect_source.contains("physical_damage"), "effect interpreter has no concrete effect map")
	_expect(not condition_source.contains("hp_percent_below"), "condition evaluator has no concrete leaf-condition branches")


func _verify_modifier_and_hook_pipeline() -> void:
	var state := StateScript.new()
	var composition: RefCounted = state.get("_core_composition")
	var unit := {"id": "hook_unit", "hp": 5, "max_hp": 10, "traits": ["trait_hook"]}
	var data := {
		"trait_catalog": {
			"trait_hook": {
				"id": "trait_hook",
				"name": "触发测试",
				"effects": [
					{"hook": "always", "type": "modify_stat", "stat": "atk", "operation": "flat_add", "value": 4},
					{"hook": "before_skill", "type": "heal", "amount": 2},
				],
			},
		},
		"status_catalog": {},
	}
	var always := Dictionary(composition.modifier_collector.collect(unit, data, "snapshot", {}))
	_expect(Array(always.get("modifiers", [])).size() == 1, "always trait modifiers are collected for every stat consumer")
	var before_skill := Dictionary(composition.battle_hook_pipeline.collect(unit, data, "before_skill", {}))
	var port := FakeHookPort.new()
	_expect(composition.battle_hook_pipeline.execute(port, {"unit": unit}, before_skill), "hook pipeline executes collected trigger effects")
	_expect(port.calls.size() == 1, "trait trigger reaches its independently registered handler")


func _verify_authoritative_stat_reads_and_round_hooks() -> void:
	var state := _test_state()
	_expect(state.dispatch({"type": "START_BATTLE"}), "architecture fixture starts battle")
	var unit := {}
	for unit_value in state.units:
		var candidate := Dictionary(unit_value)
		if String(candidate.get("side", "")) == StateScript.PLAYER and int(candidate.get("hp", 0)) > 0:
			unit = candidate
			break
	_expect(not unit.is_empty(), "fixture has a living player pet")
	if unit.is_empty():
		return
	var base_move := int(state.call("_resolved_stat_value", unit, "move_range", {"hook": "movement"}))
	var base_attacks := int(state.call("_resolved_stat_value", unit, "attack_count", {"hook": "action_count"}))
	var base_atk := int(state.call("_resolved_stat_value", unit, "atk", {"hook": "normal_attack"}))
	unit["runtime_modifiers"] = [
		{"stat": "move_range", "operation": "flat_add", "value": 2, "source_id": "test_move"},
		{"stat": "attack_count", "operation": "flat_add", "value": 2, "source_id": "test_count"},
		{"stat": "atk", "operation": "flat_add", "value": 5, "source_id": "test_atk"},
	]
	_expect(int(state.call("_effective_move_range", unit)) == base_move + 2, "movement reads the common stat resolver")
	_expect(int(state.call("_enemy_attack_count", unit)) == base_attacks + 2, "action count reads the common stat resolver")
	_expect(int(state.call("_resolved_stat_value", unit, "atk", {"hook": "normal_attack"})) == base_atk + 5, "normal attack reads the common stat resolver")
	var composition: RefCounted = state.get("_core_composition")
	composition.stat_query_service.resolve_all(unit, state.game_data, "snapshot", {"cache_key": "fixture:1"})
	var cache_size := int(composition.stat_query_service.cache_size())
	composition.stat_query_service.resolve_all(unit, state.game_data, "snapshot", {"cache_key": "fixture:1"})
	_expect(cache_size == 1 and int(composition.stat_query_service.cache_size()) == 1, "settled snapshot stats reuse a revision-scoped cache")

	var status_catalog := Dictionary(state.game_data.get("status_catalog", {})).duplicate(true)
	status_catalog["status_round_heal"] = {
		"id": "status_round_heal",
		"name": "回合恢复",
		"max_stacks": 1,
		"default_duration": 2,
		"duration_policy": "refresh",
		"effects": [{"hook": "round_start", "type": "heal", "amount": 3}],
	}
	var updated_content := Dictionary(state.game_data).duplicate(true)
	updated_content["status_catalog"] = status_catalog
	_expect(state.replace_game_data_for_test(updated_content, &"current_assembly"), "status fixture binds through the test-only authority helper")
	unit["statuses"] = [{"status_id": "status_round_heal", "stacks": 1, "remaining_rounds": 2}]
	unit["hp"] = max(1, int(unit.get("hp", 1)) - 5)
	var hp_before := int(unit.get("hp", 0))
	state.call("_apply_mechanic_round_start", StateScript.PLAYER)
	_expect(int(unit.get("hp", 0)) == hp_before + 3, "round hooks execute status trigger effects through the common pipeline")

	var orphan_unit := {"statuses": [{"status_id": "removed_in_new_version", "stacks": 2, "remaining_rounds": 4}]}
	var normalized := StatusServiceScript.new().normalized(orphan_unit, {})
	_expect(normalized.size() == 1 and bool(Dictionary(normalized[0]).get("orphaned", false)), "unknown saved statuses are preserved as orphaned compatibility data")


func _test_state() -> RefCounted:
	var production := StateScript.new()
	return StateScript.new({
		"mode": "test",
		"content_pack": Dictionary(production.game_data).duplicate(true),
		"content_source_kind": production.content_source_kind(),
	})


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
