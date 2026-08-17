extends SceneTree

const DocumentCodecScript := preload("res://persistence/save_codec.gd")
const StateScript := preload("res://core/state/game_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var state := _baseline_state()
	state.set_run_seed("core-io-golden")
	var initial: Dictionary = state.snapshot()
	var start: Dictionary = state.run_command({
		"type": "START_BATTLE",
		"commandId": "puzzle_baseline_start",
		"baseStateVersion": int(initial.get("stateVersion", 0))
	})
	var after_start: Dictionary = state.snapshot()
	var player_unit_id := _first_player_unit_id(after_start)
	var select: Dictionary = state.run_command({
		"type": "SELECT_UNIT",
		"unitId": player_unit_id,
		"commandId": "puzzle_baseline_select",
		"baseStateVersion": int(after_start.get("stateVersion", 0))
	})
	var after_select: Dictionary = state.snapshot()
	var replay_response: Dictionary = state.run_command({
		"type": "EXPORT_REPLAY",
		"commandId": "puzzle_baseline_replay",
		"playerId": "p1"
	})
	var after_replay: Dictionary = state.snapshot()
	var replay := Dictionary(replay_response.get("result", {}))
	var save: Dictionary = state.save_document("p1", {"createdAt": "puzzle-refactor-baseline"})
	var command_stream := Array(replay.get("commandStream", []))
	var first_checkpoint := _checkpoint(command_stream, 0)
	var last_checkpoint := _checkpoint(command_stream, command_stream.size() - 1)
	var save_checksum := String(save.get("checksum", ""))
	var recomputed_save_checksum := DocumentCodecScript.save_checksum(save)
	var replay_checksum := String(replay.get("checksum", ""))
	var recomputed_replay_checksum := DocumentCodecScript.replay_checksum(replay)
	var replay_summary := Dictionary(replay.get("summary", {}))
	var replay_final := Dictionary(replay.get("final", {}))
	_expect_response(start, "START_BATTLE", failures)
	_expect(not player_unit_id.is_empty(), "START_BATTLE exposes a player unit id", failures)
	_expect_response(select, "SELECT_UNIT", failures)
	_expect_response(replay_response, "EXPORT_REPLAY", failures)
	_expect(String(save.get("schema", "")) == "ysbzs.save", "save schema is ysbzs.save", failures)
	_expect(int(save.get("schemaVersion", -1)) > 0, "save schemaVersion is positive", failures)
	_expect(not save_checksum.is_empty(), "save checksum is non-empty", failures)
	_expect(save_checksum == recomputed_save_checksum, "save checksum matches recomputed checksum", failures)
	_expect(String(replay.get("schema", "")) == "ysbzs.replay", "replay schema is ysbzs.replay", failures)
	_expect(int(replay.get("schemaVersion", -1)) > 0, "replay schemaVersion is positive", failures)
	_expect(not replay_checksum.is_empty(), "replay checksum is non-empty", failures)
	_expect(replay_checksum == recomputed_replay_checksum, "replay checksum matches recomputed checksum", failures)
	_expect(not command_stream.is_empty(), "replay commandStream is non-empty", failures)
	_expect(not first_checkpoint.is_empty(), "replay first checkpoint is present", failures)
	_expect(not last_checkpoint.is_empty(), "replay last checkpoint is present", failures)
	_expect(
		int(after_select.get("stateVersion", -1)) == int(after_replay.get("stateVersion", -1)),
		"EXPORT_REPLAY preserves stateVersion",
		failures
	)
	_expect(
		String(after_select.get("stateHash", "")) == String(after_replay.get("stateHash", "")),
		"EXPORT_REPLAY preserves stateHash",
		failures
	)
	_expect(
		String(replay_final.get("stateHash", "")) == String(after_select.get("stateHash", "")),
		"replay final hash matches state after SELECT_UNIT",
		failures
	)
	_expect(
		int(replay_final.get("stateVersion", -1)) == int(after_select.get("stateVersion", -1)),
		"replay final version matches state after SELECT_UNIT",
		failures
	)
	_expect(
		String(replay_summary.get("finalStateHash", "")) == String(after_select.get("stateHash", "")),
		"replay summary final hash matches state after SELECT_UNIT",
		failures
	)
	_expect(
		String(Dictionary(replay.get("initial", {})).get("stateHash", "")) == String(initial.get("stateHash", "")),
		"replay initial hash matches initial snapshot",
		failures
	)
	if not failures.is_empty():
		for failure in failures:
			push_error("PUZZLE_REFACTOR_BASELINE_FAIL %s" % failure)
		quit(1)
		return
	var summary := {
		"probeContract": "puzzle_refactor_baseline_v1",
		"assertions": "pass",
		"state": {
			"initialHash": String(initial.get("stateHash", "")),
			"startResponseHash": String(start.get("stateHash", "")),
			"afterStartHash": String(after_start.get("stateHash", "")),
			"selectResponseHash": String(select.get("stateHash", "")),
			"afterSelectHash": String(after_select.get("stateHash", "")),
			"replayResponseHash": String(replay_response.get("stateHash", "")),
			"afterReplayHash": String(after_replay.get("stateHash", "")),
			"beforeReplayVersion": int(after_select.get("stateVersion", -1)),
			"afterReplayVersion": int(after_replay.get("stateVersion", -1)),
		},
		"save": {
			"schema": String(save.get("schema", "")),
			"schemaVersion": int(save.get("schemaVersion", -1)),
			"checksum": save_checksum,
			"recomputedChecksum": recomputed_save_checksum,
			"normalizedSha256": _sha256(DocumentCodecScript.stable_json(save)),
		},
		"replay": {
			"schema": String(replay.get("schema", "")),
			"schemaVersion": int(replay.get("schemaVersion", -1)),
			"replayVersion": String(replay.get("replayVersion", "")),
			"rulesVersion": String(replay.get("rulesVersion", "")),
			"rngVersion": String(replay.get("rngVersion", "")),
			"checksum": replay_checksum,
			"recomputedChecksum": recomputed_replay_checksum,
			"normalizedSha256": _sha256(DocumentCodecScript.stable_json(replay)),
			"initialStateHash": String(Dictionary(replay.get("initial", {})).get("stateHash", "")),
			"commandCount": command_stream.size(),
			"firstCheckpoint": first_checkpoint,
			"lastCheckpoint": last_checkpoint,
			"summaryFinalHash": String(replay_summary.get("finalStateHash", "")),
			"finalStateVersion": int(replay_final.get("stateVersion", -1)),
			"finalStateHash": String(replay_final.get("stateHash", "")),
		},
	}
	summary["normalizedSha256"] = _sha256(DocumentCodecScript.stable_json(summary))
	print("PUZZLE_REFACTOR_BASELINE_JSON %s" % JSON.stringify(summary))
	quit(0)


func _baseline_state() -> RefCounted:
	var current: RefCounted = StateScript.new()
	# The frozen P0 probe remains a historical persisted snapshot. Modern
	# assembly has an intentional content-hash migration and is opt-in here.
	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--modern-quality-assembly") or user_args.has("--modern-runtime-assembly"):
		return current
	var content := Dictionary(current.get("game_data")).duplicate(true)
	var quality := Dictionary(content.get("quality", {})).duplicate(true)
	quality.erase("runtime_schema_version")
	var upgrades: Array = []
	for upgrade_value in Array(quality.get("upgrades", [])):
		var upgrade := Dictionary(upgrade_value).duplicate(true)
		upgrade.erase("runtime_operations")
		upgrades.append(upgrade)
	quality["upgrades"] = upgrades
	content["quality"] = quality
	var economy := Dictionary(content.get("economy", {})).duplicate(true)
	economy.erase("runtime_schema_version")
	var events: Array = []
	for event_value in Array(economy.get("events", [])):
		var event := Dictionary(event_value).duplicate(true)
		event.erase("event_operations")
		event.erase("event_triggers")
		events.append(event)
	economy["events"] = events
	content["economy"] = economy
	var route := Dictionary(content.get("route", {})).duplicate(true)
	var nodes: Array = []
	for node_value in Array(route.get("node_pool", [])):
		var node := Dictionary(node_value).duplicate(true)
		if String(node.get("nodeType", "")) == "rest":
			node.erase("event_operations")
		nodes.append(node)
	route["node_pool"] = nodes
	content["route"] = route
	return StateScript.new({
		"mode": "test",
		"content_pack": content,
		"content_source_kind": &"persisted_snapshot",
	})


func _first_player_unit_id(snapshot: Dictionary) -> String:
	for item in Array(snapshot.get("units", [])):
		var unit := Dictionary(item)
		if String(unit.get("side", "")) == "player":
			return String(unit.get("id", ""))
	return ""


func _checkpoint(command_stream: Array, index: int) -> Dictionary:
	if index < 0 or index >= command_stream.size():
		return {}
	var checkpoint := Dictionary(Dictionary(command_stream[index]).get("checkpoint", {}))
	return {
		"beforeVersion": int(checkpoint.get("beforeVersion", -1)),
		"beforeHash": String(checkpoint.get("beforeHash", "")),
		"afterVersion": int(checkpoint.get("afterVersion", -1)),
		"afterHash": String(checkpoint.get("afterHash", "")),
		"stateVersion": int(checkpoint.get("stateVersion", -1)),
		"stateHash": String(checkpoint.get("stateHash", "")),
	}


func _sha256(value: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()


func _expect_response(response: Dictionary, label: String, failures: Array[String]) -> void:
	_expect(bool(response.get("ok", false)), "%s response is ok" % label, failures)
	_expect(bool(response.get("accepted", false)), "%s response is accepted" % label, failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
