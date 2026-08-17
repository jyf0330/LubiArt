extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var _failed := false


class FakeReplayRepository extends RefCounted:
	var writes: Array = []

	func write_document(path: String, document: Dictionary) -> bool:
		writes.append({"path": path, "document": document.duplicate(true)})
		return true


class FakeRunHistoryRepository extends RefCounted:
	var roots: Array[String] = []

	func list_runs(root: String) -> Array:
		roots.append(root)
		return [{"runId": "memory_run"}]


func _initialize() -> void:
	var persistence_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	_expect(not persistence_source.contains("FileAccess") and not persistence_source.contains("DirAccess"), "authoritative facade owns no file-system implementation")
	_expect(not persistence_source.contains("ReplayRepositoryScript.new()"), "persistence facade does not hard-construct replay storage")
	_expect(not persistence_source.contains("RunHistoryRepositoryScript.new()") and not persistence_source.contains("var _history_repository"), "persistence facade does not hard-construct history storage")
	_expect(persistence_source.contains("_core_composition.replay_repository.write_document"), "replay and trace exports use the composition seam")
	_expect(persistence_source.contains("_core_composition.run_history_repository"), "run history uses the composition seam")
	_expect(persistence_source.contains("_core_composition.run_history_committer.record(RunHistoryPortScript.new(self)"), "command commits use the versioned history port")
	var committer_source := FileAccess.get_file_as_string("res://persistence/run_history_committer.gd")
	_expect(not committer_source.contains("authority.get(") and not committer_source.contains("authority.call("), "history committer depends only on its narrow port")
	var builder_source := FileAccess.get_file_as_string("res://persistence/save_document_builder.gd")
	_expect(not builder_source.contains("authority: Object") and not builder_source.contains("AuthoritativeStateCodecScript"), "save builder receives only a captured state payload")

	var fake_replay := FakeReplayRepository.new()
	var fake_history := FakeRunHistoryRepository.new()
	var state: RefCounted = StateScript.new()
	state.call("configure_core_services", {
		"replay_repository": fake_replay,
		"run_history_repository": fake_history,
	})
	_expect(bool(state.call("save_replay_to_user")), "public replay export succeeds through the injected repository")
	_expect(bool(state.call("save_battle_trace_to_user")), "public trace export succeeds through the injected repository")
	_expect(fake_replay.writes.size() == 2, "injected replay repository receives both exports")
	if fake_replay.writes.size() == 2:
		var replay_write := Dictionary(fake_replay.writes[0])
		var trace_write := Dictionary(fake_replay.writes[1])
		_expect(String(replay_write.get("path", "")) == StateScript.REPLAY_PATH, "replay export preserves the public path contract")
		_expect(String(Dictionary(replay_write.get("document", {})).get("schema", "")) == StateScript.REPLAY_SCHEMA, "facade still assembles the replay document")
		_expect(String(trace_write.get("path", "")) == StateScript.BATTLE_TRACE_PATH, "trace export preserves the public path contract")
		_expect(Dictionary(trace_write.get("document", {})).has("events"), "facade still assembles the trace document")
	state.call("set_run_history_root", "user://memory_history")
	var runs := Array(state.call("run_history_runs"))
	_expect(runs.size() == 1 and String(Dictionary(runs[0]).get("runId", "")) == "memory_run", "public history query returns the injected repository result")
	_expect(fake_history.roots == ["user://memory_history"], "history query forwards the explicit root exactly once")

	print("SMOKE_PERSISTENCE_COMPOSITION_BOUNDARIES_%s" % ["OK" if not _failed else "FAIL"])
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Smoke failed: %s" % message)
