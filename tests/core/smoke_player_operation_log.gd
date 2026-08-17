extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const ProjectorScript := preload("res://core/logging/player_operation_projector.gd")
const CommandContractScript := preload("res://core/commands/command_contract.gd")
const TEST_LOG_PATH := "user://smoke_player_operations.jsonl"

const COMMAND_KEYS := [
	"accepted", "action", "after", "before", "command", "durationMs", "error",
	"events", "kind", "logs", "previewSummary", "result", "timestamp", "unixMs",
]
const SAVE_LOAD_KEYS := [
	"accepted", "after", "before", "command", "kind", "slot", "timestamp", "unixMs",
]
const STATE_KEYS := [
	"ap", "battlePeriod", "battleRound", "boardHeight", "boardLabel", "boardWidth",
	"coins", "day", "difficulty", "heroHp", "nodeIndex", "phase",
	"selectedActionSlotIndex", "selectedUnitId", "stateVersion", "units",
]
const EVENT_KEYS := [
	"actorId", "actorName", "causedById", "causedByName", "eventId", "finalDamage",
	"from", "hpDamage", "hpFrom", "hpTo", "phase", "round", "shieldDamage",
	"shieldFrom", "shieldTo", "sourceType", "targetId", "targetName", "text", "to", "type",
]

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var projector: RefCounted = ProjectorScript.new()
	_test_projector_contract(projector)
	_remove_test_log()

	var state: RefCounted = StateScript.new()
	state.player_operation_log_path = TEST_LOG_PATH
	var command_fixtures: Array = []

	var accepted_response := _run_logged_command(state, projector, {"type": "START_BATTLE"}, command_fixtures)
	_expect(bool(accepted_response.get("accepted", false)), "accepted mutating command fixture succeeds")
	_expect(_read_rows().size() == 1, "accepted command appends exactly one JSONL row")

	var view_response := _run_logged_command(state, projector, {"type": "GET_CELL_DETAIL", "x": 0, "y": 0}, command_fixtures)
	_expect(bool(view_response.get("accepted", false)), "accepted view command fixture succeeds")
	_expect(_read_rows().size() == 2, "view command appends exactly one JSONL row")

	var preview_response := _run_logged_command(state, projector, {
		"type": "PREVIEW_MANUAL_FLOW",
		"limit": 1,
		"commandId": "operation-log-preview",
	}, command_fixtures)
	_expect(bool(preview_response.get("accepted", false)), "public manual-flow preview succeeds")
	_expect(_read_rows().size() == 3, "preview outer command appends once and its simulation authority appends zero rows")

	var rejected_response := _run_logged_command(state, projector, {"type": "NOT_A_REAL_COMMAND"}, command_fixtures)
	_expect(not bool(rejected_response.get("accepted", true)), "rejected command fixture fails")
	_expect(_read_rows().size() == 4, "rejected command appends exactly one JSONL row")

	var save_before: Dictionary = projector.state_summary(_state_context(state))
	var save_ok: bool = bool(state.save_to_user(0))
	var save_after: Dictionary = projector.state_summary(_state_context(state))
	_expect(not save_ok, "invalid save slot is rejected without touching real saves")
	_expect(_read_rows().size() == 5, "save attempt appends exactly one JSONL row")

	var load_before: Dictionary = projector.state_summary(_state_context(state))
	var load_ok: bool = bool(state.load_from_user(0))
	var load_after: Dictionary = projector.state_summary(_state_context(state))
	_expect(not load_ok, "invalid load slot is rejected without touching real saves")
	var rows := _read_rows()
	_expect(rows.size() == 6, "six semantic operations append exactly six JSONL rows")

	if rows.size() == 6:
		for index in range(command_fixtures.size()):
			_assert_command_row(Dictionary(rows[index]), Dictionary(command_fixtures[index]), index)
		_assert_save_load_row(Dictionary(rows[4]), "save", "SAVE_SLOT", false, save_before, save_after)
		_assert_save_load_row(Dictionary(rows[5]), "load", "LOAD_SLOT", false, load_before, load_after)

	var facade_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	for removed_method in [
		"_player_operation_state_summary", "_player_operation_event_summaries",
		"_player_operation_result_summary", "_player_operation_new_logs",
	]:
		_expect(not facade_source.contains("func %s(" % removed_method), "facade removes migrated helper %s" % removed_method)
	var projector_source := FileAccess.get_file_as_string("res://core/logging/player_operation_projector.gd")
	for forbidden in ["Time.", "FileAccess", "DirAccess", "Repository", "_core", "game_state"]:
		_expect(not projector_source.contains(forbidden), "projector stays free of I/O/authority token %s" % forbidden)

	_remove_test_log()
	if failed:
		print("SMOKE_PLAYER_OPERATION_LOG_FAIL")
		quit(1)
		return
	print("SMOKE_PLAYER_OPERATION_LOG_OK rows=%d commands=%d" % [rows.size(), command_fixtures.size()])
	quit(0)


func _test_projector_contract(projector: RefCounted) -> void:
	var context := {
		"phase": "battle", "day": 3, "nodeIndex": 2, "battleRound": 4,
		"battlePeriod": "night", "difficulty": "normal", "boardWidth": 9,
		"boardHeight": 6, "stateVersion": 7, "selectedUnitId": "u1",
		"selectedActionSlotIndex": 2, "ap": 5, "coins": 11, "heroHp": 63,
		"units": [{
			"id": "u1", "name": "甲", "side": "player", "x": 2, "y": 3,
			"hp": 8, "shield": 4, "ap": 1, "active": false, "private": "drop",
		}],
	}
	var context_before := context.duplicate(true)
	var summary: Dictionary = projector.state_summary(context)
	_expect(context == context_before, "state_summary leaves nested input unchanged")
	_expect(_sorted_keys(summary) == STATE_KEYS, "state_summary emits the exact key set")
	_expect(String(summary.get("boardLabel", "")) == "9x6", "state_summary formats boardLabel locally")
	_expect(Array(summary.get("units", [])).size() == 1, "state_summary preserves unit order")
	var summary_unit := Dictionary(Array(summary.get("units", []))[0])
	_expect(_sorted_keys(summary_unit) == ["active", "ap", "hp", "id", "name", "shield", "side", "x", "y"], "state_summary emits the exact unit key set")
	summary_unit["hp"] = 0
	_expect(int(Dictionary(Array(context.get("units", []))[0]).get("hp", -1)) == 8, "state_summary output is detached")

	var events := [{
		"eventId": "e1", "kind": "DAMAGE_APPLIED",
		"actor": {"id": "a", "name": "攻击者"},
		"target": {"id": "t", "name": "目标"},
		"payload": {
			"sourceType": "action", "causedById": "c", "causedByName": "原因",
			"from": {"x": 1, "y": 2}, "to": {"x": 3, "y": 4},
			"finalDamage": 9, "shieldDamage": 2, "hpDamage": 7,
			"hpFrom": 10, "hpTo": 3, "shieldFrom": 2, "shieldTo": 0,
		},
		"text": "造成伤害",
	}]
	var defaults := {"round": 6, "phase": "battle"}
	var events_before := events.duplicate(true)
	var defaults_before := defaults.duplicate(true)
	var event_rows: Array = projector.event_summaries(events, defaults)
	_expect(events == events_before and defaults == defaults_before, "event_summaries leaves both inputs unchanged")
	_expect(event_rows.size() == 1 and _sorted_keys(Dictionary(event_rows[0])) == EVENT_KEYS, "event_summaries emits exact keys in input order")
	_expect(int(Dictionary(event_rows[0]).get("round", -1)) == 6 and String(Dictionary(event_rows[0]).get("type", "")) == "DAMAGE_APPLIED", "event defaults and kind fallback remain compatible")
	Dictionary(Dictionary(event_rows[0]).get("from", {}))["x"] = 99
	_expect(int(Dictionary(Dictionary(events[0]).get("payload", {})).get("from", {}).get("x", -1)) == 1, "event summary output is detached")

	var long_result: Array = []
	for index in range(33):
		long_result.append({"index": index, "accepted": true})
	var long_before := long_result.duplicate(true)
	var compact := Dictionary(projector.result_summary(long_result))
	_expect(long_result == long_before, "result_summary leaves nested input unchanged")
	_expect(int(compact.get("itemCount", 0)) == 33 and Array(compact.get("firstItems", [])).size() == 32, "result_summary preserves the 32-item cap")
	_expect(not Dictionary(Array(compact.get("firstItems", []))[0]).has("accepted"), "result_summary delegates JSON-safe filtering to CommandContract")

	var preview_fixture := {
		"previewHorizon": "manual_round_flow",
		"stateVersion": 7,
		"stateHash": "source-hash",
		"projectedStateHash": "projected-hash",
		"rolledBack": true,
		"phaseBefore": "battle",
		"phaseAfter": "battle",
		"roundBefore": 1,
		"roundAfter": 2,
		"commands": [{"type": "END_PLAYER_TURN", "accepted": true, "phase": "battle", "round": 2, "private": "drop"}],
		"damageByUnit": {"u1": {"source": "manual_flow_preview", "unitId": "u1", "totalDamage": 9, "rawDamage": 11, "hpDamage": 7, "shieldDamage": 2, "hpFrom": 8, "hpTo": 1, "shieldFrom": 2, "shieldTo": 0, "lethal": false, "hits": [{"large": "drop"}]}},
		"simulation": {"schema": "ysbzs.simulation.v1", "isolated": true, "ioAttempts": 0},
	}
	var snapshot_fixture := {"board": {"cells": [{
		"x": 2, "y": 3,
		"action_preview_data": {"previewHorizon": "immediate_action", "previewId": "p1", "actorId": "a", "actorName": "甲", "targetId": "t", "targetName": "乙", "predictedDamage": 5, "predictedActionDamage": 3, "predictedSettlementDamage": 2, "predictedHpDamage": 4, "predictedShieldDamage": 1, "predictedHpFrom": 10, "predictedHpTo": 6, "predictedShieldFrom": 1, "predictedShieldTo": 0, "predictedKill": false, "private": "drop"},
	}]}}
	var preview_before := preview_fixture.duplicate(true)
	var snapshot_before := snapshot_fixture.duplicate(true)
	var preview_summary: Dictionary = projector.preview_summary(snapshot_fixture, preview_fixture)
	_expect(preview_fixture == preview_before and snapshot_fixture == snapshot_before, "preview_summary leaves both nested inputs unchanged")
	_expect(String(preview_summary.get("schema", "")) == "ysbzs.preview-summary.v1", "preview_summary emits a versioned schema")
	_expect(int(Dictionary(preview_summary.get("immediateAction", {})).get("targetCount", 0)) == 1, "preview_summary keeps compact immediate targets")
	var compact_damage := Dictionary(Dictionary(Dictionary(preview_summary.get("manualRoundFlow", {})).get("damageByUnit", {})).get("u1", {}))
	_expect(int(compact_damage.get("totalDamage", 0)) == 9 and int(compact_damage.get("hitCount", 0)) == 1, "preview_summary keeps manual damage totals and hit count")
	_expect(not compact_damage.has("hits"), "preview_summary omits full hit rows")
	_expect(projector.preview_summary(snapshot_fixture, {}).is_empty(), "preview_summary emits nothing without a manual-flow preview")

	var before_logs := ["旧日志 1", "旧日志 2", "旧日志 3"]
	var after_logs := ["新日志 2", "新日志 1", "旧日志 1", "旧日志 2"]
	var before_copy := before_logs.duplicate(true)
	var after_copy := after_logs.duplicate(true)
	_expect(projector.new_logs(before_logs, after_logs) == ["新日志 2", "新日志 1"], "new_logs preserves push-front overlap order")
	_expect(before_logs == before_copy and after_logs == after_copy, "new_logs leaves both inputs unchanged")
	_expect(projector.new_logs(after_logs, after_logs).is_empty(), "new_logs emits nothing for unchanged logs")


func _run_logged_command(state: RefCounted, projector: RefCounted, action: Dictionary, fixtures: Array) -> Dictionary:
	var before: Dictionary = projector.state_summary(_state_context(state))
	var before_logs: Array = state.log_lines.duplicate(true)
	var response := Dictionary(state.run_command(action))
	var after: Dictionary = projector.state_summary(_state_context(state))
	fixtures.append({
		"action": CommandContractScript.replay_json_safe(action),
		"before": before,
		"after": after,
		"result": projector.result_summary(response.get("result", {})),
		"previewSummary": projector.preview_summary(
			Dictionary(response.get("snapshot", {})),
			Dictionary(response.get("manualFlowPreview", {}))
		),
		"events": projector.event_summaries(Array(response.get("events", [])), {
			"round": state.battle_round,
			"phase": state.phase,
		}),
		"logs": projector.new_logs(before_logs, state.log_lines),
		"error": Dictionary(response.get("error", {})).duplicate(true),
		"accepted": bool(response.get("accepted", false)),
		"command": String(response.get("command", "")),
	})
	return response


func _assert_command_row(row: Dictionary, fixture: Dictionary, index: int) -> void:
	_expect(_sorted_keys(row) == COMMAND_KEYS, "command row %d has exact keys" % index)
	for key in ["action", "before", "after", "result", "previewSummary", "events", "logs", "error", "accepted", "command"]:
		_expect(_stored_equal(row.get(key), fixture.get(key)), "command row %d preserves %s semantics" % [index, key])
	_expect(String(row.get("kind", "")) == "command", "command row %d keeps kind" % index)
	_expect(int(row.get("durationMs", -1)) >= 0, "command row %d records nonnegative duration" % index)
	_assert_timestamp_fields(row, "command row %d" % index)
	_assert_summary_shape(Dictionary(row.get("before", {})), "command row %d before" % index)
	_assert_summary_shape(Dictionary(row.get("after", {})), "command row %d after" % index)
	for event_value in Array(row.get("events", [])):
		_expect(_sorted_keys(Dictionary(event_value)) == EVENT_KEYS, "command row %d event has exact keys" % index)


func _assert_save_load_row(row: Dictionary, kind: String, command: String, accepted: bool, before: Dictionary, after: Dictionary) -> void:
	_expect(_sorted_keys(row) == SAVE_LOAD_KEYS, "%s row has exact keys" % kind)
	_expect(String(row.get("kind", "")) == kind and String(row.get("command", "")) == command, "%s row keeps kind/command" % kind)
	_expect(bool(row.get("accepted", not accepted)) == accepted and int(row.get("slot", -1)) == 0, "%s row keeps result/slot" % kind)
	_expect(_stored_equal(row.get("before", {}), before) and _stored_equal(row.get("after", {}), after), "%s row preserves exact summaries" % kind)
	_assert_timestamp_fields(row, "%s row" % kind)
	_assert_summary_shape(Dictionary(row.get("before", {})), "%s before" % kind)
	_assert_summary_shape(Dictionary(row.get("after", {})), "%s after" % kind)


func _assert_timestamp_fields(row: Dictionary, label: String) -> void:
	_expect(String(row.get("timestamp", "")) != "", "%s includes readable timestamp" % label)
	_expect(int(row.get("unixMs", 0)) > 0, "%s includes sortable unixMs" % label)


func _assert_summary_shape(summary: Dictionary, label: String) -> void:
	_expect(_sorted_keys(summary) == STATE_KEYS, "%s has exact state-summary keys" % label)
	_expect(String(summary.get("boardLabel", "")) == "%dx%d" % [int(summary.get("boardWidth", 0)), int(summary.get("boardHeight", 0))], "%s boardLabel matches dimensions" % label)


func _state_context(state: RefCounted) -> Dictionary:
	return {
		"phase": state.phase,
		"day": state.day,
		"nodeIndex": state.node_index,
		"battleRound": state.battle_round,
		"battlePeriod": state.battle_period,
		"difficulty": state.difficulty,
		"boardWidth": state.board_width,
		"boardHeight": state.board_height,
		"stateVersion": state.state_version,
		"selectedUnitId": state.selected_unit_id,
		"selectedActionSlotIndex": state.selected_action_slot_index,
		"ap": state.ap,
		"coins": state.coins,
		"heroHp": state.hero_hp,
		"units": state.units.duplicate(true),
	}


func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = []
	for key_value in value.keys():
		keys.append(String(key_value))
	keys.sort()
	return keys


func _stored_equal(actual: Variant, expected: Variant) -> bool:
	return actual == JSON.parse_string(JSON.stringify(expected))


func _read_rows() -> Array:
	var rows: Array = []
	if not FileAccess.file_exists(TEST_LOG_PATH):
		return rows
	for line in FileAccess.get_file_as_string(TEST_LOG_PATH).split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("SMOKE_PLAYER_OPERATION_LOG_FAIL: invalid JSONL row: %s" % line)
			failed = true
			continue
		rows.append(Dictionary(parsed))
	return rows


func _remove_test_log() -> void:
	if FileAccess.file_exists(TEST_LOG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_LOG_PATH))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_PLAYER_OPERATION_LOG_FAIL: %s" % message)
