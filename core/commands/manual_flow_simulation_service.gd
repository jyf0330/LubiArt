extends RefCounted

## Isolated PREVIEW_MANUAL_FLOW coordinator. The source is read-only; all
## gameplay commands execute on a canonical, repository-guarded fork.

const AuthoritativeStateCodecScript := preload("res://persistence/authoritative_state_codec.gd")
const BattleQueryContextScript := preload("res://core/commands/battle_query_context.gd")
const PreviewHorizonScript := preload("res://core/commands/preview_horizon.gd")
const SIMULATION_SCHEMA := "ysbzs.simulation.v1"


func preview(
	source: Object,
	action: Dictionary,
	before_query: Dictionary,
	factory: RefCounted,
	diff_projector: RefCounted,
	battle_query_projector: RefCounted
) -> Dictionary:
	var command := action.duplicate(true)
	var query_before := before_query.duplicate(true)
	if not _valid_source(source):
		return _failure({}, [], [], ["SIMULATION_SOURCE_INVALID"], 0)
	var before_snapshot := Dictionary(source.call("snapshot"))
	var before_cells := Array(Dictionary(before_snapshot.get("board", {})).get("cells", [])).duplicate(true)
	var before_cell_details: Array = []
	if not BattleQueryContextScript.validate(query_before).is_empty():
		return _failure(before_snapshot, before_cells, before_cell_details, ["SIMULATION_BATTLE_QUERY_INVALID"], 0)
	if not _valid_battle_query_projector(battle_query_projector):
		return _failure(before_snapshot, before_cells, before_cell_details, ["SIMULATION_BATTLE_QUERY_PROJECTOR_INVALID"], 0)
	before_cell_details = Array(battle_query_projector.call(
		"project_all_cell_details", query_before
	)).duplicate(true)
	var before_units := Array(battle_query_projector.call("project_unit_diff_rows", query_before)).duplicate(true)
	var source_capture := AuthoritativeStateCodecScript.capture(source, false)
	var source_hash := String(source.call("_state_hash"))
	var source_version := int(source.get("state_version"))
	var source_history := Dictionary(source.call("run_history_status")) if source.has_method(&"run_history_status") else {}
	if factory == null or not factory.has_method(&"fork"):
		return _failure(before_snapshot, before_cells, before_cell_details, ["SIMULATION_FACTORY_INVALID"], 0)
	if diff_projector == null or not _valid_diff_projector(diff_projector):
		return _failure(before_snapshot, before_cells, before_cell_details, ["SIMULATION_DIFF_PROJECTOR_INVALID"], 0)

	var fork_result := Dictionary(factory.call("fork", source, {}))
	if not bool(fork_result.get("ok", false)):
		var fork_errors := _strings(Array(fork_result.get("errors", [])))
		if fork_errors.is_empty():
			fork_errors.append("SIMULATION_FORK_FAILED")
		return _failure(before_snapshot, before_cells, before_cell_details, fork_errors, 0)
	var fork := fork_result.get("authority") as RefCounted
	var guard := fork_result.get("ioGuard") as RefCounted
	if not _valid_fork(fork) or guard == null or not guard.has_method(&"attempts"):
		return _failure(before_snapshot, before_cells, before_cell_details, ["SIMULATION_FORK_INVALID"], 0)

	var limit: int = clamp(int(command.get("limit", 2)), 1, 4)
	var commands: Array = []
	var preview_events: Array = []
	for _index in range(limit):
		var command_type := _next_manual_flow_command_type(String(fork.get("phase")), commands)
		if command_type == "":
			break
		var trace_before := Array(fork.get("battle_trace")).size()
		var accepted := bool(fork.call("dispatch", {
			"type": command_type,
			"previewOf": String(command.get("commandId", "preview_manual_flow")),
		}))
		commands.append({
			"type": command_type,
			"ok": accepted,
			"accepted": accepted,
			"phase": String(fork.get("phase")),
			"round": int(fork.get("battle_round")),
		})
		var fork_trace := Array(fork.get("battle_trace"))
		for event_index in range(trace_before, fork_trace.size()):
			preview_events.append(Dictionary(fork_trace[event_index]).duplicate(true))
		if not accepted:
			break

	var io_attempts := Array(guard.call("attempts"))
	if not io_attempts.is_empty():
		return _failure(before_snapshot, before_cells, before_cell_details, ["SIMULATION_IO_ATTEMPT"], io_attempts.size())
	if not _source_unchanged(source, source_capture, source_hash, source_version, source_history):
		return _failure(before_snapshot, before_cells, before_cell_details, ["SIMULATION_SOURCE_MUTATED"], 0)

	var projected_snapshot := Dictionary(fork.call("snapshot"))
	var projected_cells := Array(Dictionary(projected_snapshot.get("board", {})).get("cells", [])).duplicate(true)
	var query_after := Dictionary(fork.call("_battle_query_context")).duplicate(true)
	if not BattleQueryContextScript.validate(query_after).is_empty():
		return _failure(before_snapshot, before_cells, before_cell_details, ["SIMULATION_PROJECTED_BATTLE_QUERY_INVALID"], 0)
	var projected_cell_details := Array(battle_query_projector.call(
		"project_all_cell_details", query_after
	)).duplicate(true)
	var projected_units := Array(battle_query_projector.call("project_unit_diff_rows", query_after)).duplicate(true)
	var cell_diffs := Array(diff_projector.call("cell_diffs", before_cells, projected_cells))
	var unit_diffs := Array(diff_projector.call("unit_diffs", before_units, projected_units, preview_events))
	var damage_by_unit := Dictionary(diff_projector.call("damage_by_unit", unit_diffs))
	io_attempts = Array(guard.call("attempts"))
	if not io_attempts.is_empty():
		return _failure(before_snapshot, before_cells, before_cell_details, ["SIMULATION_IO_ATTEMPT"], io_attempts.size())
	return {
		"previewHorizon": PreviewHorizonScript.MANUAL_ROUND_FLOW,
		"commands": commands,
		"events": preview_events,
		"viewModel": projected_snapshot,
		"beforeCells": before_cells,
		"beforeCellDetails": before_cell_details,
		"cells": projected_cells,
		"cellDetails": projected_cell_details,
		"cellDiffs": cell_diffs,
		"unitDiffs": unit_diffs,
		"damageByUnit": damage_by_unit,
		"projectedStateHash": String(projected_snapshot.get("stateHash", fork.call("_state_hash"))),
		"rolledBack": true,
		"stateVersion": int(before_snapshot.get("stateVersion", source_version)),
		"stateHash": String(before_snapshot.get("stateHash", source_hash)),
		"phaseBefore": String(before_snapshot.get("phase", source.get("phase"))),
		"phaseAfter": String(projected_snapshot.get("phase", fork.get("phase"))),
		"roundBefore": int(before_snapshot.get("battle_round", source.get("battle_round"))),
		"roundAfter": int(projected_snapshot.get("battle_round", fork.get("battle_round"))),
		"timing": {
			"label": "PREVIEW_MANUAL_FLOW",
			"commandCount": commands.size(),
			"cellDiffCount": cell_diffs.size(),
			"unitDiffCount": unit_diffs.size(),
		},
		"simulation": {"schema": SIMULATION_SCHEMA, "ioAttempts": 0, "isolated": true},
	}


func _next_manual_flow_command_type(phase: String, commands: Array) -> String:
	if phase != "battle":
		return ""
	var used: Array[String] = []
	for item in commands:
		if typeof(item) == TYPE_DICTIONARY:
			used.append(String(Dictionary(item).get("type", "")))
	if not used.has("RUN_PLAYER_ALL_OUT"):
		return "RUN_PLAYER_ALL_OUT"
	if not used.has("END_PLAYER_TURN"):
		return "END_PLAYER_TURN"
	return ""


func _valid_source(source: Object) -> bool:
	if source == null:
		return false
	for method_name in [&"snapshot", &"_state_hash"]:
		if not source.has_method(method_name):
			return false
	return _has_property(source, &"state_version") and _has_property(source, &"phase") and _has_property(source, &"battle_round")


func _valid_fork(fork: RefCounted) -> bool:
	if fork == null:
		return false
	for method_name in [&"dispatch", &"snapshot", &"_battle_query_context", &"_state_hash"]:
		if not fork.has_method(method_name):
			return false
	return _has_property(fork, &"battle_trace") and _has_property(fork, &"phase") and _has_property(fork, &"battle_round")


func _valid_diff_projector(projector: RefCounted) -> bool:
	for method_name in [&"cell_diffs", &"unit_diffs", &"damage_by_unit"]:
		if not projector.has_method(method_name):
			return false
	return true


func _valid_battle_query_projector(projector: RefCounted) -> bool:
	return (
		projector != null
		and projector.has_method(&"project_unit_diff_rows")
		and projector.has_method(&"project_all_cell_details")
	)


func _source_unchanged(source: Object, capture: Dictionary, hash: String, version: int, history: Dictionary) -> bool:
	if AuthoritativeStateCodecScript.capture(source, false) != capture:
		return false
	if String(source.call("_state_hash")) != hash or int(source.get("state_version")) != version:
		return false
	return not source.has_method(&"run_history_status") or Dictionary(source.call("run_history_status")) == history


func _failure(before_snapshot: Dictionary, before_cells: Array, before_cell_details: Array, errors: Array, io_attempts: int) -> Dictionary:
	var state_version := int(before_snapshot.get("stateVersion", 0))
	var state_hash := String(before_snapshot.get("stateHash", ""))
	var phase := String(before_snapshot.get("phase", ""))
	var round := int(before_snapshot.get("battle_round", 0))
	return {
		"previewHorizon": PreviewHorizonScript.MANUAL_ROUND_FLOW,
		"commands": [],
		"events": [],
		"viewModel": {},
		"beforeCells": before_cells.duplicate(true),
		"beforeCellDetails": before_cell_details.duplicate(true),
		"cells": [],
		"cellDetails": [],
		"cellDiffs": [],
		"unitDiffs": [],
		"damageByUnit": {},
		"projectedStateHash": "",
		"rolledBack": true,
		"stateVersion": state_version,
		"stateHash": state_hash,
		"phaseBefore": phase,
		"phaseAfter": phase,
		"roundBefore": round,
		"roundAfter": round,
		"timing": {"label": "PREVIEW_MANUAL_FLOW", "commandCount": 0, "cellDiffCount": 0, "unitDiffCount": 0},
		"simulation": {"schema": SIMULATION_SCHEMA, "ioAttempts": io_attempts, "isolated": false},
		"ok": false,
		"errors": _strings(errors),
	}


func _has_property(source: Object, property_name: StringName) -> bool:
	for property_value in source.get_property_list():
		if StringName(Dictionary(property_value).get("name", "")) == property_name:
			return true
	return false


func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
