extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const RunHistoryPortScript := preload("res://core/ports/run_history_port.gd")

var _failed := false


func _init() -> void:
	var state: RefCounted = StateScript.new()
	var port: RefCounted = RunHistoryPortScript.new(state)
	var committer: RefCounted = state.get("_core_composition").run_history_committer
	_expect(StringName(port.contract_id()) == &"ysbzs.run-history-port.v1", "history port publishes the v1 contract")
	var context := Dictionary(port.capture_context(&"checkpoint"))
	_expect(String(context.get("stateHash", "")) == String(state.call("_state_hash")), "history port captures the canonical authority hash")
	var begin_context := Dictionary(port.capture_context(&"begin"))
	_expect(Dictionary(begin_context.get("gameData", {})) == Dictionary(state.get("game_data")), "history begin scope captures the canonical content")
	var status_context := Dictionary(port.capture_context())
	_expect(not status_context.has("gameData") and not status_context.has("stateHash"), "disabled-history status scope avoids content copies and hashes")
	_expect(Dictionary(committer.metadata(port)).get("schema") == "ysbzs.run-history", "committer accepts the versioned port")
	_expect(Dictionary(committer.metadata(RefCounted.new())).is_empty(), "committer rejects a missing port contract")
	var invalid_result := Dictionary(committer.record(RefCounted.new(), {}))
	_expect(not bool(invalid_result.get("ok", true)), "commit fails closed when the port contract is incomplete")
	var before_index := int(state.get("history_command_index"))
	port.apply_patch({"unknown": 99, "historyCommandIndex": before_index + 1})
	_expect(int(state.get("history_command_index")) == before_index + 1, "port applies only the whitelisted history patch")
	port.apply_patch({"historyCommandIndex": before_index})
	var committer_source := FileAccess.get_file_as_string("res://persistence/run_history_committer.gd")
	_expect(not committer_source.contains("authority.get(") and not committer_source.contains("authority.set(") and not committer_source.contains("authority.call("), "dynamic authority access stays inside the port adapter")
	var port_source := FileAccess.get_file_as_string("res://core/ports/run_history_port.gd")
	_expect(not port_source.contains("return _authority"), "history port never exposes the complete authority object")
	_expect(port_source.contains("AuthoritativeStateCodecScript.capture_checkpoint(_authority)"), "history port returns only a captured checkpoint payload")
	if _failed:
		quit(1)
		return
	print("SMOKE_RUN_HISTORY_COMMITTER_CONTRACT_OK contract=v1 capabilities=5")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Smoke failed: %s" % message)
