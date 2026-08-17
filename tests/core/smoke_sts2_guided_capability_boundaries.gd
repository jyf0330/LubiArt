extends SceneTree

const COMMAND_HANDLER_PATHS: Array[String] = [
	"res://core/commands/handlers/query_replay_command_handler.gd",
	"res://core/commands/handlers/route_reward_command_handler.gd",
	"res://core/commands/handlers/shop_inventory_command_handler.gd",
	"res://core/commands/handlers/run_flow_command_handler.gd",
	"res://core/commands/handlers/battle_command_handler.gd",
]
const SHOP_HANDLER_PATHS: Array[String] = [
	"res://core/shop/handlers/party_stat_effect_handler.gd",
	"res://core/shop/handlers/hero_vitality_effect_handler.gd",
	"res://core/shop/handlers/upgrade_pet_effect_handler.gd",
	"res://core/shop/handlers/duplicate_pet_effect_handler.gd",
	"res://core/shop/handlers/free_refresh_effect_handler.gd",
	"res://core/shop/handlers/next_discount_effect_handler.gd",
]
const COMMAND_PORT_PATHS: Array[String] = [
	"res://core/ports/query_replay_command_port.gd",
	"res://core/ports/route_reward_command_port.gd",
	"res://core/ports/shop_inventory_command_port.gd",
	"res://core/ports/run_flow_command_port.gd",
	"res://core/ports/battle_command_port.gd",
]

var _failed := false


func _initialize() -> void:
	_verify_thin_handlers(COMMAND_HANDLER_PATHS, "command")
	_verify_thin_handlers(SHOP_HANDLER_PATHS, "shop effect")
	var all_port_paths: Array[String] = COMMAND_PORT_PATHS.duplicate()
	all_port_paths.append("res://core/ports/shop_effect_port.gd")
	all_port_paths.append("res://core/ports/relic_combat_port.gd")
	all_port_paths.append("res://core/ports/run_history_port.gd")
	_verify_versioned_ports(all_port_paths)
	_verify_relic_service_boundary()
	_verify_authority_adapter_boundary()
	_verify_documented_decision()
	if _failed:
		quit(1)
		return
	print("SMOKE_STS2_GUIDED_CAPABILITY_BOUNDARIES_OK command_domains=5 shop_handlers=6 relic_port=v1")
	quit(0)


func _verify_thin_handlers(paths: Array[String], label: String) -> void:
	for path in paths:
		var source := FileAccess.get_file_as_string(path)
		_expect(source.contains("func execute(port: RefCounted"), "%s %s receives an explicit Port" % [label, path])
		_expect(source.contains("PORT_CONTRACT_ID"), "%s %s declares a versioned contract" % [label, path])
		_expect(not source.contains("func execute(core"), "%s %s never receives the complete core" % [label, path])
		_expect(not source.contains("core."), "%s %s cannot probe or mutate the complete core" % [label, path])


func _verify_versioned_ports(paths: Array[String]) -> void:
	for path in paths:
		var source := FileAccess.get_file_as_string(path)
		_expect(source.contains("const CONTRACT_ID := &\"ysbzs."), "%s declares a ysbzs versioned contract" % path)
		_expect(source.contains("func contract_id() -> StringName"), "%s publishes its contract identity" % path)


func _verify_relic_service_boundary() -> void:
	var source := FileAccess.get_file_as_string("res://core/battle/relics/relic_combat_service.gd")
	_expect(source.contains("PORT_CONTRACT_ID := &\"ysbzs.relic-combat-port.v1\""), "relic service pins the supported Port version")
	_expect(source.contains("REQUIRED_PORT_METHODS"), "relic service fails closed on missing capabilities")
	_expect(not source.contains("authority: Object"), "relic service never receives complete authority")
	_expect(not source.contains("authority.get(") and not source.contains("authority.set("), "relic service cannot reflect authority state")


func _verify_authority_adapter_boundary() -> void:
	var factory := FileAccess.get_file_as_string("res://core/commands/command_port_factory.gd")
	_expect(factory.contains("authority: Object"), "command Port factory is the explicit authority-to-adapter composition seam")
	_expect(not factory.contains("authority.get(") and not factory.contains("authority.set(") and not factory.contains("authority.call("), "command Port factory only selects adapters and never uses authority capabilities")
	var projection := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	_expect(projection.contains('handler.call("execute", port, action_type, action)'), "command projection gives handlers only a domain Port")
	_expect(not projection.contains('handler.call("execute", self, action_type, action)'), "command projection never gives handlers the full state")
	var run_source := projection
	_expect(run_source.contains('handler.call("execute", ShopEffectPortScript.new(self), offer, effect)'), "shop effect dispatch creates its capability adapter at the authority boundary")
	var shared_query_methods := [
		"_has_schedule_for_day",
		"_route_options_for_schedule",
		"_route_option_context",
		"_paid_refresh_cost",
		"_shop_seen_pet_ids_for_day",
		"_is_formal",
		"_day_expr_allows",
		"_available_shop_events",
		"_available_route_events",
		"_normalize_difficulty",
		"_board_label",
		"_max_scheduled_day",
		"_pet_reset_alive_threshold",
		"_quality_mode_options",
		"_unit_supports_quality_mode",
		"_quality_mode_for_unit",
		"_unit_supports_quality_mark",
		"_quality_mark_for_unit",
		"_resolved_stat_value",
		"_direction_label",
		"_normalize_direction",
		"_cell_elements_at",
		"_board_trace_at",
		"_board_traces_at",
		"_replay_debug_entry",
		"_checksum",
	]
	for method_name in shared_query_methods:
		var signature := "func %s(" % method_name
		_expect(projection.count(signature) == 1, "single authority owns shared query %s exactly once" % method_name)
	for legacy_path in [
		"res://core/state/state_base.gd",
		"res://core/party/catalog_roster_core.gd",
		"res://core/commands/command_projection_core.gd",
		"res://core/battle/battle_rules_core.gd",
		"res://core/run/run_flow_core.gd",
		"res://persistence/compatibility/persistence_core.gd",
	]:
		_expect(not FileAccess.file_exists(legacy_path), "legacy authority layer stays deleted: %s" % legacy_path)


func _verify_documented_decision() -> void:
	var architecture := FileAccess.get_file_as_string("res://docs/03_CORE_ARCHITECTURE.md")
	var sts2_map := FileAccess.get_file_as_string("res://docs/15_STS2_GUIDED_ARCHITECTURE_MAP.md")
	for phrase in ["CommandPortFactory", "ShopEffectPort", "RelicCombatPort"]:
		_expect(architecture.contains(phrase), "core architecture documents %s" % phrase)
		_expect(sts2_map.contains(phrase), "STS2 decision map documents %s" % phrase)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_STS2_GUIDED_CAPABILITY_BOUNDARIES_FAIL: %s" % message)
