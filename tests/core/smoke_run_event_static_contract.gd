extends SceneTree

const HANDLER_DIRECTORY := "res://core/run/events/handlers"
const LEGACY_CATALOG := "res://core/run/events/legacy_run_event_catalog.gd"
const COMPOSITION_PATH := "res://core/composition/core_composition.gd"
const STATE_PATH := "res://core/state/game_state.gd"
const E0_DIRECTORIES := [
	"res://core/run/events",
	"res://tests/fixtures/plugins/run_event",
]
const E0_SINGLE_SCRIPT_PATHS := [
	"res://core/run/run_event_effect_service.gd",
	"res://core/ports/run_event_port.gd",
	"res://tests/core/smoke_run_event_effect_service.gd",
	"res://tests/core/smoke_run_event_operation_params.gd",
	"res://tests/core/smoke_run_event_operation_plugin_discovery.gd",
	"res://tests/core/smoke_run_event_operations_behavior.gd",
	"res://tests/core/smoke_run_event_port_transaction.gd",
	"res://tests/core/smoke_run_event_static_contract.gd",
]
const HANDLER_FORBIDDEN_TOKENS := [
	"_authority",
	"FileAccess",
	"DirAccess",
	"port.get(",
	"port.set(",
	"port.call(",
	"core/state",
	"core/composition",
]
const CORE_FORBIDDEN_EVENT_TOKENS := [
	"evt_battle_fail",
	"evt_battle_bonus",
	"find(\"护盾\")",
	"find(\"金币\")",
	"find(\"免费刷新\")",
	"find(\"折扣\")",
	"find(\"复制\")",
	"find(\"升阶\")",
	"find(\"升级\")",
	"find(\"候选\")",
	"find(\"商品位\")",
	"find(\"补货\")",
]

var _failed := false


func _initialize() -> void:
	_verify_handler_boundary()
	_verify_service_boundary()
	_verify_port_boundary()
	_verify_production_wiring()
	_verify_no_legacy_literal_execution()
	_verify_uid_delivery()
	if _failed:
		quit(1)
		return
	print("SMOKE_RUN_EVENT_STATIC_CONTRACT_OK handlers=13 wiring=2 uid=0")
	quit(0)


func _verify_handler_boundary() -> void:
	var files := DirAccess.get_files_at(HANDLER_DIRECTORY)
	files.sort()
	var handler_count := 0
	for file_name in files:
		if not file_name.ends_with(".gd"):
			continue
		handler_count += 1
		var path := "%s/%s" % [HANDLER_DIRECTORY, file_name]
		var source := FileAccess.get_file_as_string(path)
		_expect(source.contains("func plugin_id() -> String"), "%s has typed plugin_id" % file_name)
		_expect(source.contains("func _validate_params(params: Dictionary) -> Array[String]"), "%s has typed private validator" % file_name)
		_expect(source.contains("-> Dictionary:"), "%s has typed Dictionary execution result" % file_name)
		for forbidden in HANDLER_FORBIDDEN_TOKENS:
			_expect(not source.contains(forbidden), "%s does not contain forbidden token %s" % [file_name, forbidden])
	_expect(handler_count == 13, "repository contains exactly 13 production handlers")


func _verify_service_boundary() -> void:
	var source := FileAccess.get_file_as_string("res://core/run/run_event_effect_service.gd")
	_expect(source.contains('const CONTEXT_KINDS := ["shop_event", "route_event", "rest", "post_battle"]'), "Service freezes the four structured contexts")
	_expect(source.contains('execution_context["immediate_gold"] = 0'), "Service owns transient immediate_gold accumulation")
	_expect(source.contains('String(operation.get("operation", "")) == "add_coins"'), "Service derives immediate_gold only from typed add_coins results")
	for forbidden in ['"gain"', '"option_text"', "_parse_gold", 'context.get("source"', "evt_"]:
		_expect(not source.contains(forbidden), "Service does not infer behavior from %s" % forbidden)
	_expect(not source.contains("core/state") and not source.contains("core/composition"), "Service has no state or composition dependency")


func _verify_port_boundary() -> void:
	var source := FileAccess.get_file_as_string("res://core/ports/run_event_port.gd")
	_expect(source.contains('const CONTRACT_ID := &"ysbzs.run-event-port.v1"'), "Port contract id is frozen")
	_expect(source.contains("const TRANSACTION_FIELDS: Array[StringName] = ["), "Port declares explicit transaction fields")
	_expect(not source.contains('event.get("value"'), "outer-run behavior never reads legacy event.value")
	_expect(not source.contains("core/state") and not source.contains("core/composition"), "Port does not import authority or composition")
	_expect(not source.contains("_log(") and not source.contains("log_lines"), "Port never writes authority logs")


func _verify_production_wiring() -> void:
	var composition_source := FileAccess.get_file_as_string(COMPOSITION_PATH)
	for needle in [
		'const RunEventDefinitionRegistryScript := preload("res://core/run/events/run_event_definition_registry.gd")',
		'const RunEventEffectServiceScript := preload("res://core/run/run_event_effect_service.gd")',
		"var run_event_definition_registry: RefCounted = null",
		"var run_event_effect_service: RefCounted = null",
		'run_event_definition_registry = _resolve(overrides, &"run_event_definition_registry", RunEventDefinitionRegistryScript)',
		'run_event_effect_service = _resolve(overrides, &"run_event_effect_service", RunEventEffectServiceScript)',
		'"run_event_definition_registry": run_event_definition_registry',
		'"run_event_effect_service": run_event_effect_service',
		'var run_event_prepared := Dictionary(run_event_definition_registry.call(\n\t\t&"prepare_configuration",',
		'run_event_definition_registry.call(&"commit_configuration"',
	]:
		_expect(composition_source.contains(needle), "Composition owns the run-event wire: %s" % needle)

	var state_source := FileAccess.get_file_as_string(STATE_PATH)
	for needle in [
		'const RunEventPortScript := preload("res://core/ports/run_event_port.gd")',
		"_core_composition.run_event_definition_registry.operations_for_event",
		"_core_composition.run_event_definition_registry.operations_for_rest_node",
		"_core_composition.run_event_definition_registry.matching_post_battle_events",
		"_core_composition.run_event_effect_service.execute",
		"RunEventPortScript.new(self)",
	]:
		_expect(state_source.contains(needle), "State uses the composed run-event boundary: %s" % needle)
	for removed_method in [
		"func _parse_gold_cost(",
		"func _battle_prep_effect_from_event(",
		"func _outer_run_effect_from_event(",
		"func _is_construction_duplicate_event(",
		"func _is_construction_upgrade_event(",
		"func _apply_event_effect(",
	]:
		_expect(not state_source.contains(removed_method), "State removed legacy event inference helper %s" % removed_method)


func _verify_no_legacy_literal_execution() -> void:
	_expect(FileAccess.file_exists(LEGACY_CATALOG), "legacy event definitions remain isolated for persisted snapshots")
	for path in _gd_files_recursive("res://core"):
		if path == LEGACY_CATALOG:
			continue
		var source := FileAccess.get_file_as_string(path)
		for token in CORE_FORBIDDEN_EVENT_TOKENS:
			_expect(not source.contains(token), "%s does not execute legacy event literal %s" % [path, token])


func _verify_uid_delivery() -> void:
	for directory in E0_DIRECTORIES:
		for path in _gd_files_recursive(directory):
			_expect(FileAccess.file_exists(path + ".uid"), "%s ships its stable Godot UID companion" % path)
	for path in E0_SINGLE_SCRIPT_PATHS:
		_expect(FileAccess.file_exists(path + ".uid"), "%s ships its stable Godot UID companion" % path)


func _gd_files_recursive(directory: String) -> Array[String]:
	var result: Array[String] = []
	for path in _files_recursive(directory):
		if path.ends_with(".gd"):
			result.append(path)
	return result


func _files_recursive(directory: String) -> Array[String]:
	var result: Array[String] = []
	var access := DirAccess.open(directory)
	if access == null:
		return result
	access.list_dir_begin()
	var entry := access.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var path := "%s/%s" % [directory.trim_suffix("/"), entry]
			if access.current_is_dir():
				result.append_array(_files_recursive(path))
			else:
				result.append(path)
		entry = access.get_next()
	access.list_dir_end()
	result.sort()
	return result


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_RUN_EVENT_STATIC_CONTRACT_FAIL: %s" % label)
