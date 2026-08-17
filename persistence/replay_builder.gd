extends RefCounted

## Pure replay projections. Runtime state creation and command execution
## remain in the compatibility application layer.


static func build(input: Dictionary) -> Dictionary:
	var source := input.duplicate(true)
	var command_log_value := Array(source.get("commandLog", []))
	var command_stream_value := command_stream(command_log_value)
	var debug_timeline_value := debug_timeline(
		command_stream_value,
		Array(source.get("storedDebugTimeline", []))
	)
	var initial_options := Dictionary(source.get("initialOptions", {})).duplicate(true)
	var initial_seed := String(initial_options.get("seed", source.get("seed", "")))
	var initial_day := int(initial_options.get("day", 1))
	var initial_period := String(initial_options.get("period", "上午"))
	var result := Dictionary(source.get("result", {})).duplicate(true)
	var supplied_battle_trace := Array(source.get("battleTrace", []))
	var battle_trace_value := supplied_battle_trace.duplicate(true) if not supplied_battle_trace.is_empty() else battle_trace(command_log_value)
	return {
		"schema": String(source.get("schema", "")),
		"schemaVersion": int(source.get("schemaVersion", 0)),
		"replayVersion": String(source.get("replayVersion", "")),
		"legacyReplayVersion": String(source.get("legacyReplayVersion", "")),
		"dataVersion": String(source.get("dataVersion", "")),
		"rulesVersion": String(source.get("rulesVersion", "")),
		"rngVersion": String(source.get("rngVersion", "")),
		"determinism": Dictionary(source.get("determinism", {})).duplicate(true),
		"seed": String(source.get("seed", "")),
		"day": int(source.get("day", 1)),
		"period": String(source.get("period", "上午")),
		"result": result,
		"scenario": Dictionary(source.get("scenario", {})).duplicate(true),
		"initial": {
			"options": initial_options,
			"battleId": initial_options.get("battleId", null),
			"seed": initial_seed,
			"day": initial_day,
			"period": initial_period,
			"stateHash": String(source.get("initialHash", "")),
		},
		"commandStream": command_stream_value,
		"commandCheckpoints": command_checkpoints(command_stream_value),
		"debugTimeline": debug_timeline_value,
		"summary": {
			"timelineEntries": debug_timeline_value.size(),
			"replayableCommands": command_stream_value.size(),
			"rejectedCommands": rejected_command_count(debug_timeline_value),
			"finalStateVersion": int(source.get("stateVersion", 0)),
			"finalStateHash": String(source.get("stateHash", "")),
		},
		"final": {
			"stateVersion": int(source.get("stateVersion", 0)),
			"stateHash": String(source.get("stateHash", "")),
			"phase": String(source.get("phase", "")),
			"round": int(source.get("round", 0)),
			"result": result.duplicate(true),
		},
		"inputLog": input_log(command_log_value),
		"changeLog": change_log(command_log_value),
		"battleTrace": battle_trace_value,
		"finalSummary": {
			"phase": String(source.get("phase", "")),
			"round": int(source.get("round", 0)),
			"day": int(source.get("day", 1)),
			"period": String(source.get("period", "上午")),
			"units": Array(source.get("units", [])).duplicate(true),
		},
	}


static func command_stream(command_log: Array) -> Array:
	var stream: Array = []
	for index in range(command_log.size()):
		var entry := Dictionary(command_log[index])
		var checkpoint := {
			"stateVersion": int(entry.get("afterVersion", 0)),
			"stateHash": String(entry.get("afterHash", "")),
			"beforeVersion": int(entry.get("beforeVersion", 0)),
			"beforeHash": String(entry.get("beforeHash", "")),
			"afterVersion": int(entry.get("afterVersion", 0)),
			"afterHash": String(entry.get("afterHash", "")),
			"eventIds": [event_id(index)]
		}
		stream.append({
			"index": index + 1,
			"command": Dictionary(entry.get("command", {})).duplicate(true),
			"checkpoint": checkpoint
		})
	return stream


static func input_log(command_log: Array) -> Array:
	var inputs: Array = []
	for index in range(command_log.size()):
		var entry := Dictionary(command_log[index])
		var raw := Dictionary(entry.get("raw", entry.get("command", {}))).duplicate(true)
		inputs.append({
			"inputId": "inp_%05d" % (index + 1),
			"round": int(entry.get("round", 0)),
			"phase": String(entry.get("afterPhase", entry.get("phase", "unknown"))),
			"type": String(raw.get("type", entry.get("type", "INPUT"))),
			"payload": raw
		})
	return inputs


static func change_log(command_log: Array) -> Array:
	var changes: Array = []
	for index in range(command_log.size()):
		var entry := Dictionary(command_log[index])
		var command := Dictionary(entry.get("command", {}))
		var command_type := String(command.get("type", entry.get("type", "COMMAND")))
		changes.append({
			"changeId": "chg_%05d" % (index + 1),
			"step": index + 1,
			"round": int(entry.get("round", 0)),
			"phase": String(entry.get("afterPhase", entry.get("phase", "unknown"))),
			"type": "COMMAND_ACCEPTED",
			"path": "state",
			"from": {
				"stateVersion": int(entry.get("beforeVersion", 0)),
				"stateHash": String(entry.get("beforeHash", ""))
			},
			"to": {
				"stateVersion": int(entry.get("afterVersion", 0)),
				"stateHash": String(entry.get("afterHash", ""))
			},
			"delta": 1,
			"source": {
				"commandType": command_type,
				"commandIndex": index + 1
			},
			"reason": "public_dispatch",
			"tags": ["replay", "command"]
		})
	return changes


static func battle_trace(command_log: Array) -> Array:
	var events: Array = []
	var changes := change_log(command_log)
	for index in range(changes.size()):
		var change := Dictionary(changes[index])
		var source := Dictionary(change.get("source", {})).duplicate(true)
		var event := {
			"eventId": event_id(index),
			"kind": "change",
			"type": String(change.get("type", "EVENT")),
			"step": int(change.get("step", index + 1)),
			"round": int(change.get("round", 0)),
			"phase": String(change.get("phase", "unknown")),
			"actor": null,
			"target": null,
			"payload": {
				"commandType": String(source.get("commandType", "")),
				"commandIndex": int(source.get("commandIndex", index + 1))
			},
			"changes": [battle_trace_change(change)],
			"source": source,
			"reason": change.get("reason", null),
			"tags": Array(change.get("tags", [])).duplicate(true),
			"text": null
		}
		event["protocol"] = battle_trace_protocol(event)
		event["text"] = battle_trace_text(event)
		events.append(event)
	return events


static func event_id(index: int) -> String:
	return "evt_%06d" % (index + 1)


static func battle_trace_change(change: Dictionary) -> Dictionary:
	return {
		"path": change.get("path", null),
		"from": change.get("from", null),
		"to": change.get("to", null),
		"delta": change.get("delta", null),
		"damageType": null,
		"element": null,
		"packetId": null,
		"modifierId": null,
		"source": Dictionary(change.get("source", {})).duplicate(true),
		"reason": change.get("reason", null),
		"tags": Array(change.get("tags", [])).duplicate(true)
	}


static func battle_trace_protocol(event: Dictionary) -> String:
	var parts := [
		"|%s" % String(event.get("type", "EVENT")),
		"id=%s" % String(event.get("eventId", "")),
		"round=%d" % int(event.get("round", 0)),
		"phase=%s" % String(event.get("phase", "unknown"))
	]
	var command_type := String(Dictionary(event.get("source", {})).get("commandType", ""))
	if command_type != "":
		parts.append("command=%s" % command_type)
	return "|".join(parts)


static func battle_trace_text(event: Dictionary) -> String:
	var source := Dictionary(event.get("source", {}))
	var command_type := String(source.get("commandType", String(event.get("type", "COMMAND"))))
	return "%s accepted: state checkpoint recorded." % command_type


static func debug_timeline(command_stream_value: Array, stored_timeline: Array) -> Array:
	if not stored_timeline.is_empty():
		return stored_timeline.duplicate(true)
	var timeline: Array = []
	for index in range(command_stream_value.size()):
		var item := Dictionary(command_stream_value[index])
		var command := Dictionary(item.get("command", {}))
		var checkpoint := Dictionary(item.get("checkpoint", {}))
		timeline.append(debug_entry(
			index + 1,
			command,
			int(checkpoint.get("beforeVersion", 0)),
			String(checkpoint.get("beforeHash", "")),
			int(checkpoint.get("afterVersion", 0)),
			String(checkpoint.get("afterHash", "")),
			true,
			true,
			""
		))
	return timeline


static func debug_entry(
	index: int,
	command: Dictionary,
	before_version: int,
	before_hash: String,
	after_version: int,
	after_hash: String,
	accepted: bool,
	replayable: bool,
	error: String
) -> Dictionary:
	var entry := {
		"index": index,
		"commandId": command.get("commandId", null),
		"type": String(command.get("type", "")),
		"kind": "mutation",
		"accepted": accepted,
		"replayable": replayable,
		"beforeVersion": before_version,
		"beforeHash": before_hash,
		"afterVersion": after_version,
		"afterHash": after_hash,
		"eventIds": []
	}
	if error != "":
		entry["error"] = error_payload(error)
	return entry


static func error_payload(code: String) -> Dictionary:
	return {"code": code, "message": code}


static func rejected_command_count(debug_timeline_value: Array) -> int:
	var count := 0
	for item_value in debug_timeline_value:
		if not bool(Dictionary(item_value).get("accepted", true)):
			count += 1
	return count


static func command_checkpoints(command_stream_value: Array) -> Array:
	var checkpoints: Array = []
	for item_value in command_stream_value:
		var item := Dictionary(item_value)
		var command := Dictionary(item.get("command", {}))
		checkpoints.append({
			"index": int(item.get("index", checkpoints.size() + 1)),
			"commandId": command.get("commandId", null),
			"type": String(command.get("type", "")),
			"checkpoint": Dictionary(item.get("checkpoint", {})).duplicate(true)
		})
	return checkpoints


static func verify_result(
	ok: bool,
	error: String,
	checkpoints: Array,
	final_version: int,
	final_hash: String,
	initial_hash: String = ""
) -> Dictionary:
	var result := {
		"ok": ok,
		"initialHash": initial_hash,
		"checkpoints": checkpoints,
		"finalVersion": final_version,
		"finalHash": final_hash
	}
	if error != "":
		result["error"] = error
	return result
