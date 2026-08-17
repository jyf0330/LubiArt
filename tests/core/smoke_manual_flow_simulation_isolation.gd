extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const AuthoritativeStateCodecScript := preload("res://persistence/authoritative_state_codec.gd")
const ManualFlowSimulationServiceScript := preload("res://core/commands/manual_flow_simulation_service.gd")
const ManualFlowDiffProjectorScript := preload("res://core/commands/manual_flow_diff_projector.gd")
const TEST_ROOT := "user://c3_manual_flow_simulation_isolation"

var _failed := false


class EmptyGuard extends RefCounted:
	func attempts() -> Array:
		return []


class SequenceAuthority extends RefCounted:
	var phase := "battle"
	var battle_round := 1
	var battle_trace: Array = []
	var _results: Array[bool]
	var _index := 0

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func dispatch(_action: Dictionary) -> bool:
		var accepted := bool(_results[_index]) if _index < _results.size() else false
		_index += 1
		return accepted

	func snapshot() -> Dictionary:
		return {
			"stateVersion": _index,
			"stateHash": _state_hash(),
			"phase": phase,
			"battle_round": battle_round,
			"board": {"cells": []},
		}

	func _battle_query_context() -> Dictionary:
		return {
			"schema": "ysbzs.battle-query-context.v1",
			"phase": phase,
			"stateVersion": _index,
			"battleRound": battle_round,
			"difficulty": "normal",
			"board": {"width": 1, "height": 1},
			"selection": {"unitId": "", "slotIndex": 0, "ap": 0},
			"units": [],
			"defeatedUnits": [],
			"leaders": {"player": {}, "enemy": {}},
			"cellElements": {},
			"boardTraces": {},
			"actionDirections": {},
			"actionApChoices": {},
			"placementDamageByUnit": {},
			"gameData": {},
		}

	func _state_hash() -> String:
		return "sequence-%d" % _index


class SequenceFactory extends RefCounted:
	var authority: RefCounted
	var guard := EmptyGuard.new()

	func _init(results: Array[bool]) -> void:
		authority = SequenceAuthority.new(results)

	func fork(_source: Object, _options: Dictionary = {}) -> Dictionary:
		return {
			"schema": "ysbzs.simulation-fork-result.v1",
			"ok": true,
			"authority": authority,
			"ioGuard": guard,
			"sourceStateHash": "source",
			"forkStateHash": "source",
			"errors": [],
		}


func _initialize() -> void:
	_prepare_test_tree()
	_test_source_and_file_isolation_with_production_parity()
	_test_limits_and_phase()
	_test_rejection_sequences_and_failure_schema()
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))

	if _failed:
		quit(1)
		return
	print("SMOKE_MANUAL_FLOW_SIMULATION_ISOLATION_OK source=unchanged files=unchanged parity=exact limits=0,1,4")
	quit(0)


func _test_source_and_file_isolation_with_production_parity() -> void:
	var source: RefCounted = StateScript.new()
	source.call("set_run_seed", "manual-flow-isolation")
	_expect(source.call("dispatch", {"type": "START_BATTLE"}), "fixture enters battle")
	source.set("defeated_units", [{"id": "preview-defeated", "side": "enemy", "hp": 0}])
	source.set("reward_fallback_audit", [{"seed": "preview-audit", "reason": "fixture"}])
	source.call("set_run_history_root", TEST_ROOT.path_join("history"))
	source.set("player_operation_log_path", TEST_ROOT.path_join("operations.jsonl"))
	source.set("history_recording_enabled", true)
	source.set("history_run_id", "source-run")
	source.set("history_branch_id", "source-branch")
	source.set("history_command_index", 9)

	var source_capture := AuthoritativeStateCodecScript.capture(source, false)
	var source_hash := String(source.call("_state_hash"))
	var source_version := int(source.get("state_version"))
	var source_history := Dictionary(source.call("run_history_status"))
	var source_command_log := Array(source.get("command_log")).duplicate(true)
	var source_trace := Array(source.get("battle_trace")).duplicate(true)
	var source_rng_counters := _rng_counters(source)
	var files_before := _file_tree(ProjectSettings.globalize_path(TEST_ROOT))

	var production_clone: RefCounted = StateScript.new()
	AuthoritativeStateCodecScript.restore(production_clone, source_capture)
	production_clone.set("history_recording_enabled", false)
	production_clone.set("_history_suspended", true)
	var expected := _execute_production_projection(source, production_clone, {"commandId": "parity", "limit": 2})
	var preview := Dictionary(source.call("_manual_flow_preview", {"commandId": "parity", "limit": 2}))

	_expect(Array(preview.get("commands", [])) == Array(expected.get("commands", [])), "simulation commands equal an independent production clone")
	_expect(Array(preview.get("events", [])) == Array(expected.get("events", [])), "simulation trace equals an independent production clone")
	_expect(Dictionary(preview.get("viewModel", {})) == Dictionary(expected.get("viewModel", {})), "simulation projected Snapshot equals production")
	_expect(Array(preview.get("beforeCellDetails", [])) == Array(expected.get("beforeCellDetails", [])), "simulation source cell details equal value projection")
	_expect(Array(preview.get("cellDetails", [])) == Array(expected.get("cellDetails", [])), "simulation projected cell details equal value projection")
	_expect(Array(preview.get("cellDiffs", [])) == Array(expected.get("cellDiffs", [])), "simulation cell diffs equal production")
	_expect(Array(preview.get("unitDiffs", [])) == Array(expected.get("unitDiffs", [])), "simulation unit diffs equal production")
	_expect(Dictionary(preview.get("damageByUnit", {})) == Dictionary(expected.get("damageByUnit", {})), "simulation damage projection equals production")
	_expect(String(preview.get("projectedStateHash", "")) == String(expected.get("projectedStateHash", "")), "simulation projected hash equals production")
	_expect(bool(preview.get("rolledBack", false)), "preview preserves the rolledBack compatibility field")
	var simulation := Dictionary(preview.get("simulation", {}))
	_expect(String(simulation.get("schema", "")) == "ysbzs.simulation.v1" and bool(simulation.get("isolated", false)), "preview reports isolated simulation diagnostics")
	_expect(int(simulation.get("ioAttempts", -1)) == 0, "preview reports zero repository attempts")

	_expect(AuthoritativeStateCodecScript.capture(source, false) == source_capture, "preview leaves every canonical field unchanged")
	_expect(String(source.call("_state_hash")) == source_hash and int(source.get("state_version")) == source_version, "preview leaves source hash and version unchanged")
	_expect(Dictionary(source.call("run_history_status")) == source_history, "preview leaves history metadata unchanged")
	_expect(Array(source.get("command_log")) == source_command_log and Array(source.get("battle_trace")) == source_trace, "preview leaves source command log and trace unchanged")
	_expect(_rng_counters(source) == source_rng_counters, "preview leaves deterministic counters unchanged")
	_expect(Array(source.get("defeated_units")) == Array(source_capture.get("defeated_units", [])), "preview preserves defeated_units on source")
	_expect(Array(source.get("reward_fallback_audit")) == Array(source_capture.get("reward_fallback_audit", [])), "preview preserves reward fallback audit on source")
	_expect(_file_tree(ProjectSettings.globalize_path(TEST_ROOT)) == files_before, "history/log/save/replay file tree remains byte-identical")


func _test_limits_and_phase() -> void:
	var battle: RefCounted = StateScript.new()
	_expect(battle.call("dispatch", {"type": "START_BATTLE"}), "limit fixture enters battle")
	var limit_zero := Dictionary(battle.call("_manual_flow_preview", {"limit": 0, "commandId": "limit-zero"}))
	var limit_one := Dictionary(battle.call("_manual_flow_preview", {"limit": 1, "commandId": "limit-one"}))
	var limit_four := Dictionary(battle.call("_manual_flow_preview", {"limit": 4, "commandId": "limit-four"}))
	_expect(Array(limit_zero.get("commands", [])).size() == 1, "limit 0 preserves legacy clamp-to-one behavior")
	_expect(Array(limit_one.get("commands", [])).size() == 1, "limit 1 executes one command")
	_expect(Array(limit_four.get("commands", [])).size() == 2, "limit 4 stops after the fixed two-command sequence")
	var public_version := int(battle.get("state_version"))
	var public_hash := String(battle.call("_state_hash"))
	var public_response := Dictionary(battle.call("run_command", {"type": "PREVIEW_MANUAL_FLOW", "limit": 1, "commandId": "public-preview"}))
	var public_result := Dictionary(public_response.get("result", {}))
	_expect(bool(public_response.get("accepted", false)) and Array(public_result.get("commands", [])).size() == 1, "public PREVIEW_MANUAL_FLOW command returns the isolated projection")
	_expect(int(battle.get("state_version")) == public_version and String(battle.call("_state_hash")) == public_hash, "public preview command preserves source version and hash")
	var route: RefCounted = StateScript.new()
	var non_battle := Dictionary(route.call("_manual_flow_preview", {"limit": 4, "commandId": "route"}))
	_expect(Array(non_battle.get("commands", [])).is_empty(), "non-battle preview executes no commands")
	_expect(String(non_battle.get("phaseBefore", "")) == "route" and String(non_battle.get("phaseAfter", "")) == "route", "non-battle projection keeps phase")


func _test_rejection_sequences_and_failure_schema() -> void:
	var source: RefCounted = StateScript.new()
	_expect(source.call("dispatch", {"type": "START_BATTLE"}), "rejection fixture enters battle")
	var service: RefCounted = ManualFlowSimulationServiceScript.new()
	var projector: RefCounted = ManualFlowDiffProjectorScript.new()
	var query_projector: RefCounted = source.get("_core_composition").battle_query_projector
	var before_query := Dictionary(source.call("_battle_query_context"))
	var before_query_copy := before_query.duplicate(true)
	var first_rejected := Dictionary(service.call("preview", source, {"limit": 4}, before_query, SequenceFactory.new([false]), projector, query_projector))
	_expect(Array(first_rejected.get("commands", [])).size() == 1 and not bool(Dictionary(Array(first_rejected.get("commands", []))[0]).get("accepted", true)), "first rejected command stops the sequence")
	var second_rejected := Dictionary(service.call("preview", source, {"limit": 4}, before_query, SequenceFactory.new([true, false]), projector, query_projector))
	var second_commands := Array(second_rejected.get("commands", []))
	_expect(second_commands.size() == 2 and bool(Dictionary(second_commands[0]).get("accepted", false)) and not bool(Dictionary(second_commands[1]).get("accepted", true)), "second rejected command preserves the accepted first result and stops")
	var failed := Dictionary(service.call("preview", source, {}, before_query, RefCounted.new(), projector, query_projector))
	var required_keys := [
		"previewHorizon", "commands", "events", "viewModel", "beforeCells", "beforeCellDetails", "cells", "cellDetails", "cellDiffs", "unitDiffs",
		"damageByUnit", "projectedStateHash", "rolledBack", "stateVersion", "stateHash", "phaseBefore", "phaseAfter", "roundBefore", "roundAfter", "timing",
	]
	for key in required_keys:
		_expect(failed.has(key), "failed projection preserves public key %s" % key)
	_expect(not bool(failed.get("ok", true)) and Array(failed.get("errors", [])).has("SIMULATION_FACTORY_INVALID"), "failed projection adds stable failure diagnostics")
	_expect(before_query == before_query_copy, "simulation service leaves the explicit beforeQuery value unchanged")
	var service_source := FileAccess.get_file_as_string("res://core/commands/manual_flow_simulation_service.gd")
	var facade_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	_expect(not service_source.contains('call("_unit_diff_rows")'), "simulation service no longer reflects through Facade unit rows")
	_expect(not service_source.contains('call("_all_cell_details")'), "simulation service no longer reflects through Facade cell details")
	_expect(not facade_source.contains("func _unit_diff_rows("), "Facade unit-row adapter is deleted")
	_expect(not facade_source.contains("func _preview_manual_flow("), "C3 temporary manual-flow shell is deleted")
	_expect(not facade_source.contains("func _all_cell_details("), "Facade all-cell detail helper is deleted")
	_expect(not facade_source.contains("func _cell_detail_unit("), "Facade unit-detail formatter is deleted")


func _execute_production_projection(source: RefCounted, clone: RefCounted, action: Dictionary) -> Dictionary:
	var before_snapshot := Dictionary(source.call("snapshot"))
	var before_cells := Array(Dictionary(before_snapshot.get("board", {})).get("cells", [])).duplicate(true)
	var query_projector: RefCounted = source.get("_core_composition").battle_query_projector
	var before_cell_details := Array(query_projector.call(
		"project_all_cell_details", source.call("_battle_query_context")
	)).duplicate(true)
	var before_units := Array(query_projector.call("project_unit_diff_rows", source.call("_battle_query_context"))).duplicate(true)
	var commands: Array = []
	var events: Array = []
	for command_type in ["RUN_PLAYER_ALL_OUT", "END_PLAYER_TURN"]:
		var trace_before := Array(clone.get("battle_trace")).size()
		var accepted := bool(clone.call("dispatch", {"type": command_type, "previewOf": String(action.get("commandId", "preview_manual_flow"))}))
		commands.append({
			"type": command_type,
			"ok": accepted,
			"accepted": accepted,
			"phase": String(clone.get("phase")),
			"round": int(clone.get("battle_round")),
		})
		var trace := Array(clone.get("battle_trace"))
		for index in range(trace_before, trace.size()):
			events.append(Dictionary(trace[index]).duplicate(true))
		if not accepted:
			break
	var projected_snapshot := Dictionary(clone.call("snapshot"))
	var projected_cells := Array(Dictionary(projected_snapshot.get("board", {})).get("cells", [])).duplicate(true)
	var projected_cell_details := Array(query_projector.call(
		"project_all_cell_details", clone.call("_battle_query_context")
	)).duplicate(true)
	var projected_units := Array(query_projector.call("project_unit_diff_rows", clone.call("_battle_query_context"))).duplicate(true)
	var projector: RefCounted = ManualFlowDiffProjectorScript.new()
	var cell_diffs := Array(projector.call("cell_diffs", before_cells, projected_cells))
	var unit_diffs := Array(projector.call("unit_diffs", before_units, projected_units, events))
	return {
		"commands": commands,
		"events": events,
		"viewModel": projected_snapshot,
		"beforeCellDetails": before_cell_details,
		"cellDetails": projected_cell_details,
		"cellDiffs": cell_diffs,
		"unitDiffs": unit_diffs,
		"damageByUnit": Dictionary(projector.call("damage_by_unit", unit_diffs)),
		"projectedStateHash": String(projected_snapshot.get("stateHash", "")),
	}


func _rng_counters(state: RefCounted) -> Dictionary:
	return {
		"shop_roll_count": int(state.get("shop_roll_count")),
		"shop_context_roll_count": int(state.get("shop_context_roll_count")),
		"shop_free_rolls": int(state.get("shop_free_rolls")),
		"shop_paid_refreshes": int(state.get("shop_paid_refreshes")),
	}


func _prepare_test_tree() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT)
	_remove_tree(absolute)
	for relative in ["history", "save", "replay"]:
		DirAccess.make_dir_recursive_absolute(absolute.path_join(relative))
	_write_bytes(absolute.path_join("history/run.json"), "history-sentinel".to_utf8_buffer())
	_write_bytes(absolute.path_join("operations.jsonl"), "operation-sentinel\n".to_utf8_buffer())
	_write_bytes(absolute.path_join("save/slot.json"), "save-sentinel".to_utf8_buffer())
	_write_bytes(absolute.path_join("replay/replay.json"), "replay-sentinel".to_utf8_buffer())


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_expect(false, "test can create sentinel %s" % path)
		return
	file.store_buffer(bytes)
	file.close()


func _file_tree(absolute_root: String) -> Dictionary:
	var result := {}
	_collect_files(absolute_root, "", result)
	return result


func _collect_files(absolute_root: String, relative: String, result: Dictionary) -> void:
	var directory_path := absolute_root if relative == "" else absolute_root.path_join(relative)
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if name == "." or name == "..":
			name = directory.get_next()
			continue
		var child_relative := name if relative == "" else relative.path_join(name)
		if directory.current_is_dir():
			_collect_files(absolute_root, child_relative, result)
		else:
			result[child_relative] = FileAccess.get_file_as_bytes(absolute_root.path_join(child_relative)).hex_encode()
		name = directory.get_next()
	directory.list_dir_end()


func _remove_tree(absolute_path: String) -> void:
	var directory := DirAccess.open(absolute_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if name == "." or name == "..":
			name = directory.get_next()
			continue
		var child := absolute_path.path_join(name)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_MANUAL_FLOW_SIMULATION_ISOLATION_FAIL: %s" % message)
