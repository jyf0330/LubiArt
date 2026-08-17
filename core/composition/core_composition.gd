extends RefCounted

const RoundLifecycleServiceScript := preload("res://core/battle/round_lifecycle_service.gd")
const MechanicHandlerRegistryScript := preload("res://core/battle/mechanics/mechanic_handler_registry.gd")
const MechanicProjectionServiceScript := preload("res://core/battle/mechanics/mechanic_projection_service.gd")
const DamageMechanicServiceScript := preload("res://core/battle/mechanics/damage_mechanic_service.gd")
const DamageDeathServiceScript := preload("res://core/battle/mechanics/damage_death_service.gd")
const SummonServiceScript := preload("res://core/battle/summons/summon_service.gd")
const UnitLifecycleMechanicServiceScript := preload("res://core/battle/mechanics/unit_lifecycle_mechanic_service.gd")
const ElementMechanicServiceScript := preload("res://core/battle/mechanics/element_mechanic_service.gd")
const BattleSessionScript := preload("res://core/battle/battle_session.gd")
const SnapshotProjectorScript := preload("res://core/commands/snapshot_projector.gd")
const CommandResponseBuilderScript := preload("res://core/commands/command_response_builder.gd")
const SaveRepositoryScript := preload("res://persistence/save_repository.gd")
const ReplayRepositoryScript := preload("res://persistence/replay_repository.gd")
const RunHistoryRepositoryScript := preload("res://persistence/run_history_repository.gd")
const GameDataRepositoryScript := preload("res://persistence/game_data_repository.gd")
const OperationLogRepositoryScript := preload("res://persistence/operation_log_repository.gd")
const PlayerTurnServiceScript := preload("res://core/battle/player_turn_service.gd")
const EnemyTurnServiceScript := preload("res://core/battle/enemy_turn_service.gd")
const PetResetPolicyScript := preload("res://core/battle/pet_reset_policy.gd")
const BattleOutcomePolicyScript := preload("res://core/battle/battle_outcome_policy.gd")
const BattleStartupServiceScript := preload("res://core/battle/battle_startup_service.gd")
const RunAutomationServiceScript := preload("res://core/run/run_automation_service.gd")
const SkillQueueServiceScript := preload("res://core/battle/skills/skill_queue_service.gd")
const ActionSlotServiceScript := preload("res://core/battle/action_slot_service.gd")
const SkillExecutionServiceScript := preload("res://core/battle/skills/skill_execution_service.gd")
const SkillComboServiceScript := preload("res://core/battle/skills/skill_combo_service.gd")
const QualityEffectRegistryScript := preload("res://core/battle/quality/quality_effect_registry.gd")
const RunEventDefinitionRegistryScript := preload("res://core/run/events/run_event_definition_registry.gd")
const RunEventEffectServiceScript := preload("res://core/run/run_event_effect_service.gd")
const QualityRuntimeServiceScript := preload("res://core/battle/quality/quality_runtime_service.gd")
const TraitServiceScript := preload("res://core/battle/traits/trait_service.gd")
const StatResolverScript := preload("res://core/stats/stat_resolver.gd")
const ConditionEvaluatorScript := preload("res://core/effects/condition_evaluator.gd")
const StatusServiceScript := preload("res://core/effects/status_service.gd")
const EffectInterpreterScript := preload("res://core/effects/effect_interpreter.gd")
const ModifierCollectorScript := preload("res://core/effects/modifier_collector.gd")
const BattleHookPipelineScript := preload("res://core/effects/battle_hook_pipeline.gd")
const EffectTargetResolverScript := preload("res://core/effects/effect_target_resolver.gd")
const StatQueryServiceScript := preload("res://core/stats/stat_query_service.gd")
const StatSemanticPipelineScript := preload("res://core/stats/stat_semantic_pipeline.gd")
const RelicCatalogServiceScript := preload("res://core/battle/relics/relic_catalog_service.gd")
const RelicCombatServiceScript := preload("res://core/battle/relics/relic_combat_service.gd")
const DamageResolverScript := preload("res://core/battle/damage_resolver.gd")
const AttackOptionServiceScript := preload("res://core/battle/attack_option_service.gd")
const TargetingServiceScript := preload("res://core/battle/targeting_service.gd")
const QualityHitContextProjectorScript := preload("res://core/battle/quality/quality_hit_context_projector.gd")
const ThreatTargetPolicyScript := preload("res://core/battle/threat_target_policy.gd")
const SaveDocumentBuilderScript := preload("res://persistence/save_document_builder.gd")
const RunHistoryCommitterScript := preload("res://persistence/run_history_committer.gd")
const ContentLoadServiceScript := preload("res://core/content/content_load_service.gd")
const ContentObjectRegistryScript := preload("res://core/content/content_object_registry.gd")
const RuntimeExtensionValidatorScript := preload("res://core/content/runtime_extension_validator.gd")
const SimulationAuthorityFactoryScript := preload("res://session/simulation_authority_factory.gd")
const ManualFlowSimulationServiceScript := preload("res://core/commands/manual_flow_simulation_service.gd")
const QualityProgressionPolicyScript := preload("res://core/party/quality_progression_policy.gd")
const BattleQueryProjectorScript := preload("res://core/commands/battle_query_projector.gd")
const AutoPositionEvaluatorScript := preload("res://core/battle/auto_position/auto_position_evaluator.gd")
const PlayerOperationProjectorScript := preload("res://core/logging/player_operation_projector.gd")
const ReplayVerifierScript := preload("res://persistence/replay_verifier.gd")
const AutoPositionPolicyScript := preload("res://core/battle/auto_position/auto_position_policy.gd")

const CURRENT_ASSEMBLY := QualityEffectRegistryScript.CURRENT_ASSEMBLY
const PERSISTED_SNAPSHOT := QualityEffectRegistryScript.PERSISTED_SNAPSHOT

## Per-YsbzsState composition root. Services are stateless or operate only through
## an explicit core argument; no Autoload or parallel authoritative state exists.

var mechanic_handler_registry: RefCounted = null
var mechanic_projection_service: RefCounted = null
var round_lifecycle_service: RefCounted = null
var damage_mechanic_service: RefCounted = null
var damage_death_service: RefCounted = null
var summon_service: RefCounted = null
var unit_lifecycle_mechanic_service: RefCounted = null
var element_mechanic_service: RefCounted = null
var battle_session: RefCounted = null
var snapshot_projector: RefCounted = null
var command_response_builder: RefCounted = null
var save_repository: RefCounted = null
var replay_repository: RefCounted = null
var run_history_repository: RefCounted = null
var game_data_repository: RefCounted = null
var operation_log_repository: RefCounted = null
var player_turn_service: RefCounted = null
var enemy_turn_service: RefCounted = null
var pet_reset_policy: RefCounted = null
var battle_outcome_policy: RefCounted = null
var battle_startup_service: RefCounted = null
var run_automation_service: RefCounted = null
var skill_queue_service: RefCounted = null
var action_slot_service: RefCounted = null
var skill_execution_service: RefCounted = null
var skill_combo_service: RefCounted = null
var quality_effect_registry: RefCounted = null
var quality_runtime_service: RefCounted = null
var run_event_definition_registry: RefCounted = null
var run_event_effect_service: RefCounted = null
var trait_service: RefCounted = null
var stat_resolver: RefCounted = null
var condition_evaluator: RefCounted = null
var status_service: RefCounted = null
var effect_interpreter: RefCounted = null
var modifier_collector: RefCounted = null
var battle_hook_pipeline: RefCounted = null
var effect_target_resolver: RefCounted = null
var stat_query_service: RefCounted = null
var stat_semantic_pipeline: RefCounted = null
var relic_catalog_service: RefCounted = null
var relic_combat_service: RefCounted = null
var damage_resolver: RefCounted = null
var attack_option_service: RefCounted = null
var targeting_service: RefCounted = null
var quality_hit_context_projector: RefCounted = null
var threat_target_policy: RefCounted = null
var save_document_builder: RefCounted = null
var run_history_committer: RefCounted = null
var content_load_service: RefCounted = null
var content_object_registry: RefCounted = null
var simulation_authority_factory: RefCounted = null
var manual_flow_simulation_service: RefCounted = null
var quality_progression_policy: RefCounted = null
var battle_query_projector: RefCounted = null
var auto_position_evaluator: RefCounted = null
var player_operation_projector: RefCounted = null
var replay_verifier: RefCounted = null
var _pending_content_bindings: Dictionary = {}


func _init(overrides: Dictionary = {}) -> void:
	mechanic_handler_registry = _resolve(overrides, &"mechanic_handler_registry", MechanicHandlerRegistryScript)
	mechanic_projection_service = _resolve(overrides, &"mechanic_projection_service", MechanicProjectionServiceScript)
	round_lifecycle_service = _resolve(overrides, &"round_lifecycle_service", RoundLifecycleServiceScript)
	damage_mechanic_service = _resolve(overrides, &"damage_mechanic_service", DamageMechanicServiceScript)
	damage_death_service = _resolve(overrides, &"damage_death_service", DamageDeathServiceScript)
	summon_service = _resolve(overrides, &"summon_service", SummonServiceScript)
	unit_lifecycle_mechanic_service = _resolve(overrides, &"unit_lifecycle_mechanic_service", UnitLifecycleMechanicServiceScript)
	element_mechanic_service = _resolve(overrides, &"element_mechanic_service", ElementMechanicServiceScript)
	mechanic_projection_service.call(&"configure", mechanic_handler_registry)
	round_lifecycle_service.call(&"configure_handler_registry", mechanic_handler_registry)
	damage_mechanic_service.call(&"configure_handler_registry", mechanic_handler_registry)
	unit_lifecycle_mechanic_service.call(&"configure_handler_registry", mechanic_handler_registry)
	element_mechanic_service.call(&"configure_handler_registry", mechanic_handler_registry)
	battle_session = _resolve(overrides, &"battle_session", BattleSessionScript)
	snapshot_projector = _resolve(overrides, &"snapshot_projector", SnapshotProjectorScript)
	command_response_builder = _resolve(overrides, &"command_response_builder", CommandResponseBuilderScript)
	save_repository = _resolve(overrides, &"save_repository", SaveRepositoryScript)
	replay_repository = _resolve(overrides, &"replay_repository", ReplayRepositoryScript)
	run_history_repository = _resolve(overrides, &"run_history_repository", RunHistoryRepositoryScript)
	game_data_repository = _resolve(overrides, &"game_data_repository", GameDataRepositoryScript)
	operation_log_repository = _resolve(overrides, &"operation_log_repository", OperationLogRepositoryScript)
	player_turn_service = _resolve(overrides, &"player_turn_service", PlayerTurnServiceScript)
	enemy_turn_service = _resolve(overrides, &"enemy_turn_service", EnemyTurnServiceScript)
	pet_reset_policy = _resolve(overrides, &"pet_reset_policy", PetResetPolicyScript)
	battle_outcome_policy = _resolve(overrides, &"battle_outcome_policy", BattleOutcomePolicyScript)
	battle_startup_service = _resolve(overrides, &"battle_startup_service", BattleStartupServiceScript)
	run_automation_service = _resolve(overrides, &"run_automation_service", RunAutomationServiceScript)
	skill_queue_service = _resolve(overrides, &"skill_queue_service", SkillQueueServiceScript)
	action_slot_service = _resolve(overrides, &"action_slot_service", ActionSlotServiceScript)
	quality_effect_registry = _resolve(overrides, &"quality_effect_registry", QualityEffectRegistryScript)
	quality_runtime_service = _resolve(overrides, &"quality_runtime_service", QualityRuntimeServiceScript)
	run_event_definition_registry = _resolve(overrides, &"run_event_definition_registry", RunEventDefinitionRegistryScript)
	run_event_effect_service = _resolve(overrides, &"run_event_effect_service", RunEventEffectServiceScript)
	if quality_runtime_service.has_method(&"configure"):
		quality_runtime_service.call(&"configure", quality_effect_registry)
	condition_evaluator = _resolve(overrides, &"condition_evaluator", ConditionEvaluatorScript)
	effect_interpreter = _resolve(overrides, &"effect_interpreter", EffectInterpreterScript)
	if effect_interpreter.has_method(&"configure"):
		effect_interpreter.call(&"configure", condition_evaluator)
	relic_catalog_service = _resolve(overrides, &"relic_catalog_service", RelicCatalogServiceScript)
	relic_combat_service = _resolve(overrides, &"relic_combat_service", RelicCombatServiceScript)
	if relic_combat_service.has_method(&"configure"):
		relic_combat_service.call(&"configure", relic_catalog_service, effect_interpreter)
	stat_resolver = _resolve(overrides, &"stat_resolver", StatResolverScript)
	if stat_resolver.has_method(&"configure"):
		stat_resolver.call(&"configure", condition_evaluator)
	status_service = _resolve(overrides, &"status_service", StatusServiceScript)
	if status_service.has_method(&"configure"):
		status_service.call(&"configure", condition_evaluator)
	trait_service = _resolve(overrides, &"trait_service", TraitServiceScript)
	if trait_service.has_method(&"configure"):
		trait_service.call(&"configure", condition_evaluator)
	modifier_collector = _resolve(overrides, &"modifier_collector", ModifierCollectorScript)
	modifier_collector.call(&"configure", trait_service, status_service)
	stat_query_service = _resolve(overrides, &"stat_query_service", StatQueryServiceScript)
	stat_query_service.call(&"configure", stat_resolver, modifier_collector)
	stat_semantic_pipeline = _resolve(overrides, &"stat_semantic_pipeline", StatSemanticPipelineScript)
	battle_hook_pipeline = _resolve(overrides, &"battle_hook_pipeline", BattleHookPipelineScript)
	battle_hook_pipeline.call(&"configure", modifier_collector, effect_interpreter)
	effect_target_resolver = _resolve(overrides, &"effect_target_resolver", EffectTargetResolverScript)
	skill_execution_service = _resolve(overrides, &"skill_execution_service", SkillExecutionServiceScript)
	if skill_execution_service.has_method(&"configure"):
		skill_execution_service.call(&"configure", effect_interpreter, battle_hook_pipeline)
	skill_combo_service = _resolve(overrides, &"skill_combo_service", SkillComboServiceScript)
	damage_resolver = _resolve(overrides, &"damage_resolver", DamageResolverScript)
	attack_option_service = _resolve(overrides, &"attack_option_service", AttackOptionServiceScript)
	targeting_service = _resolve(overrides, &"targeting_service", TargetingServiceScript)
	quality_hit_context_projector = _resolve(overrides, &"quality_hit_context_projector", QualityHitContextProjectorScript)
	threat_target_policy = _resolve(overrides, &"threat_target_policy", ThreatTargetPolicyScript)
	save_document_builder = _resolve(overrides, &"save_document_builder", SaveDocumentBuilderScript)
	run_history_committer = _resolve(overrides, &"run_history_committer", RunHistoryCommitterScript)
	if run_history_committer.has_method(&"configure"):
		run_history_committer.call(&"configure", run_history_repository, save_document_builder)
	content_load_service = _resolve(overrides, &"content_load_service", ContentLoadServiceScript)
	content_object_registry = _resolve(overrides, &"content_object_registry", ContentObjectRegistryScript)
	simulation_authority_factory = _resolve(overrides, &"simulation_authority_factory", SimulationAuthorityFactoryScript)
	manual_flow_simulation_service = _resolve(overrides, &"manual_flow_simulation_service", ManualFlowSimulationServiceScript)
	quality_progression_policy = _resolve(overrides, &"quality_progression_policy", QualityProgressionPolicyScript)
	battle_query_projector = _resolve(overrides, &"battle_query_projector", BattleQueryProjectorScript)
	if battle_query_projector.has_method(&"configure"):
		battle_query_projector.call(
			&"configure",
			action_slot_service,
			attack_option_service,
			targeting_service,
			stat_query_service,
			quality_effect_registry,
			quality_hit_context_projector,
			threat_target_policy,
			damage_resolver,
			stat_semantic_pipeline,
			mechanic_projection_service
		)
	auto_position_evaluator = _resolve(overrides, &"auto_position_evaluator", AutoPositionEvaluatorScript)
	if auto_position_evaluator.has_method(&"configure"):
		auto_position_evaluator.call(
			&"configure",
			battle_query_projector,
			action_slot_service,
			attack_option_service,
			targeting_service,
			stat_query_service,
			quality_effect_registry,
			quality_hit_context_projector,
			threat_target_policy,
			mechanic_projection_service,
			AutoPositionPolicyScript.new()
		)
	player_operation_projector = _resolve(overrides, &"player_operation_projector", PlayerOperationProjectorScript)
	replay_verifier = _resolve(overrides, &"replay_verifier", ReplayVerifierScript)


func services() -> Dictionary:
	return {
		"mechanic_handler_registry": mechanic_handler_registry,
		"mechanic_projection_service": mechanic_projection_service,
		"round_lifecycle_service": round_lifecycle_service,
		"damage_mechanic_service": damage_mechanic_service,
		"damage_death_service": damage_death_service,
		"summon_service": summon_service,
		"unit_lifecycle_mechanic_service": unit_lifecycle_mechanic_service,
		"element_mechanic_service": element_mechanic_service,
		"battle_session": battle_session,
		"snapshot_projector": snapshot_projector,
		"command_response_builder": command_response_builder,
		"save_repository": save_repository,
		"replay_repository": replay_repository,
		"run_history_repository": run_history_repository,
		"game_data_repository": game_data_repository,
		"operation_log_repository": operation_log_repository,
		"player_turn_service": player_turn_service,
		"enemy_turn_service": enemy_turn_service,
		"pet_reset_policy": pet_reset_policy,
		"battle_outcome_policy": battle_outcome_policy,
		"battle_startup_service": battle_startup_service,
		"run_automation_service": run_automation_service,
		"skill_queue_service": skill_queue_service,
		"action_slot_service": action_slot_service,
		"skill_execution_service": skill_execution_service,
		"skill_combo_service": skill_combo_service,
		"quality_effect_registry": quality_effect_registry,
		"quality_runtime_service": quality_runtime_service,
		"run_event_definition_registry": run_event_definition_registry,
		"run_event_effect_service": run_event_effect_service,
		"trait_service": trait_service,
		"stat_resolver": stat_resolver,
		"condition_evaluator": condition_evaluator,
		"status_service": status_service,
		"effect_interpreter": effect_interpreter,
		"modifier_collector": modifier_collector,
		"battle_hook_pipeline": battle_hook_pipeline,
		"effect_target_resolver": effect_target_resolver,
		"stat_query_service": stat_query_service,
		"stat_semantic_pipeline": stat_semantic_pipeline,
		"relic_catalog_service": relic_catalog_service,
		"relic_combat_service": relic_combat_service,
		"damage_resolver": damage_resolver,
		"attack_option_service": attack_option_service,
		"targeting_service": targeting_service,
		"quality_hit_context_projector": quality_hit_context_projector,
		"threat_target_policy": threat_target_policy,
		"save_document_builder": save_document_builder,
		"run_history_committer": run_history_committer,
		"content_load_service": content_load_service,
		"content_object_registry": content_object_registry,
		"simulation_authority_factory": simulation_authority_factory,
		"manual_flow_simulation_service": manual_flow_simulation_service,
		"quality_progression_policy": quality_progression_policy,
		"battle_query_projector": battle_query_projector,
		"auto_position_evaluator": auto_position_evaluator,
		"player_operation_projector": player_operation_projector,
		"replay_verifier": replay_verifier,
	}


func prepare_content_binding(content: Dictionary, source_kind: StringName) -> Dictionary:
	_pending_content_bindings.clear()
	var errors: Array[String] = []
	if not _registry_supports_content_binding(quality_effect_registry):
		return {"ok": false, "candidate": {}, "errors": ["CONTENT_QUALITY_REGISTRY_CONTRACT_INVALID"]}
	if not _run_event_registry_supports_runtime():
		return {"ok": false, "candidate": {}, "errors": ["CONTENT_RUN_EVENT_REGISTRY_CONTRACT_INVALID"]}
	if not _registry_supports_content_binding(content_object_registry):
		return {"ok": false, "candidate": {}, "errors": ["CONTENT_OBJECT_REGISTRY_CONTRACT_INVALID"]}
	for error_value in RuntimeExtensionValidatorScript.new().validate(content):
		errors.append(String(error_value))
	if not errors.is_empty():
		return {"ok": false, "candidate": {}, "errors": errors}
	var quality_value: Variant = content.get("quality", null)
	if not quality_value is Dictionary:
		errors.append("CONTENT_QUALITY_REQUIRED")
		return {"ok": false, "candidate": {}, "errors": errors}
	var quality := Dictionary(quality_value)
	var version_value: Variant = quality.get("runtime_schema_version", 0)
	if not _is_integral_number(version_value):
		errors.append("CONTENT_QUALITY_RUNTIME_SCHEMA_VERSION_INVALID")
		return {"ok": false, "candidate": {}, "errors": errors}
	var upgrades_value: Variant = quality.get("upgrades", null)
	if not upgrades_value is Array:
		errors.append("CONTENT_QUALITY_UPGRADES_INVALID")
		return {"ok": false, "candidate": {}, "errors": errors}
	var quality_prepared := Dictionary(quality_effect_registry.call(
		&"prepare_configuration",
		Array(upgrades_value).duplicate(true),
		int(version_value),
		source_kind
	))
	if not bool(quality_prepared.get("ok", false)):
		for error_value in Array(quality_prepared.get("errors", [])):
			errors.append(String(error_value))
		return {"ok": false, "candidate": {}, "errors": errors}
	var run_event_prepared := Dictionary(run_event_definition_registry.call(
		&"prepare_configuration",
		content.duplicate(true),
		source_kind
	))
	if not bool(run_event_prepared.get("ok", false)):
		for error_value in Array(run_event_prepared.get("errors", [])):
			errors.append(String(error_value))
		return {"ok": false, "candidate": {}, "errors": errors}
	var object_prepared := Dictionary(content_object_registry.call(
		&"prepare_configuration",
		content.duplicate(true),
		source_kind
	))
	if not bool(object_prepared.get("ok", false)):
		for error_value in Array(object_prepared.get("errors", [])):
			errors.append(String(error_value))
		return {"ok": false, "candidate": {}, "errors": errors}
	var token := RefCounted.new()
	_pending_content_bindings[token.get_instance_id()] = {
		"token": token,
		"quality_candidate": Dictionary(quality_prepared.get("candidate", {})).duplicate(),
		"run_event_candidate": Dictionary(run_event_prepared.get("candidate", {})).duplicate(),
		"object_candidate": Dictionary(object_prepared.get("candidate", {})).duplicate(),
	}
	return {"ok": true, "candidate": {"token": token}, "errors": []}


func commit_content_binding(candidate: Dictionary) -> bool:
	var token_value: Variant = candidate.get("token", null)
	if not token_value is RefCounted:
		return false
	var token := token_value as RefCounted
	var token_id := token.get_instance_id()
	var pending_value: Variant = _pending_content_bindings.get(token_id, null)
	if not pending_value is Dictionary or Dictionary(pending_value).get("token", null) != token:
		return false
	var quality_candidate := Dictionary(Dictionary(pending_value).get("quality_candidate", {}))
	var run_event_candidate := Dictionary(Dictionary(pending_value).get("run_event_candidate", {}))
	var object_candidate := Dictionary(Dictionary(pending_value).get("object_candidate", {}))
	if not bool(quality_effect_registry.call(&"_is_configuration_candidate_pending", quality_candidate)):
		_pending_content_bindings.erase(token_id)
		return false
	if not bool(run_event_definition_registry.call(&"_is_configuration_candidate_pending", run_event_candidate)):
		_pending_content_bindings.erase(token_id)
		return false
	if not bool(content_object_registry.call(&"_is_configuration_candidate_pending", object_candidate)):
		_pending_content_bindings.erase(token_id)
		return false
	_pending_content_bindings.erase(token_id)
	quality_effect_registry.call(&"commit_configuration", quality_candidate)
	run_event_definition_registry.call(&"commit_configuration", run_event_candidate)
	content_object_registry.call(&"commit_configuration", object_candidate)
	return bool(quality_effect_registry.call(&"is_configured")) \
		and bool(run_event_definition_registry.call(&"is_configured")) \
		and bool(content_object_registry.call(&"is_configured"))


func bind_content(content: Dictionary, source_kind: StringName) -> Dictionary:
	var prepared := prepare_content_binding(content, source_kind)
	if not bool(prepared.get("ok", false)):
		return prepared
	if not commit_content_binding(Dictionary(prepared.get("candidate", {}))):
		return {"ok": false, "candidate": {}, "errors": ["CONTENT_BIND_COMMIT_REJECTED"]}
	return {"ok": true, "candidate": {}, "errors": []}


func supports_content_binding() -> bool:
	return _registry_supports_content_binding(quality_effect_registry) \
		and _run_event_registry_supports_runtime() \
		and _registry_supports_content_binding(content_object_registry)


func _run_event_registry_supports_runtime() -> bool:
	if not _registry_supports_content_binding(run_event_definition_registry):
		return false
	for method_name in [
		&"operations_for_event",
		&"operations_for_rest_node",
		&"matching_post_battle_events",
	]:
		if not run_event_definition_registry.has_method(method_name):
			return false
	return true


func _registry_supports_content_binding(registry: RefCounted) -> bool:
	if registry == null:
		return false
	for method_name in [
		&"prepare_configuration",
		&"commit_configuration",
		&"_is_configuration_candidate_pending",
		&"is_configured",
	]:
		if not registry.has_method(method_name):
			return false
	return true


func _is_integral_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floor(float(value))


func _resolve(overrides: Dictionary, key: StringName, default_script: Script) -> RefCounted:
	var candidate: Variant = overrides.get(key)
	if candidate is RefCounted:
		return candidate as RefCounted
	return default_script.new() as RefCounted
