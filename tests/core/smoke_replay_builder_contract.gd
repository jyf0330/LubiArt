extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const ReplayBuilderScript := preload("res://persistence/replay_builder.gd")

var failed := false


func _initialize() -> void:
	var input := _fixture_input()
	var input_before := input.duplicate(true)
	var document := ReplayBuilderScript.build(input)
	_expect(input == input_before, "builder leaves its full nested input unchanged")
	_expect(not document.has("checksum"), "pure builder does not calculate storage checksum")
	_expect(_sorted_keys(document) == [
		"battleTrace", "changeLog", "commandCheckpoints", "commandStream", "dataVersion",
		"day", "debugTimeline", "determinism", "final", "finalSummary", "initial", "inputLog",
		"legacyReplayVersion", "period", "replayVersion", "result", "rngVersion", "rulesVersion",
		"scenario", "schema", "schemaVersion", "seed", "summary",
	], "builder emits the exact replay top-level key set")
	_expect(Array(document.get("commandStream", [])).size() == 1, "builder derives command stream from command log")
	_expect(Array(document.get("commandCheckpoints", [])).size() == 1, "builder derives command checkpoints")
	_expect(Array(document.get("inputLog", [])).size() == 1 and Array(document.get("changeLog", [])).size() == 1, "builder derives compatibility logs")
	_expect(Array(document.get("battleTrace", [])).size() == 1, "builder derives fallback battle trace when no formal trace is supplied")
	var initial := Dictionary(document.get("initial", {}))
	_expect(String(initial.get("seed", "")) == "builder-seed" and String(initial.get("stateHash", "")) == "initial-hash", "builder assembles the frozen initial block")
	var summary := Dictionary(document.get("summary", {}))
	_expect(int(summary.get("timelineEntries", -1)) == 1 and int(summary.get("replayableCommands", -1)) == 1, "builder derives frozen summary counts")
	var builder_source := FileAccess.get_file_as_string("res://persistence/replay_builder.gd")
	for forbidden in ["FileAccess", "DirAccess", "Time.", "OS.", "user://", "Repository", "authority"]:
		_expect(not builder_source.contains(forbidden), "builder source excludes I/O/authority token %s" % forbidden)

	var state: RefCounted = StateScript.new()
	var source_hash := String(state.call("_state_hash"))
	var source_payload: Dictionary = state.call("_save_state_payload")
	var replay := Dictionary(state.call("replay_document"))
	_expect(String(replay.get("checksum", "")) != "", "facade adds checksum after pure build")
	_expect(String(Dictionary(replay.get("initial", {})).get("stateHash", "")) == source_hash, "facade fresh create reproduces the initial state hash")
	_expect(String(state.call("_state_hash")) == source_hash and state.call("_save_state_payload") == source_payload, "replay build leaves source authority unchanged")
	var facade_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	for removed_method in [
		"_replay_command_stream", "_replay_input_log", "_replay_change_log", "_replay_battle_trace",
		"_replay_debug_timeline", "_replay_rejected_command_count", "_replay_command_checkpoints",
		"_replay_initial_state_hash",
	]:
		_expect(not facade_source.contains("func %s(" % removed_method), "facade removes replay builder shell %s" % removed_method)

	if failed:
		quit(1)
		return
	print("SMOKE_REPLAY_BUILDER_CONTRACT_OK keys=%d commands=1 io=0" % document.size())
	quit(0)


func _fixture_input() -> Dictionary:
	return {
		"schema": "ysbzs.replay",
		"schemaVersion": 2,
		"replayVersion": "v4",
		"legacyReplayVersion": "v2",
		"dataVersion": "content-hash",
		"rulesVersion": "rules",
		"rngVersion": "rng",
		"determinism": {"contentHash": "content-hash"},
		"seed": "builder-seed",
		"day": 2,
		"period": "夜晚",
		"result": {"win": true},
		"scenario": {"scenarioId": "fixture"},
		"initialOptions": {"seed": "builder-seed", "day": 1, "period": "上午", "boardWidth": 8, "boardHeight": 7},
		"initialHash": "initial-hash",
		"commandLog": [{
			"type": "START_BATTLE", "raw": {"type": "START_BATTLE"},
			"command": {"type": "START_BATTLE", "baseStateVersion": 0},
			"beforeVersion": 0, "beforeHash": "h0", "afterVersion": 1, "afterHash": "h1",
			"afterPhase": "battle", "round": 1,
		}],
		"storedDebugTimeline": [],
		"battleTrace": [],
		"stateVersion": 1,
		"stateHash": "h1",
		"phase": "battle",
		"round": 1,
		"units": [{"id": "u1"}],
	}


func _sorted_keys(value: Dictionary) -> Array:
	var result: Array = []
	for key_value in value.keys():
		result.append(String(key_value))
	result.sort()
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_REPLAY_BUILDER_CONTRACT_FAIL: %s" % message)
