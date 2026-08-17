extends SceneTree

const REMOVED_BASE_SIGNATURES := [
	"_route_battle_options",
	"_apply_fire_explosion_after_attack",
	"_trace_definition_for_upgrade",
	"_farthest_cell_from_unit",
	"_first_adjacent_enemy",
	"_fixed_battle_entry_options",
	"_node_options_for_schedule",
	"_battle_options_for_schedule",
	"_battle_option_for_node_choice_schedule",
	"_battle_pool_id_for_node_choice",
	"_formal_encounters_for_pool",
	"_battle_option_from_schedule",
	"_battle_option_from_encounter",
	"_encounter_for_schedule",
	"_option_kind_for_node",
	"_node_description",
	"_is_valid_save_slot",
	"_save_slot_path",
	"_save_slot_backup_path",
	"_save_slot_temp_path",
	"_load_legacy_slot_one",
	"_write_save_text",
	"_read_save_document_from_path",
	"_remove_save_path",
	"_cell_key_for_diff",
	"_cell_row_diffs",
	"_unit_row_diffs",
	"_damage_threat_from_event",
	"_attach_unit_diff_sources",
	"_damage_summary_for_unit_diff",
	"_damage_summaries_by_unit",
	"_shape_offset_cell",
	"_append_unique_cell",
	"_apply_quality_shape_mutation",
	"_apply_mechanic_round_start_to_unit",
	"_apply_mechanic_round_end_to_unit",
	"_cleanse_same_side_debuffs",
]

var failures: Array[String] = []


func _initialize() -> void:
	var game_source := FileAccess.get_file_as_string("res://core_ui/scripts/app/game_controller.gd")
	var registry_source := FileAccess.get_file_as_string("res://core_ui/scripts/app/feature_registry.gd")
	var router_source := FileAccess.get_file_as_string("res://core_ui/scripts/app/scene_router.gd")
	var artist_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/scenes/three_choice_scene.gd")
	var battle_source := FileAccess.get_file_as_string("res://core_ui/scripts/battle/scenes/battle_scene.gd")
	var battle_hud_source := FileAccess.get_file_as_string("res://core_ui/scripts/battle/prefabs/hud/battle_hud.gd")
	var authority_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	var run_source := authority_source
	var command_source := authority_source
	var rules_source := authority_source
	var persistence_source := authority_source
	var projector_source := FileAccess.get_file_as_string("res://core/commands/snapshot_projector.gd")
	var protocol_source := FileAccess.get_file_as_string("res://session/session_protocol.gd")
	var singleplayer_source := FileAccess.get_file_as_string("res://tests/integration/smoke_singleplayer.gd")
	var singleplayer_suite_source := FileAccess.get_file_as_string("res://tests/helpers/singleplayer_smoke_suite.gd")
	var art_main_source := FileAccess.get_file_as_string("res://tests/features/smoke_art_main_scene.gd")
	var artist_presenter_source := FileAccess.get_file_as_string("res://tests/features/smoke_artist_flow_presenters.gd")
	var playable_flow_source := FileAccess.get_file_as_string("res://tests/integration/smoke_playable_flow.gd")

	_expect(game_source.contains("SessionFactoryScript"), "game shell composes Session before views")
	_expect(game_source.contains("_feature_router"), "game shell owns the composed feature router")
	_expect(not game_source.contains("get_authority_state"), "game shell does not pull authority from a view")
	_expect(registry_source.contains("BATTLE_FEATURE") and registry_source.contains("battle_art_scene.tscn"), "formal battle scene is registered as a feature")
	_expect(not router_source.contains("session") and router_source.contains("mount_feature"), "router owns only Scene mount and release lifecycle")
	_expect(game_source.contains("SessionBridgeScript") and game_source.contains("_on_command_requested"), "Game owns Session operations and command dispatch")
	_expect(artist_source.contains("StagePresenterScript") and artist_source.contains("signal command_requested"), "three-choice root owns presentation and semantic requests")
	_expect(not artist_source.contains("SessionFactoryScript") and not artist_source.contains('preload("res://art/scenes/battle/battle_art_scene.tscn")'), "three-choice view creates neither Session nor battle Scene")
	for feature_name in ["route", "shop", "inventory", "party", "settlement"]:
		_expect(
			artist_source.contains("core_ui/scripts/%s/presenters/%s_presenter.gd" % [feature_name, feature_name]),
			"%s presentation model is independently composed" % feature_name
		)
	for method_name in REMOVED_BASE_SIGNATURES:
		_expect(not authority_source.contains("func %s(" % method_name), "unused compatibility signature stays removed: %s" % method_name)
	_expect(battle_hud_source.contains("BattleCommandBuilderScript"), "battle HUD delegates command construction")
	_expect(battle_source.contains("BattleTraceProjectionScript"), "battle view delegates trace projection")
	_expect(command_source.contains("RouteOptionServiceScript"), "command query layer delegates route option projection")
	_expect(authority_source.count("func _route_options_for_schedule(") == 1, "single authority owns route option projection exactly once")
	_expect(not run_source.contains("func _fixed_battle_entry_options("), "route option algorithms do not flow back into run core")
	_expect(run_source.contains("pet_reset_policy.select_cells"), "run core delegates complete pet reset rules to one policy")
	_expect(run_source.contains("battle_outcome_policy.assemble_result"), "run core keeps result sequencing while policy owns the result document")
	_expect(command_source.contains("ManualFlowDiffProjectorScript"), "command core delegates manual-flow diff projection")
	_expect(artist_source.contains("AssetRegistryScript"), "artist root delegates resource mapping")
	_expect(authority_source.contains("RosterCollectionServiceScript"), "authority delegates collection normalization")
	_expect(rules_source.contains("round_lifecycle_service.run_start") and rules_source.contains("round_lifecycle_service.run_end"), "battle core delegates complete round hook lifecycle")
	_expect(not authority_source.contains("func _apply_mechanic_round_start_to_unit(") and not authority_source.contains("func _apply_mechanic_round_end_to_unit("), "round mechanism implementation stays in composed services")
	_expect(rules_source.contains("_core_composition.attack_option_service"), "authority delegates attack option projection")
	_expect(persistence_source.contains("SaveDocumentValidatorScript"), "authoritative facade delegates save-schema validation")
	_expect(projector_source.contains("ViewModelSchemaScript.normalize"), "snapshot projector publishes the versioned ViewModel schema")
	_expect(protocol_source.contains("ViewModelSchemaScript.validate"), "session protocol validates versioned ViewModels")
	var data_repository_source := FileAccess.get_file_as_string("res://persistence/game_data_repository.gd")
	_expect(not data_repository_source.contains("static var _content_cache"), "content cache is owned by each repository instance")
	_expect(singleplayer_source.contains("route->shop->battle->reward->route"), "single-player smoke remains a short authoritative happy path")
	_expect(not singleplayer_source.contains("_run_bootstrap_contracts") and not singleplayer_source.contains("_run_mechanic_contracts"), "single-player E2E does not absorb detailed contract groups")
	for split_path in [
		"res://tests/integration/smoke_singleplayer_bootstrap.gd",
		"res://tests/integration/smoke_singleplayer_route_economy.gd",
		"res://tests/integration/smoke_singleplayer_persistence.gd",
		"res://tests/integration/smoke_singleplayer_positioning.gd",
		"res://tests/integration/smoke_singleplayer_ui_projection.gd",
	]:
		_expect(FileAccess.file_exists(split_path), "single-player responsibility suite exists: %s" % split_path)
	_expect(singleplayer_suite_source.contains("singleplayer_smoke_context.gd"), "single-player suites delegate shared failure and state fixtures")
	_expect(singleplayer_suite_source.contains("func _finish("), "single-player suites share one fail-closed completion lifecycle")
	_expect(art_main_source.contains("Game owns the GameSession boundary"), "formal art smoke verifies Session ownership at the composed Game root")
	_expect(artist_presenter_source.contains("route presenter owns route command"), "artist presenter smoke verifies semantic route commands")
	_expect(playable_flow_source.contains("RUN_BATTLE") and playable_flow_source.contains("CONTINUE_AFTER_BATTLE"), "playable flow covers formal battle entry and completion commands")

	if failures.is_empty():
		print("SMOKE_ARCHITECTURE_BOUNDARIES_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("SMOKE_ARCHITECTURE_BOUNDARIES_FAIL: %s" % message)
