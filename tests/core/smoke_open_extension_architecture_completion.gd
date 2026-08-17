extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const CoreCompositionScript := preload("res://core/composition/core_composition.gd")
const EffectInterpreterScript := preload("res://core/effects/effect_interpreter.gd")
const ScriptPluginRegistryScript := preload("res://core/plugins/script_plugin_registry.gd")
const SkillExecutionServiceScript := preload("res://core/battle/skills/skill_execution_service.gd")
const SkillEffectPortScript := preload("res://core/ports/skill_effect_port.gd")
const StatSemanticPipelineScript := preload("res://core/stats/stat_semantic_pipeline.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")

const REQUIRED_SEMANTIC_STATS: Array[String] = [
	"speed", "initiative", "element_power_permille", "boss_damage_permille",
	"crit_rate_permille", "crit_damage_permille", "lifesteal_permille",
	"block_rate_permille", "block_value", "dodge_rate_permille",
	"healing_taken_permille", "status_resist_permille", "control_resist_permille",
	"status_hit_permille", "status_duration_permille", "cooldown_rate_permille",
	"summon_power_permille", "action_cost_delta", "movement_cost_delta",
]

var failed := false


class RejectAllEvaluator extends RefCounted:
	func matches(_condition: Dictionary, _context: Dictionary) -> bool:
		return false


class ConditionalEffectPort extends RefCounted:
	var mutations := 0
	var traces := 0

	func condition_context(context: Dictionary, _effect: Dictionary) -> Dictionary:
		var result := context.duplicate(true)
		result["resolved_stats"] = {"atk": 12}
		return result

	func apply_heal(context: Dictionary, _effect: Dictionary) -> Dictionary:
		mutations += 1
		return {"applied": true, "targets": [Dictionary(context.get("unit", {}))]}

	func effect_applied(_context: Dictionary, _effect: Dictionary, _outcome: Dictionary) -> void:
		traces += 1

	func log(_message: String) -> void:
		pass


class TraitSkillPort extends RefCounted:
	var observed_trait_ids: Array = []
	var applied_effects := 0

	func game_data() -> Dictionary:
		return {}

	func condition_context(context: Dictionary, _effect: Dictionary) -> Dictionary:
		return context.duplicate(true)

	func begin_skill(unit: Dictionary, definition: Dictionary, _order_index: int, modifiers: Dictionary, source_kind: String) -> Dictionary:
		observed_trait_ids = Array(modifiers.get("trait_ids", [])).duplicate()
		return {"unit": unit, "definition": definition, "modifiers": modifiers, "source_kind": source_kind}

	func apply_physical_damage(context: Dictionary, _effect: Dictionary) -> Dictionary:
		return {"applied": true, "targets": [Dictionary(context.get("unit", {}))]}

	func effect_applied(_context: Dictionary, _effect: Dictionary, _outcome: Dictionary) -> void:
		applied_effects += 1

	func finish_skill(_context: Dictionary) -> void:
		pass

	func log(_message: String) -> void:
		pass


func _initialize() -> void:
	_verify_duplicate_plugins_fail_closed()
	_verify_invalid_plugin_contracts_fail_closed()
	_verify_shared_condition_evaluator()
	_verify_effect_conditions_and_trace()
	_verify_trait_trace_truthfulness()
	_verify_all_semantic_consumers()
	_verify_action_order_and_snapshot()
	_verify_two_sided_round_lifecycle()
	if failed:
		quit(1)
		return
	print("SMOKE_OPEN_EXTENSION_ARCHITECTURE_COMPLETION_OK")
	quit(0)


func _verify_duplicate_plugins_fail_closed() -> void:
	var registry := ScriptPluginRegistryScript.new().configure("res://tests/fixtures/plugins_duplicate")
	_expect(not registry.is_valid(), "duplicate plugin ids invalidate the registry")
	_expect(registry.ids().is_empty(), "an invalid registry exposes no partially loaded plugins")
	_expect(registry.validation_errors().size() == 1, "duplicate plugin validation reports one deterministic error")


func _verify_invalid_plugin_contracts_fail_closed() -> void:
	var registry := ScriptPluginRegistryScript.new().configure(
		"res://tests/fixtures/plugins_invalid",
		&"plugin_id",
		[&"execute"]
	)
	_expect(not registry.is_valid(), "missing plugin ids or required methods invalidate the registry")
	_expect(registry.ids().is_empty(), "invalid plugin contracts expose no partially loaded plugins")
	var errors: Array = registry.validation_errors()
	_expect(errors.size() == 2, "invalid plugin contracts report every deterministic discovery error")
	_expect(String(errors[0]).contains("missing_execute") and String(errors[1]).contains("missing_id.gd"), "plugin contract errors identify the rejected files")


func _verify_shared_condition_evaluator() -> void:
	var evaluator := RejectAllEvaluator.new()
	var composition := CoreCompositionScript.new({"condition_evaluator": evaluator})
	_expect(composition.condition_evaluator == evaluator, "composition keeps the evaluator override")
	_expect(composition.effect_interpreter.get("_condition_evaluator") == evaluator, "effect interpreter receives the shared evaluator")
	_expect(composition.stat_resolver.get("_condition_evaluator") == evaluator, "stat resolver receives the shared evaluator")
	_expect(composition.status_service.get("_condition_evaluator") == evaluator, "status service receives the shared evaluator")
	_expect(composition.trait_service.get("_condition_evaluator") == evaluator, "trait service receives the shared evaluator")


func _verify_effect_conditions_and_trace() -> void:
	var interpreter := EffectInterpreterScript.new()
	var port := ConditionalEffectPort.new()
	var context := {"unit": {"id": "condition_unit", "atk": 1}}
	_expect(interpreter.execute(port, context, [{"type": "heal", "amount": 3, "condition": {"type": "stat_compare", "stat": "atk", "operator": ">", "value": 20}}]), "false conditions skip effects without rejecting the definition")
	_expect(port.mutations == 0 and port.traces == 0, "a false effect condition produces neither mutation nor EFFECT_APPLIED")
	_expect(interpreter.execute(port, context, [{"type": "heal", "amount": 3, "condition": {"type": "stat_compare", "stat": "atk", "operator": ">=", "value": 12}}]), "true conditions execute registered effects")
	_expect(port.mutations == 1 and port.traces == 1, "a successful heal produces exactly one common effect trace callback")


func _verify_trait_trace_truthfulness() -> void:
	var interpreter := EffectInterpreterScript.new()
	var service := SkillExecutionServiceScript.new().configure(interpreter)
	var port := TraitSkillPort.new()
	var bundle := {
		"trait_ids": ["trait_true", "trait_false"],
		"trait_names": ["有效特性", "无关特性"],
		"modifiers": [
			{"type": "modify_stat", "stat": "atk", "operation": "flat_add", "value": 2, "source_type": "trait", "source_id": "trait_true"},
			{"type": "modify_stat", "stat": "movement_cost_delta", "operation": "flat_add", "value": 2, "source_type": "trait", "source_id": "trait_false"},
		],
		"trigger_effects": [],
	}
	var definition := {"id": "truthful_skill", "effects": [{"type": "physical_damage", "power_permille": 1000}]}
	_expect(service.execute(port, {"id": "trait_unit"}, definition, 0, bundle), "skill executes with a filtered trait bundle")
	_expect(port.observed_trait_ids == ["trait_true"], "only a trait consumed by the current skill is eligible for TRAIT_TRIGGERED")
	_expect(port.applied_effects == 1, "the applied skill effect reaches the common trace callback")

	var state := StateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "trait trace fixture starts battle")
	var actor := {}
	var target := {}
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if actor.is_empty() and String(unit.get("side", "")) == StateScript.PLAYER:
			actor = unit
		elif target.is_empty() and String(unit.get("side", "")) == StateScript.ENEMY:
			target = unit
	if actor.is_empty() or target.is_empty():
		_expect(false, "trait trace fixture has both sides")
		return
	var actual_port := SkillEffectPortScript.new(state)
	var actual_context := actual_port.begin_skill(actor, definition, 0, Dictionary(interpreter.relevant_bundle(actual_port, {"unit": actor, "definition": definition, "source_kind": "skill"}, bundle, Array(definition.get("effects", [])), "skill")), "skill")
	_expect(Array(actual_context.get("applied_trait_ids", [])).is_empty(), "holding an eligible trait does not immediately record TRAIT_TRIGGERED")
	actual_port.effect_applied(actual_context, {"type": "physical_damage"}, {"applied": true, "targets": [target], "consumed_stats": ["atk"]})
	_expect(Array(actual_context.get("applied_trait_ids", [])) == ["trait_true"], "a successful effect records only the trait modifier it actually consumed")
	actual_port.finish_skill(actual_context)
	var trait_trace_count := _trace_count(state.battle_trace, "TRAIT_TRIGGERED")
	_expect(trait_trace_count == 1, "the true-positive trait emits exactly one TRAIT_TRIGGERED event")
	var skipped_context := actual_port.begin_skill(actor, definition, 0, Dictionary(interpreter.relevant_bundle(actual_port, {"unit": actor, "definition": definition, "source_kind": "skill"}, bundle, Array(definition.get("effects", [])), "skill")), "skill")
	actual_port.finish_skill(skipped_context)
	_expect(_trace_count(state.battle_trace, "TRAIT_TRIGGERED") == trait_trace_count, "a skipped or false-condition effect emits no TRAIT_TRIGGERED event")


func _verify_all_semantic_consumers() -> void:
	var pipeline := StatSemanticPipelineScript.new()
	var consumed := pipeline.consumed_stat_ids()
	for stat_id in REQUIRED_SEMANTIC_STATS:
		_expect(consumed.has(stat_id), "semantic pipeline consumes %s" % stat_id)
	var source := {
		"speed": 180, "initiative": 4, "element_power_permille": 1200,
		"boss_damage_permille": 1500, "crit_rate_permille": 1000,
		"crit_damage_permille": 2000, "lifesteal_permille": 500,
		"status_hit_permille": 1000, "status_duration_permille": 1500,
		"cooldown_rate_permille": 2000, "summon_power_permille": 1500,
		"action_points": 8, "action_cost_delta": 2, "movement_cost_delta": -1,
	}
	var target := {
		"dodge_rate_permille": 0, "block_rate_permille": 1000, "block_value": 3,
		"healing_taken_permille": 1500, "status_resist_permille": 0,
		"control_resist_permille": 0,
	}
	var order := pipeline.apply("action_order", {"unit": source})
	_expect(int(order.get("speed", 0)) == 180 and int(order.get("initiative", 0)) == 4, "speed and initiative drive action order semantics")
	var outgoing := pipeline.apply("damage_outgoing", {"source": source, "target": target, "target_is_boss": true, "element": "火", "amount": 10, "event_seed": "critical"})
	_expect(int(outgoing.get("amount", 0)) == 36 and bool(outgoing.get("critical", false)), "element, boss and critical stats change outgoing damage deterministically")
	var blocked := pipeline.apply("damage_incoming", {"source": source, "target": target, "amount": 10, "event_seed": "block", "damage_props": DamagePropsScript.move_damage()})
	_expect(int(blocked.get("amount", 0)) == 7 and bool(blocked.get("blocked", false)), "block rate and block value change incoming damage")
	target["dodge_rate_permille"] = 1000
	var dodged := pipeline.apply("damage_incoming", {"source": source, "target": target, "amount": 10, "event_seed": "dodge", "damage_props": DamagePropsScript.move_damage()})
	_expect(int(dodged.get("amount", -1)) == 0 and bool(dodged.get("dodged", false)), "dodge can cancel incoming damage")
	var after_damage := pipeline.apply("damage_after", {"source": source, "target": target, "hp_damage": 10})
	_expect(int(after_damage.get("lifesteal_heal", 0)) == 5, "lifesteal derives healing from authoritative hp damage")
	_expect(int(pipeline.apply("healing", {"source": source, "target": target, "amount": 10}).get("amount", 0)) == 15, "healing taken scales authoritative healing")
	var status := pipeline.apply("status_apply", {"source": source, "target": target, "duration": 2, "status_definition": {"control": true}, "event_seed": "status"})
	_expect(bool(status.get("accepted", false)) and int(status.get("duration", 0)) == 3, "status hit, resistance, control resistance and duration are resolved together")
	_expect(int(pipeline.apply("cooldown", {"unit": source, "ticks": 4}).get("ticks", 0)) == 2, "cooldown rate changes opt-in skill cooldown ticks")
	var summon := pipeline.apply("summon", {"unit": source, "hp": 10, "atk": 4, "shield": 2})
	_expect(int(summon.get("hp", 0)) == 15 and int(summon.get("atk", 0)) == 6 and int(summon.get("shield", 0)) == 3, "summon power scales spawned combat stats")
	var action_cost := pipeline.apply("action_cost", {"unit": source, "requested": 5})
	_expect(int(action_cost.get("requested", 0)) == 5 and int(action_cost.get("cost", 0)) == 7, "action point cap and action cost delta share one consumer")
	_expect(int(pipeline.apply("movement_cost", {"unit": source, "base_cost": 3}).get("cost", 0)) == 2, "movement cost delta changes movement cost")


func _verify_action_order_and_snapshot() -> void:
	var state := StateScript.new()
	state.units = [
		{"id": "slow", "side": StateScript.PLAYER, "hp": 10, "speed": 80, "initiative": 10, "quality": "bronze"},
		{"id": "fast", "side": StateScript.PLAYER, "hp": 10, "speed": 160, "initiative": 0, "quality": "bronze"},
	]
	var ordered := Array(state.call("_sorted_action_units_for_side", StateScript.PLAYER))
	_expect(String(Dictionary(ordered[0]).get("id", "")) == "fast", "resolved speed orders real battle actors before initiative and quality")

	var snapshot_state := StateScript.new()
	_expect(snapshot_state.dispatch({"type": "START_BATTLE"}), "snapshot fixture starts battle")
	var selected := {}
	for unit_value in snapshot_state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER and int(unit.get("hp", 0)) > 0:
			selected = unit
			break
	_expect(not selected.is_empty(), "snapshot fixture has a selected player pet")
	if selected.is_empty():
		return
	selected["runtime_modifiers"] = [
		{"stat": "atk", "operation": "flat_add", "value": 7, "source_id": "snapshot_fixture_atk"},
		{"stat": "def", "operation": "flat_add", "value": 4, "source_id": "snapshot_fixture_def"},
		{"stat": "max_hp", "operation": "flat_add", "value": 9, "source_id": "snapshot_fixture_hp"},
	]
	snapshot_state.selected_unit_id = String(selected.get("id", ""))
	var expected_atk: int = int(snapshot_state.call("_resolved_stat_value", selected, "atk", {"hook": "snapshot"}))
	var expected_def: int = int(snapshot_state.call("_resolved_stat_value", selected, "def", {"hook": "snapshot"}))
	var expected_max_hp: int = int(snapshot_state.call("_resolved_stat_value", selected, "max_hp", {"hook": "snapshot"}))
	var snapshot := Dictionary(snapshot_state.snapshot())
	_expect(int(Dictionary(snapshot.get("selectedResolvedStats", {})).get("atk", -1)) == expected_atk, "selected snapshot uses the final stat query")
	var found_board_unit := false
	for cell_value in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		var cell := Dictionary(cell_value)
		if String(cell.get("unitId", "")) != String(selected.get("id", "")):
			continue
		found_board_unit = true
		_expect(int(cell.get("atk", -1)) == expected_atk, "board snapshot atk uses the final stat query")
		_expect(int(Dictionary(cell.get("resolvedStats", {})).get("atk", -1)) == expected_atk, "board snapshot exposes the same resolved stat bundle")
		break
	_expect(found_board_unit, "selected pet exists in projected board cells")
	_expect(snapshot_state.dispatch({"type": "GET_CELL_DETAIL", "x": int(selected.get("x", -1)), "y": int(selected.get("y", -1))}), "public GET_CELL_DETAIL query is accepted")
	var detail_unit := Dictionary(Dictionary(snapshot_state.last_command_result).get("unit", {}))
	_expect(int(detail_unit.get("atk", -1)) == expected_atk, "cell detail atk uses the final stat query")
	_expect(int(detail_unit.get("def", -1)) == expected_def, "cell detail def uses the final stat query")
	_expect(int(detail_unit.get("maxHp", -1)) == expected_max_hp, "cell detail maxHp uses the final stat query")
	var detail_stats := Dictionary(detail_unit.get("resolvedStats", {}))
	_expect(int(detail_stats.get("atk", -1)) == expected_atk and int(detail_stats.get("def", -1)) == expected_def and int(detail_stats.get("max_hp", -1)) == expected_max_hp, "cell detail reuses one resolvedStats bundle without a second projection path")


func _verify_two_sided_round_lifecycle() -> void:
	var state := _test_state()
	_expect(state.dispatch({"type": "START_BATTLE"}), "round lifecycle fixture starts battle")
	var status_catalog := Dictionary(state.game_data.get("status_catalog", {})).duplicate(true)
	status_catalog["status_lifecycle_probe"] = {
		"id": "status_lifecycle_probe", "name": "生命周期探针", "max_stacks": 1,
		"default_duration": 2, "duration_policy": "refresh",
		"effects": [{"hook": "round_start", "type": "heal", "amount": 3}],
	}
	var updated_content := Dictionary(state.game_data).duplicate(true)
	updated_content["status_catalog"] = status_catalog
	_expect(state.replace_game_data_for_test(updated_content, &"current_assembly"), "lifecycle fixture binds through the test-only authority helper")
	var player := {}
	var enemy := {}
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if player.is_empty() and String(unit.get("side", "")) == StateScript.PLAYER:
			player = unit
		elif enemy.is_empty() and String(unit.get("side", "")) == StateScript.ENEMY:
			enemy = unit
	if player.is_empty() or enemy.is_empty():
		_expect(false, "round lifecycle fixture has both sides")
		return
	player["statuses"] = [{"status_id": "status_lifecycle_probe", "stacks": 1, "remaining_rounds": 2}]
	enemy["statuses"] = [{"status_id": "status_lifecycle_probe", "stacks": 1, "remaining_rounds": 2}]
	enemy["max_hp"] = max(20, int(enemy.get("max_hp", 20)))
	enemy["hp"] = int(enemy.get("max_hp", 20)) - 5
	var enemy_hp_before := int(enemy.get("hp", 0))
	state.end_player_turn()
	_expect(int(Dictionary(Array(player.get("statuses", []))[0]).get("remaining_rounds", 0)) == 1, "player round_end advances player status duration")
	_expect(int(enemy.get("hp", 0)) >= enemy_hp_before + 3, "enemy round_start executes status hooks through the same pipeline")
	_expect(int(Dictionary(Array(enemy.get("statuses", []))[0]).get("remaining_rounds", 0)) == 1, "enemy round_end advances enemy status duration")


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


func _trace_count(events: Array, event_type: String) -> int:
	var result := 0
	for event_value in events:
		if String(Dictionary(event_value).get("type", "")) == event_type:
			result += 1
	return result
