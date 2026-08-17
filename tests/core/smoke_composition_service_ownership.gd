extends SceneTree

const CoreCompositionScript := preload("res://core/composition/core_composition.gd")

const ROOT_PATH := "res://core/composition/core_composition.gd"
const REMOVED_COMPOSITION_ENTRY := "stat_catalog_service"

const DIRECT_CONSUMERS := {
	"mechanic_projection_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.mechanic_projection_service.element_settlement_plan"},
	"round_lifecycle_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.round_lifecycle_service.run_start"},
	"damage_mechanic_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.damage_mechanic_service.apply_battle_start"},
	"damage_death_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.damage_death_service.resolve"},
	"summon_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.summon_service.summon_unit_on_cell"},
	"unit_lifecycle_mechanic_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.unit_lifecycle_mechanic_service.apply_on_death"},
	"element_mechanic_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.element_mechanic_service.apply_after_element"},
	"battle_session": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.battle_session.run_combat_round"},
	"snapshot_projector": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.snapshot_projector.project"},
	"command_response_builder": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.command_response_builder.build"},
	"save_repository": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.save_repository.write_slot"},
	"replay_repository": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.replay_repository.write_document"},
	"run_history_repository": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.run_history_repository.list_runs"},
	"game_data_repository": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.game_data_repository"},
	"operation_log_repository": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.operation_log_repository.append"},
	"player_turn_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.player_turn_service.run_all_out"},
	"enemy_turn_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.enemy_turn_service.run"},
	"pet_reset_policy": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.pet_reset_policy.initial_state"},
	"battle_outcome_policy": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.battle_outcome_policy.base_result"},
	"battle_startup_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.battle_startup_service.prepare_player_deployment"},
	"run_automation_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.run_automation_service.run_full_day"},
	"skill_queue_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.skill_queue_service.catalog_skill_ids"},
	"action_slot_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.action_slot_service.set_direction"},
	"skill_execution_service": {"path": "res://core/ports/player_turn_port.gd", "needle": "composition.skill_execution_service.execute"},
	"skill_combo_service": {"path": "res://core/ports/player_turn_port.gd", "needle": "composition.skill_combo_service.matches_at"},
	"quality_effect_registry": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.quality_effect_registry.effect_for_unit"},
	"quality_runtime_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.quality_runtime_service.mode_options"},
	"run_event_definition_registry": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.run_event_definition_registry.operations_for_event"},
	"run_event_effect_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.run_event_effect_service.execute"},
	"trait_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.trait_service.entries"},
	"status_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.status_service.normalized"},
	"battle_hook_pipeline": {"path": "res://core/ports/round_lifecycle_port.gd", "needle": "composition.get(\"battle_hook_pipeline\")"},
	"effect_target_resolver": {"path": "res://core/ports/skill_effect_port.gd", "needle": "composition.effect_target_resolver.targets"},
	"stat_query_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.stat_query_service.resolve_all"},
	"stat_semantic_pipeline": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.stat_semantic_pipeline.apply"},
	"relic_combat_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.relic_combat_service.start(RelicCombatPortScript.new(self))"},
	"attack_option_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.attack_option_service.build_options"},
	"targeting_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.targeting_service.targets_in_option"},
	"quality_hit_context_projector": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.quality_hit_context_projector.core_cell_index"},
	"threat_target_policy": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.threat_target_policy.select"},
	"save_document_builder": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.save_document_builder.build"},
	"run_history_committer": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.run_history_committer.record"},
	"content_load_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.content_load_service.load"},
	"content_object_registry": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.content_object_registry"},
	"simulation_authority_factory": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.simulation_authority_factory"},
	"manual_flow_simulation_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.manual_flow_simulation_service.preview"},
	"quality_progression_policy": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.quality_progression_policy.progress"},
	"battle_query_projector": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.battle_query_projector.project_board"},
	"auto_position_evaluator": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.auto_position_evaluator"},
	"player_operation_projector": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.player_operation_projector"},
	"replay_verifier": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.replay_verifier.verify"},
}

const INJECTED_ONLY_CONSUMERS := {
	"mechanic_handler_registry": {
		"wire": "mechanic_projection_service.call(&\"configure\", mechanic_handler_registry)",
		"path": "res://core/battle/mechanics/mechanic_projection_service.gd",
		"assignment": "_handler_registry = registry",
		"needle": "_handler_registry.call(&\"handler_for\"",
	},
	"stat_resolver": {
		"wire": "stat_query_service.call(&\"configure\", stat_resolver, modifier_collector)",
		"path": "res://core/stats/stat_query_service.gd",
		"assignment": "_stat_resolver = stat_resolver",
		"needle": "_stat_resolver.resolve",
	},
	"condition_evaluator": {
		"wire": "effect_interpreter.call(&\"configure\", condition_evaluator)",
		"path": "res://core/effects/effect_interpreter.gd",
		"assignment": "_condition_evaluator = condition_evaluator",
		"needle": "_condition_evaluator.matches",
	},
	"effect_interpreter": {
		"wire": "battle_hook_pipeline.call(&\"configure\", modifier_collector, effect_interpreter)",
		"path": "res://core/effects/battle_hook_pipeline.gd",
		"assignment": "_effect_interpreter = effect_interpreter",
		"needle": "_effect_interpreter.execute",
	},
	"modifier_collector": {
		"wire": "stat_query_service.call(&\"configure\", stat_resolver, modifier_collector)",
		"path": "res://core/stats/stat_query_service.gd",
		"assignment": "_modifier_collector = modifier_collector",
		"needle": "_modifier_collector.collect",
	},
	"relic_catalog_service": {
		"wire": "relic_combat_service.call(&\"configure\", relic_catalog_service, effect_interpreter)",
		"path": "res://core/battle/relics/relic_combat_service.gd",
		"assignment": "_catalog_service = catalog_service",
		"needle": "_catalog_service.inventory_entries",
	},
	"damage_resolver": {
		"wire": "\n\t\t\tdamage_resolver,\n",
		"path": "res://core/commands/battle_query_projector.gd",
		"assignment": "_damage_resolver = damage_resolver",
		"needle": "_damage_resolver.call(",
	},
}

const MECHANIC_REGISTRY_CONSUMERS := {
	"round_lifecycle_service": {
		"path": "res://core/battle/round_lifecycle_service.gd",
		"wire": "round_lifecycle_service.call(&\"configure_handler_registry\", mechanic_handler_registry)",
	},
	"damage_mechanic_service": {
		"path": "res://core/battle/mechanics/damage_mechanic_service.gd",
		"wire": "damage_mechanic_service.call(&\"configure_handler_registry\", mechanic_handler_registry)",
	},
	"unit_lifecycle_mechanic_service": {
		"path": "res://core/battle/mechanics/unit_lifecycle_mechanic_service.gd",
		"wire": "unit_lifecycle_mechanic_service.call(&\"configure_handler_registry\", mechanic_handler_registry)",
	},
	"element_mechanic_service": {
		"path": "res://core/battle/mechanics/element_mechanic_service.gd",
		"wire": "element_mechanic_service.call(&\"configure_handler_registry\", mechanic_handler_registry)",
	},
	"mechanic_projection_service": {
		"path": "res://core/battle/mechanics/mechanic_projection_service.gd",
		"wire": "mechanic_projection_service.call(&\"configure\", mechanic_handler_registry)",
	},
}

var failed := false


func _initialize() -> void:
	var composition := CoreCompositionScript.new()
	var services := Dictionary(composition.services())
	var root_source := FileAccess.get_file_as_string(ROOT_PATH)
	var expected_names: Array[String] = []

	for service_value in DIRECT_CONSUMERS:
		var service_name := String(service_value)
		_expect(not expected_names.has(service_name), "direct service is audited once: %s" % service_name)
		expected_names.append(service_name)
		_expect(services.has(service_name), "direct service remains composed: %s" % service_name)
		_expect(services.get(service_name) is RefCounted, "direct service resolves to RefCounted: %s" % service_name)
		var evidence := Dictionary(DIRECT_CONSUMERS[service_name])
		_expect(_source_contains(String(evidence["path"]), String(evidence["needle"])), "direct consumer exists for %s" % service_name)

	for service_value in INJECTED_ONLY_CONSUMERS:
		var service_name := String(service_value)
		_expect(not expected_names.has(service_name), "injected-only service is not also classified direct: %s" % service_name)
		expected_names.append(service_name)
		_expect(services.has(service_name), "injected-only service remains composed: %s" % service_name)
		_expect(services.get(service_name) is RefCounted, "injected-only service resolves to RefCounted: %s" % service_name)
		var evidence := Dictionary(INJECTED_ONLY_CONSUMERS[service_name])
		_expect(root_source.contains(String(evidence["wire"])), "composition wire exists for injected-only service: %s" % service_name)
		_expect(_source_contains(String(evidence["path"]), String(evidence["assignment"])), "configure stores injected-only service: %s" % service_name)
		_expect(_source_contains(String(evidence["path"]), String(evidence["needle"])), "downstream consumer exists for injected-only service: %s" % service_name)

	var mechanic_registry: RefCounted = services.get("mechanic_handler_registry") as RefCounted
	var mechanic_projection: RefCounted = services.get("mechanic_projection_service") as RefCounted
	_expect(mechanic_registry != null, "composition owns the single mechanic handler registry")
	for service_value in MECHANIC_REGISTRY_CONSUMERS:
		var service_name := String(service_value)
		var service: RefCounted = services.get(service_name) as RefCounted
		var evidence := Dictionary(MECHANIC_REGISTRY_CONSUMERS[service_name])
		_expect(root_source.contains(String(evidence["wire"])), "composition wires the shared mechanic registry into %s" % service_name)
		_expect(_source_contains(String(evidence["path"]), "_handler_registry = registry"), "%s stores the injected mechanic registry" % service_name)
		_expect(service != null and service.get("_handler_registry") == mechanic_registry, "%s receives the exact composed mechanic registry instance" % service_name)
	_expect(
		services.get("battle_query_projector").get("_mechanic_projection_service") == mechanic_projection,
		"BattleQueryProjector receives the exact composed mechanic projection service"
	)
	_expect(
		services.get("auto_position_evaluator").get("_mechanic_projection_service") == mechanic_projection,
		"AutoPositionEvaluator receives the exact composed mechanic projection service"
	)

	var actual_names: Array[String] = []
	for service_value in services:
		actual_names.append(String(service_value))
	actual_names.sort()
	expected_names.sort()
	var root_fields := _root_ref_counted_fields(root_source)
	var resolve_left_names: Array[String] = []
	var resolve_key_names: Array[String] = []
	for pair_value in _root_resolve_pairs(root_source):
		var pair := Dictionary(pair_value)
		var left_name := String(pair.get("left", ""))
		var key_name := String(pair.get("key", ""))
		_expect(left_name == key_name, "composition resolve field and override key match: %s/%s" % [left_name, key_name])
		resolve_left_names.append(left_name)
		resolve_key_names.append(key_name)
	root_fields.sort()
	resolve_left_names.sort()
	resolve_key_names.sort()
	_expect(root_fields == expected_names, "every root RefCounted field has exactly one audited ownership class")
	_expect(resolve_left_names == expected_names, "every root _resolve assignment has exactly one audited ownership class")
	_expect(resolve_key_names == expected_names, "every root override key has exactly one audited ownership class")
	_expect(actual_names == expected_names, "every services() key has exactly one audited ownership class")

	_expect(not services.has(REMOVED_COMPOSITION_ENTRY), "zero-consumer stat catalog composition entry stays removed")
	_expect(not root_source.contains("StatCatalogServiceScript"), "composition root no longer loads the internally owned stat catalog")
	_expect(not root_source.contains("stat_catalog_service"), "composition root no longer exposes or resolves stat catalog service")
	var resolver_source := FileAccess.get_file_as_string("res://core/stats/stat_resolver.gd")
	_expect(resolver_source.contains("const StatCatalogServiceScript := preload"), "StatResolver retains the real stat catalog implementation")
	_expect(resolver_source.contains("var _catalog_service := StatCatalogServiceScript.new()"), "StatResolver owns its catalog helper directly")
	_expect(resolver_source.contains("_catalog_service.definition") and resolver_source.contains("_catalog_service.base_value"), "StatResolver actively consumes the retained catalog helper")

	if failed:
		quit(1)
		return
	print("SMOKE_COMPOSITION_SERVICE_OWNERSHIP_OK services=%d direct=%d injected_only=%d removed=%s" % [
		services.size(),
		DIRECT_CONSUMERS.size(),
		INJECTED_ONLY_CONSUMERS.size(),
		REMOVED_COMPOSITION_ENTRY,
	])
	quit(0)


func _source_contains(path: String, needle: String) -> bool:
	return FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).contains(needle)


func _root_ref_counted_fields(root_source: String) -> Array[String]:
	var result: Array[String] = []
	for line_value in root_source.split("\n"):
		var line := String(line_value)
		if not line.begins_with("var ") or not line.ends_with(": RefCounted = null"):
			continue
		result.append(line.trim_prefix("var ").get_slice(":", 0))
	return result


func _root_resolve_pairs(root_source: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	const MARKER := " = _resolve(overrides, &\""
	for line_value in root_source.split("\n"):
		var line := String(line_value).strip_edges()
		if not line.contains(MARKER):
			continue
		var parts := line.split(MARKER, false, 1)
		if parts.size() != 2:
			continue
		result.append({
			"left": String(parts[0]),
			"key": String(parts[1]).get_slice("\"", 0),
		})
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
