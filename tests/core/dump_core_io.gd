extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := StateScript.new()
	state.set_run_seed("core-io-golden")
	var initial := state.snapshot()
	var stale := state.run_command({
		"type": "START_BATTLE",
		"commandId": "godot_stale_start",
		"baseStateVersion": int(initial.get("stateVersion", 0)) - 1
	})
	var start := state.run_command({
		"type": "START_BATTLE",
		"commandId": "godot_start",
		"baseStateVersion": int(state.snapshot().get("stateVersion", 0))
	})
	var after_start := state.snapshot()
	var player_unit_id := _first_player_unit_id(after_start)
	var select := state.run_command({
		"type": "SELECT_UNIT",
		"unitId": player_unit_id,
		"commandId": "godot_select",
		"baseStateVersion": int(state.snapshot().get("stateVersion", 0))
	})
	var before_replay_version := int(state.snapshot().get("stateVersion", 0))
	var before_replay_hash := String(state.snapshot().get("stateHash", ""))
	var replay := state.run_command({
		"type": "EXPORT_REPLAY",
		"commandId": "godot_replay"
	})
	var after_replay := state.snapshot()
	var save_doc := state.save_document("p1", {"createdAt": "core-io-golden"})
	var payload := {
		"engine": "godot",
		"initial": _snapshot_summary(initial),
		"responses": {
			"staleStart": _response_summary(stale),
			"startBattle": _response_summary(start),
			"selectUnit": _response_summary(select),
			"exportReplay": _response_summary(replay)
		},
		"stateAfterReplay": _snapshot_summary(after_replay),
		"replayImmutability": {
			"beforeVersion": before_replay_version,
			"afterVersion": int(after_replay.get("stateVersion", -1)),
			"beforeHash": before_replay_hash,
			"afterHash": String(after_replay.get("stateHash", ""))
		},
		"save": _save_summary(save_doc)
	}
	print("CORE_IO_DUMP_JSON %s" % JSON.stringify(payload))
	quit(0)

func _first_player_unit_id(snapshot: Dictionary) -> String:
	for item in Array(snapshot.get("units", [])):
		var unit := Dictionary(item)
		if String(unit.get("side", "")) == "player":
			return String(unit.get("id", ""))
	return ""

func _snapshot_summary(snapshot: Dictionary) -> Dictionary:
	var view_model := Dictionary(snapshot.get("viewModel", {}))
	return {
		"phase": String(snapshot.get("phase", "")),
		"stateVersion": int(snapshot.get("stateVersion", -1)),
		"stateHash": String(snapshot.get("stateHash", "")),
		"gold": int(view_model.get("gold", snapshot.get("coins", -1))),
		"round": int(view_model.get("round", snapshot.get("battle_round", -1))),
		"period": String(view_model.get("period", snapshot.get("battle_period", ""))),
		"heroCount": Array(view_model.get("heroes", [])).size(),
		"enemyCount": Array(view_model.get("enemies", [])).size(),
		"board": _board_summary(Dictionary(view_model.get("board", snapshot.get("board", {})))),
		"nextActionTypes": _next_action_types(Array(view_model.get("nextActions", snapshot.get("nextActions", [])))),
		"viewModelKeys": _sorted_keys(view_model)
	}

func _response_summary(response: Dictionary) -> Dictionary:
	var view_model := Dictionary(response.get("viewModel", {}))
	return {
		"ok": bool(response.get("ok", false)),
		"accepted": bool(response.get("accepted", false)),
		"readOnly": bool(response.get("readOnly", false)),
		"ephemeral": bool(response.get("ephemeral", false)),
		"command": String(response.get("command", "")),
		"commandEnvelopeType": String(Dictionary(response.get("commandEnvelope", {})).get("type", "")),
		"stateVersion": int(response.get("stateVersion", -1)),
		"stateHash": String(response.get("stateHash", "")),
		"errorCode": String(Dictionary(response.get("error", {})).get("code", "")),
		"resultSchema": String(Dictionary(response.get("result", {})).get("schema", "")),
		"eventCount": Array(response.get("events", [])).size(),
		"traceEventCount": _trace_event_count(response.get("trace", [])),
		"viewModelKeys": _sorted_keys(view_model),
		"viewModel": {
			"phase": String(view_model.get("phase", "")),
			"gold": int(view_model.get("gold", -1)),
			"round": int(view_model.get("round", -1)),
			"period": String(view_model.get("period", "")),
			"heroCount": Array(view_model.get("heroes", [])).size(),
			"enemyCount": Array(view_model.get("enemies", [])).size(),
			"selectedUnitId": String(Dictionary(view_model.get("selected", {})).get("unitId", "")),
			"board": _board_summary(Dictionary(view_model.get("board", {}))),
			"nextActionTypes": _next_action_types(Array(view_model.get("nextActions", [])))
		}
	}

func _board_summary(board: Dictionary) -> Dictionary:
	var cells := Array(board.get("cells", []))
	var first := Dictionary(cells[0]) if not cells.is_empty() else {}
	return {
		"size": int(board.get("size", 0)),
		"cellCount": cells.size(),
		"firstCellKeys": _sorted_keys(first),
		"firstCell": {
			"r": first.get("r", null),
			"c": first.get("c", null),
			"key": first.get("key", null),
			"unitId": first.get("unitId", null),
			"unitSide": first.get("unitSide", null),
			"x": first.get("x", null),
			"y": first.get("y", null)
		}
	}

func _save_summary(doc: Dictionary) -> Dictionary:
	var saved := Dictionary(doc.get("state", {}))
	return {
		"schema": String(doc.get("schema", "")),
		"schemaVersion": int(doc.get("schemaVersion", -1)),
		"hasChecksum": String(doc.get("checksum", "")) != "",
		"stateKeys": _sorted_keys(saved),
		"state": {
			"coins": int(saved.get("coins", -1)),
			"gold": int(saved.get("gold", -1)),
			"battle_round": int(saved.get("battle_round", -1)),
			"round": int(saved.get("round", -1)),
			"battle_period": String(saved.get("battle_period", "")),
			"period": String(saved.get("period", ""))
		}
	}

func _next_action_types(actions: Array) -> Array:
	var out: Array = []
	for item in actions:
		out.append(String(Dictionary(item).get("type", "")))
	return out

func _trace_event_count(trace: Variant) -> int:
	if typeof(trace) == TYPE_ARRAY:
		return Array(trace).size()
	if typeof(trace) == TYPE_DICTIONARY:
		return Array(Dictionary(trace).get("events", [])).size()
	return 0

func _sorted_keys(value: Dictionary) -> Array:
	var out: Array = []
	for key in value.keys():
		out.append(String(key))
	out.sort()
	return out
