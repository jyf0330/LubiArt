extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const CoreCompositionScript := preload("res://core/composition/core_composition.gd")
const QualityStrategyScript := preload("res://core/battle/quality/quality_effect_strategy.gd")

const ROOT_PATH := "res://core/composition/core_composition.gd"
const SERVICES := {
	"mechanic_handler_registry": "res://core/battle/mechanics/mechanic_handler_registry.gd",
	"mechanic_projection_service": "res://core/battle/mechanics/mechanic_projection_service.gd",
	"round_lifecycle_service": "res://core/battle/round_lifecycle_service.gd",
	"damage_mechanic_service": "res://core/battle/mechanics/damage_mechanic_service.gd",
	"damage_death_service": "res://core/battle/mechanics/damage_death_service.gd",
	"summon_service": "res://core/battle/summons/summon_service.gd",
	"unit_lifecycle_mechanic_service": "res://core/battle/mechanics/unit_lifecycle_mechanic_service.gd",
	"element_mechanic_service": "res://core/battle/mechanics/element_mechanic_service.gd",
	"battle_session": "res://core/battle/battle_session.gd",
	"snapshot_projector": "res://core/commands/snapshot_projector.gd",
	"command_response_builder": "res://core/commands/command_response_builder.gd",
	"save_repository": "res://persistence/save_repository.gd",
	"replay_repository": "res://persistence/replay_repository.gd",
	"run_history_repository": "res://persistence/run_history_repository.gd",
	"game_data_repository": "res://persistence/game_data_repository.gd",
	"operation_log_repository": "res://persistence/operation_log_repository.gd",
	"player_turn_service": "res://core/battle/player_turn_service.gd",
	"enemy_turn_service": "res://core/battle/enemy_turn_service.gd",
	"pet_reset_policy": "res://core/battle/pet_reset_policy.gd",
	"battle_outcome_policy": "res://core/battle/battle_outcome_policy.gd",
	"battle_startup_service": "res://core/battle/battle_startup_service.gd",
	"run_automation_service": "res://core/run/run_automation_service.gd",
	"skill_queue_service": "res://core/battle/skills/skill_queue_service.gd",
	"action_slot_service": "res://core/battle/action_slot_service.gd",
	"skill_execution_service": "res://core/battle/skills/skill_execution_service.gd",
	"skill_combo_service": "res://core/battle/skills/skill_combo_service.gd",
	"quality_effect_registry": "res://core/battle/quality/quality_effect_registry.gd",
	"quality_runtime_service": "res://core/battle/quality/quality_runtime_service.gd",
	"run_event_definition_registry": "res://core/run/events/run_event_definition_registry.gd",
	"run_event_effect_service": "res://core/run/run_event_effect_service.gd",
	"trait_service": "res://core/battle/traits/trait_service.gd",
	"stat_resolver": "res://core/stats/stat_resolver.gd",
	"condition_evaluator": "res://core/effects/condition_evaluator.gd",
	"status_service": "res://core/effects/status_service.gd",
	"effect_interpreter": "res://core/effects/effect_interpreter.gd",
	"modifier_collector": "res://core/effects/modifier_collector.gd",
	"battle_hook_pipeline": "res://core/effects/battle_hook_pipeline.gd",
	"effect_target_resolver": "res://core/effects/effect_target_resolver.gd",
	"stat_query_service": "res://core/stats/stat_query_service.gd",
	"stat_semantic_pipeline": "res://core/stats/stat_semantic_pipeline.gd",
	"relic_catalog_service": "res://core/battle/relics/relic_catalog_service.gd",
	"relic_combat_service": "res://core/battle/relics/relic_combat_service.gd",
	"damage_resolver": "res://core/battle/damage_resolver.gd",
	"attack_option_service": "res://core/battle/attack_option_service.gd",
	"targeting_service": "res://core/battle/targeting_service.gd",
	"quality_hit_context_projector": "res://core/battle/quality/quality_hit_context_projector.gd",
	"threat_target_policy": "res://core/battle/threat_target_policy.gd",
	"save_document_builder": "res://persistence/save_document_builder.gd",
	"run_history_committer": "res://persistence/run_history_committer.gd",
	"content_load_service": "res://core/content/content_load_service.gd",
	"simulation_authority_factory": "res://session/simulation_authority_factory.gd",
	"manual_flow_simulation_service": "res://core/commands/manual_flow_simulation_service.gd",
	"quality_progression_policy": "res://core/party/quality_progression_policy.gd",
	"battle_query_projector": "res://core/commands/battle_query_projector.gd",
	"auto_position_evaluator": "res://core/battle/auto_position/auto_position_evaluator.gd",
	"player_operation_projector": "res://core/logging/player_operation_projector.gd",
	"replay_verifier": "res://persistence/replay_verifier.gd",
}

var failed := false


class FakeSnapshotProjector extends RefCounted:
	func project(snapshot: Dictionary, _player_side: String, _enemy_side: String) -> Dictionary:
		return {"fakeProjector": true, "stateHash": snapshot.get("stateHash", "")}


class FakeQualityRegistry extends RefCounted:
	var effect: RefCounted

	func _init(strategy_script: Script) -> void:
		effect = strategy_script.new().configure("fake_quality", {"mode_options": ["替"]})

	func effect_for_id(_effect_id: String) -> RefCounted:
		return effect

	func effect_for_unit(_unit: Dictionary) -> RefCounted:
		return effect


class FakeActionSlotService extends RefCounted:
	func project_slots(unit: Dictionary, _input: Dictionary) -> Array:
		return [] if unit.is_empty() else [{"slot_id": "fake:slot", "index": 0, "used": false}]

	func slot_key(_unit: Dictionary, _index: int) -> String:
		return "fake:slot"

	func stored_direction(_unit: Dictionary, _index: int, _directions: Dictionary) -> String:
		return "down"

	func selected_ap(_unit: Dictionary, _index: int, _choices: Dictionary, _available_ap: int) -> int:
		return 7


class FakeMechanicRegistry extends RefCounted:
	func is_valid() -> bool:
		return true

	func handler_for(_mechanism_id: String, _mechanism: Dictionary) -> RefCounted:
		return null

	func supports(_handler: RefCounted, _hook: StringName) -> bool:
		return false


func _initialize() -> void:
	var root_source := FileAccess.get_file_as_string(ROOT_PATH)
	_expect(root_source.begins_with("extends RefCounted"), "composition root is a plain RefCounted")
	for service_name in SERVICES:
		var path := String(SERVICES[service_name])
		var source := FileAccess.get_file_as_string(path)
		_expect(source.begins_with("extends RefCounted"), "%s is composed, not inherited" % service_name)
		_expect(not source.contains("extends \"res://core/state/"), "%s does not extend the state compatibility chain" % service_name)
		_expect(not source.contains("extends \"res://persistence/compatibility/"), "%s does not extend the persistence compatibility chain" % service_name)
		_expect(not source.contains("class_name YsbzsState"), "%s does not redefine the facade" % service_name)
		_expect(not source.contains("autoload"), "%s does not introduce an Autoload dependency" % service_name)
		_expect(root_source.contains("var %s: RefCounted" % service_name), "composition root owns %s" % service_name)

	var facade_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	var battle_source := facade_source
	var projection_source := facade_source
	var flow_source := facade_source
	var persistence_source := facade_source
	_expect(facade_source.contains("_core_composition = CoreCompositionScript.new(core_overrides)"), "each authoritative state constructs one composition root before content loading")
	_expect(battle_source.contains("round_lifecycle_service.run_start"), "round-start lifecycle delegates from battle to RoundLifecycleService")
	_expect(battle_source.contains("round_lifecycle_service.run_end"), "round-end lifecycle delegates from battle to RoundLifecycleService")
	_expect(not FileAccess.file_exists("res://core/party/catalog_roster_core.gd"), "deleted catalog compatibility layer does not return")
	_expect(not facade_source.contains("func _apply_mechanic_round_start_to_unit(") and not facade_source.contains("func _apply_mechanic_round_end_to_unit("), "round mechanism implementation stays in composed services")
	_expect(projection_source.contains("snapshot_projector.project(snap, PLAYER, ENEMY)"), "ViewModel delegates to SnapshotProjector")
	_expect(flow_source.contains("pet_reset_policy.select_cells"), "pet reset placement delegates to the complete PetResetPolicy")
	_expect(flow_source.contains("battle_outcome_policy.assemble_result"), "battle result document delegates to BattleOutcomePolicy")
	for method_name in ["run_combat_round", "run_battle_auto"]:
		_expect(flow_source.contains("battle_session.%s" % method_name), "%s delegates to BattleSession" % method_name)
	for method_name in ["run_full_day", "run_full_run"]:
		_expect(flow_source.contains("run_automation_service.%s" % method_name), "%s delegates to RunAutomationService" % method_name)
	for method_name in ["write_slot", "read_slot"]:
		_expect(persistence_source.contains("save_repository.%s" % method_name), "persistence delegates %s to SaveRepository" % method_name)
	for method_name in ["validate_document", "saved_board_dimensions"]:
		_expect(persistence_source.contains("_save_document_validator.%s" % method_name), "persistence delegates %s to SaveDocumentValidator" % method_name)
	var save_validator_source := FileAccess.get_file_as_string("res://persistence/save_document_validator.gd")
	_expect(save_validator_source.contains("return validate_state_payload("), "SaveDocumentValidator owns nested state-payload validation")
	_expect(save_validator_source.contains("if not validate_units("), "SaveDocumentValidator owns nested unit validation")
	var repository_source := FileAccess.get_file_as_string("res://persistence/save_repository.gd")
	_expect(not repository_source.contains("core.call"), "SaveRepository does not depend on authoritative core callbacks")
	var round_lifecycle_source := FileAccess.get_file_as_string("res://core/battle/round_lifecycle_service.gd")
	_expect(not round_lifecycle_source.contains("core.call") and not round_lifecycle_source.contains("core.get"), "RoundLifecycleService depends on a versioned narrow port")
	var round_lifecycle_port_source := FileAccess.get_file_as_string("res://core/ports/round_lifecycle_port.gd")
	_expect(round_lifecycle_port_source.contains("ysbzs.round-lifecycle-port.v1"), "round lifecycle port publishes a stable versioned contract")
	_expect(not FileAccess.file_exists("res://core/battle/mechanics_engine.gd") and not FileAccess.file_exists("res://core/ports/mechanics_trigger_context.gd"), "one-shot Dictionary/Callable mechanic seam stays removed")
	var battle_session_source := FileAccess.get_file_as_string("res://core/battle/battle_session.gd")
	_expect(not battle_session_source.contains("core.call") and not battle_session_source.contains("core.get"), "BattleSession depends on a narrow application port")
	var run_automation_source := FileAccess.get_file_as_string("res://core/run/run_automation_service.gd")
	_expect(not run_automation_source.contains("core.call") and not run_automation_source.contains("core.get"), "RunAutomationService depends on a narrow application port")

	var first := StateScript.new()
	var second := StateScript.new({
		"mode": "test",
		"content_pack": Dictionary(first.get("game_data")).duplicate(true),
		"content_source_kind": first.call("content_source_kind"),
	})
	_expect(first.is_initialized() and second.is_initialized(), "production and explicit test authorities initialize before composition override checks")
	var first_composition: RefCounted = first.get("_core_composition") as RefCounted
	var second_composition: RefCounted = second.get("_core_composition") as RefCounted
	_expect(first_composition != second_composition, "composition roots are per-state, not global singletons")
	_expect(
		first_composition.quality_effect_registry != second_composition.quality_effect_registry
			and first_composition.quality_runtime_service != second_composition.quality_runtime_service
			and first_composition.run_event_definition_registry != second_composition.run_event_definition_registry
			and first_composition.run_event_effect_service != second_composition.run_event_effect_service
			and first_composition.action_slot_service != second_composition.action_slot_service,
		"quality, run-event, and action-slot services are per-state"
	)
	_expect(
		first_composition.mechanic_handler_registry != second_composition.mechanic_handler_registry
			and first_composition.mechanic_projection_service != second_composition.mechanic_projection_service,
		"mechanic registry and projection services are per-state"
	)
	_expect_shared_mechanic_registry(first_composition, "first authority")
	_expect_shared_mechanic_registry(second_composition, "second authority")
	var fake_projector := FakeSnapshotProjector.new()
	var fake_quality_registry := FakeQualityRegistry.new(QualityStrategyScript)
	var fake_action_slot_service := FakeActionSlotService.new()
	var fake_mechanic_registry := FakeMechanicRegistry.new()
	var overridden := CoreCompositionScript.new({
		"snapshot_projector": fake_projector,
		"quality_effect_registry": fake_quality_registry,
		"action_slot_service": fake_action_slot_service,
		"mechanic_handler_registry": fake_mechanic_registry,
	})
	_expect(overridden.snapshot_projector == fake_projector, "composition accepts an explicit service override")
	_expect(overridden.quality_effect_registry == fake_quality_registry, "composition accepts a quality registry override")
	_expect(overridden.action_slot_service == fake_action_slot_service, "composition accepts an action-slot service override")
	_expect(overridden.mechanic_handler_registry == fake_mechanic_registry, "composition accepts an explicit mechanic registry override")
	_expect_shared_mechanic_registry(overridden, "overridden composition")
	_expect(
		overridden.quality_runtime_service.display_mode({"quality_upgrade": {"id": "anything"}}) == "替",
		"default quality runtime is configured with the final registry override"
	)
	_expect(
		overridden.mechanic_handler_registry != null \
			and overridden.mechanic_projection_service != null \
			and overridden.round_lifecycle_service != null \
			and overridden.damage_mechanic_service != null \
			and overridden.damage_death_service != null \
			and overridden.summon_service != null \
			and overridden.unit_lifecycle_mechanic_service != null \
			and overridden.element_mechanic_service != null \
			and overridden.battle_session != null \
			and overridden.save_repository != null \
			and overridden.replay_repository != null \
			and overridden.run_history_repository != null \
			and overridden.command_response_builder != null \
			and overridden.game_data_repository != null \
			and overridden.operation_log_repository != null \
			and overridden.player_turn_service != null \
			and overridden.enemy_turn_service != null \
			and overridden.pet_reset_policy != null \
			and overridden.battle_outcome_policy != null \
			and overridden.battle_startup_service != null \
			and overridden.run_automation_service != null \
			and overridden.skill_queue_service != null \
			and overridden.action_slot_service != null \
			and overridden.skill_execution_service != null \
			and overridden.skill_combo_service != null \
			and overridden.quality_effect_registry != null \
			and overridden.quality_runtime_service != null \
			and overridden.run_event_definition_registry != null \
			and overridden.run_event_effect_service != null \
			and overridden.trait_service != null \
			and overridden.condition_evaluator != null \
			and overridden.stat_resolver != null \
			and overridden.status_service != null \
			and overridden.effect_interpreter != null \
			and overridden.modifier_collector != null \
			and overridden.battle_hook_pipeline != null \
			and overridden.effect_target_resolver != null \
			and overridden.stat_query_service != null \
			and overridden.stat_semantic_pipeline != null \
			and overridden.relic_catalog_service != null \
			and overridden.relic_combat_service != null \
			and overridden.damage_resolver != null \
			and overridden.attack_option_service != null \
			and overridden.targeting_service != null \
			and overridden.quality_hit_context_projector != null \
			and overridden.threat_target_policy != null \
			and overridden.save_document_builder != null \
			and overridden.run_history_committer != null \
			and overridden.content_load_service != null \
			and overridden.simulation_authority_factory != null \
			and overridden.manual_flow_simulation_service != null \
			and overridden.quality_progression_policy != null \
			and overridden.battle_query_projector != null \
			and overridden.auto_position_evaluator != null \
			and overridden.player_operation_projector != null \
			and overridden.replay_verifier != null,
		"unspecified services keep production defaults"
	)
	second.configure_core_services({
		"snapshot_projector": fake_projector,
		"quality_effect_registry": fake_quality_registry,
		"action_slot_service": fake_action_slot_service,
	})
	var injected_view_model := Dictionary(second.snapshot().get("viewModel", {}))
	_expect(bool(injected_view_model.get("fakeProjector", false)), "authoritative state can install test services without global mutation")
	_expect(second._quality_mode_options({"quality_upgrade": {"id": "anything"}}) == ["替"], "battle rules read the replaced composition registry without a stale cache")
	_expect(second._action_slot_key({"id": "anything"}, 0) == "fake:slot", "command projection reads the replaced action-slot service without a stale cache")
	var snap := first.snapshot()
	var view_model := Dictionary(snap.get("viewModel", {}))
	_expect(String(view_model.get("stateHash", "")) == String(snap.get("stateHash", "")), "projector preserves state hash")
	_expect(Dictionary(view_model.get("board", {})) == Dictionary(snap.get("board", {})), "projector preserves board read model")
	_expect(
		String(overridden.save_repository.slot_path(2, "user://ysbzs_singleplayer_save_slot_%d.json")) == "user://ysbzs_singleplayer_save_slot_2.json",
		"repository preserves slot path contract without a state compatibility wrapper"
	)
	_expect(first.dispatch({"type": "START_BATTLE"}), "composition fixture starts battle")
	_expect(first.run_combat_round(), "BattleSession advances one combat round")
	if failed:
		quit(1)
		return
	print("SMOKE_CORE_COMPOSITION_COMPLETE_OK services=%d phase=%s round=%d" % [
		SERVICES.size(),
		String(first.get("phase")),
		int(first.get("battle_round"))
	])
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)


func _expect_shared_mechanic_registry(composition: RefCounted, label: String) -> void:
	var registry: RefCounted = composition.get("mechanic_handler_registry") as RefCounted
	_expect(registry != null, "%s owns a mechanic handler registry" % label)
	for service_name in [
		"round_lifecycle_service",
		"damage_mechanic_service",
		"unit_lifecycle_mechanic_service",
		"element_mechanic_service",
		"mechanic_projection_service",
	]:
		var service: RefCounted = composition.get(service_name) as RefCounted
		_expect(
			service != null and service.get("_handler_registry") == registry,
			"%s wires the exact registry instance into %s" % [label, service_name]
		)
