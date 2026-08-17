extends RefCounted

class_name YsbzsState

## Single authoritative gameplay facade. Domain services are composed explicitly;
## command, snapshot, save, replay, and history all operate on this one state.

const BattleBoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")
const CoreCompositionScript := preload("res://core/composition/core_composition.gd")
const GameLogScript := preload("res://core/logging/game_log.gd")
const CommandContractScript := preload("res://core/commands/command_contract.gd")
const DeveloperScenarioRegistryScript := preload("res://core/debug/developer_scenario_registry.gd")
const DeveloperScenarioAssemblerScript := preload("res://core/debug/developer_scenario_assembler.gd")
const BattleQueryContextScript := preload("res://core/commands/battle_query_context.gd")
const StateContentSourceConfigScript := preload("res://core/content/content_source_config.gd")
const DocumentCodecScript := preload("res://persistence/save_codec.gd")
const StateElementRulesScript := preload("res://core/battle/elements/element_rules.gd")
const StateAutoPositionConfigScript := preload("res://core/battle/auto_position/auto_position_config.gd")
const PhasePolicyScript := preload("res://core/state/phase_policy.gd")
const StatePersistenceConfigScript := preload("res://persistence/persistence_config.gd")
const StateQualityRulesScript := preload("res://core/party/quality_rules.gd")
const StateReplayContractScript := preload("res://persistence/replay_contract.gd")
const StateSaveContractScript := preload("res://persistence/save_contract.gd")
const StateLegacySkillCatalogScript := preload("res://core/battle/skills/legacy_skill_catalog.gd")
const AuthoritativeStateCodecScript := preload("res://persistence/authoritative_state_codec.gd")
const DeterministicSelectorScript := preload("res://core/run/seeded_selector.gd")

const DEFAULT_BOARD_WIDTH := BattleBoardDimensionsScript.DEFAULT_WIDTH
const DEFAULT_BOARD_HEIGHT := BattleBoardDimensionsScript.DEFAULT_HEIGHT
const BOARD_WIDTH := DEFAULT_BOARD_WIDTH
const BOARD_HEIGHT := DEFAULT_BOARD_HEIGHT
const BOARD_SIZE := DEFAULT_BOARD_WIDTH # Deprecated legacy column-count alias.
const PLAYER := "player"
const ENEMY := "enemy"
# Compatibility aliases for callers that still inspect the aggregate state script.
const DATA_PATH := StateContentSourceConfigScript.CONTENT_PACK_PATH
const BAZAAR_DAY1_CATALOG_PATH := StateContentSourceConfigScript.BAZAAR_DAY1_CATALOG_PATH
const SAVE_PATH := StatePersistenceConfigScript.SAVE_PATH
const SAVE_BACKUP_PATH := StatePersistenceConfigScript.SAVE_BACKUP_PATH
const SAVE_TEMP_PATH := StatePersistenceConfigScript.SAVE_TEMP_PATH
const SAVE_SLOT_COUNT := StatePersistenceConfigScript.SAVE_SLOT_COUNT
const SAVE_SLOT_PATH_PATTERN := StatePersistenceConfigScript.SAVE_SLOT_PATH_PATTERN
const SAVE_SLOT_BACKUP_PATH_PATTERN := StatePersistenceConfigScript.SAVE_SLOT_BACKUP_PATH_PATTERN
const SAVE_SLOT_TEMP_PATH_PATTERN := StatePersistenceConfigScript.SAVE_SLOT_TEMP_PATH_PATTERN
const REPLAY_PATH := StatePersistenceConfigScript.REPLAY_PATH
const BATTLE_TRACE_PATH := StatePersistenceConfigScript.BATTLE_TRACE_PATH
const PLAYER_OPERATION_LOG_PATH := StatePersistenceConfigScript.PLAYER_OPERATION_LOG_PATH
const SAVE_SCHEMA := StateSaveContractScript.SCHEMA
const LEGACY_SAVE_SCHEMA := StateSaveContractScript.LEGACY_SCHEMA
const SAVE_SCHEMA_VERSION := StateSaveContractScript.SCHEMA_VERSION
const REPLAY_SCHEMA := StateReplayContractScript.SCHEMA
const REPLAY_SCHEMA_VERSION := StateReplayContractScript.SCHEMA_VERSION
const COMMAND_REPLAY_VERSION := StateReplayContractScript.COMMAND_VERSION
const RULES_VERSION := "ysbzs_rules_2026_08_10_v5_developer_scenario"
const DEFAULT_HISTORY_ROOT := "user://ysbzs_run_history"
const MAX_BATTLE_ROUNDS := 12
const DEFAULT_LEADER_HP := 80
const PET_RESET_THRESHOLD := 2
const DEFAULT_PET_RESET_CHARGE_INTERVAL := 5
const DEFAULT_PET_RESET_INITIAL_CHARGES := 0
const BATTLE_TEAM_SIZE := 4
const DIFFICULTY_EASY := "easy"
const DIFFICULTY_NORMAL := "normal"
const REPLAY_INITIAL_OPTION_KEYS = CommandContractScript.REPLAY_INITIAL_OPTION_KEYS
const REPLAY_COMMAND_EXCLUDE_KEYS = CommandContractScript.REPLAY_COMMAND_EXCLUDE_KEYS
const MAX_ACTIVE_UNITS := 4
const MAX_BENCH_UNITS := 24
const MAX_SHOP_OFFERS := 10
const AUTO_POSITION_CANDIDATE_LIMIT := StateAutoPositionConfigScript.CANDIDATE_LIMIT
const AUTO_POSITION_TARGET_SIGNATURE_LIMIT := StateAutoPositionConfigScript.TARGET_SIGNATURE_LIMIT
const AUTO_POSITION_BEAM_WIDTH := StateAutoPositionConfigScript.BEAM_WIDTH
const AUTO_POSITION_SURVIVAL_FINALIST_LIMIT := StateAutoPositionConfigScript.SURVIVAL_FINALIST_LIMIT
const AUTO_POSITION_ACTION_COUNT_DIVERSITY := StateAutoPositionConfigScript.ACTION_COUNT_DIVERSITY
const AUTO_POSITION_APPROACH_CANDIDATE_LIMIT := StateAutoPositionConfigScript.APPROACH_CANDIDATE_LIMIT
const AUTO_POSITION_STANDBY_CANDIDATE_LIMIT := StateAutoPositionConfigScript.STANDBY_CANDIDATE_LIMIT
const QUALITY_ORDER := StateQualityRulesScript.ORDER
const QUALITY_KEYS := StateQualityRulesScript.KEYS
const QUALITY_EVOLUTION_POINT_TOTALS := StateQualityRulesScript.EVOLUTION_POINT_TOTALS
const QUALITY_EVOLUTION_POINT_CATEGORIES := StateQualityRulesScript.EVOLUTION_POINT_CATEGORIES
const ACTIVE_ELEMENTS := StateElementRulesScript.ACTIVE_ELEMENTS
const ELEMENT_ALIASES := StateElementRulesScript.ALIASES
const ELEMENT_SETTLE_ELEMENTS := StateElementRulesScript.SETTLEMENT_ELEMENTS
const ELEMENT_SETTLE_DAMAGE_LABELS := StateElementRulesScript.SETTLEMENT_DAMAGE_LABELS
const SKILL_LABELS := StateLegacySkillCatalogScript.LABELS
const SKILL_DESCRIPTIONS := StateLegacySkillCatalogScript.DESCRIPTIONS
const ACTION_ALIASES = CommandContractScript.ACTION_ALIASES
const REMOVED_TRIAL_ALIASES = CommandContractScript.REMOVED_TRIAL_ALIASES
const AUTOMATION_ALIASES = CommandContractScript.AUTOMATION_ALIASES
const VIEW_STATE_ACTIONS = CommandContractScript.VIEW_STATE_ACTIONS
const STRICT_VERSION_ACTIONS = CommandContractScript.STRICT_VERSION_ACTIONS
const COMBAT_RESOLUTION_PROTOCOL := {
	"damage_core": "_resolve_attack_against_target",
	"element_core": "_apply_element_to_unit_or_cell",
	"shared_resolution_actions": ["SELECT_CELL", "USE_ACTION_SLOT", "RUN_PLAYER_ALL_OUT", "PREVIEW_MANUAL_FLOW"],
	"preview_projection_actions": ["BUILD_PREVIEW"],
	"preview_contract": "BUILD_PREVIEW projects the same selected slot, AP, direction, damage, and element settlement inputs that mutation commands resolve."
}
const SHOP_ENTRY_CHECKPOINT_FIELDS := [
	"phase", "selected_unit_id", "active_stall", "active_shop_pool", "active_shop_seed_context",
	"shop_roll_count", "shop_context_roll_count", "shop_free_rolls", "shop_paid_refreshes",
	"shop_next_discount", "shop_seen_pet_ids_by_day", "shop_seed_audit", "shop_offers", "log_lines",
]
const SHOP_ROUTE_CHECKPOINT_FIELDS := [
	"phase", "active_schedule", "active_stall", "active_shop_pool", "active_shop_seed_context",
	"shop_roll_count", "shop_context_roll_count",
	"shop_free_rolls", "shop_paid_refreshes", "shop_next_discount", "shop_seen_pet_ids_by_day",
	"shop_seed_audit", "shop_offers", "log_lines",
]
const SHOP_ROLL_CHECKPOINT_FIELDS := [
	"coins", "shop_roll_count", "shop_context_roll_count", "shop_free_rolls", "shop_paid_refreshes",
	"shop_next_discount", "shop_seen_pet_ids_by_day", "shop_seed_audit", "shop_offers", "log_lines",
]
const SHOP_PET_BUY_CHECKPOINT_FIELDS := ["coins", "roster", "shop_offers", "log_lines"]
const SHOP_EXIT_CHECKPOINT_FIELDS := [
	"phase", "selected_unit_id", "selected_action_slot_index", "active_schedule", "active_encounter", "log_lines",
]

var _core_composition: RefCounted = null
var _initialization_result: Dictionary = {
	"schema": "ysbzs.init-result.v1",
	"ok": false,
	"mode": "production",
	"source": "",
	"contentHash": "",
	"errors": ["NOT_INITIALIZED"],
}
var _content_hash_cache := ""
var _content_source_kind: StringName = CoreCompositionScript.CURRENT_ASSEMBLY
var _initialization_mode := "production"
var _content_binding_errors: Array[String] = []
var _last_dispatch_state_hash := ""
var history_recording_enabled := false
var history_root := DEFAULT_HISTORY_ROOT
var history_run_id := ""
var history_branch_id := ""
var history_parent_run_id := ""
var history_parent_checkpoint_id := ""
var history_command_index := 0
var history_content_revision := 0
var history_content_path := ""
var _history_suspended := false
var phase := "route"
var day := 1
var node_index := 1
var coins := 16
var hero_hp := DEFAULT_LEADER_HP
var hero_max_hp := DEFAULT_LEADER_HP
var enemy_hero_hp := DEFAULT_LEADER_HP
var enemy_hero_max_hp := DEFAULT_LEADER_HP
var castle_line := 10
var economy_multiplier := 1.0
var ap := 3
var battle_round := 1
var battle_round_start_checkpoints: Array = []
var battle_period := "上午"
var difficulty := DIFFICULTY_NORMAL
var board_width := DEFAULT_BOARD_WIDTH
var board_height := DEFAULT_BOARD_HEIGHT
var selected_unit_id := ""
var selected_action_slot_index := 0
var active_wave: Dictionary = {}
var active_schedule: Dictionary = {}
var active_encounter: Dictionary = {}
var scenario_provenance: Dictionary = {}
var active_stall: Dictionary = {}
var active_shop_pool := "night_base"
var active_shop_seed_context := ""
var run_seed := "ysbzs-local"
var action_ap_choices: Dictionary = {}
var shop_roll_count := 0
var shop_context_roll_count := 0
var shop_free_rolls := 0
var shop_paid_refreshes := 0
var shop_next_discount := 0
var shop_event_effects: Array = []
var shop_seen_pet_ids_by_day: Dictionary = {}
var shop_seed_audit: Array = []
var reward_fallback_audit: Array = []
var battle_prep_effects: Array = []
var outer_run_effects: Array = []
var team_placement_preview: Dictionary = {"activeUnitId": null, "movedUnitIds": []}
var run_plan: Dictionary = {}
var route_options: Array = []
var roster: Array = []
var shop_offers: Array = []
var reward_options: Array = []
var relic_inventory: Array = []
var relic_combat_state: Dictionary = {}
var units: Array = []
var defeated_units: Array = []
var battle_result: Dictionary = {}
var cell_elements: Dictionary = {}
var board_traces: Dictionary = {}
var action_dirs: Dictionary = {}
var auto_position_action_plan: Array = []
var auto_position_applied_result: Dictionary = {}
var player_elements_settled_this_round := false
var battle_roster_templates: Dictionary = {PLAYER: [], ENEMY: []}
var skill_control_orders: Dictionary = {PLAYER: [], ENEMY: []}
var pet_reset_counts: Dictionary = {PLAYER: 0, ENEMY: 0}
var pet_reset_charges: Dictionary = {PLAYER: DEFAULT_PET_RESET_INITIAL_CHARGES, ENEMY: DEFAULT_PET_RESET_INITIAL_CHARGES}
var pet_reset_next_charge_round: Dictionary = {PLAYER: DEFAULT_PET_RESET_CHARGE_INTERVAL, ENEMY: DEFAULT_PET_RESET_CHARGE_INTERVAL}


var pet_reset_eligible: Dictionary = {PLAYER: false, ENEMY: false}
var _player_all_out_resolving := false
var log_lines: Array = []
var battle_trace: Array = []
var command_log: Array = []
var replay_debug_timeline: Array = []
var last_command_result: Variant = {}
var last_manual_flow_preview: Dictionary = {}
var placement_damage_by_unit: Dictionary = {}
var state_version := 0
var game_data: Dictionary = {}
var player_operation_log_path := PLAYER_OPERATION_LOG_PATH

## Authoritative fields for the single gameplay facade. Domain algorithms are
## composed explicitly through CoreComposition services and narrow ports.

const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")
const InventoryRulesScript := preload("res://core/inventory/inventory_rules.gd")
const PartyRulesScript := preload("res://core/party/party_rules.gd")
const QualityRulesScript := preload("res://core/party/quality_rules.gd")
const RosterSlotRulesScript := preload("res://core/party/roster_slot_rules.gd")
const RosterCollectionServiceScript := preload("res://core/party/roster_collection_service.gd")
const SkillShapeRulesScript := preload("res://core/battle/skills/skill_shape_rules.gd")

## Data loading, mechanics catalog, quality growth, roster, and inventory.

const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")

## Command dispatch, response envelopes, snapshots, view models, and previews.

const CommandHandlerRegistryScript := preload("res://core/commands/handlers/command_handler_registry.gd")
const CommandPortFactoryScript := preload("res://core/commands/command_port_factory.gd")
const LegacySkillCatalogScript := preload("res://core/battle/skills/legacy_skill_catalog.gd")
const ManualFlowDiffProjectorScript := preload("res://core/commands/manual_flow_diff_projector.gd")
const EconomyRulesScript := preload("res://core/economy/economy_rules.gd")
const RouteRulesScript := preload("res://core/route/route_rules.gd")
const RouteOptionServiceScript := preload("res://core/run/route_option_service.gd")
const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")
const ElementFieldServiceScript := preload("res://core/battle/element_field_service.gd")
const ReplayBuilderScript := preload("res://persistence/replay_builder.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const RunHistoryPortScript := preload("res://core/ports/run_history_port.gd")
const ElementBurstPolicyScript := preload("res://core/battle/elements/element_burst_policy.gd")

var _command_handler_registry := CommandHandlerRegistryScript.new()
var _command_port_factory := CommandPortFactoryScript.new()
var _developer_scenario_registry := DeveloperScenarioRegistryScript.new()
var _developer_scenario_assembler := DeveloperScenarioAssemblerScript.new()
var _manual_flow_diff_projector := ManualFlowDiffProjectorScript.new()
var _element_field_service := ElementFieldServiceScript.new()
var _route_option_service := RouteOptionServiceScript.new()

const AutoPositionPlannerScript := preload("res://core/battle/auto_position/auto_position_planner.gd")
const AutoPositionConfigScript := preload("res://core/battle/auto_position/auto_position_config.gd")
const AutoPositionReadPortScript := preload("res://core/battle/auto_position/auto_position_read_port.gd")
const UnitVitalsScript := preload("res://core/battle/unit_vitals.gd")
const BattleTraceFactoryScript := preload("res://core/battle/battle_trace_factory.gd")
const QualityEffectContextScript := preload("res://core/battle/quality/quality_effect_context.gd")
const QualityBoardTraceScript := preload("res://core/battle/quality/quality_board_trace.gd")
const RelicCombatPortScript := preload("res://core/ports/relic_combat_port.gd")
const DamageMechanicPortScript := preload("res://core/ports/damage_mechanic_port.gd")
const DamageResolutionPortScript := preload("res://core/ports/damage_resolution_port.gd")
const DamageDeathPortScript := preload("res://core/ports/damage_death_port.gd")
const RoundLifecyclePortScript := preload("res://core/ports/round_lifecycle_port.gd")
const SummonPortScript := preload("res://core/ports/summon_port.gd")
const UnitLifecycleMechanicPortScript := preload("res://core/ports/unit_lifecycle_mechanic_port.gd")
const ElementMechanicPortScript := preload("res://core/ports/element_mechanic_port.gd")

## Action slots, auto-positioning, elements, damage, shapes, and quality combat rules.

var _auto_position_planner_service := AutoPositionPlannerScript.new()
var _quality_effect_context_service := QualityEffectContextScript.new()

## Route, shop, reward, battle lifecycle, turns, and full-run orchestration.

const ShopEffectRegistryScript := preload("res://core/shop/shop_effect_registry.gd")
const ShopEffectPortScript := preload("res://core/ports/shop_effect_port.gd")
const RunEventPortScript := preload("res://core/ports/run_event_port.gd")
const ShopCatalogServiceScript := preload("res://core/shop/shop_catalog_service.gd")
const ShopStallCatalogScript := preload("res://core/shop/shop_stall_catalog.gd")
const BattleSessionPortScript := preload("res://core/ports/battle_session_port.gd")
const PlayerTurnPortScript := preload("res://core/ports/player_turn_port.gd")
const EnemyTurnPortScript := preload("res://core/ports/enemy_turn_port.gd")
const SeededSelectorScript := preload("res://core/run/seeded_selector.gd")
var _shop_effect_registry := ShopEffectRegistryScript.new()
var _shop_catalog_service := ShopCatalogServiceScript.new()
var _shop_stall_catalog := ShopStallCatalogScript.new()

## State hashing, save/load, replay verification, and user storage.

const ReplayContractScript := preload("res://persistence/replay_contract.gd")
const SaveMigrationsScript := preload("res://persistence/migrations/save_migrations.gd")
const SaveContractScript := preload("res://persistence/save_contract.gd")
const SaveResultMessagesScript := preload("res://persistence/save_result_messages.gd")
const SaveDocumentValidatorScript := preload("res://persistence/save_document_validator.gd")
const PersistenceConfigScript := preload("res://persistence/persistence_config.gd")

var _save_document_validator := SaveDocumentValidatorScript.new()

## Stable public entrypoint for the single authoritative facade.
## The public cell-detail projection stays at the stable entrypoint, but all
## catalog stats come from the same final query used by board snapshots.

func _cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func board_dimensions() -> Vector2i:
	return Vector2i(board_width, board_height)

func _record_team_placement_move(unit_id: String) -> void:
	if unit_id == "":
		return
	if team_placement_preview.is_empty():
		team_placement_preview = {"activeUnitId": null, "movedUnitIds": []}
	var moved_ids: Array = Array(team_placement_preview.get("movedUnitIds", []))
	var deduped: Array = []
	for value in moved_ids:
		var id := String(value)
		if id == "" or id == unit_id or deduped.has(id):
			continue
		deduped.append(id)
	deduped.append(unit_id)
	team_placement_preview["activeUnitId"] = unit_id
	team_placement_preview["movedUnitIds"] = deduped

func _strike_damage_values(base_strike_damage: int, strike_count: int, aggregate_damage: int) -> Array:
	var values: Array = []
	var remaining_delta: int = aggregate_damage - base_strike_damage * strike_count
	for _strike_index in range(strike_count):
		var strike_damage: int = max(0, base_strike_damage)
		if remaining_delta > 0:
			strike_damage += remaining_delta
			remaining_delta = 0
		elif remaining_delta < 0:
			var reduction: int = min(strike_damage, -remaining_delta)
			strike_damage -= reduction
			remaining_delta += reduction
		values.append(strike_damage)
	return values

func unit_at(x: int, y: int) -> Dictionary:
	for unit in units:
		if int(unit["hp"]) > 0 and int(unit["x"]) == x and int(unit["y"]) == y:
			return unit
	return {}

func unit_by_id(unit_id: String) -> Dictionary:
	for unit in units:
		if String(unit["id"]) == unit_id:
			return unit
	return {}

func _living_unit_count(side: String) -> int:
	var count := 0
	for unit in units:
		if String(Dictionary(unit).get("side", "")) == side and int(Dictionary(unit).get("hp", 0)) > 0:
			count += 1
	return count

func selected_unit() -> Dictionary:
	return unit_by_id(selected_unit_id)

func _inside(x: int, y: int) -> bool:
	return BattleBoardDimensionsScript.contains(board_dimensions(), x, y)

func _state_hash_payload() -> Dictionary:
	var payload := AuthoritativeStateCodecScript.capture_hash(self)
	payload["_determinism"] = _determinism_context(false)
	return payload

func _state_hash() -> String:
	var context := HashingContext.new()
	var error := context.start(HashingContext.HASH_SHA256)
	if error != OK:
		return _checksum(_state_hash_payload()).substr(0, 16)
	context.update(_stable_json(_state_hash_payload()).to_utf8_buffer())
	return context.finish().hex_encode().substr(0, 16)

func _replay_data_version() -> String:
	return _content_hash()

func _stable_json(value: Variant) -> String:
	return DocumentCodecScript.stable_json(value)

func _checksum(value: Variant) -> String:
	return DocumentCodecScript.checksum(value)

func _content_hash_for(content: Dictionary) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return _checksum(content)
	context.update(_stable_json(content).to_utf8_buffer())
	return context.finish().hex_encode()

func _content_hash() -> String:
	if _content_hash_cache == "":
		_content_hash_cache = _content_hash_for(game_data)
	return _content_hash_cache

func _invalidate_content_hash() -> void:
	_content_hash_cache = ""

func content_source_kind() -> StringName:
	return _content_source_kind

func _replace_game_data(content: Dictionary, source_kind: StringName) -> bool:
	var replacement := content.duplicate(true)
	var prepared := Dictionary(_core_composition.prepare_content_binding(replacement, source_kind))
	if not bool(prepared.get("ok", false)):
		_content_binding_errors = []
		for error_value in Array(prepared.get("errors", [])):
			_content_binding_errors.append(String(error_value))
		return false
	if not _core_composition.commit_content_binding(Dictionary(prepared.get("candidate", {}))):
		_content_binding_errors = ["CONTENT_BIND_COMMIT_REJECTED"]
		return false
	game_data = replacement
	_content_source_kind = source_kind
	_invalidate_content_hash()
	_content_binding_errors = []
	return true

func replace_game_data_for_test(content: Dictionary, source_kind: StringName) -> bool:
	if not ["test", "simulation"].has(_initialization_mode):
		return false
	return _replace_game_data(content, source_kind)

func _determinism_context(embed_content_pack: bool) -> Dictionary:
	var context := {
		"contentHash": _content_hash(),
		"rulesVersion": RULES_VERSION,
		"rngVersion": DeterministicSelectorScript.ALGORITHM_VERSION
	}
	if embed_content_pack:
		context["contentPack"] = game_data.duplicate(true)
	return context

func _log(message: String) -> void:
	log_lines.push_front(message)
	while log_lines.size() > 8:
		log_lines.pop_back()

func configure_core_services(overrides: Dictionary) -> void:
	var replacement := CoreCompositionScript.new(overrides)
	if game_data.is_empty():
		_core_composition = replacement
		return
	# Preserve the pre-existing explicit test-service seam. Production/default
	# compositions must always implement versioned content binding.
	if (overrides.has("quality_effect_registry") or overrides.has("run_event_definition_registry")) \
			and not replacement.supports_content_binding():
		if ["test", "simulation"].has(_initialization_mode):
			_core_composition = replacement
		return
	var prepared := Dictionary(replacement.prepare_content_binding(game_data, _content_source_kind))
	if not bool(prepared.get("ok", false)):
		return
	if not replacement.commit_content_binding(Dictionary(prepared.get("candidate", {}))):
		return
	_core_composition = replacement

func is_initialized() -> bool:
	return bool(_initialization_result.get("ok", false))

func initialization_result() -> Dictionary:
	return _initialization_result.duplicate(true)

func _pet_reset_charge_interval() -> int:
	return _core_composition.pet_reset_policy.charge_interval(
		Dictionary(Dictionary(game_data.get("battle", {})).get("rules", {})),
		DEFAULT_PET_RESET_CHARGE_INTERVAL
	)

func _pet_reset_initial_charges() -> int:
	return _core_composition.pet_reset_policy.initial_charges(
		Dictionary(Dictionary(game_data.get("battle", {})).get("rules", {})),
		DEFAULT_PET_RESET_INITIAL_CHARGES
	)

func _transition_phase(next_phase: String) -> bool:
	if not PhasePolicyScript.can_transition(StringName(phase), StringName(next_phase)):
		_log("阶段切换被拒绝：%s → %s。" % [phase, next_phase])
		return false
	phase = next_phase
	return true

func _clone_units(source_units: Array, side: String) -> Array:
	var cloned: Array = []
	for source in source_units:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		var unit := Dictionary(source).duplicate(true)
		var pet_id := _pet_key(unit)
		if pet_id != "":
			unit["pet_id"] = pet_id
			unit["id"] = String(unit.get("id", pet_id))
		unit["hp"] = int(unit.get("hp", unit.get("max_hp", 1)))
		unit["max_hp"] = int(unit.get("max_hp", unit.get("hp", 1)))
		unit["atk"] = int(unit.get("atk", 0))
		unit["def"] = int(unit.get("def", 0))
		unit["shield"] = int(unit.get("shield", 0))
		unit["count"] = max(1, int(unit.get("count", 1)))
		unit["quality"] = QualityRulesScript.normalize(String(unit.get("quality", "青铜")))
		unit["slot_count"] = max(1, int(unit.get("slot_count", 3)))
		unit["base_layers"] = max(1, int(unit.get("base_layers", 1)))
		unit["hit_cells"] = max(1, int(unit.get("hit_cells", 1)))
		unit["slot_elements"] = SkillShapeRulesScript.slot_elements(unit)
		unit["elements"] = ElementRulesScript.normalize_layers(Dictionary(unit.get("elements", {})))
		if typeof(unit.get("action_slots_used", {})) != TYPE_DICTIONARY:
			unit["action_slots_used"] = {}
		unit["action_ap_spent"] = int(unit.get("action_ap_spent", 0))
		unit["has_attacked"] = bool(unit.get("has_attacked", unit.get("hasAttacked", false)))
		unit["guard_reduction"] = int(unit.get("guard_reduction", 0))
		unit["skill_bonus_atk"] = int(unit.get("skill_bonus_atk", 0))
		var progression_result := _progressed_unit(unit, true)
		if not bool(progression_result.get("ok", false)):
			push_error("Quality progression failed while cloning %s: %s" % [pet_id, str(progression_result.get("errors", []))])
			continue
		unit = Dictionary(progression_result.get("unit", {}))
		unit["x"] = int(unit.get("x", 0))
		unit["y"] = int(unit.get("y", 0))
		unit["side"] = side
		if side == PLAYER:
			unit["active"] = bool(unit.get("active", cloned.size() < MAX_ACTIVE_UNITS))
			unit["slot"] = int(unit.get("slot", cloned.size() + 1)) if bool(unit.get("active", true)) else 0
			unit["bag_slot"] = 0 if bool(unit.get("active", true)) else int(unit.get("bag_slot", unit.get("bagSlot", 0)))
		cloned.append(unit)
	return cloned

func _pet_key(row: Dictionary) -> String:
	var pet_id := String(row.get("pet_id", "")).strip_edges()
	if pet_id != "":
		return pet_id
	return String(row.get("id", "")).strip_edges()

func _leader_position(player_side: bool) -> Dictionary:
	var cell := BattleBoardDimensionsScript.leader_cell(board_dimensions(), player_side)
	return {"r": cell.y, "c": cell.x, "x": cell.x, "y": cell.y}

func _leader_unit(player_side: bool) -> Dictionary:
	var position := _leader_position(player_side)
	var hp := hero_hp if player_side else enemy_hero_hp
	var max_hp := hero_max_hp if player_side else enemy_hero_max_hp
	var side := "hero_leader" if player_side else "boss"
	var camp := "player" if player_side else "enemy"
	var id := "player_hero" if player_side else "enemy_boss"
	var name := "孙悟空" if player_side else "虎先锋"
	var guard_active := _living_unit_count(camp) > 0
	return {
		"id": id,
		"type": "hero" if player_side else "boss",
		"side": side,
		"camp": camp,
		"name": name,
		"displayName": name,
		"hp": hp,
		"maxHp": max_hp,
		"max_hp": max_hp,
		"atk": 0,
		"def": 0,
		"shield": 0,
		"ap": 0,
		"alive": hp > 0,
		"position": {"r": int(position["r"]), "c": int(position["c"])},
		"x": int(position["x"]),
		"y": int(position["y"]),
		"elements": ElementRulesScript.normalize_layers({}),
		"mechanics": ["宠物护卫：单次伤害上限4"] if guard_active else ["宠物护卫已解除"],
		"buffs": [{"id": "pet_guard", "name": "宠物护卫", "active": guard_active, "max_damage_per_hit": 4}]
	}

func _sync_leader_hp_from_target(target: Dictionary) -> void:
	match String(target.get("id", "")):
		"player_hero":
			hero_hp = clampi(int(target.get("hp", hero_hp)), 0, hero_max_hp)
		"enemy_boss":
			enemy_hero_hp = clampi(int(target.get("hp", enemy_hero_hp)), 0, enemy_hero_max_hp)

func _combat_target_at(x: int, y: int) -> Dictionary:
	var unit := unit_at(x, y)
	if not unit.is_empty():
		return unit
	return _leader_at(x, y)

func _leader_guard_side(target: Dictionary) -> String:
	match String(target.get("id", "")):
		"player_hero":
			return PLAYER
		"enemy_boss":
			return ENEMY
	return ""

func _leader_guard_active(target: Dictionary) -> bool:
	var side := _leader_guard_side(target)
	return side != "" and _living_unit_count(side) > 0

func _leader_guarded_damage_packet(target: Dictionary, amount: int) -> int:
	return mini(maxi(0, amount), 4) if _leader_guard_active(target) else maxi(0, amount)

func _leaders() -> Dictionary:
	return {
		"player": _leader_unit(true),
		"enemy": _leader_unit(false)
	}

func _leader_at(x: int, y: int) -> Dictionary:
	for leader_value in _leaders().values():
		var leader := Dictionary(leader_value)
		if bool(leader.get("alive", false)) and int(leader.get("x", -1)) == x and int(leader.get("y", -1)) == y:
			return leader
	return {}

func _split_id_list(value) -> Array:
	var out: Array = []
	if typeof(value) == TYPE_ARRAY:
		for item in Array(value):
			var token := String(item).strip_edges()
			if token != "" and not out.has(token):
				out.append(token)
		return out
	var text := String(value).strip_edges()
	if text == "":
		return out
	for token in text.replace("，", ",").replace("、", ",").replace("；", ",").replace(";", ",").split(",", false):
		var item := String(token).strip_edges()
		if item != "" and not out.has(item):
			out.append(item)
	return out

func _unit_mechanic_ids(unit: Dictionary) -> Array:
	var ids := _split_id_list(unit.get("mechanics", []))
	for item in _split_id_list(unit.get("mechanism_id", "")):
		if item != "none" and not ids.has(item):
			ids.append(item)
	if ids.is_empty():
		ids.append("none")
	return ids

func _mechanism_by_id(mechanism_id: String) -> Dictionary:
	for item in _battle_mechanisms():
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if String(row.get("id", "")) == mechanism_id:
			return row
	return {}

func _battle_mechanisms() -> Array:
	return Array(Dictionary(game_data.get("battle", {})).get("mechanisms", [])).duplicate(true)

func _mechanic_element_settlement_plan(elements: Dictionary, element: String) -> Dictionary:
	return Dictionary(_core_composition.mechanic_projection_service.element_settlement_plan(
		units.duplicate(true),
		_battle_mechanisms(),
		elements.duplicate(true),
		element
	)).duplicate(true)

func _mechanic_param_int(unit: Dictionary, mechanism: Dictionary, key: String, fallback: int) -> int:
	var unit_params := Dictionary(unit.get("mechanic_params", unit.get("mechanicParams", {})))
	if unit_params.has(key):
		return int(unit_params.get(key, fallback))
	for part in String(mechanism.get("default_params", "")).replace("；", ";").split(";", false):
		var text := String(part).strip_edges()
		var equals_index := text.find("=")
		if equals_index <= 0:
			continue
		if text.substr(0, equals_index).strip_edges() == key:
			return int(float(text.substr(equals_index + 1).strip_edges()))
	return fallback

func _mechanic_param_float(unit: Dictionary, mechanism: Dictionary, key: String, fallback: float) -> float:
	var unit_params := Dictionary(unit.get("mechanic_params", unit.get("mechanicParams", {})))
	if unit_params.has(key):
		return float(unit_params.get(key, fallback))
	for part in String(mechanism.get("default_params", "")).replace("；", ";").split(";", false):
		var text := String(part).strip_edges()
		var equals_index := text.find("=")
		if equals_index <= 0:
			continue
		if text.substr(0, equals_index).strip_edges() == key:
			return float(text.substr(equals_index + 1).strip_edges())
	return fallback

func _mechanic_param_string(unit: Dictionary, mechanism: Dictionary, key: String, fallback: String) -> String:
	var unit_params := Dictionary(unit.get("mechanic_params", unit.get("mechanicParams", {})))
	if unit_params.has(key):
		return String(unit_params.get(key, fallback))
	for part in String(mechanism.get("default_params", "")).replace("；", ";").split(";", false):
		var text := String(part).strip_edges()
		var equals_index := text.find("=")
		if equals_index <= 0:
			continue
		if text.substr(0, equals_index).strip_edges() == key:
			return text.substr(equals_index + 1).strip_edges()
	return fallback

func _mechanic_param_element(unit: Dictionary, mechanism: Dictionary, key: String, fallback: String) -> String:
	var value := _mechanic_param_string(unit, mechanism, key, fallback).strip_edges()
	match value.to_lower():
		"fire":
			return "火"
		"water":
			return "水"
		"wind", "air":
			return "雷"
		"earth":
			return "地"
		"metal":
			return "无"
		"wood":
			return "草"
	return ElementRulesScript.canonical(value)

func _quality_progression_context() -> Dictionary:
	return {"gameData": game_data.duplicate(true)}

func _progressed_unit(unit: Dictionary, fill_hp_to_max: bool) -> Dictionary:
	return _core_composition.quality_progression_policy.progress(
		unit,
		_quality_progression_context(),
		fill_hp_to_max
	)

func _roster_index_for_pet_quality(pet_id: String, quality: String) -> int:
	return RosterCollectionServiceScript.index_for_pet_quality(
		roster,
		pet_id,
		quality,
		Callable(self, "_pet_key"),
		func(value: Variant) -> String: return QualityRulesScript.normalize(String(value))
	)

func _next_roster_instance_id(pet_id: String, quality: String, preferred: String = "") -> String:
	return RosterCollectionServiceScript.next_instance_id(
		roster,
		pet_id,
		QualityRulesScript.key(quality),
		preferred
	)

func _acquisition_record(acquired_from: String) -> Dictionary:
	return {
		"source": acquired_from,
		"day": day,
		"node_index": node_index,
		"phase": phase,
		"state_version": state_version,
		"at": "day:%d/node:%d/state:%d" % [day, node_index, state_version]
	}

func _roster_index_for_ref(ref: String) -> int:
	return RosterCollectionServiceScript.index_for_ref(roster, ref, Callable(self, "_pet_key"))

func _active_roster_count(skip_index: int = -1) -> int:
	return PartyRulesScript.active_count(roster, skip_index)

func _bench_roster_count(skip_index: int = -1) -> int:
	return InventoryRulesScript.bench_count(roster, skip_index)

func _next_active_slot() -> int:
	return RosterSlotRulesScript.next_active_slot(roster, MAX_ACTIVE_UNITS)

func _normalize_roster_active_slots() -> void:
	RosterCollectionServiceScript.normalize_active_slots(roster, MAX_ACTIVE_UNITS)

func _normalize_roster_bag_slots() -> void:
	RosterCollectionServiceScript.normalize_bag_slots(roster, MAX_BENCH_UNITS)

func _normalize_roster_slots() -> void:
	_normalize_roster_active_slots()
	_normalize_roster_bag_slots()

func _active_roster_for_battle() -> Array:
	_normalize_roster_active_slots()
	return RosterCollectionServiceScript.active_for_battle(
		roster,
		MAX_ACTIVE_UNITS,
		Callable(self, "_pet_key")
	)

func _battle_deploy_cell(_pet: Dictionary, fallback: Vector2i, used_cells: Dictionary) -> Vector2i:
	if _inside(fallback.x, fallback.y) and not used_cells.has(_cell_key(fallback.x, fallback.y)):
		return fallback
	for y in range(board_height - 1, -1, -1):
		for x in range(board_width):
			var key := _cell_key(x, y)
			if not used_cells.has(key) and _leader_at(x, y).is_empty():
				return Vector2i(x, y)
	return fallback

func _battle_deploy_cells() -> Array[Vector2i]:
	var preferred: Array[Vector2i] = [
		Vector2i(mini(1, board_width - 1), maxi(0, board_height - 3)),
		Vector2i(mini(2, board_width - 1), maxi(0, board_height - 2)),
		Vector2i(0, maxi(0, board_height - 2)),
		Vector2i(mini(1, board_width - 1), maxi(0, board_height - 2)),
		Vector2i(mini(2, board_width - 1), maxi(0, board_height - 3))
	]
	var region := BattleBoardDimensionsScript.side_spawn_region_cells(board_dimensions(), true, 3)
	var leader := BattleBoardDimensionsScript.leader_cell(board_dimensions(), true)
	var ordered: Array[Vector2i] = []
	for cell in preferred:
		if cell != leader and region.has(cell) and not ordered.has(cell):
			ordered.append(cell)
	for cell in region:
		if cell != leader and not ordered.has(cell):
			ordered.append(cell)
	return ordered

func _sell_value_for_quality(quality: String) -> int:
	return QualityRulesScript.sell_value(quality)

func _normalize_drop_type(value: Variant) -> String:
	return RosterSlotRulesScript.normalize_drop_type(value)

func _target_active_slot(target_index: int, skip_index: int = -1) -> int:
	return RosterSlotRulesScript.target_active_slot(roster, target_index, MAX_ACTIVE_UNITS, skip_index)

func _requested_active_slot(target_index: int) -> int:
	return RosterSlotRulesScript.requested_active_slot(roster, target_index, MAX_ACTIVE_UNITS)

func _roster_index_for_active_slot(slot: int, skip_index: int = -1) -> int:
	return RosterSlotRulesScript.index_for_active_slot(roster, slot, MAX_ACTIVE_UNITS, skip_index)

func _next_bag_slot_excluding(skip_index: int = -1) -> int:
	return RosterSlotRulesScript.next_bag_slot(roster, MAX_BENCH_UNITS, skip_index)

func _target_bag_slot(target_index: int, skip_index: int = -1) -> int:
	return RosterSlotRulesScript.target_bag_slot(roster, target_index, MAX_BENCH_UNITS, skip_index)

func _requested_bag_slot(target_index: int) -> int:
	return RosterSlotRulesScript.requested_bag_slot(roster, target_index, MAX_BENCH_UNITS)

func _roster_index_for_bag_slot(slot: int, skip_index: int = -1) -> int:
	return RosterSlotRulesScript.index_for_bag_slot(roster, slot, MAX_BENCH_UNITS, skip_index)

func _add_pet_to_roster(source: Dictionary, acquired_from: String, target_kind: String = "", target_index: int = -1) -> Dictionary:
	var pet_id: String = _pet_key(source)
	if pet_id == "":
		pet_id = "pet_%03d" % roster.size()
	var incoming_quality := QualityRulesScript.normalize(String(source.get("quality", "青铜")))
	var acquisition := _acquisition_record(acquired_from)
	var index: int = _roster_index_for_pet_quality(pet_id, incoming_quality)
	if index >= 0:
		var existing: Dictionary = Dictionary(roster[index]).duplicate(true)
		var quality_from: String = QualityRulesScript.normalize(String(existing.get("quality", incoming_quality)))
		var quality_to := ""
		var count: int = max(1, int(existing.get("count", 1))) + 1
		while count >= 2:
			var next_quality: String = QualityRulesScript.next(quality_from)
			if next_quality == "":
				break
			count -= 2
			quality_to = next_quality
			quality_from = next_quality
			count += 1
		existing["pet_id"] = pet_id
		existing["quality"] = quality_from
		existing["count"] = count
		existing["side"] = PLAYER
		existing["acquired_from"] = acquired_from
		existing["acquired_at"] = acquisition.duplicate(true)
		var acquisition_history := Array(existing.get("acquisition_history", [])).duplicate(true)
		acquisition_history.append(acquisition.duplicate(true))
		existing["acquisition_history"] = acquisition_history
		var requested_kind := _normalize_drop_type(target_kind)
		if requested_kind == "party":
			if bool(existing.get("active", true)) or _active_roster_count(index) < MAX_ACTIVE_UNITS:
				existing["active"] = true
				existing["slot"] = _target_active_slot(target_index, index)
				existing["bag_slot"] = 0
		elif requested_kind == "bag":
			if not bool(existing.get("active", true)) or _bench_roster_count(index) < MAX_BENCH_UNITS:
				existing["active"] = false
				existing["slot"] = 0
				existing["bag_slot"] = _target_bag_slot(target_index, index)
		else:
			existing["active"] = bool(existing.get("active", true))
			existing["slot"] = int(existing.get("slot", _next_active_slot())) if bool(existing["active"]) else 0
			existing["bag_slot"] = 0 if bool(existing["active"]) else int(existing.get("bag_slot", existing.get("bagSlot", _target_bag_slot(-1, index))))
		var progression_result := _progressed_unit(existing, true)
		if not bool(progression_result.get("ok", false)):
			push_error("Quality progression failed while merging %s: %s" % [pet_id, str(progression_result.get("errors", []))])
			return {}
		existing = Dictionary(progression_result.get("unit", {}))
		roster[index] = existing
		return {
			"merged": true,
			"pet_id": pet_id,
			"name": String(existing.get("name", source.get("name", pet_id))),
			"quality": quality_from,
			"quality_to": quality_to,
			"count": count,
			"acquired_from": acquired_from,
			"acquired_at": acquisition.duplicate(true),
			"active": bool(existing.get("active", true)),
			"placement": "active" if bool(existing.get("active", true)) else "bench"
		}
	var slot: int = roster.size()
	var pet: Dictionary = source.duplicate(true)
	var requested_kind := _normalize_drop_type(target_kind)
	var active := _active_roster_count() < MAX_ACTIVE_UNITS
	if requested_kind == "party":
		active = _active_roster_count() < MAX_ACTIVE_UNITS
	elif requested_kind == "bag":
		active = false
	pet["id"] = _next_roster_instance_id(pet_id, incoming_quality, String(pet.get("id", "")))
	pet["pet_id"] = pet_id
	pet["x"] = clamp(slot, 0, MAX_ACTIVE_UNITS - 1)
	pet["y"] = 6
	pet["hp"] = int(pet.get("max_hp", 1))
	pet["side"] = PLAYER
	pet["count"] = max(1, int(pet.get("count", 1)))
	pet["quality"] = incoming_quality
	pet["acquired_from"] = acquired_from
	pet["acquired_at"] = acquisition.duplicate(true)
	pet["acquisition_history"] = [acquisition.duplicate(true)]
	pet["active"] = active
	pet["slot"] = _target_active_slot(target_index) if active else 0
	pet["bag_slot"] = 0 if active else _target_bag_slot(target_index)
	var progression_result := _progressed_unit(pet, true)
	if not bool(progression_result.get("ok", false)):
		push_error("Quality progression failed while adding %s: %s" % [pet_id, str(progression_result.get("errors", []))])
		return {}
	pet = Dictionary(progression_result.get("unit", {}))
	roster.append(pet)
	return {
		"merged": false,
		"pet_id": pet_id,
		"name": String(pet.get("name", pet_id)),
		"quality": String(pet.get("quality", "青铜")),
		"count": int(pet.get("count", 1)),
		"acquired_from": acquired_from,
		"acquired_at": acquisition.duplicate(true),
		"active": active,
		"placement": "active" if active else "bench"
	}

func sell_unit(ref: String) -> bool:
	var index := _roster_index_for_ref(ref)
	if index < 0:
		_log("出售失败：找不到单位 %s。" % ref)
		return false
	var pet: Dictionary = Dictionary(roster[index]).duplicate(true)
	var refund := _sell_value_for_quality(String(pet.get("quality", "青铜")))
	var before := coins
	coins += refund
	var count: int = max(0, int(pet.get("count", 1)) - 1)
	if count <= 0:
		roster.remove_at(index)
		_normalize_roster_bag_slots()
	else:
		pet["count"] = count
		roster[index] = pet
	var unit := unit_by_id(String(pet.get("id", pet.get("pet_id", ""))))
	if not unit.is_empty():
		unit["hp"] = 0
		unit["active"] = false
	_log("出售 %s，金币%d→%d。" % [String(pet.get("name", pet.get("pet_id", ref))), before, coins])
	return true

func toggle_unit_active(ref: String) -> bool:
	var index := _roster_index_for_ref(ref)
	if index < 0:
		_log("切换失败：找不到 %s。" % ref)
		return false
	var pet: Dictionary = Dictionary(roster[index]).duplicate(true)
	var currently_active := bool(pet.get("active", true))
	if currently_active:
		if _bench_roster_count(index) >= MAX_BENCH_UNITS:
			_log("下阵失败：背包已满 %d/%d。" % [MAX_BENCH_UNITS, MAX_BENCH_UNITS])
			return false
		pet["active"] = false
		pet["slot"] = 0
		pet["bag_slot"] = _target_bag_slot(-1, index)
		_log("下阵：%s 进入背包。" % String(pet.get("name", pet.get("pet_id", ref))))
	else:
		if _active_roster_count(index) >= MAX_ACTIVE_UNITS:
			_log("上阵失败：上场位已满 %d/%d。" % [MAX_ACTIVE_UNITS, MAX_ACTIVE_UNITS])
			return false
		pet["active"] = true
		pet["slot"] = _next_active_slot()
		pet["bag_slot"] = 0
		_log("上阵：%s。" % String(pet.get("name", pet.get("pet_id", ref))))
	roster[index] = pet
	return true

func _is_boss_enemy(unit: Dictionary) -> bool:
	if String(unit.get("id", "")) == "enemy_boss":
		return true
	if String(unit.get("side", "")) != ENEMY:
		return false
	for key in ["is_boss", "isBoss", "boss"]:
		if bool(unit.get(key, false)):
			return true
	var role_text := "%s %s %s %s" % [
		String(unit.get("role", "")),
		String(unit.get("enemy_role", "")),
		String(unit.get("enemyType", "")),
		String(unit.get("type", ""))
	]
	if role_text.to_lower().find("boss") >= 0 or role_text.find("首领") >= 0:
		return true
	var identity_text := "%s %s" % [String(unit.get("id", "")), String(unit.get("name", ""))]
	return identity_text.to_lower().find("boss") >= 0 or identity_text.find("首领") >= 0

func _apply_stat_semantics(event_id: String, context: Dictionary) -> Dictionary:
	var effective := context.duplicate()
	effective["stat_value"] = Callable(self, "_resolved_stat_value")
	return Dictionary(_core_composition.stat_semantic_pipeline.apply(event_id, effective))

func _battle_query_damage_final(
	source: Dictionary,
	target: Dictionary,
	amount: int,
	element: String = "",
	trace_context: Dictionary = {},
	damage_props: Variant = {},
	query_context: Dictionary = {},
	query_session: RefCounted = null
) -> int:
	if query_session != null:
		return int(query_session.call(
			"project_damage_final", source, target, amount, element, trace_context, damage_props
		))
	var effective_context := query_context if not query_context.is_empty() else _battle_query_context()
	return int(_core_composition.battle_query_projector.project_damage(
		effective_context,
		source,
		target,
		amount,
		element,
		trace_context,
		damage_props
	).get("final", 0))

func _quality_upgrade(attacker: Dictionary) -> Dictionary:
	return Dictionary(attacker.get("quality_upgrade", {}))

func _quality_upgrade_id(attacker: Dictionary) -> String:
	return String(_quality_upgrade(attacker).get("id", ""))

func _quality_upgrade_name(attacker: Dictionary) -> String:
	var upgrade := _quality_upgrade(attacker)
	return String(upgrade.get("name", upgrade.get("id", "")))

func _quality_mark_matches_unit(marked_cell: Dictionary, unit: Dictionary) -> bool:
	return _core_composition.quality_runtime_service.mark_matches_unit(marked_cell, unit)

func _option_cell_index_for_target(option: Dictionary, target: Dictionary) -> int:
	return ShapeGeometryScript.option_cell_index(option, target)

func _core_cell_index(option: Dictionary) -> int:
	return _core_composition.quality_hit_context_projector.core_cell_index(option)

func _quality_cell_damage_delta(option: Dictionary, target: Dictionary) -> int:
	return _core_composition.quality_hit_context_projector.cell_damage_delta(option, target)

func _option_all_cells_occupied(option: Dictionary) -> bool:
	for cell in Array(option.get("cells", [])):
		var row := Dictionary(cell)
		if unit_at(int(row.get("x", -1)), int(row.get("y", -1))).is_empty():
			return false
	return true

func _quality_hit_context(
	attacker: Dictionary,
	option: Dictionary,
	targets: Array,
	target: Dictionary,
	hit_index: int,
	damage: int
) -> Dictionary:
	var runtime := Dictionary(attacker.get("quality_runtime", {}))
	var marked_cell := Dictionary(runtime.get("marked_cell", {}))
	return _core_composition.quality_hit_context_projector.build(
		attacker,
		option,
		targets,
		target,
		hit_index,
		damage,
		_option_all_cells_occupied(option),
		_quality_mark_matches_unit(marked_cell, target)
	)

func _quality_modify_hit_damage(attacker: Dictionary, context: Dictionary) -> int:
	return int(_core_composition.quality_effect_registry.effect_for_unit(attacker).modify_hit_damage(context))

func _opponent_side(side: String) -> String:
	return PLAYER if side == ENEMY else ENEMY

func _shape_attack_options(unit: Dictionary) -> Array:
	var definition := _shape_definition(unit)
	return _core_composition.attack_option_service.build_options(
		unit,
		board_width,
		board_height,
		definition,
		_core_composition.quality_effect_registry.effect_for_unit(unit),
		_quality_upgrade_name(unit)
	)

func _quality_shape_name(unit: Dictionary, base_name: String) -> String:
	return _core_composition.attack_option_service.quality_shape_name(
		base_name,
		_core_composition.quality_effect_registry.effect_for_unit(unit),
		_quality_upgrade_name(unit)
	)

func _option_contains_cell(option: Dictionary, x: int, y: int) -> bool:
	return ShapeGeometryScript.option_contains_cell(option, x, y)

func _attack_option_for_direction(attacker: Dictionary, direction: String) -> Dictionary:
	return _core_composition.attack_option_service.option_for_direction(
		_shape_attack_options(attacker),
		direction
	)

func _attack_option_for_target(attacker: Dictionary, target: Dictionary, direction: String = "") -> Dictionary:
	return _core_composition.attack_option_service.option_for_target(
		_shape_attack_options(attacker),
		target,
		direction
	)

func _quality_attack_option_for_target(attacker: Dictionary, target: Dictionary, option: Dictionary) -> Dictionary:
	return _core_composition.quality_effect_registry.effect_for_unit(
		attacker
	).attack_option_for_target(attacker, target, option)

func _enemies_in_attack_option(attacker: Dictionary, option: Dictionary) -> Array:
	var target_side := _opponent_side(String(attacker.get("side", PLAYER)))
	var opposing_leader := _leader_unit(target_side == PLAYER)
	var targets: Array = _core_composition.targeting_service.targets_in_option(
		attacker,
		option,
		units,
		opposing_leader,
		target_side
	)
	_core_composition.quality_effect_registry.effect_for_unit(attacker).sort_targets(targets, option)
	return targets

func _nearest_player(enemy: Dictionary) -> Dictionary:
	var taunt_target := _guard_taunt_target_for_enemy(enemy)
	if not taunt_target.is_empty():
		return taunt_target
	var living_players: Array = []
	for target_value in units:
		var target := Dictionary(target_value)
		if String(target.get("side", "")) != PLAYER or int(target.get("hp", 0)) <= 0:
			continue
		living_players.append(target)
	var selection: Dictionary = _core_composition.threat_target_policy.select(
		enemy,
		living_players,
		_leader_unit(true),
		[]
	)
	return Dictionary(selection.get("target", {}))

func _guard_taunt_target_for_enemy(enemy: Dictionary) -> Dictionary:
	if enemy.is_empty():
		return {}
	var taunt_candidates := Array(_core_composition.mechanic_projection_service.threat_candidates(
		units.duplicate(true),
		_battle_mechanisms(),
		{"enemy": enemy.duplicate(true)}
	)).duplicate(true)
	var selection: Dictionary = _core_composition.threat_target_policy.select(
		enemy,
		[],
		{},
		taunt_candidates
	)
	var redirect := Dictionary(selection.get("redirect", {}))
	if redirect.is_empty():
		return {}
	enemy["target_select_redirect"] = redirect
	var selected_target := Dictionary(selection.get("target", {}))
	var selected_target_id := String(selected_target.get("id", ""))
	if selected_target_id == "":
		return {}
	return unit_by_id(selected_target_id)

func _record_history_after_command(
	action_type: String,
	command: Dictionary,
	before_version: int,
	before_hash: String,
	before_phase: String,
	after_hash: String
) -> void:
	var result: Dictionary = _core_composition.run_history_committer.record(RunHistoryPortScript.new(self), {
		"actionType": action_type,
		"command": command,
		"beforeVersion": before_version,
		"beforeHash": before_hash,
		"beforePhase": before_phase,
		"afterHash": after_hash,
	})
	var message := String(result.get("message", ""))
	if not bool(result.get("ok", false)) and message != "":
		_log(message)

func dispatch(action: Dictionary, known_before_hash: String = "", calculate_state_hash: bool = true) -> bool:
	var action_type := _normalize_action_type(String(action.get("type", "")))
	last_command_result = {}
	last_manual_flow_preview = {}
	var before_version := state_version
	var before_hash := known_before_hash if known_before_hash != "" else (_state_hash() if calculate_state_hash else "")
	_last_dispatch_state_hash = before_hash
	var before_phase := phase
	var baseline_error := (
		_command_baseline_error(action, before_hash)
		if calculate_state_hash or action.has("baseStateHash") or action.has("base_state_hash")
		else CommandContractScript.baseline_error(action, state_version, "")
	)
	if not baseline_error.is_empty():
		var baseline_code := String(baseline_error.get("code", "COMMAND_BASELINE_REJECTED"))
		_log("%s：%s" % [baseline_code, String(baseline_error.get("message", "指令基线不匹配。"))])
		_record_rejected_dispatch(action_type, action, before_version, before_hash, baseline_code)
		return false
	if not PhasePolicyScript.can_execute(StringName(phase), action_type):
		_log("阶段 %s 不接受指令 %s。" % [phase, action_type])
		_record_rejected_dispatch(action_type, action, before_version, before_hash, "PHASE_COMMAND_REJECTED")
		return false
	var checkpoint_plan := _command_checkpoint_plan(action_type, action)
	var command_checkpoint := (
		AuthoritativeStateCodecScript.capture_properties(self, Array(checkpoint_plan.get("properties", [])))
		if String(checkpoint_plan.get("mode", "full")) == "narrow"
		else AuthoritativeStateCodecScript.capture(self, false)
	)
	var checkpoint_logs := Array(command_checkpoint.get("log_lines", [])).duplicate(true)
	var action_result := _dispatch_action(action_type, action)
	if action_type == "MOVE_HERO":
		last_command_result = action_result
		return _record_dispatch_result(action_type, action, true, before_version, before_hash, before_phase, calculate_state_hash)
	if not action_result:
		var rejection_logs := _command_rejection_logs(checkpoint_logs, log_lines)
		AuthoritativeStateCodecScript.restore_changed(self, command_checkpoint)
		last_command_result = {}
		last_manual_flow_preview = {}
		for index in range(rejection_logs.size() - 1, -1, -1):
			_log(String(rejection_logs[index]))
		_log("指令 %s 被规则拒绝，权威状态未改变。" % action_type)
	return _record_dispatch_result(action_type, action, action_result, before_version, before_hash, before_phase, calculate_state_hash)


func _command_checkpoint_plan(action_type: String, action: Dictionary) -> Dictionary:
	match action_type:
		"ENTER_SHOP":
			return {"mode": "narrow", "properties": SHOP_ENTRY_CHECKPOINT_FIELDS}
		"BACK_TO_ROUTE", "EXIT_SHOP":
			return {"mode": "narrow", "properties": SHOP_EXIT_CHECKPOINT_FIELDS}
		"ROLL_SHOP":
			return {"mode": "narrow", "properties": SHOP_ROLL_CHECKPOINT_FIELDS}
		"BUY_OFFER":
			var offer_id := String(action.get("offer_id", action.get("offerId", action.get("id", ""))))
			for offer_value in shop_offers:
				var offer := Dictionary(offer_value)
				if String(offer.get("id", offer.get("offer_id", offer.get("offerId", "")))) != offer_id:
					continue
				var item_type := String(offer.get("item_type", "宠物" if String(offer.get("pet_id", "")) != "" else ""))
				if item_type == "宠物":
					return {"mode": "narrow", "properties": SHOP_PET_BUY_CHECKPOINT_FIELDS}
				return {"mode": "full", "properties": []}
			# A missing offer cannot mutate gameplay state, but its rejection still
			# needs the normal diagnostic-log preservation path.
			return {"mode": "narrow", "properties": ["log_lines"]}
		"CHOOSE_ROUTE":
			var option_id := String(action.get("option_id", action.get("optionId", "")))
			for option_value in route_options:
				var option := Dictionary(option_value)
				if option_id not in [
					String(option.get("id", "")), String(option.get("optionId", "")),
					String(option.get("nodeId", "")), String(option.get("encounterId", "")),
				]:
					continue
				if String(option.get("kind", "")) == "shop":
					return {"mode": "narrow", "properties": SHOP_ROUTE_CHECKPOINT_FIELDS}
				return {"mode": "full", "properties": []}
			return {"mode": "narrow", "properties": ["log_lines"]}
		_:
			return {"mode": "full", "properties": []}

func _command_rejection_logs(before_logs: Array, after_logs: Array) -> Array:
	# `_log()` pushes to the front and caps the list. Find the retained prefix of
	# the pre-command log so only diagnostics produced by the rejected handler
	# survive the authoritative rollback.
	for new_log_count in range(after_logs.size() + 1):
		var retained_count := after_logs.size() - new_log_count
		if retained_count > before_logs.size():
			continue
		if after_logs.slice(new_log_count) == before_logs.slice(0, retained_count):
			return after_logs.slice(0, new_log_count).duplicate(true)
	# A handler may replace its log projection wholesale (for example reset()).
	# In that case the current projection is the only available failure context.
	return after_logs.duplicate(true)

func run_command(action: Dictionary) -> Dictionary:
	var action_type := _normalize_action_type(String(action.get("type", "")))
	var operation_started_unix_ms := Time.get_ticks_msec()
	var operation_log_enabled := GameLogScript.operation_log_enabled()
	var before_summary: Dictionary = _core_composition.player_operation_projector.state_summary(_player_operation_projection_context()) if operation_log_enabled else {}
	var before_logs := log_lines.duplicate() if operation_log_enabled else []
	var before_version := state_version
	var before_hash := _state_hash()
	var before_trace_count := battle_trace.size()
	var before_phase := phase
	var baseline_error := _command_baseline_error(action, before_hash)
	var accepted: bool = dispatch(action, before_hash)
	var snapshot_started_usec := Time.get_ticks_usec()
	var after_snapshot: Dictionary = snapshot(_last_dispatch_state_hash)
	var snapshot_duration_usec := Time.get_ticks_usec() - snapshot_started_usec
	var result_value: Variant = _duplicate_result_value(last_command_result)
	var response: Dictionary = _core_composition.command_response_builder.build({
		"accepted": accepted,
		"command": action_type,
		"commandEnvelope": _command_envelope(action_type, action, before_version, before_hash),
		"beforeVersion": before_version,
		"beforeHash": before_hash,
		"result": result_value,
		"events": _response_events_since(before_trace_count),
		"trace": _response_trace_since(before_trace_count),
		"snapshot": after_snapshot,
		"timing": {
			"snapshotDurationUs": snapshot_duration_usec
		},
		"ephemeral": _is_view_state_action(action_type),
		"readOnly": _is_read_only_action(action_type),
		"error": _command_error(action_type, baseline_error) if not accepted else {},
		"manualFlowPreview": last_manual_flow_preview if action_type == "MOVE_HERO" else {}
	})
	var operation_duration_ms := Time.get_ticks_msec() - operation_started_unix_ms
	GameLogScript.info("核心/命令", "命令处理完成", {
		"命令": action_type,
		"结果": "接受" if accepted else "拒绝",
		"阶段": "%s → %s" % [before_phase, phase],
		"回合": battle_round,
		"耗时毫秒": operation_duration_ms,
		"新增表现事件": Array(response.get("events", [])).size(),
		"状态版本": "%d → %d" % [before_version, int(response.get("stateVersion", before_version))]
	})
	if operation_log_enabled:
		_append_player_operation({
			"kind": "command",
			"command": action_type,
			"action": _replay_json_safe(action),
			"accepted": accepted,
			"durationMs": operation_duration_ms,
			"before": before_summary,
			"after": _core_composition.player_operation_projector.state_summary(_player_operation_projection_context()),
			"result": _core_composition.player_operation_projector.result_summary(result_value),
			"previewSummary": _core_composition.player_operation_projector.preview_summary(
				after_snapshot,
				Dictionary(response.get("manualFlowPreview", {}))
			),
			"events": _core_composition.player_operation_projector.event_summaries(Array(response.get("events", [])), {"round": battle_round, "phase": phase}),
			"logs": _core_composition.player_operation_projector.new_logs(before_logs, log_lines),
			"error": Dictionary(response.get("error", {})).duplicate(true)
		})
	return response


func can_run_incremental_command(action: Dictionary) -> bool:
	if history_recording_enabled:
		return false
	var action_type := _normalize_action_type(String(action.get("type", "")))
	if action_type in ["ENTER_SHOP", "ROLL_SHOP", "EXIT_SHOP", "BACK_TO_ROUTE"]:
		return true
	if action_type == "CHOOSE_ROUTE":
		var route_plan := _command_checkpoint_plan(action_type, action)
		return String(route_plan.get("mode", "full")) == "narrow" and Array(route_plan.get("properties", [])).has("active_stall")
	if action_type == "BUY_OFFER":
		var plan := _command_checkpoint_plan(action_type, action)
		var properties := Array(plan.get("properties", []))
		return String(plan.get("mode", "full")) == "narrow" and (properties.has("roster") or properties == ["log_lines"])
	return false


func run_incremental_command(action: Dictionary) -> Dictionary:
	if not can_run_incremental_command(action):
		return run_command(action)
	var action_type := _normalize_action_type(String(action.get("type", "")))
	var operation_started_usec := Time.get_ticks_usec()
	var before_version := state_version
	var before_trace_count := battle_trace.size()
	var before_phase := phase
	var baseline_error := CommandContractScript.baseline_error(action, state_version, "")
	var dispatch_started_usec := Time.get_ticks_usec()
	var accepted := dispatch(action, "", false)
	var dispatch_done_usec := Time.get_ticks_usec()
	var delta := _incremental_presentation_delta(action_type)
	var delta_done_usec := Time.get_ticks_usec()
	var response: Dictionary = _core_composition.command_response_builder.build_incremental({
		"accepted": accepted,
		"command": action_type,
		"commandEnvelope": _command_envelope(action_type, action, before_version, ""),
		"beforeVersion": before_version,
		"afterVersion": state_version,
		"result": _duplicate_result_value(last_command_result),
		"events": _response_events_since(before_trace_count),
		"trace": _response_trace_since(before_trace_count),
		"delta": delta,
		"timing": {"incrementalDurationUs": Time.get_ticks_usec() - operation_started_usec},
		"error": _command_error(action_type, baseline_error) if not accepted else {},
	})
	GameLogScript.info("核心/命令", "增量命令处理完成", {
		"命令": action_type,
		"结果": "接受" if accepted else "拒绝",
		"阶段": "%s → %s" % [before_phase, phase],
		"耗时微秒": Time.get_ticks_usec() - operation_started_usec,
		"规则微秒": dispatch_done_usec - dispatch_started_usec,
		"增量投影微秒": delta_done_usec - dispatch_done_usec,
		"状态版本": "%d → %d" % [before_version, state_version],
	})
	return response


func _incremental_presentation_delta(action_type: String) -> Dictionary:
	var actions := _next_actions()
	var delta := {
		"phase": phase,
		"stateVersion": state_version,
		"state_version": state_version,
		"stateHash": "",
		"state_hash": "",
		"next_actions": actions.duplicate(true),
		"nextActions": actions.duplicate(true),
		"log_lines": log_lines.duplicate(true),
		"last_command_result": _duplicate_result_value(last_command_result),
		"lastCommandResult": _duplicate_result_value(last_command_result),
	}
	if action_type == "BUY_OFFER":
		delta.merge({
			"coins": coins,
			"roster": roster.duplicate(true),
			"shop_offers": shop_offers.duplicate(true),
			"inventory": {
				"active_count": _active_roster_count(),
				"bench_count": _bench_roster_count(),
				"max_active": MAX_ACTIVE_UNITS,
				"max_bench": MAX_BENCH_UNITS,
			},
		})
		return delta
	if action_type in ["EXIT_SHOP", "BACK_TO_ROUTE"]:
		delta.merge({
			"selected_unit_id": selected_unit_id,
			"selected_action_slot_index": selected_action_slot_index,
			"active_schedule": active_schedule.duplicate(true),
			"active_encounter": active_encounter.duplicate(true),
		})
		return delta
	var seen_pet_ids := _shop_seen_pet_ids_for_day()
	delta.merge({
		"coins": coins,
		"active_stall": active_stall.duplicate(true),
		"active_shop_pool": active_shop_pool,
		"active_shop_seed_context": active_shop_seed_context,
		"active_schedule": active_schedule.duplicate(true),
		"route_options": route_options.duplicate(true),
		"shop_offers": shop_offers.duplicate(true),
		"shop_events": _available_shop_events(),
		"shop_roll_count": shop_roll_count,
		"shop_context_roll_count": shop_context_roll_count,
		"shop_free_rolls": shop_free_rolls,
		"shop_paid_refreshes": shop_paid_refreshes,
		"shop_next_discount": shop_next_discount,
		"shop_event_effects": shop_event_effects.duplicate(true),
		"shop_seen_pet_ids": seen_pet_ids,
		"shop_seen_pet_ids_by_day": shop_seen_pet_ids_by_day.duplicate(true),
		"shop_seed_audit": shop_seed_audit.duplicate(true),
		"shop_refresh": {
			"free_rolls": shop_free_rolls,
			"paid_refreshes": shop_paid_refreshes,
			"next_refresh_cost": 0 if shop_free_rolls > 0 else _paid_refresh_cost(),
			"next_discount": shop_next_discount,
			"effects": shop_event_effects.duplicate(true),
			"daily_seen_pet_ids": seen_pet_ids.duplicate(true),
			"daily_seen_count": seen_pet_ids.size(),
		},
		"rng": {
			"seed": run_seed,
			"shop_roll_count": shop_roll_count,
			"shop_context_roll_count": shop_context_roll_count,
			"active_shop_seed_context": active_shop_seed_context,
		},
	})
	return delta

func _append_player_operation(payload: Dictionary) -> bool:
	if _initialization_mode != "production" or not GameLogScript.operation_log_enabled():
		return false
	var entry := payload.duplicate(true)
	entry["timestamp"] = Time.get_datetime_string_from_system(true, true)
	entry["unixMs"] = int(Time.get_unix_time_from_system() * 1000.0)
	if not _core_composition.operation_log_repository.append(player_operation_log_path, entry):
		GameLogScript.warning("持久日志", "无法打开玩家操作日志", {"路径": player_operation_log_path})
		return false
	return true

func _player_operation_projection_context() -> Dictionary:
	return {
		"phase": phase,
		"day": day,
		"nodeIndex": node_index,
		"battleRound": battle_round,
		"battlePeriod": battle_period,
		"difficulty": difficulty,
		"boardWidth": board_width,
		"boardHeight": board_height,
		"stateVersion": state_version,
		"selectedUnitId": selected_unit_id,
		"selectedActionSlotIndex": selected_action_slot_index,
		"ap": ap,
		"coins": coins,
		"heroHp": hero_hp,
		"units": units.duplicate(true),
	}

func _command_baseline_error(action: Dictionary, current_hash: String = "") -> Dictionary:
	var resolved_hash := current_hash if current_hash != "" else _state_hash()
	return CommandContractScript.baseline_error(action, state_version, resolved_hash)

func _record_dispatch_result(action_type: String, action: Dictionary, accepted: bool, before_version: int, before_hash: String, before_phase: String, calculate_state_hash: bool = true) -> bool:
	if accepted and not _is_view_state_action(action_type):
		if action_type != "MOVE_HERO" and not _is_read_only_action(action_type):
			placement_damage_by_unit = {}
		state_version += 1
		var after_hash := _state_hash() if calculate_state_hash else ""
		_last_dispatch_state_hash = after_hash
		var after_phase := phase
		var replay_command := _replayable_command(action_type, action, before_version)
		command_log.append({
			"type": action_type,
			"raw": action.duplicate(true),
			"command": replay_command,
			"phase": after_phase,
			"beforePhase": before_phase,
			"afterPhase": after_phase,
			"beforeVersion": before_version,
			"afterVersion": state_version,
			"beforeHash": before_hash,
			"afterHash": after_hash,
			"accepted": true
		})
		replay_debug_timeline.append(_replay_debug_entry(replay_debug_timeline.size() + 1, replay_command, before_version, before_hash, state_version, after_hash, true, true, ""))
		_record_history_after_command(
			action_type,
			replay_command,
			before_version,
			before_hash,
			before_phase,
			after_hash
		)
		_attach_post_placement_damage_preview(action_type, action)
	elif not accepted:
		_record_rejected_dispatch(action_type, action, before_version, before_hash, "COMMAND_REJECTED")
	return accepted

func _attach_post_placement_damage_preview(action_type: String, action: Dictionary) -> void:
	if not ["MOVE_HERO", "AUTO_POSITION_HEROES"].has(action_type):
		return
	if action_type == "MOVE_HERO" and last_command_result != true:
		return
	if action_type == "AUTO_POSITION_HEROES" and (typeof(last_command_result) != TYPE_DICTIONARY or not bool(Dictionary(last_command_result).get("ok", false))):
		return
	placement_damage_by_unit = {}
	var preview := _manual_flow_preview({
		"type": "PREVIEW_MANUAL_FLOW",
		"playerId": String(action.get("playerId", action.get("player_id", "p1"))),
		"battleId": String(action.get("battleId", action.get("battle_id", ""))),
		"commandId": "%s:placement-preview" % String(action.get("commandId", action.get("command_id", action_type.to_lower()))),
		"limit": 2
	})
	if action_type == "MOVE_HERO":
		last_command_result = true
	last_manual_flow_preview = preview.duplicate(true)
	placement_damage_by_unit = Dictionary(preview.get("damageByUnit", {})).duplicate(true)

func _record_rejected_dispatch(action_type: String, action: Dictionary, before_version: int, before_hash: String, error: String) -> void:
	_last_dispatch_state_hash = before_hash
	replay_debug_timeline.append(_replay_debug_entry(replay_debug_timeline.size() + 1, _replayable_command(action_type, action, before_version), before_version, before_hash, state_version, before_hash, false, false, error))

func _command_envelope(action_type: String, action: Dictionary, before_version: int, before_hash: String) -> Dictionary:
	return CommandContractScript.command_envelope(action_type, action, before_version, before_hash)

func _command_error(action_type: String, baseline_error: Dictionary = {}) -> Dictionary:
	return CommandContractScript.command_error(action_type, baseline_error)

func _is_read_only_action(action_type: String) -> bool:
	return CommandContractScript.is_read_only_action(action_type)

func _response_events_since(before_trace_count: int) -> Array:
	var events: Array = []
	for index in range(before_trace_count, battle_trace.size()):
		events.append(Dictionary(battle_trace[index]).duplicate(true))
	return events

func _response_trace_since(before_trace_count: int) -> Array:
	return _response_events_since(before_trace_count)

func _replayable_command(action_type: String, action: Dictionary, before_version: int) -> Dictionary:
	return CommandContractScript.replayable_command(action_type, action, before_version)

func _sanitize_replay_initial_options(options: Dictionary) -> Dictionary:
	return CommandContractScript.sanitize_replay_initial_options(options)

func _replay_json_safe(value: Variant) -> Variant:
	return CommandContractScript.replay_json_safe(value)

func _is_view_state_action(action_type: String) -> bool:
	return CommandContractScript.is_view_state_action(action_type)

func _dispatch_action(action_type: String, action: Dictionary) -> bool:
	var handler: RefCounted = _command_handler_registry.handler_for(action_type)
	if handler == null:
		_log("未知指令：%s。" % action_type)
		return false
	var port: RefCounted = _command_port_factory.create(_command_handler_registry.domain_for(action_type), self)
	if port == null:
		_log("指令 %s 缺少领域能力端口。" % action_type)
		return false
	return bool(handler.call("execute", port, action_type, action))

func _normalize_action_type(raw_type: String) -> String:
	return CommandContractScript.normalize_action_type(raw_type)

func _route_option_id(action: Dictionary) -> String:
	return String(action.get("option_id", action.get("optionId", action.get("nodeId", action.get("node_id", action.get("encounterId", action.get("encounter_id", "")))))))

func _offer_id(action: Dictionary) -> String:
	return String(action.get("offer_id", action.get("offerId", action.get("id", ""))))

func _action_x(action: Dictionary) -> int:
	if action.has("x"):
		return int(action["x"])
	if action.has("c"):
		return int(action["c"])
	if action.has("col"):
		return int(action["col"])
	var cell := Dictionary(action.get("cell", {}))
	if cell.is_empty():
		cell = Dictionary(action.get("to", {}))
	return int(cell.get("c", cell.get("x", -1)))

func _action_y(action: Dictionary) -> int:
	if action.has("y"):
		return int(action["y"])
	if action.has("r"):
		return int(action["r"])
	if action.has("row"):
		return int(action["row"])
	var cell := Dictionary(action.get("cell", {}))
	if cell.is_empty():
		cell = Dictionary(action.get("to", {}))
	return int(cell.get("r", cell.get("y", -1)))

func _action_slot_index(action: Dictionary) -> int:
	return int(action.get("slotId", action.get("slot_id", action.get("slotIndex", action.get("slot_index", action.get("index", 0))))))

func _action_ap(action: Dictionary) -> int:
	return int(action.get("ap", action.get("actionAp", action.get("action_ap", 0))))

func _summary_add_count(map: Dictionary, key: String, label: String, amount: float) -> void:
	if key == "" or key == "-":
		return
	if not map.has(key):
		map[key] = {"id": key, "label": label, "count": 0.0}
	var row: Dictionary = Dictionary(map[key])
	row["count"] = float(row.get("count", 0.0)) + amount
	map[key] = row

func _summary_add_tag(tags: Dictionary, id: String, label: String, kind: String, weight: float, source_id: String) -> void:
	if id == "" or label == "" or label == "-":
		return
	if not tags.has(id):
		tags[id] = {"id": id, "label": label, "kind": kind, "weight": 0.0, "source_ids": []}
	var tag: Dictionary = Dictionary(tags[id])
	tag["weight"] = float(tag.get("weight", 0.0)) + weight
	var source_ids: Array = Array(tag.get("source_ids", []))
	if source_id != "" and not source_ids.has(source_id):
		source_ids.append(source_id)
	tag["source_ids"] = source_ids
	tags[id] = tag

func _summary_kind_order(kind: String) -> int:
	match kind:
		"element":
			return 1
		"role":
			return 2
		"tier":
			return 3
	return 9

func _sorted_summary_counts(map: Dictionary) -> Array:
	var values: Array = map.values()
	values.sort_custom(func(a, b):
		var left := Dictionary(a)
		var right := Dictionary(b)
		var count_left := float(left.get("count", 0.0))
		var count_right := float(right.get("count", 0.0))
		if count_left != count_right:
			return count_left > count_right
		return String(left.get("label", "")).naturalnocasecmp_to(String(right.get("label", ""))) < 0
	)
	return values

func _sorted_summary_tags(tags: Dictionary) -> Array:
	var values: Array = tags.values()
	values.sort_custom(func(a, b):
		var left := Dictionary(a)
		var right := Dictionary(b)
		var weight_left := float(left.get("weight", 0.0))
		var weight_right := float(right.get("weight", 0.0))
		if weight_left != weight_right:
			return weight_left > weight_right
		var kind_left := _summary_kind_order(String(left.get("kind", "")))
		var kind_right := _summary_kind_order(String(right.get("kind", "")))
		if kind_left != kind_right:
			return kind_left < kind_right
		return String(left.get("label", "")).naturalnocasecmp_to(String(right.get("label", ""))) < 0
	)
	return values

func _summary_weight_for_roster(row: Dictionary) -> float:
	var count: int = max(1, int(row.get("count", 1)))
	var active_bonus: float = 1.5 if bool(row.get("active", true)) else 1.0
	return float(count) * active_bonus

func _shop_item_for_pet(pet_id: String) -> Dictionary:
	for item in Array(_economy_data().get("shop_items", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if String(row.get("pet_id", row.get("id", ""))) == pet_id:
			return row
	for item in Array(game_data.get("roster", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if String(row.get("pet_id", row.get("id", ""))) == pet_id:
			return row
	return {}

func _add_roster_summary(row: Dictionary, maps: Dictionary) -> void:
	var pet_id := _pet_key(row)
	var catalog := _shop_item_for_pet(pet_id)
	var element := String(row.get("element", catalog.get("element", "-")))
	var role := String(row.get("role", catalog.get("role", "-")))
	var tier := QualityRulesScript.normalize(String(row.get("quality", catalog.get("quality", "青铜"))))
	var weight := _summary_weight_for_roster(row)
	_summary_add_count(maps["elements"], element, "%s系" % element, weight)
	_summary_add_count(maps["roles"], role, role, weight)
	_summary_add_count(maps["tiers"], tier, tier, max(1.0, weight * 0.5))
	_summary_add_tag(maps["tags"], "element:%s" % element, "%s系" % element, "element", weight, pet_id)
	_summary_add_tag(maps["tags"], "role:%s" % role, role, "role", weight, pet_id)
	_summary_add_tag(maps["tags"], "tier:%s" % tier, tier, "tier", max(1.0, weight * 0.5), pet_id)

func _build_core_summary() -> Dictionary:
	var maps := {"tags": {}, "elements": {}, "roles": {}, "tiers": {}}
	for item in roster:
		if typeof(item) == TYPE_DICTIONARY:
			_add_roster_summary(Dictionary(item), maps)
	var tags := _sorted_summary_tags(Dictionary(maps["tags"]))
	var primary: Array = []
	for tag in tags:
		var row := Dictionary(tag)
		var kind := String(row.get("kind", ""))
		if kind == "element" or kind == "role":
			primary.append(row)
		if primary.size() >= 5:
			break
	if primary.is_empty():
		for tag in tags:
			primary.append(Dictionary(tag))
			if primary.size() >= 5:
				break
	var labels: Array = []
	for tag in primary:
		labels.append(String(Dictionary(tag).get("label", "")))
	return {
		"summary_text": " / ".join(labels) if labels.size() > 0 else "尚未形成",
		"tags": tags,
		"primary_tags": primary,
		"elements": _sorted_summary_counts(Dictionary(maps["elements"])),
		"roles": _sorted_summary_counts(Dictionary(maps["roles"])),
			"tiers": _sorted_summary_counts(Dictionary(maps["tiers"])),
			"inventory": {
				"total_count": roster.size(),
				"active_count": _active_roster_count(),
				"bench_count": _bench_roster_count()
			}
		}

func snapshot(known_state_hash: String = "") -> Dictionary:
	var battle := Dictionary(game_data.get("battle", {}))
	var wave := Dictionary(battle.get("wave", {}))
	var runtime_database := Dictionary(game_data.get("runtime_database", {}))
	var runtime_database_counts := Dictionary(runtime_database.get("counts", {}))
	var runtime_database_tables := Dictionary(runtime_database.get("tables", {}))
	var actions := _next_actions()
	var hash := known_state_hash if known_state_hash != "" else _state_hash()
	var run_plan_hash := _run_plan_hash()
	var skill_catalog := Dictionary(game_data.get("skill_catalog", {}))
	var trait_catalog := Dictionary(game_data.get("trait_catalog", {}))
	var skill_combo_catalog := Dictionary(game_data.get("skill_combo_catalog", {}))
	var stat_catalog := Dictionary(game_data.get("stat_catalog", {}))
	var status_catalog := Dictionary(game_data.get("status_catalog", {}))
	var selected_unit_value := selected_unit()
	var battle_query_context: Dictionary = _battle_query_context()
	var battle_projections := Dictionary(_core_composition.battle_query_projector.snapshot_projection(battle_query_context, selected_unit_value))
	var selected_action_slots: Array = Array(battle_projections.get("actionSlots", []))
	var selected_action_cells: Array = Array(battle_projections.get("selectedActionCells", []))
	var action_preview_by_unit: Dictionary = Dictionary(battle_projections.get("actionPreviewByUnit", {}))
	var action_block_ranges_by_unit: Dictionary = Dictionary(battle_projections.get("actionBlockRangesByUnit", {}))
	var projected_board: Dictionary = Dictionary(battle_projections.get("board", {}))
	var skill_control_bar: Array = _skill_control_entries(PLAYER)
	var control_skill_ids: Array[String] = _core_composition.skill_queue_service.skill_ids(skill_control_bar)
	var selected_traits: Array = _core_composition.trait_service.entries(selected_unit_value, trait_catalog)
	var selected_skill_combos: Array = _core_composition.skill_combo_service.planned_matches(control_skill_ids, skill_catalog, skill_combo_catalog)
	var selected_statuses: Array = _core_composition.status_service.normalized(selected_unit_value, status_catalog)
	var selected_resolved := Dictionary(_core_composition.stat_query_service.resolve_all(selected_unit_value, game_data, EffectHookIdsScript.SNAPSHOT, {
		"unit": selected_unit_value,
		"round": battle_round,
		"cache_key": "%d:%s" % [state_version, String(selected_unit_value.get("id", ""))],
	}))
	var selected_resolved_values := Dictionary(_core_composition.stat_query_service.values_from_resolved(selected_resolved))
	var selected_stat_breakdown := Dictionary(_core_composition.stat_query_service.breakdown_from_resolved(selected_resolved))
	var round_rewind := _round_rewind_snapshot()
	var snap := {
		"phase": phase,
		"stateVersion": state_version,
		"state_version": state_version,
		"stateHash": hash,
		"state_hash": hash,
		"day": day,
		"node_index": node_index,
		"coins": coins,
		"hero_hp": hero_hp,
		"heroMaxHp": hero_max_hp,
		"hero_max_hp": hero_max_hp,
		"enemyHeroHp": enemy_hero_hp,
		"enemy_hero_hp": enemy_hero_hp,
		"enemyHeroMaxHp": enemy_hero_max_hp,
		"enemy_hero_max_hp": enemy_hero_max_hp,
		"castleLine": castle_line,
		"castle_line": castle_line,
		"economyMultiplier": economy_multiplier,
		"economy_multiplier": economy_multiplier,
		"ap": ap,
		"battle_round": battle_round,
		"round_rewind": round_rewind,
		"roundRewind": round_rewind.duplicate(true),
		"battle_period": battle_period,
		"difficulty": difficulty,
		"board_width": board_width,
		"board_height": board_height,
		"boardWidth": board_width,
		"boardHeight": board_height,
		"maxRounds": MAX_BATTLE_ROUNDS,
		"max_rounds": MAX_BATTLE_ROUNDS,
		"max_route_day": _max_scheduled_day(),
		"active_wave": active_wave.duplicate(true),
		"active_schedule": active_schedule.duplicate(true),
		"active_encounter": active_encounter.duplicate(true),
		"scenario": scenario_provenance.duplicate(true),
		"contentManifest": Dictionary(game_data.get("_content_manifest", {})).duplicate(true),
		"active_stall": active_stall.duplicate(true),
		"active_shop_pool": active_shop_pool,
		"active_shop_seed_context": active_shop_seed_context,
		"run_seed": run_seed,
		"run_plan": run_plan.duplicate(true),
		"runPlan": run_plan.duplicate(true),
		"run_plan_hash": run_plan_hash,
		"runPlanHash": run_plan_hash,
			"shop_roll_count": shop_roll_count,
			"shop_context_roll_count": shop_context_roll_count,
			"shop_free_rolls": shop_free_rolls,
			"shop_paid_refreshes": shop_paid_refreshes,
			"shop_next_discount": shop_next_discount,
			"shop_event_effects": shop_event_effects.duplicate(true),
			"shop_seen_pet_ids_by_day": shop_seen_pet_ids_by_day.duplicate(true),
			"shop_seen_pet_ids": _shop_seen_pet_ids_for_day(),
			"shop_seed_audit": shop_seed_audit.duplicate(true),
			"reward_fallback_audit": reward_fallback_audit.duplicate(true),
			"battle_prep_effects": battle_prep_effects.duplicate(true),
			"outer_run_effects": outer_run_effects.duplicate(true),
			"team_placement_preview": team_placement_preview.duplicate(true),
			"teamPlacementPreview": team_placement_preview.duplicate(true),
			"placement_damage_by_unit": placement_damage_by_unit.duplicate(true),
			"placementDamageByUnit": placement_damage_by_unit.duplicate(true),
			"selected_unit_id": selected_unit_id,
		"selected_action_slot_index": selected_action_slot_index,
		"action_dirs": action_dirs.duplicate(true),
		"action_ap_choices": action_ap_choices.duplicate(true),
			"selected_action_ap": _selected_action_ap(selected_unit(), selected_action_slot_index),
			"selected_action_slots": selected_action_slots,
			"selected_action_cells": selected_action_cells,
			"action_preview_by_unit": action_preview_by_unit,
			"action_block_ranges_by_unit": action_block_ranges_by_unit,
			"selected_skill": _skill_summary_for_unit(selected_unit()),
			"skill_control_bar": skill_control_bar,
			"skillControlBar": skill_control_bar.duplicate(true),
			"skill_catalog": _skill_catalog_snapshot(),
			"selected_traits": selected_traits,
			"selectedTraits": selected_traits.duplicate(true),
			"selected_skill_combos": selected_skill_combos,
			"selectedSkillCombos": selected_skill_combos.duplicate(true),
			"trait_catalog": trait_catalog.duplicate(true),
			"skill_combo_catalog": skill_combo_catalog.duplicate(true),
			"stat_catalog": stat_catalog.duplicate(true),
			"statCatalog": stat_catalog.duplicate(true),
			"status_catalog": status_catalog.duplicate(true),
			"statusCatalog": status_catalog.duplicate(true),
			"selected_resolved_stats": selected_resolved_values,
			"selectedResolvedStats": selected_resolved_values.duplicate(true),
			"selected_stat_breakdown": selected_stat_breakdown,
			"selectedStatBreakdown": selected_stat_breakdown.duplicate(true),
			"selected_statuses": selected_statuses,
			"selectedStatuses": selected_statuses.duplicate(true),
			"route_options": route_options.duplicate(true),
			"roster": roster.duplicate(true),
			"leaders": _leaders(),
			"pet_reset": {
				"threshold": PET_RESET_THRESHOLD,
				"player": {
					"eligible": bool(pet_reset_eligible.get(PLAYER, false)),
					"resetCount": int(pet_reset_counts.get(PLAYER, 0)),
					"aliveThreshold": _pet_reset_alive_threshold(PLAYER),
					"charges": int(pet_reset_charges.get(PLAYER, 0)),
					"nextChargeRound": int(pet_reset_next_charge_round.get(PLAYER, _pet_reset_charge_interval())),
					"cooldownRemaining": maxi(0, int(pet_reset_next_charge_round.get(PLAYER, _pet_reset_charge_interval())) - battle_round)
				},
				"enemy": {
					"eligible": bool(pet_reset_eligible.get(ENEMY, false)),
					"resetCount": int(pet_reset_counts.get(ENEMY, 0)),
					"aliveThreshold": _pet_reset_alive_threshold(ENEMY),
					"charges": int(pet_reset_charges.get(ENEMY, 0)),
					"nextChargeRound": int(pet_reset_next_charge_round.get(ENEMY, _pet_reset_charge_interval())),
					"cooldownRemaining": maxi(0, int(pet_reset_next_charge_round.get(ENEMY, _pet_reset_charge_interval())) - battle_round)
				}
			},
			"shop_offers": shop_offers.duplicate(true),
			"shop_events": _available_shop_events(),
			"route_events": _available_route_events(),
			"reward_options": reward_options.duplicate(true),
			"relic_inventory": relic_inventory.duplicate(true),
			"relic_combat_state": relic_combat_state.duplicate(true),
			"units": units.duplicate(true),
		"battle_result": battle_result.duplicate(true),
		"board": projected_board,
		"battleTrace": battle_trace.duplicate(true),
		"battle_trace": battle_trace.duplicate(true),
		"next_actions": actions.duplicate(true),
		"nextActions": actions.duplicate(true),
		"command_protocol": {
			"strict_version_actions": STRICT_VERSION_ACTIONS.duplicate(true),
			"view_state_actions": VIEW_STATE_ACTIONS.duplicate(true),
			"aliases": ACTION_ALIASES.duplicate(true),
			"public_aliases": ACTION_ALIASES.duplicate(true),
			"removed_trial_aliases": REMOVED_TRIAL_ALIASES.duplicate(true),
			"automation_aliases": AUTOMATION_ALIASES.duplicate(true)
		},
		"combat_resolution_protocol": COMBAT_RESOLUTION_PROTOCOL.duplicate(true),
		"log_lines": log_lines.duplicate(true),
		"command_log": command_log.duplicate(true),
		"last_command_result": _duplicate_result_value(last_command_result),
		"lastCommandResult": _duplicate_result_value(last_command_result),
			"rng": {
				"seed": run_seed,
				"shop_roll_count": shop_roll_count,
				"shop_context_roll_count": shop_context_roll_count,
				"active_shop_seed_context": active_shop_seed_context
			},
			"shop_refresh": {
				"free_rolls": shop_free_rolls,
				"paid_refreshes": shop_paid_refreshes,
				"next_refresh_cost": 0 if shop_free_rolls > 0 else _paid_refresh_cost(),
				"next_discount": shop_next_discount,
				"effects": shop_event_effects.duplicate(true),
				"daily_seen_pet_ids": _shop_seen_pet_ids_for_day(),
				"daily_seen_count": _shop_seen_pet_ids_for_day().size()
			},
			"route_effects": {
				"battle_prep": battle_prep_effects.duplicate(true),
				"outer_run": outer_run_effects.duplicate(true)
			},
		"inventory": {
			"active_count": _active_roster_count(),
			"bench_count": _bench_roster_count(),
			"max_active": MAX_ACTIVE_UNITS,
			"max_bench": MAX_BENCH_UNITS
		},
		"build_core": _build_core_summary(),
		"source": Dictionary(game_data.get("source", {})).duplicate(true),
		"mechanism_status": Dictionary(game_data.get("mechanism_status", {})).duplicate(true),
		"battle": battle.duplicate(true),
		"data_counts": {
			"roster": roster.size(),
			"active_roster": _active_roster_count(),
			"bench_roster": _bench_roster_count(),
			"max_active_roster": MAX_ACTIVE_UNITS,
			"max_bench_roster": MAX_BENCH_UNITS,
				"shop_offers": shop_offers.size(),
				"shop_events": _available_shop_events().size(),
				"route_events": _available_route_events().size(),
				"enemies": Array(battle.get("enemies", [])).size(),
				"shop_items": Array(Dictionary(game_data.get("economy", {})).get("shop_items", [])).size(),
				"shop_stores": Array(Dictionary(game_data.get("economy", {})).get("shop_stores", [])).size(),
				"events": Array(Dictionary(game_data.get("economy", {})).get("events", [])).size(),
				"relics": Array(Dictionary(game_data.get("economy", {})).get("relics", [])).size(),
				"battle_prep_effects": battle_prep_effects.size(),
				"outer_run_effects": outer_run_effects.size(),
				"shapes": Array(battle.get("shape_catalog", [])).size(),
				"action_shapes": Array(battle.get("action_shapes", [])).size(),
				"mechanisms": Array(battle.get("mechanisms", [])).size(),
				"quality_growth": Array(Dictionary(game_data.get("quality", {})).get("growth", [])).size(),
				"quality_upgrades": Array(Dictionary(game_data.get("quality", {})).get("upgrades", [])).size(),
					"route_schedule": Array(Dictionary(game_data.get("route", {})).get("schedule", [])).size(),
					"node_pool": Array(Dictionary(game_data.get("route", {})).get("node_pool", [])).size(),
					"encounters": Array(Dictionary(game_data.get("route", {})).get("encounters", [])).size(),
					"runtime_database_tables": runtime_database_tables.size(),
					"runtime_database_units": int(runtime_database_counts.get("units", 0)),
					"runtime_database_shapes": int(runtime_database_counts.get("shapes", 0)),
					"runtime_database_wave_rounds": int(runtime_database_counts.get("wave_rounds", 0)),
					"runtime_database_shop_items": int(runtime_database_counts.get("shop_items", 0)),
					"run_plan_entries": Array(run_plan.get("entries", [])).size(),
				"waves": Array(battle.get("waves", [])).size() if Array(battle.get("waves", [])).size() > 0 else int(wave.get("wave_count", 0))
		}
	}
	snap["viewModel"] = _view_model_from_snapshot(snap)
	return snap

func _view_model_from_snapshot(snap: Dictionary) -> Dictionary:
	return _core_composition.snapshot_projector.project(snap, PLAYER, ENEMY)

func _next_actions() -> Array:
	var actions: Array = []
	match phase:
		"route":
			for option in route_options:
				var row := Dictionary(option)
				var kind := String(row.get("kind", ""))
				if kind == "battle":
					actions.append(_next_action(
						"RUN_ROUTE_FIXED_BATTLE",
						"进入%s" % String(row.get("title", row.get("name", "固定战"))),
						{
							"optionId": String(row.get("id", "")),
							"encounterId": String(row.get("encounterId", "")),
							"scheduleStep": int(Dictionary(row.get("schedule", {})).get("step", node_index))
						}
					))
				else:
					actions.append(_next_action(
						"PICK_NODE",
						"选择 %s" % String(row.get("title", row.get("name", row.get("id", "节点")))),
						{
							"optionId": String(row.get("id", "")),
							"nodeId": String(row.get("nodeId", row.get("id", "")))
						}
					))
			for event in _available_route_events():
				var row := Dictionary(event)
				actions.append(_next_action(
					"APPLY_ROUTE_EVENT",
					"路线事件：%s" % String(row.get("name", row.get("id", "事件"))),
					{"eventId": String(row.get("id", ""))}
				))
			actions.append(_next_action("ENTER_SHOP", "进入夜晚商店", {"poolId": "night_base", "slots": 10}))
			actions.append(_next_action("RUN_BATTLE", "自动完成战斗", {}))
		"shop":
			var refresh_cost := 0 if shop_free_rolls > 0 else _paid_refresh_cost()
			actions.append(_next_action(
				"ROLL_SHOP",
				"刷新商店（%d金）" % refresh_cost if refresh_cost > 0 else "免费刷新商店",
				{"slots": int(active_stall.get("slots", 10))}
			))
			for offer in shop_offers:
				var row := Dictionary(offer)
				if bool(row.get("sold", false)):
					continue
				var offer_id := String(row.get("offer_id", row.get("id", "")))
				actions.append(_next_action(
					"BUY_OFFER",
					"购买宠物 %s" % String(row.get("name", offer_id)),
					{"offerId": offer_id}
				))
				actions.append(_next_action(
					"UNFREEZE_OFFER" if bool(row.get("frozen", false)) else "FREEZE_OFFER",
					"解锁商品 %s" % String(row.get("name", offer_id)) if bool(row.get("frozen", false)) else "锁定商品 %s" % String(row.get("name", offer_id)),
					{"offerId": offer_id}
				))
			for event in _available_shop_events():
				var row := Dictionary(event)
				actions.append(_next_action(
					"APPLY_SHOP_EVENT",
					"商店事件：%s" % String(row.get("name", row.get("id", "事件"))),
					{"eventId": String(row.get("id", ""))}
				))
			actions.append(_next_action("EXIT_SHOP", "离开商店", {}))
		"reward":
			for index in range(reward_options.size()):
				var row := Dictionary(reward_options[index])
				actions.append(_next_action(
					"PICK_REWARD",
					"选择奖励%d：%s" % [index + 1, String(row.get("name", row.get("id", "奖励")))],
					{"index": index, "id": String(row.get("id", ""))}
				))
		"battle":
			if bool(pet_reset_eligible.get(PLAYER, false)):
				actions.append(_next_action("RESET_PETS", "重置宠物", {}))
			actions.append(_next_action("AUTO_POSITION_HEROES", "智能调整站位", {}))
			actions.append(_next_action("MOVE_HERO", "移动宠物", {}))
			actions.append(_next_action("SET_ACTION_DIRECTION", "调整行动槽方向", {"unitId": selected_unit_id, "slotId": selected_action_slot_index}))
			actions.append(_next_action("SET_ACTION_AP", "调整行动槽AP", {"unitId": selected_unit_id, "slotId": selected_action_slot_index, "ap": _selected_action_ap(selected_unit(), selected_action_slot_index)}))
			if _unit_supports_quality_mode(selected_unit()):
				actions.append(_next_action("SET_QUALITY_MODE", "切换品质模式", {
					"unitId": selected_unit_id,
					"mode": _quality_mode_for_unit(selected_unit()),
					"modes": _quality_mode_options(selected_unit())
				}))
			if _unit_supports_quality_mark(selected_unit()):
				actions.append(_next_action("SET_QUALITY_MARK", "设置精准印记", {
					"unitId": selected_unit_id,
					"slotId": selected_action_slot_index,
					"cell": _quality_mark_for_unit(selected_unit())
				}))
			actions.append(_next_action("RUN_COMBAT_ROUND", "开始完整战斗回合", {}))
		"battle_end":
			actions.append(_next_action("CONTINUE_AFTER_BATTLE", "继续", {}))
		"day_end":
			if day < _max_scheduled_day() and _has_schedule_for_day(day + 1):
				actions.append(_next_action("START_NEXT_DAY", "进入第%d天" % (day + 1), {"day": day + 1}))
			else:
				actions.append(_next_action("NEW_RUN", "重新开始", {}))
		"game_over":
			actions.append(_next_action("NEW_RUN", "重新开始", {}))
	return actions

func _next_action(action_type: String, label: String, default_payload: Dictionary = {}) -> Dictionary:
	return {
		"type": action_type,
		"label": label,
		"defaultPayload": default_payload.duplicate(true)
	}

func _duplicate_result_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return Dictionary(value).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return Array(value).duplicate(true)
	return value

func _route_data() -> Dictionary:
	return Dictionary(game_data.get("route", {}))

func _economy_data() -> Dictionary:
	return Dictionary(game_data.get("economy", {}))

## Shared read-only rules used by multiple domains; no service caches writable
## authority state here.

func _has_schedule_for_day(target_day: int) -> bool:
	for item in Array(_route_data().get("schedule", [])):
		if typeof(item) == TYPE_DICTIONARY and int(Dictionary(item).get("day", 1)) == target_day and _is_formal(Dictionary(item)):
			return true
	return false

func _route_options_for_schedule(schedule: Dictionary) -> Array:
	return Array(_route_option_service.call("options_for_schedule", schedule, _route_option_context()))

func _route_option_context() -> Dictionary:
	return {
		"day": day,
		"nodeIndex": node_index,
		"routeData": _route_data(),
		"runSeed": run_seed,
		"boardLabel": _board_label(),
		"maxShopOffers": MAX_SHOP_OFFERS,
	}

func _paid_refresh_cost() -> int:
	return EconomyRulesScript.paid_refresh_cost(shop_paid_refreshes)

func _shop_seen_pet_ids_for_day(target_day: int = -1) -> Array:
	var resolved_day := day if target_day < 1 else target_day
	var values := Array(shop_seen_pet_ids_by_day.get(str(resolved_day), []))
	var seen := {}
	var pet_ids: Array = []
	for value in values:
		var pet_id := String(value).strip_edges()
		if pet_id == "" or seen.has(pet_id):
			continue
		seen[pet_id] = true
		pet_ids.append(pet_id)
	pet_ids.sort()
	return pet_ids

func _is_formal(row: Dictionary) -> bool:
	return String(row.get("status", "")).strip_edges() == "正式"

func _day_expr_allows(day_expr: String) -> bool:
	return RouteRulesScript.day_expression_allows(day_expr, day)

func _available_shop_events() -> Array:
	var events: Array = []
	for item in Array(_economy_data().get("events", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var event := Dictionary(item)
		if String(event.get("layer", "")) != "shop_phase":
			continue
		if not _is_formal(event):
			continue
		if not _day_expr_allows(String(event.get("day_expr", ""))):
			continue
		events.append(event)
	return events

func _available_route_events() -> Array:
	var events: Array = []
	for item in Array(_economy_data().get("events", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var event := Dictionary(item)
		if not ["event", "pre_battle"].has(String(event.get("layer", ""))):
			continue
		if not _is_formal(event):
			continue
		if not _day_expr_allows(String(event.get("day_expr", ""))):
			continue
		events.append(event)
	return events

func _normalize_difficulty(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if [DIFFICULTY_EASY, "simple", "简单", "简易"].has(normalized):
		return DIFFICULTY_EASY
	return DIFFICULTY_NORMAL

func _board_label() -> String:
	return "%dx%d" % [board_width, board_height]

func _max_scheduled_day() -> int:
	var max_day := day
	for item in Array(_route_data().get("schedule", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if not _is_formal(row):
			continue
		max_day = max(max_day, int(row.get("day", max_day)))
	return max_day

func _pet_reset_alive_threshold(side: String) -> int:
	return _core_composition.pet_reset_policy.alive_threshold(PET_RESET_THRESHOLD, int(pet_reset_counts.get(side, 0)))

func _quality_mode_options(unit: Dictionary) -> Array:
	return _core_composition.quality_runtime_service.mode_options(unit)

func _unit_supports_quality_mode(unit: Dictionary) -> bool:
	return _core_composition.quality_runtime_service.supports_mode(unit)

func _quality_mode_for_unit(unit: Dictionary) -> String:
	return _core_composition.quality_runtime_service.display_mode(unit)

func _unit_supports_quality_mark(unit: Dictionary) -> bool:
	return _core_composition.quality_runtime_service.supports_mark(unit)

func _quality_mark_for_unit(unit: Dictionary) -> Dictionary:
	return _core_composition.quality_runtime_service.mark_for_unit(unit)

func _resolved_stat_value(unit: Dictionary, stat_id: String, context: Dictionary = {}) -> int:
	var hook := String(context.get("hook", EffectHookIdsScript.BATTLE))
	return int(_core_composition.stat_query_service.value(unit, game_data, stat_id, hook, context))

func _direction_label(direction: String) -> String:
	return ShapeGeometryScript.direction_label(direction)

func _normalize_direction(direction: String) -> String:
	return ShapeGeometryScript.normalize_direction(direction)

func _cell_elements_at(x: int, y: int) -> Dictionary:
	return _element_field_service.elements_at(cell_elements, _cell_key(x, y), Callable(self, "_normalize_elements"))

func _board_trace_at(x: int, y: int) -> Dictionary:
	var value = board_traces.get(_cell_key(x, y), {})
	if typeof(value) == TYPE_ARRAY:
		var rows := Array(value)
		if rows.is_empty():
			return {}
		return Dictionary(rows[rows.size() - 1]).duplicate(true)
	return Dictionary(value).duplicate(true)

func _board_traces_at(x: int, y: int) -> Array:
	var value = board_traces.get(_cell_key(x, y), {})
	if typeof(value) == TYPE_ARRAY:
		return Array(value).duplicate(true)
	if typeof(value) == TYPE_DICTIONARY and not Dictionary(value).is_empty():
		return [Dictionary(value).duplicate(true)]
	return []

func _replay_debug_entry(index: int, command: Dictionary, before_version: int, before_hash: String, after_version: int, after_hash: String, accepted: bool, replayable: bool, error: String) -> Dictionary:
	return ReplayBuilderScript.debug_entry(index, command, before_version, before_hash, after_version, after_hash, accepted, replayable, error)

func _has_route_data() -> bool:
	return Array(_route_data().get("schedule", [])).size() > 0

func _run_plan_key(target_day: int, step: int) -> String:
	return "%d:%d" % [target_day, step]

func _run_plan_hash(plan: Dictionary = {}) -> String:
	var source := run_plan if plan.is_empty() else plan
	# Current run plans are immutable and store the hash created alongside their
	# entries. Reuse it for public Snapshots; explicit candidate plans still get
	# fully hashed while they are being built or validated.
	if plan.is_empty():
		var stored_hash := String(source.get("plan_hash", ""))
		if stored_hash != "":
			return stored_hash
	return _checksum({
		"version": String(source.get("version", "")),
		"seed": String(source.get("seed", "")),
		"dataVersion": String(source.get("dataVersion", "")),
		"entries": Array(source.get("entries", []))
	})

func _formal_route_schedules() -> Array:
	var rows: Array = []
	for item in Array(_route_data().get("schedule", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if not _is_formal(row):
			continue
		rows.append(row.duplicate(true))
	rows.sort_custom(func(a, b):
		var left := Dictionary(a)
		var right := Dictionary(b)
		if int(left.get("day", 1)) == int(right.get("day", 1)):
			return int(left.get("step", 1)) < int(right.get("step", 1))
		return int(left.get("day", 1)) < int(right.get("day", 1))
	)
	return rows

func _build_run_plan() -> Dictionary:
	if not _has_route_data():
		return {}
	var entries: Array = []
	var by_key: Dictionary = {}
	for schedule_value in _formal_route_schedules():
		var schedule := Dictionary(schedule_value)
		var entry := {
			"id": "day_%d_step_%d" % [int(schedule.get("day", 1)), int(schedule.get("step", 1))],
			"day": int(schedule.get("day", 1)),
			"step": int(schedule.get("step", 1)),
			"kind": String(schedule.get("kind", "")),
			"schedule": schedule.duplicate(true),
			"options": _route_options_for_schedule(schedule)
		}
		entries.append(entry)
		by_key[_run_plan_key(int(entry["day"]), int(entry["step"]))] = entry
	var plan := {
		"version": "ysbzs_run_plan_v1",
		"seed": run_seed,
		"dataVersion": _replay_data_version(),
		"entries": entries,
		"by_key": by_key
	}
	plan["plan_hash"] = _run_plan_hash(plan)
	return plan

func _current_run_plan_entry() -> Dictionary:
	if run_plan.is_empty():
		return {}
	var by_key := Dictionary(run_plan.get("by_key", {}))
	return Dictionary(by_key.get(_run_plan_key(day, node_index), {}))

func _current_schedule() -> Dictionary:
	var plan_entry := _current_run_plan_entry()
	if not plan_entry.is_empty():
		return Dictionary(plan_entry.get("schedule", {})).duplicate(true)
	for item in Array(_route_data().get("schedule", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if int(row.get("day", 1)) == day and int(row.get("step", 1)) == node_index and _is_formal(row):
			return row
	return {}

func _shape_id_for_unit(unit: Dictionary) -> String:
	return SkillShapeRulesScript.shape_id_for_unit(unit, game_data)

func _shape_definition(unit: Dictionary) -> Dictionary:
	return SkillShapeRulesScript.shape_definition(unit, game_data)

func skill_label(skill_id: String) -> String:
	var skill := skill_id.strip_edges()
	if skill == "":
		return ""
	var definition := Dictionary(Dictionary(game_data.get("skill_catalog", {})).get(skill, {}))
	if not definition.is_empty():
		return String(definition.get("name", skill))
	return String(LegacySkillCatalogScript.LABELS.get(skill, skill))

func skill_description(skill_id: String) -> String:
	var skill := skill_id.strip_edges()
	if skill == "":
		return ""
	return String(LegacySkillCatalogScript.DESCRIPTIONS.get(skill, ""))

func _skill_summary_for_unit(unit: Dictionary) -> Dictionary:
	var skill := String(unit.get("skill", "")).strip_edges()
	return {
		"id": skill,
		"name": skill_label(skill),
		"description": skill_description(skill),
		"action_type": String(unit.get("action_type", unit.get("role", "")))
	}

func _skill_catalog_snapshot() -> Dictionary:
	var catalog := {}
	for skill_id_value in Dictionary(game_data.get("skill_catalog", {})).keys():
		var skill_id := String(skill_id_value)
		catalog[skill_id] = Dictionary(Dictionary(game_data.get("skill_catalog", {})).get(skill_id_value, {})).duplicate(true)
	var legacy_entries := LegacySkillCatalogScript.snapshot_entries()
	for skill_id_value in legacy_entries.keys():
		var skill_id := String(skill_id_value)
		if catalog.has(skill_id):
			continue
		catalog[skill_id] = Dictionary(legacy_entries.get(skill_id, {})).duplicate(true)
	return catalog

func _empty_elements() -> Dictionary:
	return ElementRulesScript.empty_layers()

func _normalize_elements(raw: Dictionary) -> Dictionary:
	return ElementRulesScript.normalize_layers(raw)

func _canonical_element(value: String) -> String:
	return ElementRulesScript.canonical(value)

func _slot_elements_for_unit(unit: Dictionary) -> Array:
	return SkillShapeRulesScript.slot_elements(unit)

func _battle_query_context() -> Dictionary:
	return BattleQueryContextScript.build({
		"phase": phase,
		"stateVersion": state_version,
		"battleRound": battle_round,
		"difficulty": difficulty,
		"board": {"width": board_width, "height": board_height},
		"selection": {"unitId": selected_unit_id, "slotIndex": selected_action_slot_index, "ap": ap},
		"units": units,
		"defeatedUnits": defeated_units,
		"leaders": _leaders(),
		"cellElements": cell_elements,
		"boardTraces": board_traces,
		"actionDirections": action_dirs,
		"actionApChoices": action_ap_choices,
		"placementDamageByUnit": placement_damage_by_unit,
		"gameData": game_data,
	})

func _battle_query_session(context: Dictionary = {}) -> RefCounted:
	var effective_context := context if not context.is_empty() else _battle_query_context()
	return _core_composition.battle_query_projector.begin(effective_context)

func _action_slots_for_unit(unit: Dictionary) -> Array:
	return _core_composition.action_slot_service.project_slots(unit, {
		"availableAp": ap,
		"selectedApChoices": action_ap_choices,
		"directions": action_dirs,
		"shapeDefinition": _shape_definition(unit),
	})

func _selected_action_ap(unit: Dictionary, index: int) -> int:
	return _core_composition.action_slot_service.selected_ap(unit, index, action_ap_choices, ap)

func _selected_action_slot(unit: Dictionary) -> Dictionary:
	var slots: Array = _action_slots_for_unit(unit)
	if slots.is_empty():
		return {}
	var index: int = clamp(selected_action_slot_index, 0, slots.size() - 1)
	return Dictionary(slots[index])

func select_action_slot(index: int) -> bool:
	var unit := selected_unit()
	if unit.is_empty():
		_log("先选择我方宠物。")
		return false
	var slots := _action_slots_for_unit(unit)
	if index < 0 or index >= slots.size():
		_log("行动槽不存在。")
		return false
	selected_action_slot_index = index
	var slot := Dictionary(slots[index])
	_log("选择%s：%s%d层，%s。" % [String(slot.get("label", "")), String(slot.get("element", "")), int(slot.get("layers", 1)), String(slot.get("shape_name", ""))])
	return true

func _action_slot_key(unit: Dictionary, index: int) -> String:
	return _core_composition.action_slot_service.slot_key(unit, index)

func _action_slot_direction(unit: Dictionary, index: int) -> String:
	return _normalize_direction(
		_core_composition.action_slot_service.stored_direction(unit, index, action_dirs)
	)

func _battle_query_action_grid(action: Dictionary) -> Array:
	return Array(_core_composition.battle_query_projector.project_action_grid(
		_battle_query_context(),
		action
	)).duplicate(true)

func battle_query_cell_detail(action: Dictionary) -> Dictionary:
	return Dictionary(_core_composition.battle_query_projector.project_cell_detail(
		_battle_query_context(),
		action
	)).duplicate(true)

func _manual_flow_preview(action: Dictionary) -> Dictionary:
	var before_query := _battle_query_context()
	return Dictionary(_core_composition.manual_flow_simulation_service.preview(
		self,
		action,
		before_query,
		_core_composition.simulation_authority_factory,
		_manual_flow_diff_projector,
		_core_composition.battle_query_projector
	))

func _apply_mechanic_battle_start(unit: Dictionary) -> Array:
	return _core_composition.damage_mechanic_service.apply_battle_start(
		DamageMechanicPortScript.new(self),
		unit
	)

func _apply_mechanic_round_start(side: String) -> void:
	_core_composition.round_lifecycle_service.run_start(RoundLifecyclePortScript.new(self), side)

func _apply_mechanic_round_end(side: String) -> void:
	_core_composition.round_lifecycle_service.run_end(RoundLifecyclePortScript.new(self), side)

func _apply_mechanic_before_damage(target: Dictionary, source: Dictionary, amount: int, element: String = "", damage_props: Dictionary = {}) -> Dictionary:
	return _core_composition.damage_mechanic_service.apply_before_damage(
		DamageMechanicPortScript.new(self),
		target,
		source,
		amount,
		element,
		damage_props
	)

func _apply_mechanic_after_damage(target: Dictionary, source: Dictionary, amount: int, damage_props: Dictionary = {}) -> Array:
	return _core_composition.damage_mechanic_service.apply_after_damage(
		DamageMechanicPortScript.new(self),
		target,
		source,
		amount,
		damage_props
	)

func _apply_mechanic_after_hit(target: Dictionary, source: Dictionary, amount: int, damage_props: Dictionary = {}) -> Array:
	return _core_composition.damage_mechanic_service.apply_after_hit(
		DamageMechanicPortScript.new(self),
		target,
		source,
		amount,
		damage_props
	)

func _apply_attacker_mechanic_after_hit(attacker: Dictionary, target: Dictionary, amount: int, element: String, direction: String = "") -> Array:
	return _core_composition.damage_mechanic_service.apply_attacker_after_hit(
		DamageMechanicPortScript.new(self),
		attacker,
		target,
		amount,
		element,
		direction
	)

func _first_empty_cell_near_unit(unit: Dictionary, include_origin: bool = true) -> Dictionary:
	return _core_composition.summon_service.first_empty_near(SummonPortScript.new(self), unit, include_origin)

func _apply_cross_damage_from_unit(unit: Dictionary, source: Dictionary, damage: int, element: String, label: String, trace_context: Dictionary = {}) -> Dictionary:
	return _core_composition.damage_mechanic_service.apply_cross_damage(
		DamageMechanicPortScript.new(self), unit, source, damage, element, label, trace_context
	)

func _apply_mechanic_on_death(unit: Dictionary, source: Dictionary) -> Array:
	return _core_composition.unit_lifecycle_mechanic_service.apply_on_death(
		UnitLifecycleMechanicPortScript.new(self), unit, source
	)

func _apply_mechanic_on_shield_break(unit: Dictionary, source: Dictionary) -> Array:
	return _core_composition.unit_lifecycle_mechanic_service.apply_on_shield_break(
		UnitLifecycleMechanicPortScript.new(self), unit, source
	)

func _apply_mechanic_after_ally_death(defeated: Dictionary) -> Array:
	return _core_composition.unit_lifecycle_mechanic_service.apply_after_ally_death(
		UnitLifecycleMechanicPortScript.new(self), defeated
	)

func _apply_attacker_mechanic_after_kill(killer: Dictionary, defeated: Dictionary) -> Array:
	return _core_composition.unit_lifecycle_mechanic_service.apply_attacker_after_kill(
		UnitLifecycleMechanicPortScript.new(self), killer, defeated
	)

func _apply_mechanic_after_action(actor: Dictionary) -> Array:
	return _core_composition.unit_lifecycle_mechanic_service.apply_after_action(
		UnitLifecycleMechanicPortScript.new(self), actor
	)

func _first_adjacent_empty_cell(unit: Dictionary) -> Dictionary:
	return _core_composition.summon_service.first_adjacent_empty(SummonPortScript.new(self), unit)

func _summon_unit_on_cell(caster: Dictionary, mechanism: Dictionary, cell: Dictionary, default_summon_id: String = "ally_sprite", display_name: String = "小灵", default_hp: int = 6, default_atk: int = 1) -> Dictionary:
	return _core_composition.summon_service.summon_unit_on_cell(
		SummonPortScript.new(self), caster, mechanism, cell,
		default_summon_id, display_name, default_hp, default_atk
	)

func _summon_wall_on_cell(caster: Dictionary, cell: Dictionary, hp: int, duration: int) -> Dictionary:
	return _core_composition.summon_service.summon_wall_on_cell(SummonPortScript.new(self), caster, cell, hp, duration)

func _copy_weak_self_on_cell(source: Dictionary, cell: Dictionary, hp_pct: float, atk_pct: float) -> Dictionary:
	return _core_composition.summon_service.copy_weak_self_on_cell(SummonPortScript.new(self), source, cell, hp_pct, atk_pct)

func _apply_mechanic_after_element_apply(caster: Dictionary, target: Dictionary, element: String, layers: int, cell: Dictionary = {}) -> Array:
	return _core_composition.element_mechanic_service.apply_after_element(
		ElementMechanicPortScript.new(self), caster, target, element, layers, cell
	)

func _apply_mechanic_battle_end(win: bool, gold_reward: int) -> Dictionary:
	return _core_composition.unit_lifecycle_mechanic_service.apply_battle_end(
		UnitLifecycleMechanicPortScript.new(self), win, gold_reward
	)

func _skill_control_entries(side: String) -> Array:
	var skill_catalog := Dictionary(game_data.get("skill_catalog", {}))
	var fallback_skill_ids: Array[String] = _core_composition.skill_queue_service.catalog_skill_ids(skill_catalog)
	return _core_composition.skill_queue_service.control_entries(
		Array(battle_roster_templates.get(side, [])),
		Array(skill_control_orders.get(side, [])),
		Callable(self, "skill_label"),
		fallback_skill_ids
	)

func _normalize_skill_control_orders() -> void:
	var normalized := {}
	for side in [PLAYER, ENEMY]:
		normalized[side] = _core_composition.skill_queue_service.entry_ids(_skill_control_entries(side))
	skill_control_orders = normalized

func _initialize_skill_control_orders() -> void:
	skill_control_orders = {PLAYER: [], ENEMY: []}
	_normalize_skill_control_orders()

func set_skill_control_order(ordered_entry_ids: Array) -> bool:
	if phase != "battle" or _player_all_out_resolving:
		return false
	var current := _skill_control_entries(PLAYER)
	if not _core_composition.skill_queue_service.is_exact_reorder(current, ordered_entry_ids):
		_log("技能控制条顺序无效：必须完整包含当前上阵宠物的全部 A/B 技能格。")
		return false
	skill_control_orders[PLAYER] = Array(ordered_entry_ids).duplicate()
	auto_position_action_plan = []
	var control_bar := _skill_control_entries(PLAYER)
	last_command_result = {
		"ok": true,
		"skillControlBar": control_bar.duplicate(true)
	}
	_log("已调整整队共享技能控制条顺序。")
	return true

func set_action_direction(unit_id: String, index: int, direction: String) -> bool:
	if phase != "battle":
		return false
	var unit := unit_by_id(unit_id)
	if unit.is_empty() and selected_unit_id != "":
		unit = selected_unit()
	if unit.is_empty():
		for candidate in units:
			if String(candidate.get("side", "")) == PLAYER and int(candidate.get("hp", 0)) > 0:
				unit = candidate
				break
	if unit.is_empty() or String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
		_log("方向调整失败：未选择可行动我方宠物。")
		return false
	var slots := _action_slots_for_unit(unit)
	if index < 0 or index >= slots.size():
		_log("方向调整失败：行动槽不存在。")
		return false
	var dir := _normalize_direction(direction)
	if not _core_composition.action_slot_service.set_direction(unit, index, dir, action_dirs):
		return false
	auto_position_action_plan = []
	selected_unit_id = String(unit.get("id", selected_unit_id))
	selected_action_slot_index = index
	var preview := _attack_option_for_direction(unit, dir)
	var target_names: Array = []
	for target in _enemies_in_attack_option(unit, preview):
		target_names.append(String(target.get("name", target.get("id", "敌人"))))
	var summary := "预览%d格" % Array(preview.get("cells", [])).size()
	if not target_names.is_empty():
		summary += "，命中%s" % "、".join(target_names)
	_log("%s 第%d槽方向改为%s：%s。" % [
		String(unit.get("name", "我方")),
		index + 1,
		_direction_label(dir),
		summary
	])
	return true

func set_action_ap(unit_id: String, index: int, requested_ap: int) -> bool:
	if phase != "battle":
		return false
	var unit := unit_by_id(unit_id)
	if unit.is_empty() and selected_unit_id != "":
		unit = selected_unit()
	if unit.is_empty() or String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
		_log("AP调整失败：未选择可行动我方宠物。")
		return false
	var slots := _action_slots_for_unit(unit)
	if index < 0 or index >= slots.size():
		_log("AP调整失败：行动槽不存在。")
		return false
	var value: int = max(1, requested_ap)
	if value > ap:
		_log("AP调整失败：AP不足（需要%d，剩余%d）。" % [value, ap])
		return false
	if not _core_composition.action_slot_service.set_ap_choice(unit, index, value, action_ap_choices):
		return false
	auto_position_action_plan = []
	selected_unit_id = String(unit.get("id", selected_unit_id))
	selected_action_slot_index = index
	_log("%s 第%d槽AP改为%d。" % [String(unit.get("name", "我方")), index + 1, value])
	return true

func _normalize_quality_mode(upgrade_id: String, raw_mode: String) -> String:
	return _core_composition.quality_runtime_service.normalize_mode(upgrade_id, raw_mode)

func set_quality_mode(unit_id: String, mode: String) -> bool:
	if phase != "battle":
		return false
	var unit := unit_by_id(unit_id)
	if unit.is_empty() and selected_unit_id != "":
		unit = selected_unit()
	if unit.is_empty() or String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
		_log("品质模式切换失败：未选择可行动我方宠物。")
		return false
	var upgrade_id := _quality_upgrade_id(unit)
	if not _unit_supports_quality_mode(unit):
		_log("品质模式切换失败：%s 当前品质效果不可切换。" % String(unit.get("name", "我方")))
		return false
	var normalized := _normalize_quality_mode(upgrade_id, mode)
	if normalized == "":
		_log("品质模式切换失败：未知模式 %s。" % mode)
		return false
	var result: Dictionary = _core_composition.quality_runtime_service.try_set_mode(unit, normalized)
	if not bool(result.get("ok", false)):
		return false
	selected_unit_id = String(unit.get("id", selected_unit_id))
	_log("%s 品质模式切换为%s。" % [String(unit.get("name", "我方")), normalized])
	return true

func set_quality_mark(unit_id: String, x: int, y: int) -> bool:
	if phase != "battle":
		return false
	var unit := unit_by_id(unit_id)
	if unit.is_empty() and selected_unit_id != "":
		unit = selected_unit()
	if unit.is_empty() or String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
		_log("品质标记失败：未选择可行动我方宠物。")
		return false
	if not _unit_supports_quality_mark(unit):
		_log("品质标记失败：%s 当前品质效果不能标记格子。" % String(unit.get("name", "我方")))
		return false
	if not _inside(x, y):
		_log("品质标记失败：目标格不在棋盘内。")
		return false
	var slot := _selected_action_slot(unit)
	if slot.is_empty() or bool(slot.get("used", false)):
		_log("品质标记失败：当前行动槽不可用。")
		return false
	var option := _attack_option_for_direction(unit, String(slot.get("direction", "right")))
	if option.is_empty() or not _option_contains_cell(option, x, y):
		_log("品质标记失败：只能标记当前行动槽作用格。")
		return false
	var result: Dictionary = _core_composition.quality_runtime_service.try_set_mark(
		unit,
		x,
		y,
		int(slot.get("index", selected_action_slot_index)),
		battle_round
	)
	if not bool(result.get("ok", false)):
		return false
	selected_unit_id = String(unit.get("id", selected_unit_id))
	_log("%s 品质标记 (%d,%d)。" % [String(unit.get("name", "我方")), x + 1, y + 1])
	return true

func _set_action_slot_used(unit: Dictionary, index: int, spent_ap: int = 1) -> void:
	_core_composition.action_slot_service.mark_used(unit, index, spent_ap)

func _next_action_slot_index(unit: Dictionary) -> int:
	return _core_composition.action_slot_service.next_available_index(_action_slots_for_unit(unit))

func _has_available_action_slot(unit: Dictionary) -> bool:
	return _core_composition.action_slot_service.has_available(_action_slots_for_unit(unit))

func _has_used_action_slot(unit: Dictionary) -> bool:
	return _core_composition.action_slot_service.has_used(unit)

func _effective_move_range(unit: Dictionary) -> int:
	return max(0, _resolved_stat_value(unit, "move_range", {"hook": EffectHookIdsScript.MOVEMENT}))

func _enemy_attack_count(unit: Dictionary) -> int:
	return max(0, _resolved_stat_value(unit, "attack_count", {"hook": EffectHookIdsScript.ACTION_COUNT}))

func _unit_ids(items: Array) -> Array:
	var ids: Array = []
	for item in items:
		var row := Dictionary(item)
		var unit_id := String(row.get("id", ""))
		if unit_id != "":
			ids.append(unit_id)
	return ids

func _auto_position_applied_state_signature() -> String:
	var unit_rows := units.duplicate(true)
	unit_rows.sort_custom(func(a, b): return String(Dictionary(a).get("id", "")) < String(Dictionary(b).get("id", "")))
	return JSON.stringify({
		"phase": phase,
		"battleRound": battle_round,
		"ap": ap,
		"units": unit_rows,
		"cellElements": cell_elements,
		"actionDirs": action_dirs,
		"actionApChoices": action_ap_choices,
		"difficulty": difficulty
	})

func _reuse_applied_auto_position_result() -> bool:
	if auto_position_applied_result.is_empty():
		return false
	if String(auto_position_applied_result.get("stateSignature", "")) != _auto_position_applied_state_signature():
		return false
	var plan := Dictionary(auto_position_applied_result.get("plan", {})).duplicate(true)
	if plan.is_empty():
		return false
	auto_position_action_plan = Array(plan.get("actions", [])).duplicate(true)
	var text := "智能调整站位：战斗状态未变化，保持已应用的唯一击杀优先方案。"
	_log(text)
	plan["text"] = text
	last_command_result = {"ok": true, "moves": [], "plan": plan, "text": text, "reused": true}
	GameLogScript.info("战斗/自动布置", "战场未变化，复用上次唯一方案", {
		"回合": battle_round,
		"难度": difficulty,
		"预计击杀": int(plan.get("kills", 0)),
		"有效伤害": int(plan.get("effectiveDamage", 0))
	})
	return true

func _build_auto_position_plan(side: String = PLAYER, action_budget: int = -1, constrain_movement_by_unit: bool = false) -> Dictionary:
	var resolved_action_budget := ap if action_budget < 0 else action_budget
	var input := AutoPositionConfigScript.defaults()
	input.merge({
		"side": side,
		"playerSide": PLAYER,
		"difficulty": difficulty,
		"easyDifficulty": DIFFICULTY_EASY,
		"actionBudget": resolved_action_budget,
		"constrainMovementByUnit": constrain_movement_by_unit
	}, true)
	var context := {
		"schema": "ysbzs.auto-position-context.v1",
		"query": _battle_query_context(),
		"side": side,
		"playerSide": PLAYER,
		"difficulty": difficulty,
		"easyDifficulty": DIFFICULTY_EASY,
		"actionBudget": resolved_action_budget,
		"constrainMovementByUnit": constrain_movement_by_unit,
		"limits": {
			"candidate": int(input.get("candidateLimit", AutoPositionConfigScript.CANDIDATE_LIMIT)),
			"targetSignature": int(input.get("targetSignatureLimit", AutoPositionConfigScript.TARGET_SIGNATURE_LIMIT)),
			"approach": int(input.get("approachCandidateLimit", AutoPositionConfigScript.APPROACH_CANDIDATE_LIMIT)),
			"standby": int(input.get("standbyCandidateLimit", AutoPositionConfigScript.STANDBY_CANDIDATE_LIMIT)),
			"beam": int(input.get("beamWidth", AutoPositionConfigScript.BEAM_WIDTH)),
			"survivalFinalist": int(input.get("survivalFinalistLimit", AutoPositionConfigScript.SURVIVAL_FINALIST_LIMIT)),
			"actionCountDiversity": int(input.get("actionCountDiversity", AutoPositionConfigScript.ACTION_COUNT_DIVERSITY)),
		},
	}
	return _auto_position_planner_service.build_plan(
		input,
		AutoPositionReadPortScript.new(context, _core_composition.auto_position_evaluator)
	)

func auto_position_heroes() -> bool:
	if phase != "battle":
		var blocked_text := "当前阶段 %s 不能智能调整站位。" % phase
		last_command_result = {"ok": false, "moves": [], "text": blocked_text}
		_log(blocked_text)
		GameLogScript.warning("战斗/自动布置", "请求被阶段拦截", {"当前阶段": phase})
		return false
	if _reuse_applied_auto_position_result():
		return true
	var planning_started_usec := Time.get_ticks_usec()
	GameLogScript.info("战斗/自动布置", "开始计算唯一站位方案", {
		"回合": battle_round,
		"难度": difficulty,
		"我方存活": _living_unit_count(PLAYER),
		"敌方存活": _living_unit_count(ENEMY),
		"棋盘": "%dx%d" % [board_width, board_height]
	})
	var plan := _build_auto_position_plan()
	var occupied_targets := {}
	var planned_move_by_unit := {}
	var planned_moves_are_valid := true
	for move_value in Array(plan.get("moves", [])):
		var move := Dictionary(move_value)
		var unit := unit_by_id(String(move.get("unitId", "")))
		var to := Dictionary(move.get("to", {}))
		var x := int(to.get("x", -1))
		var y := int(to.get("y", -1))
		var key := _cell_key(x, y)
		var unit_id := String(unit.get("id", ""))
		if unit.is_empty() or String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0 \
				or unit_id == "" or planned_move_by_unit.has(unit_id) or occupied_targets.has(key) \
				or not _inside(x, y) or not _leader_at(x, y).is_empty():
			planned_moves_are_valid = false
			break
		occupied_targets[key] = true
		planned_move_by_unit[unit_id] = move
	var apply_result := {"ok": false, "moves": []}
	if planned_moves_are_valid:
		apply_result = _apply_auto_position_moves_atomically(planned_move_by_unit)
	if not bool(apply_result.get("ok", false)):
		var blocked_text := "智能调整站位：方案会造成宠物重叠或丢失，已保留全部宠物原站位。"
		_log(blocked_text)
		plan["moves"] = []
		plan["text"] = blocked_text
		last_command_result = {"ok": false, "moves": [], "plan": plan.duplicate(true), "text": blocked_text}
		GameLogScript.error("战斗/自动布置", "原子应用失败，已保留全部原站位", {
			"计划移动数": Array(plan.get("moves", [])).size(),
			"方案签名": String(plan.get("resultSignature", ""))
		})
		return false
	var moves: Array = Array(apply_result.get("moves", [])).duplicate(true)
	if difficulty == DIFFICULTY_EASY:
		for direction_value in Array(plan.get("directions", [])):
			var direction := Dictionary(direction_value)
			var unit_id := String(direction.get("unitId", ""))
			var slot_index := int(direction.get("slotIndex", 0))
			if unit_id != "":
				action_dirs["%s:slot%d" % [unit_id, slot_index]] = _normalize_direction(String(direction.get("dir", "right")))
	auto_position_action_plan = Array(plan.get("actions", [])).duplicate(true)
	var direction_text := "简单难度允许智能调整攻击方向" if difficulty == DIFFICULTY_EASY else "普通难度保持原攻击方向"
	var text := "智能调整站位：移动%d只我方宠物，%s；已应用击杀优先且规避掉血的唯一方案，预计击杀%d只、我方掉血%d、有效伤害%d。" % [moves.size(), direction_text, int(plan.get("kills", 0)), int(plan.get("playerHpDamage", 0)), int(plan.get("effectiveDamage", 0))]
	if moves.is_empty():
		text = "智能调整站位：没有更优可移动站位，%s。" % direction_text
	_log(text)
	plan["moves"] = moves
	plan["text"] = text
	# Wall-clock profiling belongs to diagnostics, never to replayable authority.
	# Keep it on the command result/log, but store a deterministic plan for reuse
	# and state hashing.
	var authoritative_plan := plan.duplicate(true)
	var authoritative_sandbox := Dictionary(authoritative_plan.get("sandbox", {}))
	for timing_key in ["candidateDurationMs", "beamDurationMs", "retaliationDurationMs"]:
		authoritative_sandbox.erase(timing_key)
	authoritative_plan["sandbox"] = authoritative_sandbox
	auto_position_applied_result = {
		"stateSignature": _auto_position_applied_state_signature(),
		"plan": authoritative_plan
	}
	last_command_result = {"ok": true, "moves": moves.duplicate(true), "plan": plan.duplicate(true), "text": text}
	var sandbox := Dictionary(plan.get("sandbox", {}))
	GameLogScript.info("战斗/自动布置", "唯一站位方案已应用", {
		"回合": battle_round,
		"难度": difficulty,
		"移动宠物": moves.size(),
		"预计击杀": int(plan.get("kills", 0)),
		"我方预计掉血": int(plan.get("playerHpDamage", 0)),
		"有效伤害": int(plan.get("effectiveDamage", 0)),
		"候选数量": sandbox.get("candidateCounts", []),
		"评估方案数": int(sandbox.get("evaluatedPlans", 0)),
		"计算耗时毫秒": snappedf(float(Time.get_ticks_usec() - planning_started_usec) / 1000.0, 0.01)
	})
	return true

func _apply_auto_position_moves_atomically(planned_move_by_unit: Dictionary) -> Dictionary:
	var identity_before := _living_player_identity_signature()
	var original_positions := {}
	var projected_positions := {}
	var occupied_cells := {}
	var seen_player_ids := {}
	for unit_value in units:
		var unit := Dictionary(unit_value)
		if int(unit.get("hp", 0)) <= 0:
			continue
		var unit_id := String(unit.get("id", ""))
		if unit_id == "":
			return {"ok": false, "moves": []}
		var x := int(unit.get("x", -1))
		var y := int(unit.get("y", -1))
		if String(unit.get("side", "")) == PLAYER:
			if seen_player_ids.has(unit_id):
				return {"ok": false, "moves": []}
			seen_player_ids[unit_id] = true
			original_positions[unit_id] = Vector2i(x, y)
			if planned_move_by_unit.has(unit_id):
				var to := Dictionary(Dictionary(planned_move_by_unit[unit_id]).get("to", {}))
				x = int(to.get("x", -1))
				y = int(to.get("y", -1))
			projected_positions[unit_id] = Vector2i(x, y)
		if not _inside(x, y) or not _leader_at(x, y).is_empty():
			return {"ok": false, "moves": []}
		var cell_key := _cell_key(x, y)
		if occupied_cells.has(cell_key):
			return {"ok": false, "moves": []}
		occupied_cells[cell_key] = unit_id
	for unit_id_value in planned_move_by_unit.keys():
		if not projected_positions.has(String(unit_id_value)):
			return {"ok": false, "moves": []}
	for unit_id_value in planned_move_by_unit.keys():
		var unit := unit_by_id(String(unit_id_value))
		var position := Vector2i(projected_positions[String(unit_id_value)])
		unit["x"] = position.x
		unit["y"] = position.y
	if _living_player_identity_signature() != identity_before or not _living_unit_positions_are_unique():
		for unit_id_value in original_positions.keys():
			var unit := unit_by_id(String(unit_id_value))
			var position := Vector2i(original_positions[unit_id_value])
			unit["x"] = position.x
			unit["y"] = position.y
		return {"ok": false, "moves": []}
	var moves: Array = []
	for unit_id_value in planned_move_by_unit.keys():
		_record_team_placement_move(String(unit_id_value))
		moves.append(Dictionary(planned_move_by_unit[unit_id_value]).duplicate(true))
	return {"ok": true, "moves": moves}

func _living_player_identity_signature() -> Array[String]:
	var signature: Array[String] = []
	for unit_value in units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
			continue
		signature.append("%s|%s" % [String(unit.get("id", "")), String(unit.get("pet_id", unit.get("petId", "")))])
	signature.sort()
	return signature

func _living_unit_positions_are_unique() -> bool:
	var occupied := {}
	for unit_value in units:
		var unit := Dictionary(unit_value)
		if int(unit.get("hp", 0)) <= 0:
			continue
		var x := int(unit.get("x", -1))
		var y := int(unit.get("y", -1))
		var key := _cell_key(x, y)
		if not _inside(x, y) or not _leader_at(x, y).is_empty() or occupied.has(key):
			return false
		occupied[key] = true
	return true

func _quality_actor_order(unit: Dictionary) -> int:
	return int(_core_composition.quality_effect_registry.effect_for_unit(unit).actor_order)

func _sorted_player_action_units_for_quality() -> Array:
	return _sorted_action_units_for_side(PLAYER)

func _sorted_action_units_for_side(side: String) -> Array:
	var entries: Array = []
	for index in range(units.size()):
		var unit := Dictionary(units[index])
		if String(unit.get("side", "")) != side or int(unit.get("hp", 0)) <= 0:
			continue
		var action_order := _apply_stat_semantics(EffectHookIdsScript.ACTION_ORDER, {"unit": unit})
		entries.append({
			"unit": units[index],
			"quality_order": _quality_actor_order(unit),
			"speed": int(action_order.get("speed", 100)),
			"initiative": int(action_order.get("initiative", 0)),
			"index": index
		})
	entries.sort_custom(func(a, b):
		var left := Dictionary(a)
		var right := Dictionary(b)
		var left_speed := int(left.get("speed", 100))
		var right_speed := int(right.get("speed", 100))
		if left_speed != right_speed: return left_speed > right_speed
		var left_initiative := int(left.get("initiative", 0))
		var right_initiative := int(right.get("initiative", 0))
		if left_initiative != right_initiative: return left_initiative > right_initiative
		var left_order := int(left.get("quality_order", 0))
		var right_order := int(right.get("quality_order", 0))
		if left_order != right_order: return left_order < right_order
		return int(left.get("index", 0)) < int(right.get("index", 0))
	)
	var sorted_units: Array = []
	for entry in entries:
		sorted_units.append(Dictionary(entry).get("unit"))
	return sorted_units

func _reset_action_slots(side: String) -> void:
	if side == PLAYER:
		auto_position_action_plan = []
	for unit in units:
		if String(unit.get("side", "")) == side:
			_core_composition.action_slot_service.clear_unit(
				unit,
				action_ap_choices,
				int(unit.get("slot_count", 3))
			)
			unit["has_attacked"] = false
			unit["guard_reduction"] = 0
			_core_composition.quality_runtime_service.clear_mark(unit)

func _apply_quality_round_start(side: String) -> void:
	for unit in units:
		if String(unit.get("side", "")) != side or int(unit.get("hp", 0)) <= 0:
			continue
		for line in _apply_quality_round_start_to_unit(unit):
			_log(String(line))

func _apply_quality_round_start_to_unit(unit: Dictionary) -> Array:
	var upgrade := Dictionary(unit.get("quality_upgrade", {}))
	var upgrade_id := String(upgrade.get("id", ""))
	if upgrade_id == "":
		return []
	var runtime := Dictionary(unit.get("quality_runtime", {}))
	var flags := Dictionary(runtime.get("flags", {}))
	runtime["flags"] = flags
	unit["quality_runtime"] = runtime
	var quality_context := _quality_effect_context_service.configure_for_core(self)
	var effect = _core_composition.quality_effect_registry.effect_for_id(upgrade_id)
	var logs: Array = effect.on_round_start(quality_context, unit)
	for line in QualityBoardTraceScript.apply_round_start(
		quality_context,
		unit,
		_board_traces_at(int(unit.get("x", -1)), int(unit.get("y", -1)))
	):
		logs.append(String(line))
	return logs

func _apply_element_to_unit(unit: Dictionary, element: String, layers: int) -> void:
	element = _canonical_element(element)
	if element == "":
		return
	_element_field_service.add_to_unit(unit, element, layers, Callable(self, "_normalize_elements"))

func _cell_has_element_trap(x: int, y: int) -> bool:
	return _element_field_service.has_active_element(_cell_elements_at(x, y))

func _apply_element_to_cell(x: int, y: int, element: String, layers: int) -> void:
	element = _canonical_element(element)
	if element == "":
		return
	_element_field_service.add_to_field(cell_elements, _cell_key(x, y), element, layers, Callable(self, "_normalize_elements"))

func _clear_element_from_unit(unit: Dictionary, element: String) -> void:
	element = _canonical_element(element)
	if unit.is_empty() or element == "":
		return
	_element_field_service.clear_from_unit(unit, element, Callable(self, "_normalize_elements"))

func _clear_element_from_cell(x: int, y: int, element: String) -> void:
	element = _canonical_element(element)
	if element == "":
		return
	_element_field_service.clear_from_field(cell_elements, _cell_key(x, y), element, Callable(self, "_normalize_elements"))

func _cross_cells(x: int, y: int) -> Array:
	var cells: Array = []
	for delta in [
		{"x": 0, "y": 0},
		{"x": 1, "y": 0},
		{"x": -1, "y": 0},
		{"x": 0, "y": 1},
		{"x": 0, "y": -1}
	]:
		var row := Dictionary(delta)
		var cell_x: int = x + int(row.get("x", 0))
		var cell_y: int = y + int(row.get("y", 0))
		if _inside(cell_x, cell_y):
			cells.append({"x": cell_x, "y": cell_y})
	return cells

func _settle_threshold_elements() -> bool:
	var settled := false
	var marker_recorded := false
	var settlement_work := _threshold_element_settlement_work()
	for work_value in settlement_work:
		var work := Dictionary(work_value)
		var preflight_plan := _mechanic_element_settlement_plan(
			_cell_elements_at(int(work.get("x", -1)), int(work.get("y", -1))),
			String(work.get("element", ""))
		)
		if not bool(preflight_plan.get("ok", false)):
			return false
	for work_value in settlement_work:
		var work := Dictionary(work_value)
		var target := Dictionary(work.get("target", {}))
		if String(target.get("side", "")) != ENEMY:
			continue
		var x: int = int(target.get("x", -1))
		var y: int = int(target.get("y", -1))
		if not _inside(x, y):
			continue
		var elements := _cell_elements_at(x, y)
		var element := String(work.get("element", ""))
		var layers: int = int(elements.get(element, 0))
		if layers <= 0:
			continue
		var plan := _mechanic_element_settlement_plan(elements, element)
		if not bool(plan.get("ok", false)):
			return false
		if not marker_recorded:
			_record_element_settlement_start_trace()
			marker_recorded = true
		var damage: int = max(0, int(plan.get("damage", 0)))
		var multi_contribution := _settlement_contribution(plan, "multi_element_bonus")
		var multi_element_bonus: int = max(0, int(multi_contribution.get("damage_add", 0)))
		var multi_element_source := Dictionary(multi_contribution.get("source", {}))
		var damage_result := {"mechanic_logs": []}
		if String(plan.get("target_pattern", "")) == "cross":
			var projected_source := Dictionary(plan.get("source", {}))
			var cross_source := unit_by_id(String(projected_source.get("id", "")))
			if cross_source.is_empty():
				return false
			var cross_hit_count := 0
			var cross_pending_deaths: Array = []
			for cross_cell in _cross_cells(x, y):
				var cross := Dictionary(cross_cell)
				var cross_target := unit_at(int(cross.get("x", -1)), int(cross.get("y", -1)))
				if cross_target.is_empty() or String(cross_target.get("side", "")) != ENEMY:
					continue
				var cross_result := _deal_damage(cross_source, cross_target, damage, element, false, {
					"sourceType": "element_settlement",
					"deferDeathResolution": true,
				})
				if bool(cross_result.get("pending_death", false)):
					cross_pending_deaths.append({"source": cross_source, "target": cross_target, "result": cross_result})
				cross_hit_count += 1
				for line in Array(cross_result.get("mechanic_logs", [])):
					_log(String(line))
			for death_line in _resolve_damage_deaths(cross_pending_deaths):
				_log(String(death_line))
			_log("%s 触发火魔十字结算，命中%d个怪物，每个造成%d点火元素伤害。" % [String(cross_source.get("name", "单位")), cross_hit_count, damage])
		else:
			damage_result = _deal_damage({}, target, damage, element, false, {"sourceType": "element_settlement"})
		_clear_element_from_cell(x, y, element)
		_clear_element_from_unit(target, element)
		_log("%s 所在格%s%d层结算，%s伤害=%d。" % [
			String(target.get("name", target.get("id", "单位"))),
			element,
			layers,
			ElementRulesScript.settlement_damage_label(element),
			damage
		])
		if multi_element_bonus > 0:
			_log("%s 触发多元素共鸣，额外造成%d。" % [String(multi_element_source.get("name", "单位")), multi_element_bonus])
		for line in Array(damage_result.get("mechanic_logs", [])):
			_log(String(line))
		settled = true
	for y in range(board_height):
		for x in range(board_width):
			if not unit_at(x, y).is_empty():
				continue
			for element in ElementRulesScript.SETTLEMENT_ELEMENTS:
				var layers: int = int(_cell_elements_at(x, y).get(element, 0))
				if layers > 0:
					_log("R%dC%d %s%d层：格上没有敌方怪物，地形保留。" % [y + 1, x + 1, element, layers])
	return settled

func _threshold_element_settlement_work() -> Array:
	var work: Array = []
	for target_value in units:
		var target := Dictionary(target_value)
		if String(target.get("side", "")) != ENEMY or int(target.get("hp", 0)) <= 0:
			continue
		var x: int = int(target.get("x", -1))
		var y: int = int(target.get("y", -1))
		if not _inside(x, y):
			continue
		var elements := _cell_elements_at(x, y)
		# One cell can carry several element terrains at the same time. If a
		# living enemy occupies it, settle every positive layer stack in the
		# canonical element order; an empty cell never enters this work list and
		# therefore keeps all of its terrain data unchanged.
		for element in ElementRulesScript.SETTLEMENT_ELEMENTS:
			if int(elements.get(element, 0)) > 0:
				work.append({"target": target, "x": x, "y": y, "element": element})
	return work

func _settlement_contribution(plan: Dictionary, exclusive_key: String) -> Dictionary:
	for value in Array(plan.get("contributions", [])):
		var contribution := Dictionary(value)
		if String(contribution.get("exclusive_key", "")) == exclusive_key:
			return contribution.duplicate(true)
	return {}

func _record_element_settlement_start_trace() -> void:
	var event_id := "bt_%06d" % (battle_trace.size() + 1)
	var wait_seconds := 1.0
	battle_trace.append({
		"eventId": event_id,
		"kind": "combat_pause",
		"type": "ELEMENT_SETTLEMENT_START",
		"step": battle_trace.size() + 1,
		"round": battle_round,
		"phase": phase,
		"actor": {},
		"target": {},
		"payload": {"waitSeconds": wait_seconds},
		"changes": [],
		"source": {"system": "ysbzs_state.gd", "function": "_settle_threshold_elements"},
		"reason": "element_settlement_after_all_attacks",
		"tags": ["battle", "element", "settlement", "pause"],
		"text": "所有我方攻击完成，等待1秒后结算怪物所在元素格。",
		"protocol": "|ELEMENT_SETTLEMENT_START|id=%s|round=%d|phase=%s|wait=1.0" % [event_id, battle_round, phase]
	})

func _apply_trap_stack_on_enter(unit: Dictionary) -> void:
	if unit.is_empty() or int(unit.get("hp", 0)) <= 0:
		return
	# Terrain is an enemy-only hazard. Keep this authority-side guard even
	# though current player movement does not call this entry point.
	if String(unit.get("side", "")) != ENEMY:
		return
	if not _core_composition.mechanic_projection_service.trap_entry_allowed(
		unit.duplicate(true),
		_battle_mechanisms(),
		String(unit.get("side", "")) == ENEMY
	):
		return
	var x: int = int(unit.get("x", -1))
	var y: int = int(unit.get("y", -1))
	if not _inside(x, y):
		return
	var elements := _cell_elements_at(x, y)
	var triggered: Array = []
	var pending_deaths: Array = []
	var total_damage := 0
	for element in ElementRulesScript.SETTLEMENT_ELEMENTS:
		var layers: int = int(elements.get(element, 0))
		if layers <= 0:
			continue
		var damage := ElementBurstPolicyScript.damage(layers)
		var damage_result := _deal_damage({}, unit, damage, element, false, {
			"sourceType": "element_trap",
			"suppressProjectile": true,
			"deferDeathResolution": true,
		})
		if bool(damage_result.get("pending_death", false)):
			pending_deaths.append({"source": {}, "target": unit, "result": damage_result})
		total_damage += int(damage_result.get("hp_damage", 0))
		_clear_element_from_cell(x, y, element)
		triggered.append("%s%d层" % [element, layers])
		for line in Array(damage_result.get("mechanic_logs", [])):
			_log(String(line))
	for death_line in _resolve_damage_deaths(pending_deaths):
		_log(String(death_line))
	if triggered.is_empty():
		return
	_log("%s 踩中陷阱，触发全部元素：%s，造成%d伤害。" % [
		String(unit.get("name", unit.get("id", "单位"))),
		"、".join(triggered),
		total_damage
	])

func _set_board_trace(x: int, y: int, trace: Dictionary) -> bool:
	if not _inside(x, y):
		return false
	var row := trace.duplicate(true)
	row["x"] = x
	row["y"] = y
	row["duration"] = max(1, int(row.get("duration", 1)))
	var key := _cell_key(x, y)
	var rows := _board_traces_at(x, y)
	rows.append(row)
	board_traces[key] = rows
	return true

func _tick_board_traces() -> void:
	var expired: Array = []
	for key in board_traces.keys():
		var kept: Array = []
		for item in _board_traces_at(int(String(key).split(",")[0]), int(String(key).split(",")[1])):
			var trace := Dictionary(item)
			if bool(trace.get("persistent", false)):
				kept.append(trace)
				continue
			trace["duration"] = int(trace.get("duration", 1)) - 1
			if int(trace.get("duration", 0)) > 0:
				kept.append(trace)
		if kept.is_empty():
			expired.append(key)
		else:
			board_traces[key] = kept
	for key in expired:
		board_traces.erase(key)

func _apply_board_trace_to_unit(unit: Dictionary, trace: Dictionary) -> String:
	return QualityBoardTraceScript.apply_to_unit(
		_quality_effect_context_service.configure_for_core(self),
		unit,
		trace
	)

func _add_incoming_damage_bonus(unit: Dictionary, amount: int) -> int:
	return UnitVitalsScript.add_incoming_damage_bonus(unit, amount)

func _heal_unit(unit: Dictionary, amount: int, source: Dictionary = {}) -> int:
	var before: int = max(0, int(unit.get("hp", 0)))
	var maximum: int = max(1, _resolved_stat_value(unit, "max_hp", {"hook": EffectHookIdsScript.HEALING}))
	var semantic := _apply_stat_semantics(EffectHookIdsScript.HEALING, {"source": source, "target": unit, "amount": max(0, amount)})
	unit["hp"] = min(maximum, before + max(0, int(semantic.get("amount", amount))))
	return int(unit["hp"]) - before

func _deal_damage(
	source: Dictionary,
	target: Dictionary,
	amount: int,
	element: String = "",
	consume_incoming_bonus: bool = true,
	trace_context: Dictionary = {},
	damage_props: Variant = {}
) -> Dictionary:
	var effective_trace_context := trace_context.duplicate(true)
	if String(effective_trace_context.get("sourceType", "")).strip_edges() == "":
		effective_trace_context["sourceType"] = "effect"
	var effective_props := DamagePropsScript.resolve(damage_props, String(effective_trace_context.get("sourceType", "effect")))
	var result := Dictionary(_core_composition.damage_resolver.resolve(
		DamageResolutionPortScript.new(self),
		source,
		target,
		amount,
		element,
		consume_incoming_bonus,
		effective_trace_context,
		effective_props
	))
	if bool(result.get("pending_death", false)) and not bool(effective_trace_context.get("deferDeathResolution", false)):
		var death_logs := _resolve_damage_deaths([{
			"source": source,
			"target": target,
			"result": result,
		}])
		var mechanic_logs := Array(result.get("mechanic_logs", [])).duplicate()
		mechanic_logs.append_array(death_logs)
		result["mechanic_logs"] = mechanic_logs
	return result

func _resolve_damage_deaths(candidates: Array) -> Array:
	return _core_composition.damage_death_service.resolve(DamageDeathPortScript.new(self), candidates)

func _effective_action_cost(unit: Dictionary, requested: int) -> Dictionary:
	return _apply_stat_semantics(EffectHookIdsScript.ACTION_COST, {"unit": unit, "requested": requested})

func _effective_movement_cost(unit: Dictionary, base_cost: int = 0) -> int:
	return int(_apply_stat_semantics(EffectHookIdsScript.MOVEMENT_COST, {"unit": unit, "base_cost": base_cost}).get("cost", base_cost))

func _battle_trace_unit_ref(unit: Dictionary) -> Dictionary:
	return BattleTraceFactoryScript.unit_ref(unit)

func _position_ref(x: int, y: int) -> Dictionary:
	return BattleTraceFactoryScript.position_ref(x, y)

func _record_move_trace(event_type: String, unit: Dictionary, from_pos: Dictionary, to_pos: Dictionary, move_range: int, text: String) -> void:
	battle_trace.append(BattleTraceFactoryScript.move_event(
		battle_trace.size() + 1,
		battle_round,
		phase,
		event_type,
		unit,
		from_pos,
		to_pos,
		move_range,
		text
	))

func _record_damage_trace(source: Dictionary, target: Dictionary, raw_damage: int, shield_damage: int, hp_damage: int, hp_before: int, hp_after: int, shield_before: int, shield_after: int, element: String, trace_context: Dictionary = {}) -> void:
	var event := BattleTraceFactoryScript.damage_event(
		battle_trace.size() + 1,
		battle_round,
		phase,
		source,
		target,
		raw_damage,
		shield_damage,
		hp_damage,
		hp_before,
		hp_after,
		shield_before,
		shield_after,
		element,
		trace_context
	)
	if not event.is_empty():
		battle_trace.append(event)
		var text := String(event.get("text", ""))
		if text != "":
			_log(text)
			if String(_initialization_result.get("mode", "production")) != "simulation":
				var payload := Dictionary(event.get("payload", {}))
				GameLogScript.info("战斗/伤害", text, {
					"来源类型": String(payload.get("sourceType", "action")),
					"回合": battle_round,
					"事件": String(event.get("eventId", "")),
					"元素": element
				})
		_publish_relic_event("DAMAGE_APPLIED", {
			"source_unit_id": String(source.get("id", "")),
			"source_side": String(source.get("side", "")),
			"target_unit_id": String(target.get("id", "")),
			"target_side": String(target.get("side", "")),
			"hp_damage": hp_damage,
			"shield_damage": shield_damage,
			"element": element,
			"source_type": String(trace_context.get("sourceType", "action")),
		})

func _start_relic_combat() -> void:
	_core_composition.relic_combat_service.start(RelicCombatPortScript.new(self))

func _advance_relic_time(delta_ticks: int) -> void:
	if phase != "battle" or delta_ticks <= 0:
		return
	var port: RefCounted = RelicCombatPortScript.new(self)
	var current_tick := int(_core_composition.relic_combat_service.current_tick(port))
	_core_composition.relic_combat_service.advance(port, current_tick + delta_ticks)

func _publish_relic_event(event_type: String, payload: Dictionary = {}) -> void:
	_core_composition.relic_combat_service.publish(RelicCombatPortScript.new(self), event_type, payload)

func _publish_relic_battle_end(payload: Dictionary = {}) -> void:
	_core_composition.relic_combat_service.publish_battle_end(RelicCombatPortScript.new(self), payload)

func _record_element_applied_trace(source: Dictionary, cells: Array, element: String, layers: int, suppress_projectile: bool = false) -> void:
	if source.is_empty() or element == "" or cells.is_empty():
		return
	var targets: Array = []
	for cell_value in cells:
		var cell := Dictionary(cell_value)
		var x := int(cell.get("x", -1))
		var y := int(cell.get("y", -1))
		if not _inside(x, y):
			continue
		targets.append(_position_ref(x, y))
	if targets.is_empty():
		return
	battle_trace.append(BattleTraceFactoryScript.element_event(
		battle_trace.size() + 1,
		battle_round,
		phase,
		source,
		targets,
		element,
		layers,
		suppress_projectile
	))

func _record_attack_strike_trace(source: Dictionary, target_cells: Array, element: String, strike_index: int, strike_count: int) -> void:
	if source.is_empty() or target_cells.is_empty():
		return
	var target_refs: Array = []
	for cell_value in target_cells:
		var cell := Dictionary(cell_value)
		var x := int(cell.get("x", -1))
		var y := int(cell.get("y", -1))
		if not _inside(x, y):
			continue
		var occupying_target := _combat_target_at(x, y)
		target_refs.append(_battle_trace_unit_ref(occupying_target) if not occupying_target.is_empty() else _position_ref(x, y))
	if target_refs.is_empty():
		return
	battle_trace.append(BattleTraceFactoryScript.attack_strike_event(
		battle_trace.size() + 1,
		battle_round,
		phase,
		source,
		target_refs,
		element,
		strike_index,
		strike_count
	))

func _skill_damage_bonus(attacker: Dictionary, slot: Dictionary, option: Dictionary, targets: Array) -> int:
	var skill := String(attacker.get("skill", ""))
	if skill == "spaceExplosionBonus":
		return max(2, int(slot.get("layers", 1)) * 2)
	if skill == "advHitBonus" and targets.size() == 1:
		return 1
	return 0

func _quality_element_apply_count(attacker: Dictionary, cell: Dictionary = {}) -> int:
	return int(_core_composition.quality_effect_registry.effect_for_unit(
		attacker
	).element_application_count(
		_quality_effect_context_service.configure_for_core(self),
		cell
	))

func _quality_element_layers(attacker: Dictionary, slot_element: String, base_layers: int) -> int:
	return int(_core_composition.quality_effect_registry.effect_for_unit(
		attacker
	).element_layers(attacker, slot_element, base_layers))

func _apply_quality_before_attack(attacker: Dictionary, option: Dictionary) -> Array:
	return _core_composition.quality_effect_registry.effect_for_unit(attacker).on_before_attack(
		_quality_effect_context_service.configure_for_core(self),
		attacker,
		option
	)

func _quality_damage_for_hit(attacker: Dictionary, slot: Dictionary, option: Dictionary, targets: Array, target: Dictionary, hit_index: int, base_damage: int) -> int:
	var incoming_bonus: int = max(0, int(target.get("incoming_damage_bonus", 0)))
	if incoming_bonus > 0:
		target["incoming_damage_bonus"] = 0
	var damage: int = max(0, base_damage + _quality_cell_damage_delta(option, target) + incoming_bonus)
	return _quality_modify_hit_damage(
		attacker,
		_quality_hit_context(attacker, option, targets, target, hit_index, damage)
	)

func _quality_bonus_label(attacker: Dictionary, amount: int) -> String:
	if amount <= 0:
		return ""
	var upgrade_name := _quality_upgrade_name(attacker)
	if upgrade_name == "":
		return ""
	return "%s+%d" % [upgrade_name, amount]

func _quality_immediate_element_burst(attacker: Dictionary, target: Dictionary, slot_element: String) -> Array:
	return _core_composition.quality_effect_registry.effect_for_unit(attacker).on_before_hit(
		_quality_effect_context_service.configure_for_core(self),
		attacker,
		target,
		slot_element
	)

func _friendly_units_in_option(attacker: Dictionary, option: Dictionary) -> Array:
	var allies: Array = []
	for unit in units:
		if String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
			continue
		if String(unit.get("id", "")) == String(attacker.get("id", "")):
			continue
		if _option_contains_cell(option, int(unit.get("x", -1)), int(unit.get("y", -1))):
			allies.append(unit)
	return allies

func _units_in_option(option: Dictionary) -> Array:
	var covered: Array = []
	for unit in units:
		if int(Dictionary(unit).get("hp", 0)) <= 0:
			continue
		if _option_contains_cell(option, int(Dictionary(unit).get("x", -1)), int(Dictionary(unit).get("y", -1))):
			covered.append(unit)
	return covered

func _apply_quality_after_attack(attacker: Dictionary, option: Dictionary, targets: Array) -> Array:
	return _core_composition.quality_effect_registry.effect_for_unit(attacker).on_after_attack(
		_quality_effect_context_service.configure_for_core(self),
		attacker,
		option,
		targets
	)

func _lowest_low_hp_enemy() -> Dictionary:
	var best := {}
	var best_hp := 999999
	for unit in units:
		if String(Dictionary(unit).get("side", "")) != ENEMY:
			continue
		var hp := int(Dictionary(unit).get("hp", 0))
		if hp <= 0 or hp > 5:
			continue
		if hp < best_hp:
			best = unit
			best_hp = hp
	return best

func _apply_quality_after_hit(attacker: Dictionary, target: Dictionary) -> Array:
	return _core_composition.quality_effect_registry.effect_for_unit(attacker).on_after_hit(
		_quality_effect_context_service.configure_for_core(self),
		attacker,
		target
	)

func _adjacent_enemies(target: Dictionary) -> Array:
	var rows: Array = []
	var target_x := int(target.get("x", -999))
	var target_y := int(target.get("y", -999))
	for unit in units:
		if String(Dictionary(unit).get("side", "")) != ENEMY or int(Dictionary(unit).get("hp", 0)) <= 0:
			continue
		if String(Dictionary(unit).get("id", "")) == String(target.get("id", "")):
			continue
		var distance: int = abs(int(Dictionary(unit).get("x", -999)) - target_x) + abs(int(Dictionary(unit).get("y", -999)) - target_y)
		if distance == 1:
			rows.append(unit)
	return rows

func _apply_action_skill_after_attack(attacker: Dictionary, slot: Dictionary, option: Dictionary, targets: Array) -> Array:
	var logs: Array = []
	var skill := String(attacker.get("skill", ""))
	var layers: int = max(1, int(slot.get("layers", 1)))
	var base_layers: int = max(1, int(slot.get("base_layers", layers)))
	if skill == "castleReduce":
		var shield_gain: int = base_layers * 2
		var guard_gain: int = base_layers * 2
		var before_shield := int(attacker.get("shield", 0))
		attacker["shield"] = before_shield + shield_gain
		attacker["guard_reduction"] = max(int(attacker.get("guard_reduction", 0)), guard_gain)
		logs.append("%s：护盾+%d，下一次受击减伤%d。" % [skill_label(skill), shield_gain, guard_gain])
	elif skill == "spaceExplosionBonus":
		var bonus_fire: int = layers
		var applied := 0
		for cell in Array(option.get("cells", [])):
			var row := Dictionary(cell)
			var x := int(row.get("x", -1))
			var y := int(row.get("y", -1))
			if _inside(x, y) and unit_at(x, y).is_empty():
				_apply_element_to_cell(x, y, "火", bonus_fire)
				applied += 1
		if applied > 0:
			logs.append("%s：%d 个空作用格追加火%d层。" % [skill_label(skill), applied, bonus_fire])
	elif skill == "healAmpBonus":
		var heal_amount: int = layers * 3
		var receiver := _lowest_damaged_player_in_option(option)
		if receiver.is_empty():
			receiver = attacker
		var healed := _heal_unit(receiver, heal_amount)
		logs.append("%s：%s 恢复%d生命。" % [skill_label(skill), String(receiver.get("name", "我方")), healed])
	elif skill == "buffAllSummons":
		var buffed := 0
		for unit in units:
			if String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
				continue
			unit["atk"] = int(unit.get("atk", 0)) + 1
			unit["skill_bonus_atk"] = int(unit.get("skill_bonus_atk", 0)) + 1
			buffed += 1
		if buffed > 0:
			logs.append("%s：%d 个我方单位攻击+1。" % [skill_label(skill), buffed])
	elif skill == "advHitBonus":
		for hit in targets:
			hit["ap"] = max(0, int(hit.get("ap", 0)) - 1)
		if targets.size() > 0:
			logs.append("%s：命中目标行动-1。" % skill_label(skill))
	return logs

func _lowest_damaged_player_in_option(option: Dictionary) -> Dictionary:
	var best := {}
	var best_missing := 0
	for unit in units:
		if String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
			continue
		if not _option_contains_cell(option, int(unit.get("x", -1)), int(unit.get("y", -1))):
			continue
		var missing: int = int(unit.get("max_hp", 0)) - int(unit.get("hp", 0))
		if missing > best_missing:
			best = unit
			best_missing = missing
	return best

func _element_summary(elements: Dictionary) -> String:
	var parts: Array = []
	for element in ElementRulesScript.ACTIVE_ELEMENTS:
		var layers := int(elements.get(element, 0))
		if layers > 0:
			parts.append("%s%d" % [element, layers])
	return "无" if parts.is_empty() else " ".join(parts)

func _direction_delta(direction: String) -> Vector2i:
	return ShapeGeometryScript.direction_delta(direction)

func _init(options: Dictionary = {}) -> void:
	var supplied := options.duplicate(true)
	var mode := String(supplied.get("mode", "production"))
	_initialization_mode = mode if ["production", "simulation", "test"].has(mode) else "production"
	var option_errors: Array[String] = []
	var allowed_keys := ["mode", "content_pack", "content_source_kind", "core_overrides"]
	var option_keys: Array[String] = []
	for key_value in supplied.keys():
		option_keys.append(String(key_value))
	option_keys.sort()
	for key in option_keys:
		if not allowed_keys.has(key):
			option_errors.append("INIT_OPTION_UNSUPPORTED:%s" % key)
	if not ["production", "simulation", "test"].has(mode):
		option_errors.append("INIT_MODE_UNSUPPORTED")
	var source_kind_value: Variant = supplied.get("content_source_kind", CoreCompositionScript.CURRENT_ASSEMBLY)
	var source_kind := CoreCompositionScript.CURRENT_ASSEMBLY
	if not [TYPE_STRING, TYPE_STRING_NAME].has(typeof(source_kind_value)):
		option_errors.append("INIT_CONTENT_SOURCE_KIND_INVALID")
	else:
		source_kind = StringName(String(source_kind_value))
		if not [CoreCompositionScript.CURRENT_ASSEMBLY, CoreCompositionScript.PERSISTED_SNAPSHOT].has(source_kind):
			option_errors.append("INIT_CONTENT_SOURCE_KIND_UNSUPPORTED")
	var overrides_value: Variant = supplied.get("core_overrides", {})
	if typeof(overrides_value) != TYPE_DICTIONARY:
		option_errors.append("CORE_OVERRIDES_INVALID")
	var core_overrides := Dictionary(overrides_value).duplicate(true) if typeof(overrides_value) == TYPE_DICTIONARY else {}
	_core_composition = CoreCompositionScript.new(core_overrides)
	if not option_errors.is_empty():
		_initialization_result = {
			"schema": "ysbzs.init-result.v1",
			"ok": false,
			"mode": mode if ["production", "simulation", "test"].has(mode) else "production",
			"source": "",
			"contentHash": "",
			"errors": option_errors,
		}
		return
	var content_value: Variant = supplied.get("content_pack", {})
	var content_pack := Dictionary(content_value).duplicate(true) if typeof(content_value) == TYPE_DICTIONARY else {}
	var load_result := Dictionary(_core_composition.content_load_service.load({
		"mode": mode,
		"contentPack": content_pack,
		"contentPath": StateContentSourceConfigScript.CONTENT_PACK_PATH,
		"supplementPath": StateContentSourceConfigScript.BAZAAR_DAY1_CATALOG_PATH,
	}, _core_composition.game_data_repository))
	_initialization_result = load_result.duplicate(true)
	_initialization_result.erase("contentPack")
	if not bool(load_result.get("ok", false)):
		return
	if not _replace_game_data(Dictionary(load_result.get("contentPack", {})), source_kind):
		_initialization_result["ok"] = false
		_initialization_result["contentHash"] = ""
		_initialization_result["errors"] = _content_binding_errors.duplicate()
		return
	reset()

func reset() -> void:
	phase = "route"
	state_version = 0
	day = 1
	node_index = 1
	var player := Dictionary(game_data.get("player", {}))
	coins = int(player.get("coins", 16))
	hero_max_hp = int(player.get("heroMaxHp", player.get("hero_max_hp", player.get("hero_hp", DEFAULT_LEADER_HP))))
	hero_hp = int(player.get("hero_hp", hero_max_hp))
	enemy_hero_max_hp = int(player.get("enemyHeroMaxHp", player.get("enemy_hero_max_hp", DEFAULT_LEADER_HP)))
	enemy_hero_hp = int(player.get("enemyHeroHp", player.get("enemy_hero_hp", enemy_hero_max_hp)))
	castle_line = int(player.get("castleLine", player.get("castle_line", 10)))
	economy_multiplier = float(player.get("economyMultiplier", player.get("economy_multiplier", 1.0)))
	ap = int(player.get("ap", 3))
	battle_round = 1
	battle_period = "上午"
	difficulty = DIFFICULTY_NORMAL
	board_width = DEFAULT_BOARD_WIDTH
	board_height = DEFAULT_BOARD_HEIGHT
	selected_unit_id = ""
	selected_action_slot_index = 0
	team_placement_preview = {"activeUnitId": null, "movedUnitIds": []}
	active_wave = {}
	active_schedule = {}
	active_encounter = {}
	scenario_provenance = {}
	active_stall = {}
	active_shop_pool = "night_base"
	active_shop_seed_context = ""
	run_seed = String(game_data.get("seed", Dictionary(game_data.get("source", {})).get("seed", "ysbzs-local")))
	if run_seed.strip_edges() == "":
		run_seed = "ysbzs-local"
	action_ap_choices = {}
	shop_roll_count = 0
	shop_context_roll_count = 0
	shop_free_rolls = 0
	shop_paid_refreshes = 0
	shop_next_discount = 0
	shop_event_effects = []
	shop_seen_pet_ids_by_day = {}
	shop_seed_audit = []
	reward_fallback_audit = []
	battle_prep_effects = []
	outer_run_effects = []
	team_placement_preview = {"activeUnitId": null, "movedUnitIds": []}
	run_plan = _build_run_plan()
	route_options = _build_route_options()
	roster = _clone_units(Array(game_data.get("roster", [])), PLAYER)
	_normalize_roster_slots()
	shop_offers = Array(game_data.get("shop_offers", [])).duplicate(true)
	reward_options = []
	relic_inventory = Array(game_data.get("relic_inventory", [])).duplicate(true)
	relic_combat_state = {}
	units = []
	defeated_units = []
	battle_result = {}
	cell_elements = {}
	board_traces = {}
	action_dirs = {}
	auto_position_action_plan = []
	auto_position_applied_result = {}
	player_elements_settled_this_round = false
	battle_roster_templates = {PLAYER: [], ENEMY: []}
	skill_control_orders = {PLAYER: [], ENEMY: []}
	pet_reset_counts = {PLAYER: 0, ENEMY: 0}
	pet_reset_charges = {PLAYER: _pet_reset_initial_charges(), ENEMY: _pet_reset_initial_charges()}
	pet_reset_next_charge_round = {PLAYER: _pet_reset_charge_interval(), ENEMY: _pet_reset_charge_interval()}
	pet_reset_eligible = {PLAYER: false, ENEMY: false}
	battle_trace = []
	command_log = []
	replay_debug_timeline = []
	last_command_result = {}
	last_manual_flow_preview = {}
	placement_damage_by_unit = {}
	log_lines = ["进入时间节点 1，选择当前路线节点。"]

func _build_route_options() -> Array:
	if not _has_route_data():
		return Array(game_data.get("route_options", [])).duplicate(true)
	var plan_entry := _current_run_plan_entry()
	if not plan_entry.is_empty():
		active_schedule = Dictionary(plan_entry.get("schedule", {})).duplicate(true)
		return Array(plan_entry.get("options", [])).duplicate(true)
	var schedule := _current_schedule()
	if schedule.is_empty():
		return []
	active_schedule = schedule.duplicate(true)
	return _route_options_for_schedule(schedule)

func _stall_for_node(node: Dictionary) -> Dictionary:
	var pool_id := String(node.get("shopPoolId", "night_base"))
	var store := _shop_store_definition(pool_id)
	if not store.is_empty():
		var resolved := _shop_stall_catalog.resolve(
			store,
			Array(_economy_data().get("shop_mapping", [])),
			day,
			"%s|%s" % [active_shop_seed_context, pool_id],
			String(node.get("stallId", node.get("stall_id", "")))
		)
		if not resolved.is_empty():
			resolved["slots"] = _shop_slot_count(int(resolved.get("slots", store.get("default_slots", MAX_SHOP_OFFERS))))
			resolved["node_id"] = String(node.get("nodeId", ""))
			return resolved
		var stall := store.duplicate(true)
		stall["pool_id"] = pool_id
		stall["slots"] = _shop_slot_count(int(node.get("slots", store.get("default_slots", MAX_SHOP_OFFERS))))
		stall["node_id"] = String(node.get("nodeId", ""))
		stall["available"] = true
		return stall
	return {
		"id": pool_id,
		"pool_id": pool_id,
		"name": String(node.get("name", "宠物商店")),
		"tags": [],
		"slots": _shop_slot_count(int(node.get("slots", MAX_SHOP_OFFERS))),
		"status": "正式",
		"available": true,
	}

func _shop_store_definition(pool_id: String) -> Dictionary:
	for item in Array(_economy_data().get("shop_stores", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var store := Dictionary(item)
		if String(store.get("id", "")) == pool_id:
			var definition := store.duplicate(true)
			definition["pool_id"] = pool_id
			return definition
	return {}

func _shop_pool_has_candidates(pool_id: String) -> bool:
	var store := _shop_store_definition(pool_id)
	if store.is_empty():
		store = {"id": pool_id, "pool_id": pool_id}
	var mappings := Array(_economy_data().get("shop_mapping", []))
	if _shop_stall_catalog.has_location(mappings, pool_id):
		for value in _shop_stall_catalog.open_stalls(mappings, pool_id, day):
			var mapping := Dictionary(value)
			if _shop_stall_has_candidates(pool_id, String(mapping.get("id", ""))):
				return true
		return false
	return _shop_catalog_service.has_candidates(
		Array(_economy_data().get("shop_items", [])),
		store,
		_shop_catalog_context(pool_id, false)
	)

func _shop_stall_has_candidates(pool_id: String, stall_id: String) -> bool:
	var mappings := Array(_economy_data().get("shop_mapping", []))
	var is_open := false
	for value in _shop_stall_catalog.open_stalls(mappings, pool_id, day):
		if String(Dictionary(value).get("id", "")) == stall_id:
			is_open = true
			break
	if not is_open:
		return false
	var store := _shop_store_definition(pool_id)
	if store.is_empty():
		store = {"id": pool_id, "pool_id": pool_id}
	return _shop_catalog_service.has_candidates(
		Array(_economy_data().get("shop_items", [])),
		store,
		_shop_catalog_context(pool_id, false, stall_id)
	)

func _resolve_day1_shop_pool(requested_pool: String, seed_context: String) -> String:
	var candidates: Array[String] = []
	var source_node_type := "merchant" if requested_pool == "day1_element_dynamic" else "trainer"
	if ["day1_element_dynamic", "day1_role_dynamic"].has(requested_pool):
		for value in Array(_economy_data().get("shop_mapping", [])):
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var mapping := Dictionary(value)
			if String(mapping.get("source_node_type", "")) != source_node_type:
				continue
			var location_id := String(mapping.get("local_shop_id", ""))
			if location_id == "" or candidates.has(location_id):
				continue
			if _shop_stall_has_candidates(location_id, String(mapping.get("id", ""))):
				candidates.append(location_id)
	if candidates.is_empty() and requested_pool == "day1_element_dynamic":
		for element in ElementRulesScript.ACTIVE_ELEMENTS:
			var element_pool := "elem_%s" % String(element)
			if _shop_pool_has_candidates(element_pool):
				candidates.append(element_pool)
	elif candidates.is_empty() and requested_pool == "day1_role_dynamic":
		for role in ["坦克", "输出", "控制", "治疗", "召唤", "经济", "机动"]:
			var role_pool := "role_%s" % role
			if _shop_pool_has_candidates(role_pool):
				candidates.append(role_pool)
	if candidates.is_empty():
		return requested_pool
	candidates.sort()
	var random := _rng("%s|%s|day%d" % [seed_context, requested_pool, day])
	var index: int = mini(candidates.size() - 1, int(floor(_rng_next(random) * candidates.size())))
	return candidates[index]

func _shop_weight(item: Dictionary, pool_id: String) -> int:
	return EconomyRulesScript.shop_weight(item, pool_id)

func _shop_slot_count(requested: int) -> int:
	return RouteRulesScript.normalized_shop_slots(requested, MAX_SHOP_OFFERS)

func _shop_event_by_id(event_id: String) -> Dictionary:
	for event in _available_shop_events():
		var row := Dictionary(event)
		if String(row.get("id", "")) == event_id:
			return row
	return {}

func _shop_seen_pet_lookup_for_day(target_day: int = -1) -> Dictionary:
	var lookup := {}
	for pet_id in _shop_seen_pet_ids_for_day(target_day):
		lookup[String(pet_id)] = true
	return lookup

func _record_shop_seen_pet_ids(offers: Array, target_day: int = -1) -> Array:
	var resolved_day := day if target_day < 1 else target_day
	var pet_ids := _shop_seen_pet_ids_for_day(resolved_day)
	var lookup := {}
	for pet_id in pet_ids:
		lookup[String(pet_id)] = true
	var newly_seen: Array = []
	for value in offers:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var pet_id := _pet_key(Dictionary(value))
		if pet_id == "" or lookup.has(pet_id):
			continue
		lookup[pet_id] = true
		pet_ids.append(pet_id)
		newly_seen.append(pet_id)
	pet_ids.sort()
	shop_seen_pet_ids_by_day[str(resolved_day)] = pet_ids
	return newly_seen

func _shop_offers_for_pool(pool_id: String, slots: int, kept_offers: Array = []) -> Array:
	var roll_seed := _shop_roll_seed(pool_id)
	var context_counter_before := shop_context_roll_count
	var general_counter_before := shop_roll_count
	var seen_count_before := _shop_seen_pet_ids_for_day().size()
	var store := _shop_store_definition(pool_id)
	if store.is_empty():
		store = {"id": pool_id, "pool_id": pool_id}
	elif not active_stall.is_empty() and String(active_stall.get("pool_id", "")) == pool_id:
		store = active_stall.duplicate(true)
	var context := _shop_catalog_context(pool_id)
	context["random"] = _rng(roll_seed)
	context["discount"] = shop_next_discount
	context["max_offers"] = MAX_SHOP_OFFERS
	var result := Dictionary(_shop_catalog_service.build_offers(
		Array(_economy_data().get("shop_items", [])),
		store,
		_shop_slot_count(slots),
		kept_offers,
		context
	))
	var offers := Array(result.get("offers", []))
	var kept_count := int(result.get("kept_offer_count", 0))
	var newly_seen_pet_ids := _record_shop_seen_pet_ids(offers)
	shop_next_discount = 0
	if active_shop_seed_context != "":
		shop_context_roll_count += 1
	else:
		shop_roll_count += 1
	shop_seed_audit.append({
		"pool_id": pool_id,
		"mode": "route_context" if active_shop_seed_context != "" else "manual_or_period",
		"seed_context": active_shop_seed_context,
		"seed": roll_seed,
		"day": day,
		"period": battle_period,
		"kept_offer_count": kept_count,
		"generated_offer_count": int(result.get("generated_offer_count", max(0, offers.size() - kept_count))),
		"newly_seen_pet_ids": newly_seen_pet_ids,
		"daily_seen_count_before": seen_count_before,
		"daily_seen_count_after": _shop_seen_pet_ids_for_day().size(),
		"shop_roll_count_before": general_counter_before,
		"shop_roll_count_after": shop_roll_count,
		"shop_context_roll_count_before": context_counter_before,
		"shop_context_roll_count_after": shop_context_roll_count
	})
	return offers

func _shop_catalog_context(
	pool_id: String,
	apply_owned_diamond_blocker: bool = true,
	source_stall_override: String = ""
) -> Dictionary:
	var context := {
		"day": day,
		"weight_fn": func(row: Dictionary): return _shop_weight(row, pool_id),
		"key_fn": func(row: Dictionary): return _pet_key(row),
		"source_objects": Array(_economy_data().get("bazaar_objects", [])),
	}
	var daily_seen := _shop_seen_pet_lookup_for_day()
	var source_stall_id := source_stall_override
	if source_stall_id == "" and String(active_stall.get("pool_id", "")) == pool_id:
		source_stall_id = String(active_stall.get("source_stall_id", active_stall.get("stall_id", "")))
	if source_stall_id != "":
		context["source_stall_id"] = source_stall_id
	context["blocked_fn"] = func(row: Dictionary):
		var pet_id := _pet_key(row)
		if pet_id != "" and daily_seen.has(pet_id):
			return true
		return apply_owned_diamond_blocker and pet_id != "" and _roster_index_for_pet_quality(pet_id, "钻石") >= 0
	return context

func _frozen_shop_offers() -> Array:
	var rows: Array = []
	for offer in shop_offers:
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(offer)
		if bool(row.get("frozen", false)):
			rows.append(row.duplicate(true))
	return rows

func _reward_options_for_pool(pool_id: String, count: int, seed_context: String = "") -> Array:
	var pets: Array = []
	for item in Array(_economy_data().get("shop_items", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var shop_item := Dictionary(item)
		if int(shop_item.get("unlock_day", 1)) <= day and Array(shop_item.get("reward_pools", [])).has(pool_id):
			pets.append(shop_item)
	var random := _rng(_reward_seed(pool_id, seed_context))
	var options: Array = []
	for index in range(min(count, pets.size())):
		var pet := _weighted_pick(pets, func(row): return int(Dictionary(Dictionary(row).get("weights", {})).get("reward", 1)), random)
		if pet.is_empty():
			break
		options.append({
			"id": "reward_%03d_%s" % [options.size() + 1, String(pet.get("pet_id", ""))],
			"type": "pet",
			"pet_id": String(pet.get("pet_id", "")),
			"name": String(pet.get("name", pet.get("pet_id", ""))),
			"pool_id": pool_id,
			"source": pet.duplicate(true)
			})
	return options

func _tier_reward_pool_for_day() -> String:
	return EconomyRulesScript.tier_reward_pool_for_day(day)

func _base_reward_pool_for_battle_code(code: String) -> String:
	return EconomyRulesScript.reward_pool_for_battle(code, day)

func _event_by_id(event_id: String, layer: String = "") -> Dictionary:
	for item in Array(_economy_data().get("events", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var event := Dictionary(item)
		if String(event.get("id", "")) != event_id:
			continue
		if layer != "" and String(event.get("layer", "")) != layer:
			continue
		if not _is_formal(event):
			continue
		if not _day_expr_allows(String(event.get("day_expr", ""))):
			continue
		return event
	return {}

func _run_event_operations(event_id: String) -> Array:
	return Array(_core_composition.run_event_definition_registry.operations_for_event(event_id)).duplicate(true)


func _rest_event_operations(node_id: String) -> Array:
	return Array(_core_composition.run_event_definition_registry.operations_for_rest_node(node_id)).duplicate(true)


func _execute_run_event(
	event: Dictionary,
	context_kind: String,
	node_id: String,
	operations: Array,
	context_extra: Dictionary = {}
) -> Dictionary:
	var context := context_extra.duplicate(true)
	context["context_kind"] = context_kind
	context["node_id"] = node_id
	return Dictionary(_core_composition.run_event_effect_service.execute(
		RunEventPortScript.new(self),
		event.duplicate(true),
		context,
		operations.duplicate(true)
	))


func _run_event_cost(operations: Array, context_kind: String) -> int:
	var result := 0
	for operation_value in operations:
		var operation := Dictionary(operation_value)
		var contexts := Array(operation.get("contexts", []))
		if not contexts.is_empty() and not contexts.has(context_kind):
			continue
		if String(operation.get("operation", "")) == "spend_coins":
			result += int(Dictionary(operation.get("params", {})).get("amount", 0))
	return result


func _run_event_refill_result(result: Dictionary) -> Dictionary:
	for value in Array(result.get("operation_results", [])):
		var operation_result := Dictionary(value)
		if String(operation_result.get("operation", "")) == "refill_shop_pool":
			return operation_result
	return {}


func _log_committed_run_event_effects(event: Dictionary, result: Dictionary) -> void:
	for line in Array(result.get("logs", [])):
		_log(String(line))
	var prep_effect := Dictionary(result.get("battle_prep_effect", {}))
	if not prep_effect.is_empty():
		var effect_type := String(prep_effect.get("type", ""))
		var value := int(prep_effect.get("shield", 0)) if effect_type == "shield" else int(prep_effect.get("bonus_damage", 0))
		_log("战前效果入队：%s，%s。" % [
			String(event.get("name", "事件")),
			"下一场护盾+%d" % value if effect_type == "shield" else "下一次火陷阱伤害+%d" % value,
		])
	var run_effect := Dictionary(result.get("outer_run_effect", {}))
	if not run_effect.is_empty():
		_log("外层风险：%s，金币%d→%d，下一场战斗奖励按%d%%结算。" % [
			String(event.get("name", "事件")),
			int(result.get("coins_from", coins)),
			int(result.get("coins_to", coins)),
			int(run_effect.get("multiplier", 100)),
		])

func _apply_battle_prep_effects() -> Array:
	var applied: Array = []
	for index in range(battle_prep_effects.size()):
		var effect := Dictionary(battle_prep_effects[index]).duplicate(true)
		if String(effect.get("status", "")) != "pending" or int(effect.get("uses_remaining", 0)) <= 0:
			continue
		if String(effect.get("type", "")) == "shield":
			var shield: int = max(0, int(effect.get("shield", 0)))
			var targets: Array = []
			for unit_index in range(units.size()):
				var unit: Dictionary = Dictionary(units[unit_index]).duplicate(true)
				if String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
					continue
				var from_shield: int = int(unit.get("shield", 0))
				unit["shield"] = from_shield + shield
				units[unit_index] = unit
				targets.append({
					"unit_id": _pet_key(unit),
					"name": String(unit.get("name", _pet_key(unit))),
					"shield_from": from_shield,
					"shield_to": int(unit.get("shield", 0))
				})
			effect["status"] = "applied"
			effect["uses_remaining"] = 0
			effect["targets"] = targets
			_log("战前护盾：%s，使%d个我方单位护盾+%d。" % [String(effect.get("name", "护盾祝福")), targets.size(), shield])
		elif String(effect.get("type", "")) == "trap_damage_bonus":
			effect["status"] = "active"
			effect["applied_at"] = {"day": day, "period": battle_period, "round": battle_round}
			_log("陷阱增伤：%s 已激活，下一次火陷阱伤害+%d。" % [
				String(effect.get("name", "陷阱商人")),
				int(effect.get("bonus_damage", 0))
			])
		battle_prep_effects[index] = effect
		applied.append(effect.duplicate(true))
	return applied

func _apply_outer_run_effects_to_gold_delta(before_coins: int) -> Dictionary:
	var base_delta: int = max(0, coins - before_coins)
	var delta := base_delta
	var consumed: Array = []
	for index in range(outer_run_effects.size()):
		var effect := Dictionary(outer_run_effects[index]).duplicate(true)
		if String(effect.get("type", "")) != "reward_gold_multiplier":
			continue
		if int(effect.get("uses_remaining", 0)) <= 0:
			continue
		if not ["pending", "active"].has(String(effect.get("status", ""))):
			continue
		var from_delta := delta
		delta = EconomyRulesScript.apply_reward_gold_multiplier(delta, int(effect.get("multiplier", 100)))
		effect["status"] = "consumed"
		effect["uses_remaining"] = 0
		effect["gold_delta_from"] = from_delta
		effect["gold_delta_to"] = delta
		effect["consumed_at"] = {"day": day, "period": battle_period, "round": battle_round}
		outer_run_effects[index] = effect
		consumed.append(effect.duplicate(true))
		_log("奖励折损：%s 使战斗金币%d→%d。" % [String(effect.get("name", "风险事件")), from_delta, delta])
	coins = before_coins + delta
	return {
		"gold_base_delta": base_delta,
		"gold_delta": delta,
		"consumed": consumed
	}

func _post_battle_events_for_result(code: String, base_reward_pool_id: String, encounter_id: String) -> Dictionary:
	var reward_pool_id := base_reward_pool_id
	var events: Array = []
	for match_value in _core_composition.run_event_definition_registry.matching_post_battle_events(code):
		var match := Dictionary(match_value)
		var event_id := String(match.get("event_id", ""))
		var event := _event_by_id(event_id, "post_battle")
		if event.is_empty():
			continue
		var reward_pool_from := reward_pool_id
		var result := _execute_run_event(
			event,
			"post_battle",
			"",
			Array(match.get("operations", [])),
			{"encounter_id": encounter_id}
		)
		if not bool(result.get("ok", false)):
			continue
		var selected_pool := String(result.get("reward_pool_id", ""))
		if selected_pool != "":
			reward_pool_id = selected_pool
		events.append({
			"event_id": event_id,
			"name": String(event.get("name", event_id)),
			"condition": String(match.get("condition_label", "")),
			"encounter_id": encounter_id,
			"reward_pool_from": reward_pool_from,
			"reward_pool_to": reward_pool_id,
			"gain": String(event.get("gain", "")),
			"value": int(event.get("value", 0)),
		})
	return {
		"reward_pool_id": reward_pool_id,
		"events": events,
	}

func _reward_pool_with_available_options(pool_id: String, seed_context: String = "") -> String:
	if pool_id != "" and not _reward_options_for_pool(pool_id, 3, seed_context).is_empty():
		return pool_id
	var fallback := _tier_reward_pool_for_day()
	if fallback != pool_id and not _reward_options_for_pool(fallback, 3, seed_context).is_empty():
		return fallback
	return pool_id

func _battle_reward_seed_context(result: Dictionary) -> String:
	var step := int(result.get("node_index", node_index))
	var encounter_id := String(result.get("encounter_id", ""))
	var reward_id := "route_reward_%d_%d_%s" % [int(result.get("day", day)), step, encounter_id]
	return "route:%d:%d:%s" % [int(result.get("day", day)), step, reward_id]

func set_run_seed(seed: String) -> void:
	run_seed = seed.strip_edges()
	if run_seed == "":
		run_seed = "ysbzs-local"
	shop_roll_count = 0
	shop_context_roll_count = 0
	active_shop_seed_context = ""
	run_plan = _build_run_plan()
	route_options = _build_route_options()

func set_difficulty(value: String) -> void:
	difficulty = _normalize_difficulty(value)
	auto_position_action_plan = []
	auto_position_applied_result = {}

func set_board_dimensions(width: int, height: int) -> bool:
	if not BattleBoardDimensionsScript.is_valid(width, height):
		_log("棋盘尺寸不合法：%dx%d。" % [width, height])
		return false
	if phase == "battle" and not units.is_empty() and (width != board_width or height != board_height):
		_log("战斗进行中不能修改棋盘尺寸。")
		return false
	board_width = width
	board_height = height
	auto_position_action_plan = []
	auto_position_applied_result = {}
	if phase != "battle":
		run_plan = _build_run_plan()
		route_options = _build_route_options()
	return true

func _u32(value: int) -> int:
	return SeededSelectorScript.u32(value)

func _rng(seed: String) -> Dictionary:
	return SeededSelectorScript.rng(seed)

func _rng_next(random: Dictionary) -> float:
	return SeededSelectorScript.next(random)

func _weighted_pick(items: Array, weight_fn: Callable, random: Dictionary) -> Dictionary:
	return SeededSelectorScript.weighted_pick(items, weight_fn, random)

func _route_seed(schedule: Dictionary, kind: String) -> String:
	var pool_id := String(schedule.get("poolId", schedule.get("encounterPoolId", "pool")))
	return "route:%s:%s:%d:%d:%s" % [
		kind,
		run_seed,
		int(schedule.get("day", day)),
		int(schedule.get("step", node_index)),
		pool_id
	]

func _route_choice_seed_context(option: Dictionary) -> String:
	var schedule := Dictionary(option.get("schedule", {}))
	var option_id := String(option.get("nodeId", option.get("optionId", option.get("encounterId", "option"))))
	return "route:%d:%d:%s" % [
		int(schedule.get("day", day)),
		int(schedule.get("step", node_index)),
		option_id
	]

func _shop_roll_seed(pool_id: String) -> String:
	var source_stall_id := String(active_stall.get("source_stall_id", active_stall.get("stall_id", "")))
	var source_suffix := "" if source_stall_id == "" else ":%s" % source_stall_id
	if active_shop_seed_context != "":
		return "shop:v2:%s:%s:%d:%s%s" % [run_seed, active_shop_seed_context, shop_context_roll_count, pool_id, source_suffix]
	return "shop:v2:%s:%d:%s:%d:%s%s" % [run_seed, day, battle_period, shop_roll_count, pool_id, source_suffix]

func _reward_seed(pool_id: String, seed_context: String = "") -> String:
	if seed_context != "":
		return "reward:%s:%s:%s" % [run_seed, seed_context, pool_id]
	return "reward:%s:%d:%s:%s:%d" % [run_seed, day, battle_period, pool_id, battle_round]

func _advance_route_step() -> void:
	node_index += 1
	active_schedule = {}
	active_encounter = {}
	if run_plan.is_empty():
		run_plan = _build_run_plan()
	route_options = _build_route_options()
	if route_options.is_empty():
		_log("当前路线日程已完成。")

func _is_current_day_route_complete() -> bool:
	return _has_route_data() and route_options.is_empty() and _current_schedule().is_empty()

func _set_day_end() -> void:
	if not _transition_phase("day_end"):
		return
	active_schedule = {}
	active_encounter = {}
	selected_unit_id = ""
	selected_action_slot_index = 0
	_log("第%d天路线结束。" % day)

func _return_to_route_or_day_end() -> void:
	if _is_current_day_route_complete():
		_set_day_end()
	else:
		_transition_phase("route")

func start_next_day(target_day: int = 0) -> bool:
	var current_day := day
	var next_day := target_day if target_day > 0 else current_day + 1
	if phase != "day_end":
		_log("进入下一天失败：当天路线还没有结束。")
		return false
	if next_day <= current_day or not _has_schedule_for_day(next_day):
		_log("进入下一天失败：目标第%d天不可用。" % next_day)
		return false
	day = next_day
	node_index = 1
	battle_round = 1
	battle_period = "上午"
	ap = 3
	active_wave = {}
	active_schedule = {}
	active_encounter = {}
	active_stall = {}
	active_shop_pool = "night_base"
	active_shop_seed_context = ""
	shop_context_roll_count = 0
	reward_options = []
	battle_result = {}
	units = []
	cell_elements = {}
	board_traces = {}
	action_dirs = {}
	auto_position_action_plan = []
	auto_position_applied_result = {}
	action_ap_choices = {}
	selected_unit_id = ""
	selected_action_slot_index = 0
	if run_plan.is_empty():
		run_plan = _build_run_plan()
	route_options = _build_route_options()
	if not _transition_phase("route"):
		return false
	_log("进入第%d天。" % day)
	return true

func choose_route(option_id: String) -> bool:
	for option in route_options:
		var row := Dictionary(option)
		if String(row.get("id", "")) == option_id or String(row.get("optionId", "")) == option_id or String(row.get("nodeId", "")) == option_id or String(row.get("encounterId", "")) == option_id:
			var kind := String(row["kind"])
			var selected_schedule := Dictionary(row.get("schedule", {})).duplicate(true)
			if kind == "shop":
				var node := Dictionary(row.get("sourceNode", {}))
				active_shop_seed_context = _route_choice_seed_context(row)
				var requested_pool := String(node.get("shopPoolId", "night_base"))
				node["shopPoolId"] = _resolve_day1_shop_pool(requested_pool, active_shop_seed_context)
				active_stall = _stall_for_node(node)
				if not bool(active_stall.get("available", true)):
					_log("选择节点失败：%s 在第%d天没有开放摊位。" % [String(active_stall.get("location_name", active_shop_pool)), day])
					return false
				active_schedule = selected_schedule
				active_shop_pool = String(active_stall.get("pool_id", node.get("shopPoolId", "night_base")))
				shop_context_roll_count = 0
				shop_free_rolls = int(active_stall.get("free_rerolls", 0))
				shop_paid_refreshes = 0
				shop_offers = _shop_offers_for_pool(active_shop_pool, int(active_stall.get("slots", 10)))
				if not _transition_phase("shop"):
					return false
				_log("选择节点：%s，进入%s，浏览 %d 件商品。" % [String(row.get("title", "商店")), String(active_stall.get("name", active_shop_pool)), shop_offers.size()])
				_advance_route_step()
			elif kind == "battle":
				active_schedule = selected_schedule
				active_encounter = Dictionary(row.get("encounter", {})).duplicate(true)
				battle_period = String(active_encounter.get("wavePeriod", row.get("wavePeriod", battle_period)))
				start_battle()
			elif kind == "reward":
				var reward_node := Dictionary(row.get("sourceNode", {}))
				var pool_id := String(reward_node.get("rewardPoolId", "reward_pT1"))
				active_schedule = selected_schedule
				reward_options = _reward_options_for_pool(pool_id, int(reward_node.get("slots", 3)), _route_choice_seed_context(row))
				if not _transition_phase("reward"):
					return false
				_log("选择节点：%s，从 %d 个奖励中选择 1 个。" % [String(row.get("title", "奖励")), reward_options.size()])
				_advance_route_step()
			elif kind == "event":
				if not _apply_route_event(Dictionary(row.get("sourceNode", {}))):
					return false
			elif kind == "rest":
				if not _apply_rest_route_node(Dictionary(row.get("sourceNode", {}))):
					return false
			return true
	return false

func _apply_rest_route_node(node: Dictionary) -> bool:
	var node_id := String(node.get("nodeId", ""))
	if node_id == "":
		return false
	var operations := _rest_event_operations(node_id)
	if operations.is_empty():
		return false
	var event := node.duplicate(true)
	event["id"] = node_id
	var result := _execute_run_event(event, "rest", node_id, operations)
	if not bool(result.get("ok", false)):
		return false
	_log("整备完成：英雄生命 +4，金币 +2。")
	_advance_route_step()
	_return_to_route_or_day_end()
	return true


func _apply_route_event(node: Dictionary) -> bool:
	var event_id := String(node.get("eventId", ""))
	var event := _event_by_id(event_id)
	if event.is_empty():
		return false
	var operations := _run_event_operations(event_id)
	if operations.is_empty():
		return false
	var before := coins
	var node_id := String(node.get("nodeId", ""))
	var result := _execute_run_event(event, "route_event", node_id, operations)
	if not bool(result.get("ok", false)):
		if String(result.get("code", "")) == "insufficient_coins":
			var cost := _run_event_cost(operations, "route_event")
			_log("金币不足，无法选择路线事件【%s】：需要%d金币，当前%d。" % [
				String(event.get("name", event_id)),
				cost,
				before,
			])
		return false
	_log_committed_run_event_effects(event, result)
	if Dictionary(result.get("battle_prep_effect", {})).is_empty() \
			and Dictionary(result.get("outer_run_effect", {})).is_empty() \
			and String(event.get("layer", "")) == "event":
		_log("节点事件【%s】：当前 Godot 单机版保留为构筑事件占位。" % String(event.get("name", event_id)))
	_log("节点事件【%s】：金币%d→%d。" % [
		String(event.get("name", node.get("name", event_id if event_id != "" else "事件"))),
		before,
		int(result.get("coins_to", coins)),
	])
	_advance_route_step()
	_return_to_route_or_day_end()
	return true

func apply_route_event(event_id: String) -> bool:
	if phase != "route":
		_log("路线事件只能在路线阶段使用。")
		return false
	if event_id == "":
		_log("路线事件缺少事件ID。")
		return false
	var event := _event_by_id(event_id)
	if event.is_empty():
		_log("路线事件不存在或当前天数不可用：%s。" % event_id)
		return false
	return _apply_route_event({
		"eventId": event_id,
		"nodeId": "manual_%s" % event_id,
		"name": String(event.get("name", event_id))
	})

func pick_reward(action: Dictionary) -> bool:
	if reward_options.is_empty():
		_log("当前没有可领取的奖励。")
		return false
	var ref := String(action.get("rewardId", action.get("reward_id", action.get("id", ""))))
	var index := int(action.get("index", 0))
	var picked: Dictionary = {}
	if ref != "":
			for option in reward_options:
				var row := Dictionary(option)
				if String(row.get("id", "")) == ref or String(row.get("pet_id", "")) == ref:
					picked = row
					break
	elif index >= 0 and index < reward_options.size():
		picked = Dictionary(reward_options[index])
	if picked.is_empty():
		_log("奖励选择失败：候选不存在。")
		return false
	var result := _add_pet_to_roster(Dictionary(picked.get("source", picked)).duplicate(true), "reward")
	if bool(result.get("merged", false)) and String(result.get("quality_to", "")) != "":
		_log("选择奖励：%s 同名合成到%s。" % [String(result.get("name", "宠物")), String(result.get("quality", "青铜"))])
	else:
		_log("选择奖励：%s %s。" % [
			String(result.get("name", picked.get("name", "宠物"))),
			"加入上阵队伍" if bool(result.get("active", true)) else "加入背包"
		])
	reward_options = []
	_return_to_route_or_day_end()
	return true

func back_to_route() -> void:
	selected_unit_id = ""
	_return_to_route_or_day_end()
	_log("返回时间节点 %d。" % node_index)

func _start_route_battle_from_action(action: Dictionary) -> bool:
	var ref := _route_option_id(action)
	if ref == "":
		ref = String(action.get("encounterId", action.get("encounter_id", "")))
	if ref != "" and choose_route(ref):
		return true
	for option in route_options:
		var row := Dictionary(option)
		if String(row.get("kind", "")) == "battle":
			return choose_route(String(row.get("id", "")))
	start_battle()
	return true

func roll_shop() -> bool:
	var cost := 0
	var used_free_roll := false
	if shop_free_rolls > 0:
		shop_free_rolls -= 1
		used_free_roll = true
	else:
		cost = _paid_refresh_cost()
	if cost > 0 and coins < cost:
		_log("金币不足，无法刷新：需要%d金币，当前%d。" % [cost, coins])
		return false
	if cost > 0:
		coins -= cost
		shop_paid_refreshes += 1
	shop_offers = _shop_offers_for_pool(active_shop_pool, int(active_stall.get("slots", 10)), _frozen_shop_offers())
	_log("刷新商店：花费%d金币%s，%s 生成 %d 个候选。" % [
		cost,
		"（免费刷新）" if used_free_roll else "",
		active_shop_pool,
		shop_offers.size()
	])
	return true

func _upgrade_roster_pet_for_event(event: Dictionary) -> Dictionary:
	for index in range(roster.size()):
		var pet: Dictionary = Dictionary(roster[index]).duplicate(true)
		var quality_from := QualityRulesScript.normalize(String(pet.get("quality", "青铜")))
		var quality_to := QualityRulesScript.next(quality_from)
		if quality_to == "":
			continue
		pet["quality"] = quality_to
		var progression_result := _progressed_unit(pet, true)
		if not bool(progression_result.get("ok", false)):
			push_error("Quality progression failed while upgrading %s: %s" % [_pet_key(pet), str(progression_result.get("errors", []))])
			return {}
		pet = Dictionary(progression_result.get("unit", {}))
		roster[index] = pet
		return {
			"event_id": String(event.get("id", "")),
			"type": "upgrade_pet",
			"pet_id": _pet_key(pet),
			"name": String(pet.get("name", _pet_key(pet))),
			"quality_from": quality_from,
			"quality_to": quality_to
		}
	return {}

func _duplicate_roster_pet_for_event(event: Dictionary) -> Dictionary:
	if roster.is_empty():
		return {}
	var target := Dictionary(roster[0]).duplicate(true)
	var result := _add_pet_to_roster(target, "shop_event")
	return {
		"event_id": String(event.get("id", "")),
		"type": "duplicate_pet",
		"pet_id": String(result.get("pet_id", _pet_key(target))),
		"name": String(result.get("name", target.get("name", _pet_key(target)))),
		"quality": String(result.get("quality", "")),
		"merged": bool(result.get("merged", false))
	}

func apply_shop_event(event_id: String) -> bool:
	if phase != "shop":
		_log("商店事件只能在商店阶段使用。")
		return false
	var event := _shop_event_by_id(event_id)
	if event.is_empty():
		_log("商店事件不存在：%s。" % event_id)
		return false
	var operations := _run_event_operations(event_id)
	if operations.is_empty():
		return false
	var before := coins
	var result := _execute_run_event(event, "shop_event", "", operations)
	if not bool(result.get("ok", false)):
		if String(result.get("code", "")) == "insufficient_coins":
			_log("金币不足，无法选择事件 %s。" % String(event.get("name", event_id)))
		return false
	for line in Array(result.get("logs", [])):
		_log(String(line))
	var refill_result := _run_event_refill_result(result)
	if not refill_result.is_empty():
		var stall := Dictionary(refill_result.get("active_stall_to", {}))
		_log("定向补货：%s -> %s，槽位%d。" % [
			String(event.get("name", event_id)),
			String(refill_result.get("active_shop_pool_to", "")),
			int(stall.get("slots", 0)),
		])
	var effect := Dictionary(result.get("shop_effect", {}))
	var construction := Dictionary(effect.get("construction", {}))
	var construction_text := ""
	if not construction.is_empty():
		if String(construction.get("type", "")) == "upgrade_pet":
			construction_text = "，%s %s→%s" % [
				String(construction.get("name", "宠物")),
				String(construction.get("quality_from", "")),
				String(construction.get("quality_to", ""))
			]
		elif String(construction.get("type", "")) == "duplicate_pet":
			construction_text = "，复制 %s%s" % [
				String(construction.get("name", "宠物")),
				"，同名合成到%s" % String(construction.get("quality", "")) if bool(construction.get("merged", false)) else ""
			]
	_log("选择商店事件【%s】：%s，金币%d→%d%s。" % [
		String(event.get("name", event_id)),
		String(event.get("option_text", event.get("gain", "已结算"))),
		before,
		int(result.get("coins_to", coins)),
		construction_text
	])
	return true

func drop_item_on_target(action: Dictionary) -> bool:
	var target_type := _normalize_drop_type(action.get("target_type", action.get("targetType", action.get("target", ""))))
	var target_index := int(action.get("target_index", action.get("targetIndex", -1)))
	var offer_id := _offer_id(action)
	var unit_ref := String(action.get("unitId", action.get("unit_id", action.get("petId", action.get("pet_id", "")))))
	if (offer_id == "") == (unit_ref == ""):
		_log("拖拽失败：必须且只能提供 offer_id 或 unitId。")
		return false
	if offer_id != "":
		if target_type != "party" and target_type != "bag":
			_log("拖拽购买取消：商店候选只能落到队伍或背包。")
			return false
		return buy_offer(offer_id, target_type, target_index)
	var roster_index := _roster_index_for_ref(unit_ref)
	if roster_index < 0:
		_log("拖拽失败：找不到单位 %s。" % unit_ref)
		return false
	var source_type := "party" if bool(Dictionary(roster[roster_index]).get("active", false)) else "bag"
	if target_type == "sell":
		return sell_unit(unit_ref)
	if target_type == "party" or target_type == "bag":
		return set_roster_drop_target(unit_ref, target_type, target_index)
	_log("拖拽取消：%s 不能落到 %s。" % [source_type, target_type])
	return false

func set_roster_drop_target(ref: String, target_kind: String, target_index: int = -1) -> bool:
	var index := _roster_index_for_ref(ref)
	if index < 0:
		_log("拖拽失败：找不到单位 %s。" % ref)
		return false
	var normalized_target := _normalize_drop_type(target_kind)
	if normalized_target == "bag":
		return _move_roster_index_to_bag_slot(index, target_index)
	if normalized_target == "party":
		return _move_roster_index_to_active_slot(index, target_index)
	return false

func _move_roster_index_to_active_slot(index: int, target_index: int) -> bool:
	_normalize_roster_slots()
	var pet: Dictionary = Dictionary(roster[index]).duplicate(true)
	var was_active := bool(pet.get("active", false))
	var source_slot := int(pet.get("slot", 0))
	var source_bag_slot := int(pet.get("bag_slot", 0))
	var target_slot := _requested_active_slot(target_index)
	var occupant_index := _roster_index_for_active_slot(target_slot, index)
	if occupant_index >= 0:
		var occupant: Dictionary = Dictionary(roster[occupant_index]).duplicate(true)
		if was_active:
			occupant["active"] = true
			occupant["slot"] = source_slot
			occupant["bag_slot"] = 0
		else:
			occupant["active"] = false
			occupant["slot"] = 0
			occupant["bag_slot"] = source_bag_slot if source_bag_slot > 0 else _next_bag_slot_excluding(occupant_index)
		roster[occupant_index] = occupant
	elif not was_active and _active_roster_count(index) >= MAX_ACTIVE_UNITS:
		_log("上阵失败：上场位已满 %d/%d。" % [MAX_ACTIVE_UNITS, MAX_ACTIVE_UNITS])
		return false
	pet["active"] = true
	pet["slot"] = target_slot
	pet["bag_slot"] = 0
	roster[index] = pet
	_normalize_roster_slots()
	_log("拖拽上阵：%s 到队伍槽%d。" % [String(pet.get("name", pet.get("pet_id", ""))), int(pet.get("slot", target_slot))])
	return true

func _move_roster_index_to_bag_slot(index: int, target_index: int) -> bool:
	_normalize_roster_slots()
	var pet: Dictionary = Dictionary(roster[index]).duplicate(true)
	var was_active := bool(pet.get("active", false))
	var source_slot := int(pet.get("slot", 0))
	var source_bag_slot := int(pet.get("bag_slot", 0))
	var target_slot := _requested_bag_slot(target_index)
	var occupant_index := _roster_index_for_bag_slot(target_slot, index)
	if occupant_index >= 0:
		var occupant: Dictionary = Dictionary(roster[occupant_index]).duplicate(true)
		if was_active:
			occupant["active"] = true
			occupant["slot"] = source_slot
			occupant["bag_slot"] = 0
		else:
			occupant["active"] = false
			occupant["slot"] = 0
			occupant["bag_slot"] = source_bag_slot if source_bag_slot > 0 else _next_bag_slot_excluding(occupant_index)
		roster[occupant_index] = occupant
	elif was_active and _bench_roster_count(index) >= MAX_BENCH_UNITS:
		_log("下阵失败：背包已满 %d/%d。" % [MAX_BENCH_UNITS, MAX_BENCH_UNITS])
		return false
	pet["active"] = false
	pet["slot"] = 0
	pet["bag_slot"] = target_slot
	roster[index] = pet
	_normalize_roster_slots()
	_log("拖拽下阵：%s 到背包槽%d。" % [String(pet.get("name", pet.get("pet_id", ""))), int(pet.get("bag_slot", target_slot))])
	return true

func _apply_non_pet_shop_item(offer: Dictionary) -> Dictionary:
	var effect := Dictionary(offer.get("effect", {}))
	var effect_type := String(effect.get("type", ""))
	var handler: RefCounted = _shop_effect_registry.handler_for(effect_type)
	return Dictionary(handler.call("execute", ShopEffectPortScript.new(self), offer, effect)) if handler != null else {}

func buy_offer(offer_id: String, target_kind: String = "", target_index: int = -1) -> bool:
	for offer in shop_offers:
		if String(offer.get("id", "")) == offer_id or String(offer.get("offer_id", "")) == offer_id or String(offer.get("offerId", "")) == offer_id:
			if bool(offer["sold"]):
				_log("%s 已售罄。" % offer["name"])
				return false
			if coins < int(offer["price"]):
				_log("金币不足，无法购买 %s。" % offer["name"])
				return false
			var item_type := String(offer.get("item_type", "宠物" if String(offer.get("pet_id", "")) != "" else ""))
			if item_type != "宠物":
				var applied := _apply_non_pet_shop_item(Dictionary(offer).duplicate(true))
				if applied.is_empty():
					_log("购买失败：%s 当前没有可应用目标。" % String(offer["name"]))
					return false
				coins -= int(offer["price"])
				offer["sold"] = true
				_log("购买%s【%s】：%s。" % [item_type, String(offer["name"]), String(applied.get("text", "已生效"))])
				return true
			coins -= int(offer["price"])
			offer["sold"] = true
			var result := _add_pet_to_roster(Dictionary(offer).duplicate(true), "shop", target_kind, target_index)
			if bool(result.get("merged", false)) and String(result.get("quality_to", "")) != "":
				_log("购买 %s，背包同名合成到%s。" % [String(offer["name"]), String(result.get("quality", "青铜"))])
			else:
				_log("购买 %s，%s。" % [String(offer["name"]), "加入上阵队伍" if bool(result.get("active", true)) else "加入背包"])
			return true
	return false

func set_offer_frozen(offer_id: String, frozen: bool) -> bool:
	for offer in shop_offers:
		if String(offer.get("id", "")) == offer_id or String(offer.get("offerId", "")) == offer_id:
			offer["frozen"] = frozen
			_log("%s %s。" % [String(offer.get("name", offer_id)), "已锁定" if frozen else "取消锁定"])
			return true
	return false

func developer_object_catalog() -> Dictionary:
	return Dictionary(_developer_scenario_registry.catalog(
		_core_composition.content_object_registry,
		Dictionary(game_data.get("_content_manifest", {}))
	)).duplicate(true)


func debug_pet_catalog() -> Dictionary:
	var catalog := developer_object_catalog()
	return {
		"schema": "ysbzs.debug-pet-catalog.v1",
		"teamSize": int(catalog.get("teamSize", 4)),
		"pets": Array(catalog.get("pets", [])).duplicate(true),
		"defaults": Dictionary(catalog.get("defaults", {})).duplicate(true),
	}


func start_developer_scenario(action: Dictionary) -> bool:
	var intent := Dictionary(_developer_scenario_registry.normalize_intent(action))
	var definition := Dictionary(_developer_scenario_registry.definition(String(intent.get("scenarioId", ""))))
	if definition.is_empty():
		_log("SCENARIO_ID_UNKNOWN：未知 Developer Scenario。")
		return false
	var setup := Dictionary(_developer_scenario_assembler.prepare(
		_core_composition.content_object_registry,
		definition,
		intent,
		Dictionary(game_data.get("_content_manifest", {}))
	))
	if not bool(setup.get("ok", false)):
		var setup_error := Dictionary(setup.get("error", {}))
		_log("%s：%s" % [
			String(setup_error.get("code", "SCENARIO_SETUP_REJECTED")),
			String(setup_error.get("message", "Developer Scenario 配置无效。")),
		])
		return false

	reset()
	var board := Dictionary(setup.get("board", {}))
	if not set_board_dimensions(int(board.get("width", DEFAULT_BOARD_WIDTH)), int(board.get("height", DEFAULT_BOARD_HEIGHT))):
		return false
	var battle := Dictionary(setup.get("battle", {}))
	day = max(1, int(battle.get("day", 1)))
	battle_period = String(battle.get("period", "上午"))
	set_run_seed(String(setup.get("seed", "")))
	roster = _clone_units(Array(setup.get("playerTemplates", [])), PLAYER)
	_normalize_roster_slots()
	if roster.size() != int(definition.get("teamSize", BATTLE_TEAM_SIZE)):
		_log("SCENARIO_PLAYER_TEMPLATE_RESOLUTION_FAILED：我方对象未能完整进入权威阵容。")
		return false
	active_encounter = Dictionary(battle.get("encounter", {})).duplicate(true)
	scenario_provenance = Dictionary(setup.get("provenance", {})).duplicate(true)
	if not _start_battle_with_enemy_templates(
		Array(setup.get("enemyTemplates", [])).duplicate(true),
		String(active_encounter.get("name", "Developer Scenario"))
	):
		return false
	last_command_result = {
		"schema": String(setup.get("schema", "ysbzs.developer-scenario-setup.v1")),
		"scenarioId": String(setup.get("scenarioId", "")),
		"scenarioVersion": String(setup.get("scenarioVersion", "")),
		"seed": String(setup.get("seed", "")),
		"playerRefs": Array(setup.get("playerRefs", [])).duplicate(true),
		"enemyRefs": Array(setup.get("enemyRefs", [])).duplicate(true),
		"playerPetIds": Array(setup.get("playerPetIds", [])).duplicate(),
		"enemyPetIds": Array(setup.get("enemyPetIds", [])).duplicate(),
		"provenance": scenario_provenance.duplicate(true),
	}
	return true


func start_debug_first_battle(action: Dictionary) -> bool:
	if typeof(action.get("seed")) != TYPE_STRING \
			or typeof(action.get("playerPetIds")) != TYPE_ARRAY \
			or typeof(action.get("enemyPetIds")) != TYPE_ARRAY:
		_log("DEBUG_BATTLE_INTENT_TYPE_INVALID：seed 必须为文本，双方宠物 ID 必须为数组。")
		return false
	var compatibility_action := action.duplicate(true)
	compatibility_action["scenarioId"] = DeveloperScenarioRegistryScript.FIRST_BATTLE_ID
	if not start_developer_scenario(compatibility_action):
		return false
	last_command_result["schema"] = "ysbzs.debug-first-battle-setup.v1"
	return true


func start_battle() -> void:
	_start_battle_with_enemy_templates(_enemy_battle_roster_templates())


func _start_battle_with_enemy_templates(enemy_templates: Array, encounter_name_override: String = "") -> bool:
	if not _transition_phase("battle"):
		return false
	ap = 3
	battle_round = 1
	battle_round_start_checkpoints = []
	enemy_hero_hp = enemy_hero_max_hp
	if battle_period == "":
		battle_period = "上午"
	selected_unit_id = ""
	selected_action_slot_index = 0
	active_wave = {}
	battle_result = {}
	units = []
	defeated_units = []
	battle_trace = []
	cell_elements = {}
	board_traces = {}
	action_dirs = {}
	auto_position_action_plan = []
	auto_position_applied_result = {}
	player_elements_settled_this_round = false
	var reset_state: Dictionary = _core_composition.pet_reset_policy.initial_state(
		Dictionary(Dictionary(game_data.get("battle", {})).get("rules", {})),
		PLAYER,
		ENEMY,
		DEFAULT_PET_RESET_CHARGE_INTERVAL,
		DEFAULT_PET_RESET_INITIAL_CHARGES
	)
	pet_reset_counts = Dictionary(reset_state.get("counts", {}))
	pet_reset_charges = Dictionary(reset_state.get("charges", {}))
	pet_reset_next_charge_round = Dictionary(reset_state.get("next_charge_round", {}))
	pet_reset_eligible = Dictionary(reset_state.get("eligible", {}))
	var placement := _battle_deploy_cells()
	var active_roster: Array = []
	for roster_value in _active_roster_for_battle():
		var progression_result := _progressed_unit(Dictionary(roster_value), true)
		if not bool(progression_result.get("ok", false)):
			push_error("Quality progression failed while preparing battle roster: %s" % str(progression_result.get("errors", [])))
			continue
		active_roster.append(Dictionary(progression_result.get("unit", {})))
	battle_roster_templates = {
		PLAYER: active_roster.slice(0, mini(active_roster.size(), BATTLE_TEAM_SIZE)).duplicate(true),
		ENEMY: enemy_templates.slice(0, mini(enemy_templates.size(), BATTLE_TEAM_SIZE)).duplicate(true)
	}
	_initialize_skill_control_orders()
	for entry_value in _core_composition.battle_startup_service.prepare_player_deployment(
		active_roster,
		placement,
		BATTLE_TEAM_SIZE,
		{
			"player_side": PLAYER,
			"deploy_cell": Callable(self, "_battle_deploy_cell"),
			"cell_key": Callable(self, "_cell_key"),
			"battle_start_mechanics": Callable(self, "_apply_mechanic_battle_start"),
		}
	):
		var entry := Dictionary(entry_value)
		for line in Array(entry.get("logs", [])):
			_log(String(line))
		units.append(Dictionary(entry.get("unit", {})))
	_spawn_team_from_templates(ENEMY, false)
	ap = _player_round_action_budget()
	_apply_mechanic_round_start(PLAYER)
	_apply_quality_round_start(PLAYER)
	var applied_prep := _apply_battle_prep_effects()
	_start_relic_combat()
	_record_battle_round_start_checkpoint()
	var encounter_name := encounter_name_override if encounter_name_override != "" else String(active_encounter.get("name", "路线战斗"))
	_log("进入双人对战：%s，我方%d只、敌方%d只宠物，第12回合结束按英雄生命结算。战前效果%d个。" % [
		encounter_name,
		_living_unit_count(PLAYER),
		_living_unit_count(ENEMY),
		applied_prep.size()
	])
	GameLogScript.info("战斗/开场", "正式战斗初始化完成", {
		"遭遇": encounter_name,
		"棋盘": "%dx%d" % [board_width, board_height],
		"我方宠物": _living_unit_count(PLAYER),
		"敌方宠物": _living_unit_count(ENEMY),
		"我方英雄生命": hero_hp,
		"敌方英雄生命": enemy_hero_hp,
		"重置间隔": _pet_reset_charge_interval(),
		"战前效果": applied_prep.size()
	})
	return true

func _enemy_battle_roster_templates() -> Array:
	var battle := Dictionary(game_data.get("battle", {}))
	return _core_composition.battle_startup_service.select_enemy_templates(
		battle,
		day,
		battle_period,
		BATTLE_TEAM_SIZE
	)

func _side_reset_cells(side: String, reset_number: int) -> Array:
	var required_count := mini(Array(battle_roster_templates.get(side, [])).size(), BATTLE_TEAM_SIZE)
	var occupied_cells := {}
	var trapped_cells := {}
	for y in range(board_height):
		for x in range(board_width):
			var key := _cell_key(x, y)
			# Leaders are projected separately from `units`, but they still occupy a
			# real board cell. Include both live leaders in the authoritative
			# occupancy map before random reset placement is selected.
			if not unit_at(x, y).is_empty() or not _leader_at(x, y).is_empty():
				occupied_cells[key] = true
			if _cell_has_element_trap(x, y):
				trapped_cells[key] = true
	return _core_composition.pet_reset_policy.select_cells(
		board_dimensions(),
		side == PLAYER,
		required_count,
		occupied_cells,
		trapped_cells,
		"pet_reset:%s:%s:%d:%d:%s:%d" % [run_seed, side, day, battle_round, battle_period, reset_number]
	)

func _spawn_team_from_templates(side: String, is_reset: bool, show_next_round_banner: bool = false) -> Array:
	var templates := Array(battle_roster_templates.get(side, []))
	var reset_number := int(pet_reset_counts.get(side, 0))
	var cells := _side_reset_cells(side, reset_number)
	var spawned: Array = []
	for index in range(mini(mini(templates.size(), cells.size()), BATTLE_TEAM_SIZE)):
		var pet := Dictionary(templates[index]).duplicate(true)
		var progression_result := _progressed_unit(pet, true)
		if not bool(progression_result.get("ok", false)):
			push_error("Quality progression failed while spawning %s: %s" % [_pet_key(pet), str(progression_result.get("errors", []))])
			continue
		pet = Dictionary(progression_result.get("unit", {}))
		var cell := Vector2i(cells[index])
		pet["x"] = cell.x
		pet["y"] = cell.y
		pet["side"] = side
		pet["hp"] = max(1, int(pet.get("max_hp", pet.get("maxHp", pet.get("hp", 1)))))
		pet["shield"] = max(0, int(Dictionary(templates[index]).get("shield", 0)))
		pet["action_slots_used"] = {}
		pet["action_ap_spent"] = 0
		pet["has_attacked"] = false
		pet.erase("incoming_damage_bonus")
		pet.erase("roundDamageTaken")
		pet.erase("round_damage_taken")
		for line in _apply_mechanic_battle_start(pet):
			_log(String(line))
		units.append(pet)
		spawned.append(pet.duplicate(true))
	if is_reset:
		_record_pets_reset_trace(side, spawned, show_next_round_banner)
	return spawned

func _reset_side_pets(side: String, between_rounds: bool = false) -> Array:
	var alive_before := _living_unit_count(side)
	var charges_before := int(pet_reset_charges.get(side, 0))
	var kept: Array = []
	for unit_value in units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == side:
			defeated_units.append(unit.duplicate(true))
		else:
			kept.append(unit)
	units = kept
	pet_reset_charges[side] = maxi(0, int(pet_reset_charges.get(side, 0)) - 1)
	pet_reset_counts[side] = int(pet_reset_counts.get(side, 0)) + 1
	pet_reset_eligible[side] = false
	var spawned := _spawn_team_from_templates(side, true, between_rounds)
	_log("%s宠物重置：在英雄安全区生成%d只；第%d次重置，剩余次数%d，下次第%d回合增加次数。" % [
		"我方" if side == PLAYER else "敌方",
		spawned.size(),
		int(pet_reset_counts[side]),
		int(pet_reset_charges.get(side, 0)),
		int(pet_reset_next_charge_round.get(side, _pet_reset_charge_interval()))
	])
	GameLogScript.info("战斗/宠物重置", "宠物队伍已重置", {
		"阵营": "我方" if side == PLAYER else "敌方",
		"回合": battle_round,
		"重置前存活": alive_before,
		"生成数量": spawned.size(),
		"重置序号": int(pet_reset_counts.get(side, 0)),
		"次数": "%d → %d" % [charges_before, int(pet_reset_charges.get(side, 0))],
		"轮间重置": between_rounds
	})
	return spawned

func _grant_pet_reset_charges_for_round(round_number: int) -> void:
	var interval := _pet_reset_charge_interval()
	for grant_value in _core_composition.pet_reset_policy.grant_for_round(
		[PLAYER, ENEMY],
		round_number,
		interval,
		pet_reset_charges,
		pet_reset_next_charge_round
	):
		var grant := Dictionary(grant_value)
		var side := String(grant.get("side", ""))
		GameLogScript.info("战斗/宠物重置", "获得一次宠物重置次数", {
			"阵营": "我方" if side == PLAYER else "敌方",
			"进入回合": int(grant.get("round", round_number)),
			"当前次数": int(grant.get("charges", 0)),
			"间隔": int(grant.get("interval", interval))
		})

func _reset_eligible_sides_after_round() -> void:
	for side in [PLAYER, ENEMY]:
		var alive_count := _living_unit_count(side)
		var threshold := _pet_reset_alive_threshold(side)
		if _core_composition.pet_reset_policy.is_eligible(
			alive_count,
			int(pet_reset_counts.get(side, 0)),
			int(pet_reset_charges.get(side, 0)),
			PET_RESET_THRESHOLD
		):
			pet_reset_eligible[side] = true
			GameLogScript.info("战斗/宠物重置", "完整回合检查后满足重置条件", {
				"阵营": "我方" if side == PLAYER else "敌方",
				"回合": battle_round,
				"存活": alive_count,
				"门槛": threshold,
				"可用次数": int(pet_reset_charges.get(side, 0))
			})
	if bool(pet_reset_eligible.get(ENEMY, false)):
		_reset_side_pets(ENEMY, true)
	if bool(pet_reset_eligible.get(PLAYER, false)):
		_log("我方宠物已满足第%d次重置条件（存活≤%d），请在本回合行动前点击“重置宠物”。" % [
			int(pet_reset_counts.get(PLAYER, 0)) + 1,
			_pet_reset_alive_threshold(PLAYER)
		])

func reset_player_pets() -> bool:
	if phase != "battle" or not bool(pet_reset_eligible.get(PLAYER, false)):
		_log("当前不能重置我方宠物：需要完整回合结束检查、存活宠物≤%d且至少有1次重置次数。" % _pet_reset_alive_threshold(PLAYER))
		GameLogScript.warning("战斗/宠物重置", "玩家重置请求被拒绝", {
			"阶段": phase,
			"回合": battle_round,
			"存活": _living_unit_count(PLAYER),
			"门槛": _pet_reset_alive_threshold(PLAYER),
			"次数": int(pet_reset_charges.get(PLAYER, 0)),
			"条件已满足": bool(pet_reset_eligible.get(PLAYER, false))
		})
		return false
	for unit_value in units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == PLAYER and (_has_used_action_slot(unit) or bool(unit.get("has_attacked", false))):
			_log("本回合已有我方宠物行动，不能再重置宠物。")
			GameLogScript.warning("战斗/宠物重置", "已有宠物行动，拒绝回合中重置", {"回合": battle_round, "宠物": String(unit.get("name", unit.get("id", "")))})
			return false
	var spawned := _reset_side_pets(PLAYER)
	ap = _player_round_action_budget()
	_reset_action_slots(PLAYER)
	_apply_mechanic_round_start(PLAYER)
	_apply_quality_round_start(PLAYER)
	selected_unit_id = ""
	selected_action_slot_index = 0
	last_command_result = {
		"ok": not spawned.is_empty(),
		"side": PLAYER,
		"spawned": spawned.duplicate(true),
		"resetCount": int(pet_reset_counts.get(PLAYER, 0)),
		"chargesRemaining": int(pet_reset_charges.get(PLAYER, 0))
	}
	return not spawned.is_empty()

func _record_pets_reset_trace(side: String, spawned_units: Array, show_next_round_banner: bool) -> void:
	if spawned_units.is_empty():
		return
	var unit_refs: Array = []
	for unit_value in spawned_units:
		unit_refs.append(_battle_trace_unit_ref(Dictionary(unit_value)))
	var event_id := "bt_%06d" % (battle_trace.size() + 1)
	var event := {
		"eventId": event_id,
		"kind": "pet_reset",
		"type": "PETS_RESET",
		"step": battle_trace.size() + 1,
		"round": battle_round,
		"phase": phase,
		"actor": {"id": "%s_hero" % side, "side": side},
		"target": Dictionary(unit_refs[0]),
		"payload": {
			"side": side,
			"units": unit_refs.duplicate(true),
			"unitCount": unit_refs.size(),
			"resetCount": int(pet_reset_counts.get(side, 0)),
			"chargesRemaining": int(pet_reset_charges.get(side, 0)),
			"nextAliveThreshold": _pet_reset_alive_threshold(side),
			"nextChargeRound": int(pet_reset_next_charge_round.get(side, _pet_reset_charge_interval())),
			"nextRound": battle_round + 1,
			"showNextRoundBanner": show_next_round_banner
		},
		"changes": [],
		"source": {"system": "ysbzs_state.gd", "function": "_reset_side_pets"},
		"reason": "pet_count_at_or_below_reset_threshold",
		"tags": ["battle", "pet_reset", "animation"],
		"text": "%s宠物重置，在英雄安全区生成%d只。" % ["我方" if side == PLAYER else "敌方", unit_refs.size()]
	}
	event["protocol"] = "|PETS_RESET|id=%s|round=%d|side=%s|units=%d|count=%d|charges=%d" % [
		event_id, battle_round, side, unit_refs.size(), int(pet_reset_counts.get(side, 0)), int(pet_reset_charges.get(side, 0))
	]
	battle_trace.append(event)

func _finish_battle_result(win: bool, reason: String = "", draw: bool = false) -> void:
	var before_coins := coins
	var before_hp := hero_hp
	var enemy_hp_at_end := enemy_hero_hp
	var before_castle_line := castle_line
	var before_economy_multiplier := economy_multiplier
	var base_outcome: Dictionary = _core_composition.battle_outcome_policy.base_result(win, draw, reason, battle_round)
	var gold_reward := int(base_outcome.get("gold", 0))
	var code := String(base_outcome.get("code", "LOSE"))
	var grade := String(base_outcome.get("grade", "D"))
	var game_over := bool(base_outcome.get("game_over", false)) and hero_hp <= 0
	if bool(base_outcome.get("reduce_defense", false)):
		castle_line = max(0, castle_line - 1)
		economy_multiplier *= 0.9
	var battle_end_mechanic_result := _apply_mechanic_battle_end(win, gold_reward)
	gold_reward = int(battle_end_mechanic_result.get("gold", gold_reward))
	coins = before_coins + gold_reward
	var encounter_id := String(active_encounter.get("encounterId", active_encounter.get("id", "")))
	var reward_id := "route_reward_%d_%d_%s" % [day, node_index, encounter_id]
	var reward_seed_context := "route:%d:%d:%s" % [day, node_index, reward_id]
	var base_reward_pool_id := _base_reward_pool_for_battle_code(code)
	var post_battle := _post_battle_events_for_result(code, base_reward_pool_id, encounter_id)
	var run_effect_result := _apply_outer_run_effects_to_gold_delta(before_coins)
	var gold_base_delta: int = int(run_effect_result.get("gold_base_delta", gold_reward))
	var gold_delta: int = int(run_effect_result.get("gold_delta", coins - before_coins))
	gold_reward = gold_delta
	var event_reward_pool_id := String(post_battle.get("reward_pool_id", base_reward_pool_id))
	var reward_pool_id := _reward_pool_with_available_options(event_reward_pool_id, reward_seed_context) if win else event_reward_pool_id
	var reward_fallback_entry := {}
	if win and reward_pool_id != event_reward_pool_id:
		reward_fallback_entry = {
			"requested_pool_id": event_reward_pool_id,
			"resolved_pool_id": reward_pool_id,
			"base_reward_pool_id": base_reward_pool_id,
			"seed_context": reward_seed_context,
			"reason": "requested_pool_empty",
			"day": day,
			"node_index": node_index,
			"encounter_id": encounter_id
		}
		reward_fallback_audit.append(reward_fallback_entry.duplicate(true))
	battle_result = _core_composition.battle_outcome_policy.assemble_result({
		"win": win,
		"code": code,
		"grade": grade,
		"gold": gold_reward,
		"gold_base_delta": gold_base_delta,
		"gold_delta": gold_delta,
		"gold_from": before_coins,
		"gold_to": coins,
		"hero_hp_from": before_hp,
		"hero_hp_to": hero_hp,
		"enemy_hero_hp": enemy_hp_at_end,
		"draw": draw,
		"castle_line_from": before_castle_line,
		"castle_line_to": castle_line,
		"economy_multiplier_from": before_economy_multiplier,
		"economy_multiplier_to": economy_multiplier,
		"game_over": game_over,
		"reason": reason,
		"day": day,
		"node_index": node_index,
		"battle_round": battle_round,
		"encounter_id": encounter_id,
		"encounter_name": String(active_encounter.get("name", "路线战斗")),
		"base_reward_pool_id": base_reward_pool_id,
		"reward_pool_id": reward_pool_id,
		"reward_seed_context": reward_seed_context,
		"post_battle_events": Array(post_battle.get("events", [])),
		"run_effects": Array(run_effect_result.get("consumed", [])),
		"battle_end_mechanics": Array(battle_end_mechanic_result.get("applied", [])),
		"extra_rewards": Array(battle_end_mechanic_result.get("extra_rewards", [])),
		"reward_fallback_audit": reward_fallback_entry.duplicate(true),
		"event_reward_pool_id": event_reward_pool_id,
	})
	_publish_relic_battle_end({
		"win": win,
		"draw": draw,
		"reason": reason,
		"battle_round": battle_round,
	})
	active_wave = {}
	selected_unit_id = ""
	selected_action_slot_index = 0
	if not _transition_phase("battle_end"):
		return
	if draw:
		_log("战斗结束：第12回合双方英雄生命同为%d，平局。" % hero_hp)
	elif win:
		_log("战斗结束：%s，评级%s，金币%d→%d。" % [code, grade, before_coins, coins])
		for line in Array(battle_end_mechanic_result.get("logs", [])):
			_log(String(line))
			for event in Array(battle_result.get("post_battle_events", [])):
				var row := Dictionary(event)
				_log("战后事件：%s，本场奖励已调整。" % String(row.get("name", "战后事件")))
	else:
		if reason == "player_hero_dead":
			_log("战斗失败：我方英雄生命归零。")
		elif reason == "hero_hp_lower":
			_log("战斗失败：第12回合结算，我方英雄生命%d，敌方英雄生命%d。" % [hero_hp, enemy_hero_hp])
		else:
			_log("战斗失败：超过%d回合，防线%d→%d，经济倍率%.2f→%.2f。" % [
				MAX_BATTLE_ROUNDS,
				before_castle_line,
				castle_line,
				before_economy_multiplier,
				economy_multiplier
			])
		for line in Array(battle_end_mechanic_result.get("logs", [])):
			_log(String(line))
		for event in Array(battle_result.get("post_battle_events", [])):
			_log("战后事件：%s。" % String(Dictionary(event).get("name", "失败惩罚")))
		if game_over:
			_log("玩家英雄死亡，游戏结束。")

func continue_after_battle() -> bool:
	if phase != "battle_end":
		return false
	var result := battle_result.duplicate(true)
	if bool(result.get("game_over", false)):
		if not _transition_phase("game_over"):
			return false
		_log("单局结束：止步第%d天时间节点%d。" % [int(result.get("day", day)), int(result.get("node_index", node_index))])
		return true
	if bool(result.get("advance_route", false)):
		_advance_route_step()
	if bool(result.get("reward_eligible", false)):
		var pool_id := String(result.get("reward_pool_id", _tier_reward_pool_for_day()))
		var seed_context := _battle_reward_seed_context(result)
		reward_options = _reward_options_for_pool(pool_id, 3, seed_context)
		if reward_options.is_empty() and pool_id != _tier_reward_pool_for_day():
			pool_id = _tier_reward_pool_for_day()
			reward_options = _reward_options_for_pool(pool_id, 3, seed_context)
		if not reward_options.is_empty():
				if not _transition_phase("reward"):
					return false
				battle_result["reward_pool_id"] = pool_id
				battle_result["reward_options_count"] = reward_options.size()
				_log("战斗奖励：从 %d 个奖励中选择 1 个。" % reward_options.size())
				return true
	_return_to_route_or_day_end()
	_log("战斗结算确认，返回时间节点 %d。" % node_index)
	return true

func _start_next_battle_round() -> bool:
	if phase != "battle" or battle_round >= MAX_BATTLE_ROUNDS:
		return false
	battle_round += 1
	ap = _player_round_action_budget()
	player_elements_settled_this_round = false
	_reset_action_slots(PLAYER)
	team_placement_preview = {"activeUnitId": null, "movedUnitIds": []}
	_apply_mechanic_round_start(PLAYER)
	_apply_quality_round_start(PLAYER)
	selected_unit_id = ""
	selected_action_slot_index = 0
	_record_battle_round_start_checkpoint()
	_log("进入第 %d 回合；双方重置次数与动态宠物门槛独立计算。" % battle_round)
	GameLogScript.info("战斗/回合", "进入下一回合", {
		"回合": battle_round,
		"行动力": ap,
		"我方存活": _living_unit_count(PLAYER),
		"敌方存活": _living_unit_count(ENEMY),
		"我方英雄生命": hero_hp,
		"敌方英雄生命": enemy_hero_hp,
		"我方重置次数": int(pet_reset_charges.get(PLAYER, 0)),
		"敌方重置次数": int(pet_reset_charges.get(ENEMY, 0))
	})
	return true


func rewind_to_previous_round_start() -> bool:
	if phase != "battle":
		return false
	var target_index := _previous_round_start_checkpoint_index()
	if target_index < 0:
		return false
	var version_before := state_version
	var from_round := battle_round
	var target_entry := Dictionary(battle_round_start_checkpoints[target_index])
	var target_state := Dictionary(target_entry.get("state", {})).duplicate(true)
	AuthoritativeStateCodecScript.restore_changed(self, target_state)
	state_version = version_before
	battle_round_start_checkpoints = battle_round_start_checkpoints.slice(0, target_index + 1).duplicate(true)
	placement_damage_by_unit = {}
	last_command_result = {
		"ok": true,
		"fromRound": from_round,
		"targetRound": battle_round,
	}
	_log("回撤到第 %d 回合开始。" % battle_round)
	return true


func _record_battle_round_start_checkpoint() -> void:
	var retained: Array = []
	for entry_value in battle_round_start_checkpoints:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry := Dictionary(entry_value)
		if int(entry.get("round", 0)) < battle_round:
			retained.append(entry.duplicate(true))
	retained.append({
		"round": battle_round,
		"state": AuthoritativeStateCodecScript.capture_round_start_checkpoint(self),
	})
	battle_round_start_checkpoints = retained.slice(maxi(0, retained.size() - MAX_BATTLE_ROUNDS)).duplicate(true)


func _previous_round_start_checkpoint_index() -> int:
	for index in range(battle_round_start_checkpoints.size() - 1, -1, -1):
		var entry_value: Variant = battle_round_start_checkpoints[index]
		if entry_value is Dictionary and int(Dictionary(entry_value).get("round", 0)) < battle_round:
			return index
	return -1


func _round_rewind_snapshot() -> Dictionary:
	var target_index := _previous_round_start_checkpoint_index()
	var target_round := 0
	if target_index >= 0:
		target_round = int(Dictionary(battle_round_start_checkpoints[target_index]).get("round", 0))
	return {
		"canRewind": phase == "battle" and target_index >= 0,
		"currentRound": battle_round,
		"targetRound": target_round,
		"availableCheckpoints": target_index + 1,
	}

func select_cell(x: int, y: int) -> bool:
	if phase != "battle":
		return false
	if not _inside(x, y):
		return false
	var occupant := _combat_target_at(x, y)
	if not occupant.is_empty() and String(occupant.get("camp", occupant.get("side", ""))) == PLAYER and String(occupant.get("id", "")) != "player_hero":
		selected_unit_id = String(occupant["id"])
		selected_action_slot_index = _next_action_slot_index(occupant)
		_log("选中 %s。" % occupant["name"])
		return true
	if selected_unit_id == "":
		if occupant.is_empty():
			_log("先选择我方宠物。")
		else:
			_log("先选择我方宠物，再攻击敌人。")
		return false
	if not occupant.is_empty() and String(occupant.get("camp", occupant.get("side", ""))) == ENEMY:
		return attack_selected(String(occupant["id"]))
	elif occupant.is_empty():
		return move_selected(x, y)
	return false

func select_unit(unit_id: String) -> bool:
	if unit_id == "":
		return false
	for unit in units:
		if String(unit.get("id", "")) == unit_id and int(unit.get("hp", 0)) > 0:
			selected_unit_id = unit_id
			selected_action_slot_index = _next_action_slot_index(unit)
			_log("选中 %s。" % unit.get("name", unit_id))
			return true
	return false

func move_selected(x: int, y: int, requested_unit_id: String = "") -> bool:
	var unit_id := requested_unit_id
	if unit_id == "":
		unit_id = selected_unit_id
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty():
		for candidate in units:
			if String(candidate.get("side", "")) == PLAYER and int(candidate.get("hp", 0)) > 0:
				unit = candidate
				break
	var move_text := ""
	if unit.is_empty():
		move_text = "移动失败：未选择我方宠物。"
		_log(move_text)
		_record_move_trace("MOVE_HERO_BLOCKED", {}, {}, _position_ref(x, y), 0, move_text)
		return false
	if String(unit.get("side", "")) != PLAYER:
		move_text = "移动失败：只能移动我方宠物。"
		_log(move_text)
		_record_move_trace("MOVE_HERO_BLOCKED", unit, _position_ref(int(unit.get("x", -1)), int(unit.get("y", -1))), _position_ref(x, y), _effective_move_range(unit), move_text)
		return false
	if not _inside(x, y):
		move_text = "移动失败：(%d,%d) 超出棋盘。" % [x + 1, y + 1]
		_log(move_text)
		_record_move_trace("MOVE_HERO_BLOCKED", unit, _position_ref(int(unit.get("x", -1)), int(unit.get("y", -1))), _position_ref(x, y), _effective_move_range(unit), move_text)
		return false
	var occupant := unit_at(x, y)
	if not occupant.is_empty() and String(occupant.get("id", "")) != String(unit.get("id", "")):
		move_text = "移动失败：(%d,%d) 已被占用。" % [x + 1, y + 1]
		_log(move_text)
		_record_move_trace("MOVE_HERO_BLOCKED", unit, _position_ref(int(unit.get("x", -1)), int(unit.get("y", -1))), _position_ref(x, y), _effective_move_range(unit), move_text)
		return false
	if bool(unit.get("has_attacked", false)) or bool(unit.get("hasAttacked", false)):
		move_text = "%s 本回合已行动，位置锁定。" % String(unit.get("name", String(unit.get("id", selected_unit_id))))
		_log(move_text)
		_record_move_trace("MOVE_HERO_BLOCKED", unit, _position_ref(int(unit.get("x", -1)), int(unit.get("y", -1))), _position_ref(x, y), _effective_move_range(unit), move_text)
		return false
	var distance: int = abs(int(unit["x"]) - x) + abs(int(unit["y"]) - y)
	var move_range := _effective_move_range(unit)
	if distance > move_range:
		move_text = "移动失败：%s 移动力%d，距离%d。" % [String(unit.get("name", String(unit.get("id", selected_unit_id)))), move_range, distance]
		_log(move_text)
		_record_move_trace("MOVE_HERO_BLOCKED", unit, _position_ref(int(unit.get("x", -1)), int(unit.get("y", -1))), _position_ref(x, y), move_range, move_text)
		return false
	var movement_ap_cost := _effective_movement_cost(unit, 0)
	if movement_ap_cost > ap:
		move_text = "移动失败：移动消耗修正需要%d AP，当前剩余%d。" % [movement_ap_cost, ap]
		_log(move_text)
		_record_move_trace("MOVE_HERO_BLOCKED", unit, _position_ref(int(unit.get("x", -1)), int(unit.get("y", -1))), _position_ref(x, y), move_range, move_text)
		return false
	var from_x := int(unit.get("x", x))
	var from_y := int(unit.get("y", y))
	unit["x"] = x
	unit["y"] = y
	ap -= movement_ap_cost
	auto_position_action_plan = []
	_record_team_placement_move(String(unit.get("id", selected_unit_id)))
	move_text = "%s 移动：R%dC%d->R%dC%d。" % [String(unit.get("name", String(unit.get("id", selected_unit_id)))), from_y + 1, from_x + 1, y + 1, x + 1]
	_log(move_text)
	_record_move_trace("MOVE_HERO", unit, _position_ref(from_x, from_y), _position_ref(x, y), move_range, move_text)
	_check_battle_end()
	return true

func use_selected_action_slot(requested_ap: int = 0) -> bool:
	var attacker := selected_unit()
	if attacker.is_empty() or String(attacker.get("side", "")) != PLAYER or int(attacker.get("hp", 0)) <= 0:
		_log("施放失败：未选择可行动我方宠物。")
		return false
	var slot := _selected_action_slot(attacker)
	if slot.is_empty():
		_log("当前单位没有可用行动槽。")
		return false
	if bool(slot.get("used", false)):
		_log("%s 已使用，选择其他行动槽。" % String(slot.get("label", "行动槽")))
		return false
	var option := _attack_option_for_direction(attacker, String(slot.get("direction", "right")))
	if option.is_empty():
		_log("%s 第%d槽没有合法目标格。" % [String(attacker.get("name", "我方")), int(slot.get("index", selected_action_slot_index)) + 1])
		return false
	return _execute_selected_action_option(attacker, slot, option, requested_ap)

func attack_selected(target_id: String, requested_ap: int = 0) -> bool:
	if ap <= 0:
		_log("AP 不足。")
		return false
	var attacker := unit_by_id(selected_unit_id)
	var target := unit_by_id(target_id)
	if target.is_empty() and target_id == "enemy_boss":
		target = _leader_unit(false)
	if attacker.is_empty() or target.is_empty():
		return false
	if String(target.get("camp", target.get("side", ""))) != ENEMY:
		return false
	var slot := _selected_action_slot(attacker)
	if slot.is_empty():
		_log("当前单位没有可用行动槽。")
		return false
	if bool(slot.get("used", false)):
		_log("%s 已使用，选择其他行动槽。" % String(slot.get("label", "行动槽")))
		return false
	var option: Dictionary = _attack_option_for_target(attacker, target, String(slot.get("direction", "right")))
	if option.is_empty():
		_log("目标不在 %s/%s 作用格。" % [
			String(_shape_definition(attacker).get("label", "形状01")),
			_direction_label(String(slot.get("direction", "right")))
		])
		return false
	option = _quality_attack_option_for_target(attacker, target, option)
	return _execute_selected_action_option(attacker, slot, option, requested_ap)

func _execute_selected_action_option(attacker: Dictionary, slot: Dictionary, option: Dictionary, requested_ap: int = 0) -> bool:
	if ap <= 0:
		_log("AP 不足。")
		return false
	var requested_strength: int = max(1, requested_ap if requested_ap > 0 else int(slot.get("selected_ap", _selected_action_ap(attacker, int(slot.get("index", selected_action_slot_index))))))
	var cost_result := _effective_action_cost(attacker, requested_strength)
	requested_strength = max(0, int(cost_result.get("requested", requested_strength)))
	var spent_ap: int = max(0, int(cost_result.get("cost", requested_strength)))
	if requested_strength <= 0:
		_log("行动失败：%s 当前行动点上限为0。" % String(attacker.get("name", "宠物")))
		return false
	if spent_ap > ap:
		_log("AP 不足（需要%d，剩余%d）。" % [spent_ap, ap])
		return false
	var slot_element := String(slot.get("element", String(attacker.get("element", ""))))
	var base_slot_layers: int = max(1, int(slot.get("base_layers", slot.get("layers", 1))))
	var slot_layers: int = base_slot_layers * requested_strength
	slot["ap_used"] = requested_strength
	slot["base_layers"] = base_slot_layers
	slot["layers"] = slot_layers
	slot["effective_layers"] = slot_layers
	var pre_quality_logs := _apply_quality_before_attack(attacker, option)
	var targets: Array = _enemies_in_attack_option(attacker, option)
	var damage_bonus: int = _skill_damage_bonus(attacker, slot, option, targets)
	var strike_count: int = max(1, int(slot.get("strike_count", 1)))
	var base_strike_damage: int = max(0, _resolved_stat_value(attacker, "atk", {"hook": EffectHookIdsScript.NORMAL_ATTACK, "option": option, "slot": slot}))
	var damage_values: Array = []
	var pending_damage_deaths: Array = []
	var hit_quality_logs: Array = []
	var hit_index := 0
	var quality_slot_layers: int = _quality_element_layers(attacker, slot_element, slot_layers)
	var action_element_layers: int = quality_slot_layers * strike_count
	for hit in targets:
		var hit_cell := {"x": int(hit.get("x", -1)), "y": int(hit.get("y", -1))}
		var quality_apply_count: int = _quality_element_apply_count(attacker, hit_cell)
		for apply_index in range(quality_apply_count):
			_apply_element_to_unit(hit, slot_element, action_element_layers)
			for line in _apply_mechanic_after_element_apply(attacker, hit, slot_element, action_element_layers, hit_cell):
				hit_quality_logs.append(String(line))
		for line in _quality_immediate_element_burst(attacker, hit, slot_element):
			pre_quality_logs.append(String(line))
		for apply_index in range(quality_apply_count):
			_apply_element_to_cell(int(hit_cell.get("x", -1)), int(hit_cell.get("y", -1)), slot_element, action_element_layers)
	var covered_cells: Array = Array(option.get("cells", [])).duplicate(true)
	for cell in covered_cells:
		var row := Dictionary(cell)
		var occupying_unit := unit_at(int(row.get("x", -1)), int(row.get("y", -1)))
		if occupying_unit.is_empty() or String(occupying_unit.get("side", "")) == PLAYER:
			var quality_apply_count: int = _quality_element_apply_count(attacker, row)
			for apply_index in range(quality_apply_count):
				_apply_element_to_cell(int(row.get("x", -1)), int(row.get("y", -1)), slot_element, action_element_layers)
				if not occupying_unit.is_empty():
					_apply_element_to_unit(occupying_unit, slot_element, action_element_layers)
				for line in _apply_mechanic_after_element_apply(attacker, occupying_unit, slot_element, action_element_layers, row):
					hit_quality_logs.append(String(line))
	_record_element_applied_trace(attacker, covered_cells, slot_element, action_element_layers, not targets.is_empty())
	hit_index = 0
	for hit in targets:
		var aggregate_base_damage := base_strike_damage * strike_count + damage_bonus
		var aggregate_hit_damage: int = _quality_damage_for_hit(attacker, slot, option, targets, hit, hit_index, aggregate_base_damage)
		var strike_damage_values: Array = _strike_damage_values(base_strike_damage, strike_count, aggregate_hit_damage)
		var last_damage_result := {"final": 0}
		for strike_index in range(strike_count):
			if hit_index == 0:
				_record_attack_strike_trace(attacker, covered_cells, slot_element, strike_index + 1, strike_count)
			var hit_damage: int = int(strike_damage_values[strike_index])
			var damage_result := {"final": 0}
			if int(hit.get("hp", 0)) > 0:
				damage_result = _deal_damage(attacker, hit, hit_damage, slot_element, false, {
					"sourceType": "action",
					"calculationKind": "physical",
					"strikeIndex": strike_index + 1,
					"strikeCount": strike_count,
					"suppressProjectile": true,
					"deferDeathResolution": true,
				}, DamagePropsScript.move_damage())
				if bool(damage_result.get("pending_death", false)):
					pending_damage_deaths.append({
						"source": attacker,
						"target": hit,
						"result": damage_result,
					})
			last_damage_result = damage_result
			damage_values.append(int(damage_result.get("final", 0)))
			for mechanic_line in Array(damage_result.get("mechanic_logs", [])):
				hit_quality_logs.append(String(mechanic_line))
		for attacker_mechanic_line in _apply_attacker_mechanic_after_hit(attacker, hit, int(last_damage_result.get("final", 0)), slot_element, String(option.get("direction", ""))):
			hit_quality_logs.append(String(attacker_mechanic_line))
		for quality_line in _apply_quality_after_hit(attacker, hit):
			hit_quality_logs.append(String(quality_line))
		hit_index += 1
	for death_line in _resolve_damage_deaths(pending_damage_deaths):
		hit_quality_logs.append(String(death_line))
	_set_action_slot_used(attacker, int(slot.get("index", selected_action_slot_index)), requested_strength)
	attacker["has_attacked"] = true
	ap -= spent_ap
	selected_action_slot_index = _next_action_slot_index(attacker)
	var quality_logs := hit_quality_logs
	for line in _apply_quality_after_attack(attacker, option, targets):
		quality_logs.append(String(line))
	var skill_logs := _apply_action_skill_after_attack(attacker, slot, option, targets)
	for line in _apply_mechanic_after_action(attacker):
		quality_logs.append(String(line))
	var target_names: Array = []
	for hit in targets:
		target_names.append("%s[%s]" % [String(hit.get("name", hit.get("id", "敌人"))), _element_summary(Dictionary(hit.get("elements", {})))])
	var target_text := "、".join(target_names)
	var bonus_parts: Array = []
	if damage_bonus > 0:
		var skill_name := skill_label(String(attacker.get("skill", "")))
		if skill_name == "":
			skill_name = "痕迹"
		bonus_parts.append("%s+%d" % [skill_name, damage_bonus])
	var max_quality_bonus := 0
	for value in damage_values:
		max_quality_bonus = max(max_quality_bonus, int(value) - base_strike_damage)
	var quality_bonus_label := _quality_bonus_label(attacker, max_quality_bonus)
	if quality_bonus_label != "":
		bonus_parts.append(quality_bonus_label)
	var bonus_text := "" if bonus_parts.is_empty() else "，%s" % "，".join(bonus_parts)
	var damage_text := str(base_strike_damage)
	if not damage_values.is_empty():
		var damage_parts: Array = []
		for value in damage_values:
			damage_parts.append(str(int(value)))
		damage_text = "/".join(damage_parts)
	if targets.is_empty():
		_log("%s 施放%s AP%d：%s%d层 %s/%s，作用%d格并铺设元素。" % [
			String(attacker["name"]),
			String(slot.get("label", "")),
			requested_strength,
			slot_element,
			action_element_layers,
			String(option.get("shape_name", "形状01")),
			String(option.get("direction_label", "")),
			Array(option.get("cells", [])).size()
		])
	else:
		_log("%s 施放%s AP%d：%s%d层 %s/%s，命中 %s，造成 %s 伤害%s。" % [
			String(attacker["name"]),
			String(slot.get("label", "")),
			requested_strength,
			slot_element,
			action_element_layers,
			String(option.get("shape_name", "形状01")),
			String(option.get("direction_label", "")),
			target_text,
			damage_text if strike_count == 1 else "%d段 %s" % [strike_count, damage_text],
			bonus_text
		])
	for line in pre_quality_logs:
		_log(String(line))
	for line in skill_logs:
		_log(String(line))
	for line in quality_logs:
		_log(String(line))
	for hit in targets:
		if int(hit["hp"]) <= 0:
			_log("%s 被击败。" % hit["name"])
	_check_battle_end()
	return true

func run_player_all_out() -> void:
	_core_composition.player_turn_service.run_all_out(PlayerTurnPortScript.new(self))

func run_combat_round() -> bool:
	return _core_composition.battle_session.run_combat_round(BattleSessionPortScript.new(self), PLAYER, ENEMY)

func _settle_player_elements_after_all_out() -> bool:
	if phase != "battle" or player_elements_settled_this_round:
		return false
	player_elements_settled_this_round = true
	_log("所有我方攻击完成，1秒后结算怪物所在元素格。")
	var settled := _settle_threshold_elements()
	if settled:
		_check_battle_end()
	return settled

func run_battle_auto() -> bool:
	return _core_composition.battle_session.run_battle_auto(BattleSessionPortScript.new(self), PLAYER)

func run_full_day() -> bool:
	return _core_composition.run_automation_service.run_full_day(BattleSessionPortScript.new(self))

func run_full_run() -> bool:
	return _core_composition.run_automation_service.run_full_run(BattleSessionPortScript.new(self))

func end_player_turn() -> void:
	if phase != "battle":
		return
	ap = 0
	if not player_elements_settled_this_round:
		_log("我方回合结束，补做怪物所在元素格统一结算。")
		_settle_player_elements_after_all_out()
	_apply_mechanic_round_end(PLAYER)
	_log("敌方行动。")
	_enemy_turn()
	_apply_mechanic_round_end(ENEMY)
	_tick_board_traces()
	var completed_round := battle_round
	_check_battle_end(true)
	if phase == "battle" and battle_round == completed_round:
		_grant_pet_reset_charges_for_round(completed_round + 1)
		_reset_eligible_sides_after_round()
		_start_next_battle_round()
	if phase == "battle":
		_log("新的我方回合，AP 恢复为 3。")

func _enemy_turn() -> void:
	_core_composition.enemy_turn_service.run(EnemyTurnPortScript.new(self, ENEMY))

func _best_enemy_shape_action(enemy: Dictionary, required_target: Dictionary = {}) -> Dictionary:
	var battle_query_context: Dictionary = _battle_query_context()
	var best: Dictionary = {}
	var best_score := -1
	var required_target_id := String(required_target.get("id", ""))
	for slot_value in _action_slots_for_unit(enemy):
		var slot := Dictionary(slot_value)
		if bool(slot.get("used", false)):
			continue
		for option_value in _shape_attack_options(enemy):
			var option := Dictionary(option_value)
			var targets := _enemies_in_attack_option(enemy, option)
			if targets.is_empty():
				continue
			if required_target_id != "" and not _unit_ids(targets).has(required_target_id):
				continue
			var effective_damage := 0
			var kills := 0
			for target_value in targets:
				var target := Dictionary(target_value)
				var attack: int = max(0, _resolved_stat_value(enemy, "atk", {"hook": EffectHookIdsScript.ENEMY_TARGETING, "target": target}))
				var final_damage: int = _battle_query_damage_final(enemy, target, _leader_guarded_damage_packet(target, attack), String(enemy.get("element", "")), {"sourceType": "enemy_targeting", "calculationKind": "physical"}, {}, battle_query_context)
				var durability: int = max(0, int(target.get("shield", 0))) + max(0, int(target.get("hp", 0)))
				effective_damage += min(final_damage, durability)
				if final_damage >= durability and durability > 0:
					kills += 1
			var score: int = kills * 1_000_000 + effective_damage * 100 + targets.size()
			if score <= best_score:
				continue
			best_score = score
			best = {
				"slot": slot.duplicate(true),
				"option": option.duplicate(true),
				"targets": targets
			}
	return best

func _execute_enemy_shape_action(enemy: Dictionary, action: Dictionary) -> int:
	var slot := Dictionary(action.get("slot", {}))
	var option := Dictionary(action.get("option", {}))
	var targets := Array(action.get("targets", []))
	if slot.is_empty() or option.is_empty() or targets.is_empty():
		return 0
	_set_action_slot_used(enemy, int(slot.get("index", 0)), 1)
	enemy["has_attacked"] = true
	var hit_count := 0
	var target_names: Array = []
	var pending_damage_deaths: Array = []
	for target_value in targets:
		var target := Dictionary(target_value)
		if int(target.get("hp", 0)) <= 0:
			continue
		var result := _deal_damage(enemy, target, max(0, _resolved_stat_value(enemy, "atk", {"hook": EffectHookIdsScript.ENEMY_PET_ACTION, "target": target})), String(enemy.get("element", "")), false, {
			"sourceType": "enemy_pet_action",
			"calculationKind": "physical",
			"slotIndex": int(slot.get("index", 0)),
			"shapeId": String(option.get("shape_id", "")),
			"direction": String(option.get("direction", "")),
			"deferDeathResolution": true,
		}, DamagePropsScript.move_damage())
		if bool(result.get("pending_death", false)):
			pending_damage_deaths.append({"source": enemy, "target": target, "result": result})
		hit_count += 1
		target_names.append(String(target.get("name", target.get("id", "我方"))))
		var guard_text := "" if int(result.get("guard_reduction", 0)) <= 0 else "，守护减伤%d" % int(result.get("guard_reduction", 0))
		var shield_text := "" if int(result.get("shield_damage", 0)) <= 0 else "，护盾抵消%d" % int(result.get("shield_damage", 0))
		_log("%s 使用%s/%s攻击 %s，造成 %d 生命伤害%s%s。" % [
			String(enemy.get("name", "敌方")),
			String(slot.get("label", "行动槽")),
			String(option.get("shape_name", "攻击形状")),
			String(target.get("name", "我方")),
			int(result.get("hp_damage", 0)),
			guard_text,
			shield_text
		])
	for death_line in _resolve_damage_deaths(pending_damage_deaths):
		_log(String(death_line))
	if hit_count > 0:
		_log("%s 向%s施放%s（%s），命中%d个目标。" % [
			String(enemy.get("name", "敌方")),
			_direction_label(String(option.get("direction", "right"))),
			String(option.get("shape_name", "攻击形状")),
			"、".join(target_names),
			hit_count
		])
	return hit_count

func _apply_enemy_auto_position_plan() -> Array:
	var action_budget := 0
	for unit_value in units:
		var enemy := Dictionary(unit_value)
		if String(enemy.get("side", "")) == ENEMY and int(enemy.get("hp", 0)) > 0:
			action_budget += _enemy_attack_count(enemy)
	var plan := _build_auto_position_plan(ENEMY, action_budget, true)
	var planned_move_by_unit := {}
	var move_order: Array[String] = []
	var occupied_targets := {}
	for move_value in Array(plan.get("moves", [])):
		var move := Dictionary(move_value)
		var unit_id := String(move.get("unitId", ""))
		var enemy := unit_by_id(unit_id)
		var from := Dictionary(move.get("from", {}))
		var to := Dictionary(move.get("to", {}))
		var x := int(to.get("x", -1))
		var y := int(to.get("y", -1))
		var movement_budget := _effective_move_range(enemy)
		var distance: int = abs(int(from.get("x", -1)) - x) + abs(int(from.get("y", -1)) - y)
		var target_key := _cell_key(x, y)
		if enemy.is_empty() or String(enemy.get("side", "")) != ENEMY or not _inside(x, y) or not _leader_at(x, y).is_empty():
			continue
		if distance <= 0 or distance > movement_budget or occupied_targets.has(target_key):
			continue
		occupied_targets[target_key] = true
		planned_move_by_unit[unit_id] = move
		move_order.append(unit_id)
	var simultaneous_moves_are_valid := true
	for unit_id in move_order:
		var move := Dictionary(planned_move_by_unit[unit_id])
		var to := Dictionary(move.get("to", {}))
		var occupant := unit_at(int(to.get("x", -1)), int(to.get("y", -1)))
		if occupant.is_empty() or String(occupant.get("id", "")) == unit_id:
			continue
		if not planned_move_by_unit.has(String(occupant.get("id", ""))):
			simultaneous_moves_are_valid = false
			break
	if not simultaneous_moves_are_valid:
		_log("敌方智能站位取消：目标格存在不能同步让位的单位。")
		return []
	var applied_moves: Array = []
	for unit_id in move_order:
		var move := Dictionary(planned_move_by_unit[unit_id])
		var enemy := unit_by_id(unit_id)
		var from := Dictionary(move.get("from", {}))
		var to := Dictionary(move.get("to", {}))
		var from_x := int(from.get("x", int(enemy.get("x", -1))))
		var from_y := int(from.get("y", int(enemy.get("y", -1))))
		var to_x := int(to.get("x", from_x))
		var to_y := int(to.get("y", from_y))
		enemy["x"] = to_x
		enemy["y"] = to_y
		var movement_budget := _effective_move_range(enemy)
		var move_text := "%s 按智能站位从 R%dC%d 移动到 R%dC%d（移动力 %d）。" % [
			String(enemy.get("name", "敌方")),
			from_y + 1,
			from_x + 1,
			to_y + 1,
			to_x + 1,
			movement_budget
		]
		_record_move_trace("MOVE_MONSTER", enemy, _position_ref(from_x, from_y), _position_ref(to_x, to_y), movement_budget, move_text)
		_log(move_text)
		_apply_trap_stack_on_enter(enemy)
		applied_moves.append(move.duplicate(true))
	return applied_moves

func _player_round_action_budget() -> int:
	return max(3, _living_unit_count(PLAYER))

func _nearest_enemy(unit: Dictionary, exclude: Array = []) -> Dictionary:
	var excluded: Dictionary = {}
	for target in exclude:
		excluded[String(Dictionary(target).get("id", ""))] = true
	var best: Dictionary = {}
	var best_distance := 999
	for target in units:
		if String(target.get("side", "")) != ENEMY or int(target.get("hp", 0)) <= 0:
			continue
		if bool(excluded.get(String(target.get("id", "")), false)):
			continue
		var distance: int = abs(int(unit.get("x", 0)) - int(target.get("x", 0))) + abs(int(unit.get("y", 0)) - int(target.get("y", 0)))
		if distance < best_distance:
			best = target
			best_distance = distance
	var enemy_leader := _leader_unit(false)
	if bool(enemy_leader.get("alive", false)) and not bool(excluded.get(String(enemy_leader.get("id", "")), false)):
		var leader_distance: int = abs(int(unit.get("x", 0)) - int(enemy_leader.get("x", 0))) + abs(int(unit.get("y", 0)) - int(enemy_leader.get("y", 0)))
		if leader_distance < best_distance:
			best = enemy_leader
	return best

func _check_battle_end(resolve_round_limit: bool = false) -> void:
	if phase != "battle":
		return
	var verdict: Dictionary = _core_composition.battle_outcome_policy.terminal_reason(
		hero_hp,
		enemy_hero_hp,
		battle_round,
		MAX_BATTLE_ROUNDS,
		resolve_round_limit
	)
	if bool(verdict.get("finished", false)):
		_finish_battle_result(
			bool(verdict.get("win", false)),
			String(verdict.get("reason", "")),
			bool(verdict.get("draw", false))
		)

func _save_state_payload() -> Dictionary:
	return AuthoritativeStateCodecScript.capture(self, true)

func save_document(player_id: String = "p1", meta: Dictionary = {}) -> Dictionary:
	var embed_content_pack := bool(meta.get("embedContentPack", true))
	var state_payload := (
		AuthoritativeStateCodecScript.capture_checkpoint(self)
		if bool(meta.get("historyCheckpoint", false))
		else _save_state_payload()
	)
	return _core_composition.save_document_builder.build(
		state_payload,
		player_id,
		meta,
		_determinism_context(embed_content_pack),
		_core_composition.run_history_committer.metadata(RunHistoryPortScript.new(self))
	)

func replay_document(options: Dictionary = {}) -> Dictionary:
	var final_hash := _state_hash()
	var initial_options := _sanitize_replay_initial_options(Dictionary(options.get("initialOptions", {})))
	var replay_seed := String(options.get("seed", run_seed))
	var initial_seed := String(options.get("seed", initial_options.get("seed", replay_seed)))
	var initial_day := int(initial_options.get("day", 1))
	var initial_period := String(initial_options.get("period", "上午"))
	if not initial_options.has("seed"):
		initial_options["seed"] = initial_seed
	if not initial_options.has("day"):
		initial_options["day"] = initial_day
	if not initial_options.has("period"):
		initial_options["period"] = initial_period
	if not initial_options.has("playerId"):
		initial_options["playerId"] = String(options.get("playerId", "p1"))
	if not initial_options.has("mode"):
		initial_options["mode"] = "solo"
	if not initial_options.has("boardWidth"):
		initial_options["boardWidth"] = board_width
	if not initial_options.has("boardHeight"):
		initial_options["boardHeight"] = board_height
	if not scenario_provenance.is_empty():
		initial_options["scenarioId"] = String(scenario_provenance.get("scenarioId", ""))
		initial_options["scenarioVersion"] = String(scenario_provenance.get("scenarioVersion", ""))
		initial_options["scenarioProvenance"] = scenario_provenance.duplicate(true)
	var fresh_result: Dictionary = _core_composition.simulation_authority_factory.create(
		get_script(),
		game_data.duplicate(true),
		{
			"seed": initial_seed,
			"boardDimensions": Vector2i(board_width, board_height),
			"contentSourceKind": _content_source_kind,
		}
	)
	var initial_hash: String = String(fresh_result.get("forkStateHash", "")) if bool(fresh_result.get("ok", false)) else ""
	var replay: Dictionary = ReplayBuilderScript.build({
		"schema": ReplayContractScript.SCHEMA,
		"schemaVersion": ReplayContractScript.SCHEMA_VERSION,
		"replayVersion": ReplayContractScript.COMMAND_VERSION,
		"legacyReplayVersion": "ysbzs_replay_v2_protocol",
		"dataVersion": _replay_data_version(),
		"rulesVersion": RULES_VERSION,
		"rngVersion": DeterministicSelectorScript.ALGORITHM_VERSION,
		"determinism": _determinism_context(false),
		"seed": replay_seed,
		"day": day,
			"period": battle_period,
		"result": battle_result,
		"initialOptions": initial_options,
		"initialHash": initial_hash,
		"commandLog": command_log,
		"storedDebugTimeline": replay_debug_timeline,
		"battleTrace": battle_trace,
		"stateVersion": state_version,
		"stateHash": final_hash,
		"phase": phase,
		"round": battle_round,
		"units": units,
		"scenario": scenario_provenance,
	})
	replay["checksum"] = _replay_checksum(replay)
	return replay

func save_replay_to_user() -> bool:
	if not supports_persistence():
		return false
	if not _core_composition.replay_repository.write_document(PersistenceConfigScript.REPLAY_PATH, replay_document()):
		_log("导出回放失败：无法写入 user://。")
		return false
	_log("已导出回放。")
	return true

func save_battle_trace_to_user() -> bool:
	if not supports_persistence():
		return false
	if not _core_composition.replay_repository.write_document(PersistenceConfigScript.BATTLE_TRACE_PATH, {"events": _export_battle_trace_events()}):
		_log("导出战报失败：无法写入 user://。")
		return false
	_log("已导出战报。")
	return true

func verify_replay_document(replay: Dictionary) -> Dictionary:
	return _core_composition.replay_verifier.verify(replay, {
		"authorityScript": get_script(),
		"contentPack": game_data.duplicate(true),
		"contentHash": _content_hash(),
		"contentSourceKind": _content_source_kind,
		"rulesVersion": RULES_VERSION,
		"rngVersion": DeterministicSelectorScript.ALGORITHM_VERSION,
		"defaultBoardDimensions": BattleBoardDimensionsScript.legacy_defaults(),
	}, _core_composition.simulation_authority_factory)

func _export_battle_trace_events() -> Array:
	if not battle_trace.is_empty():
		return battle_trace.duplicate(true)
	return ReplayBuilderScript.battle_trace(command_log)

func _replay_checksum(doc: Dictionary) -> String:
	return DocumentCodecScript.replay_checksum(doc)

func _save_checksum(doc: Dictionary) -> String:
	return DocumentCodecScript.save_checksum(doc)

func _save_summary_from_state(saved: Dictionary) -> Dictionary:
	return _core_composition.save_document_builder.summary_from_state(saved)

func _restore_and_validate_determinism(document: Dictionary) -> bool:
	var determinism := Dictionary(document.get("determinism", {}))
	if determinism.is_empty():
		return true
	var expected_rules := String(determinism.get("rulesVersion", ""))
	if expected_rules != "" and expected_rules != RULES_VERSION:
		_log("读档失败：规则版本不匹配。")
		return false
	var expected_rng := String(determinism.get("rngVersion", ""))
	if expected_rng != "" and expected_rng != DeterministicSelectorScript.ALGORITHM_VERSION:
		_log("读档失败：随机算法版本不匹配。")
		return false
	var expected_content_hash := String(determinism.get("contentHash", ""))
	var embedded_value: Variant = determinism.get("contentPack")
	if typeof(embedded_value) == TYPE_DICTIONARY:
		var embedded := Dictionary(embedded_value).duplicate(true)
		if expected_content_hash != "" and _content_hash_for(embedded) != expected_content_hash:
			_log("读档失败：内嵌内容包校验不匹配。")
			return false
		if not _replace_game_data(embedded, CoreCompositionScript.PERSISTED_SNAPSHOT):
			_log("读档失败：内嵌内容包运行时配置不合法。")
			return false
	if expected_content_hash != "" and _content_hash() != expected_content_hash:
		_log("读档失败：缺少历史使用的内容版本。")
		return false
	return true

func _validate_browser_save_document(doc: Dictionary) -> bool:
	return _save_document_validator.validate_document(
		doc,
		SaveContractScript.SCHEMA_VERSION,
		Callable(self, "_save_checksum"),
		Callable(self, "_log"),
		Vector2i(DEFAULT_BOARD_WIDTH, DEFAULT_BOARD_HEIGHT)
	)

func _saved_board_dimensions(saved: Dictionary) -> Vector2i:
	return _save_document_validator.saved_board_dimensions(
		saved,
		Vector2i(DEFAULT_BOARD_WIDTH, DEFAULT_BOARD_HEIGHT)
	)

func load_document(doc: Dictionary) -> bool:
	var migrated_doc := SaveMigrationsScript.normalize_document(doc)
	var schema := String(migrated_doc.get("schema", ""))
	if schema == SaveContractScript.SCHEMA:
		if not _validate_browser_save_document(migrated_doc):
			return false
		if not _restore_and_validate_determinism(migrated_doc):
			return false
	elif schema != SaveContractScript.LEGACY_SCHEMA:
			_log("读档失败：存档格式不匹配。")
			return false
	var saved := Dictionary(migrated_doc.get("state", {}))
	var saved_dimensions := _saved_board_dimensions(saved)
	if not saved.has("skill_control_orders") and not saved.has("skillControlOrders"):
		skill_control_orders = {PLAYER: [], ENEMY: []}
	AuthoritativeStateCodecScript.restore(self, saved)
	board_width = saved_dimensions.x
	board_height = saved_dimensions.y
	difficulty = _normalize_difficulty(difficulty)
	_normalize_roster_slots()
	_normalize_skill_control_orders()
	if run_plan.is_empty():
		run_plan = _build_run_plan()
	var history := Dictionary(migrated_doc.get("history", {}))
	history_run_id = String(history.get("runId", history_run_id))
	history_branch_id = String(history.get("branchId", history_branch_id))
	history_parent_run_id = String(history.get("parentRunId", history_parent_run_id))
	history_parent_checkpoint_id = String(history.get("parentCheckpointId", history_parent_checkpoint_id))
	history_command_index = int(history.get("commandIndex", history_command_index))
	history_content_revision = int(history.get("contentRevision", history_content_revision))
	history_content_path = String(history.get("contentPath", history_content_path))
	_log("读档完成：%s。" % String(_save_summary_from_state(saved).get("text", "")))
	return true

func set_run_history_root(path: String) -> void:
	var normalized := path.strip_edges()
	history_root = normalized if normalized != "" else DEFAULT_HISTORY_ROOT

func supports_persistence() -> bool:
	return _initialization_mode == "production"

func enable_run_history(enabled: bool = true) -> bool:
	history_recording_enabled = enabled
	return true

func supports_run_history() -> bool:
	return _initialization_mode in ["production", "test"]

func run_history_runs() -> Array:
	if not supports_run_history():
		return []
	return _core_composition.run_history_repository.list_runs(history_root)

func run_history_checkpoints(run_id: String = "") -> Array:
	if not supports_run_history():
		return []
	var resolved_run_id := run_id if run_id != "" else history_run_id
	if resolved_run_id == "":
		return []
	return _core_composition.run_history_repository.list_checkpoints(history_root, resolved_run_id)

func run_history_checkpoint_for_day(run_id: String, target_day: int, kind: String = "start") -> Dictionary:
	if run_id == "" or target_day < 1:
		return {}
	return _core_composition.run_history_repository.checkpoint_for_day(history_root, run_id, target_day, kind)

func run_history_status() -> Dictionary:
	return {
		"enabled": history_recording_enabled,
		"root": history_root,
		"runId": history_run_id,
		"branchId": history_branch_id,
		"parentRunId": history_parent_run_id,
		"parentCheckpointId": history_parent_checkpoint_id,
		"commandIndex": history_command_index,
		"contentRevision": history_content_revision,
		"contentPath": history_content_path,
		"contentHash": _content_hash(),
		"rulesVersion": RULES_VERSION,
		"rngVersion": DeterministicSelectorScript.ALGORITHM_VERSION
	}

func resume_from_run_history(run_id: String, checkpoint_id: String) -> bool:
	if run_id.strip_edges() == "" or checkpoint_id.strip_edges() == "":
		_log("历史恢复失败：缺少运行或检查点标识。")
		return false
	var run_header: Dictionary = Dictionary(_core_composition.run_history_repository.read_run_header(history_root, run_id))
	var checkpoint_summary := _history_checkpoint_summary(run_id, checkpoint_id)
	var document: Dictionary = Dictionary(_core_composition.run_history_repository.read_checkpoint(history_root, run_id, checkpoint_id))
	return _resume_from_history_checkpoint(
		run_id,
		checkpoint_id,
		run_header,
		checkpoint_summary,
		document
	)

func resume_from_run_history_day(run_id: String, target_day: int, kind: String = "start") -> bool:
	if run_id.strip_edges() == "" or target_day < 1:
		_log("历史恢复失败：缺少运行或日期标识。")
		return false
	var checkpoint_summary := run_history_checkpoint_for_day(run_id, target_day, kind)
	var checkpoint_id := String(checkpoint_summary.get("checkpointId", ""))
	if checkpoint_id == "":
		_log("历史恢复失败：该日没有直接检查点。")
		return false
	return _resume_from_history_checkpoint(
		run_id,
		checkpoint_id,
		_core_composition.run_history_repository.read_run_header(history_root, run_id),
		checkpoint_summary,
		_core_composition.run_history_repository.read_checkpoint_item(history_root, run_id, checkpoint_summary)
	)

func _resume_from_history_checkpoint(
	run_id: String,
	checkpoint_id: String,
	run_header: Dictionary,
	checkpoint_summary: Dictionary,
	document: Dictionary
) -> bool:
	if run_header.is_empty() or document.is_empty():
		_log("历史恢复失败：运行或检查点不存在。")
		return false
	var determinism := Dictionary(run_header.get("determinism", {}))
	var content_pack: Dictionary = Dictionary(_core_composition.run_history_repository.read_content_reference(history_root, determinism))
	if content_pack.is_empty():
		content_pack = _core_composition.run_history_repository.read_content_pack(history_root, run_id)
	if content_pack.is_empty():
		_log("历史恢复失败：内容修订不存在。")
		return false
	if String(determinism.get("rulesVersion", "")) != RULES_VERSION:
		_log("历史恢复失败：规则版本不匹配。")
		return false
	if String(determinism.get("rngVersion", "")) != DeterministicSelectorScript.ALGORITHM_VERSION:
		_log("历史恢复失败：随机算法版本不匹配。")
		return false
	if String(determinism.get("contentHash", "")) != _content_hash_for(content_pack):
		_log("历史恢复失败：内容包校验不匹配。")
		return false
	var rollback := _capture_history_resume_rollback()
	var previous_suspended := _history_suspended
	_history_suspended = true
	if not _replace_game_data(content_pack, CoreCompositionScript.PERSISTED_SNAPSHOT):
		# Prepare/commit rejection leaves content, registry, cache, and authority
		# untouched. Rebinding the old content here would unnecessarily rebuild
		# last-good Strategy identities.
		_history_suspended = previous_suspended
		_content_hash_cache = String(rollback.get("content_hash_cache", ""))
		_content_binding_errors = []
		for error_value in Array(rollback.get("content_binding_errors", [])):
			_content_binding_errors.append(String(error_value))
		_log("历史恢复失败：内容运行时配置不合法。")
		return false
	if not load_document(document):
		var load_message := String(log_lines[0]) if not log_lines.is_empty() else "历史恢复失败：检查点内容恢复失败。"
		_restore_history_resume_rollback(rollback)
		_log(load_message)
		return false
	var restored_hash := _state_hash()
	var expected_hash := String(checkpoint_summary.get("stateHash", ""))
	if expected_hash != "" and restored_hash != expected_hash:
		_restore_history_resume_rollback(rollback)
		_log("历史恢复失败：检查点状态校验不匹配。")
		return false
	var parent := {
		"parentRunId": run_id,
		"parentCheckpointId": checkpoint_id
	}
	var history_port := RunHistoryPortScript.new(self)
	var begin_result: Dictionary = _core_composition.run_history_committer.begin(history_port, "branch", parent, false)
	if not bool(begin_result.get("ok", false)):
		var begin_message := String(begin_result.get("message", ""))
		_restore_history_resume_rollback(rollback)
		if begin_message != "":
			_log(begin_message)
		return false
	var checkpoint_result: Dictionary = _core_composition.run_history_committer.write_checkpoint(history_port, "branch_start")
	if not bool(checkpoint_result.get("ok", false)):
		var checkpoint_message := String(checkpoint_result.get("message", ""))
		_restore_history_resume_rollback(rollback)
		if checkpoint_message != "":
			_log(checkpoint_message)
		return false
	_history_suspended = previous_suspended
	history_recording_enabled = true
	_log("已从第%d天历史检查点创建新分支。" % day)
	return true

func _capture_history_resume_rollback() -> Dictionary:
	var content_hash_cache_before := _content_hash_cache
	var state_hash_before := _state_hash()
	return {
		"authority": AuthoritativeStateCodecScript.capture(self, false),
		"content": game_data.duplicate(true),
		"content_source_kind": _content_source_kind,
		"content_hash_cache": content_hash_cache_before,
		"content_binding_errors": _content_binding_errors.duplicate(),
		"state_hash": state_hash_before,
		"last_command_result": _duplicate_history_rollback_value(last_command_result),
		"history": {
			"recording_enabled": history_recording_enabled,
			"root": history_root,
			"run_id": history_run_id,
			"branch_id": history_branch_id,
			"parent_run_id": history_parent_run_id,
			"parent_checkpoint_id": history_parent_checkpoint_id,
			"command_index": history_command_index,
			"content_revision": history_content_revision,
			"content_path": history_content_path,
			"suspended": _history_suspended,
		},
	}

func _restore_history_resume_rollback(rollback: Dictionary) -> bool:
	var restored_content := Dictionary(rollback.get("content", {})).duplicate(true)
	var restored_source := StringName(rollback.get("content_source_kind", CoreCompositionScript.CURRENT_ASSEMBLY))
	if not _replace_game_data(restored_content, restored_source):
		return false
	AuthoritativeStateCodecScript.restore(self, Dictionary(rollback.get("authority", {})))
	last_command_result = _duplicate_history_rollback_value(rollback.get("last_command_result"))
	var history := Dictionary(rollback.get("history", {}))
	history_recording_enabled = bool(history.get("recording_enabled", false))
	history_root = String(history.get("root", DEFAULT_HISTORY_ROOT))
	history_run_id = String(history.get("run_id", ""))
	history_branch_id = String(history.get("branch_id", ""))
	history_parent_run_id = String(history.get("parent_run_id", ""))
	history_parent_checkpoint_id = String(history.get("parent_checkpoint_id", ""))
	history_command_index = int(history.get("command_index", 0))
	history_content_revision = int(history.get("content_revision", 0))
	history_content_path = String(history.get("content_path", ""))
	_history_suspended = bool(history.get("suspended", false))
	var expected_hash := String(rollback.get("state_hash", ""))
	var restored_hash := _state_hash()
	_content_hash_cache = String(rollback.get("content_hash_cache", ""))
	_content_binding_errors = []
	for error_value in Array(rollback.get("content_binding_errors", [])):
		_content_binding_errors.append(String(error_value))
	return expected_hash == "" or restored_hash == expected_hash

func _duplicate_history_rollback_value(value: Variant) -> Variant:
	if value is Dictionary:
		return Dictionary(value).duplicate(true)
	if value is Array:
		return Array(value).duplicate(true)
	return value

func _history_checkpoint_summary(run_id: String, checkpoint_id: String) -> Dictionary:
	for value in _core_composition.run_history_repository.list_checkpoints(history_root, run_id):
		var item := Dictionary(value)
		if String(item.get("checkpointId", "")) == checkpoint_id:
			return item
	return {}

func save_to_user(slot: int = 1) -> bool:
	if not supports_persistence():
		return false
	var operation_log_enabled := GameLogScript.operation_log_enabled()
	var before_summary: Dictionary = _core_composition.player_operation_projector.state_summary(_player_operation_projection_context()) if operation_log_enabled else {}
	var ok := _save_to_user_impl(slot)
	if operation_log_enabled:
		_append_player_operation({
			"kind": "save",
			"command": "SAVE_SLOT",
			"slot": slot,
			"accepted": ok,
			"before": before_summary,
			"after": _core_composition.player_operation_projector.state_summary(_player_operation_projection_context())
		})
	GameLogScript.info("存档/保存", "保存操作完成", {
		"槽位": slot,
		"结果": "成功" if ok else "失败",
		"阶段": phase,
		"天数": day,
		"时间点": node_index,
		"回合": battle_round
	})
	return ok

func _save_to_user_impl(slot: int = 1) -> bool:
	var document := save_document()
	var result := Dictionary(_core_composition.save_repository.write_slot(
		document,
		slot,
		PersistenceConfigScript.save_slot_config()
	))
	if not bool(result.get("ok", false)):
		_log(SaveResultMessagesScript.write_error(String(result.get("error", ""))))
		return false
	_log("已保存当前进度（槽%d）：%s。" % [slot, String(Dictionary(document.get("summary", {})).get("text", ""))])
	return true

func load_from_user(slot: int = 1) -> bool:
	if not supports_persistence():
		return false
	var operation_log_enabled := GameLogScript.operation_log_enabled()
	var before_summary: Dictionary = _core_composition.player_operation_projector.state_summary(_player_operation_projection_context()) if operation_log_enabled else {}
	var ok := _load_from_user_impl(slot)
	if operation_log_enabled:
		_append_player_operation({
			"kind": "load",
			"command": "LOAD_SLOT",
			"slot": slot,
			"accepted": ok,
			"before": before_summary,
			"after": _core_composition.player_operation_projector.state_summary(_player_operation_projection_context())
		})
	GameLogScript.info("存档/读取", "读取操作完成", {
		"槽位": slot,
		"结果": "成功" if ok else "失败",
		"阶段": phase,
		"天数": day,
		"时间点": node_index,
		"回合": battle_round,
		"棋盘": "%dx%d" % [board_width, board_height]
	})
	return ok

func _load_from_user_impl(slot: int = 1) -> bool:
	var result := Dictionary(_core_composition.save_repository.read_slot(
		slot,
		PersistenceConfigScript.save_slot_config()
	))
	if not bool(result.get("ok", false)):
		_log("读档失败：槽%d没有可用存档或备份。" % slot if String(result.get("error", "")) != "INVALID_SLOT" else "读档失败：存档槽无效。")
		return false
	var document := Dictionary(result.get("document", {}))
	if not load_document(document):
		return false
	var source := String(result.get("source", "primary"))
	if source == "backup":
		var saved := Dictionary(document.get("state", {}))
		_log("已从槽%d备份读档：%s。" % [slot, String(_save_summary_from_state(saved).get("text", ""))])
	elif source == "legacy":
		_log("已从旧单存档读入槽1；下次保存会写入槽1。")
	return true
