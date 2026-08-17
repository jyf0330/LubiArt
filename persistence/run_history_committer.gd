extends RefCounted

const HISTORY_SCHEMA := "ysbzs.run-history"
const HISTORY_SCHEMA_VERSION := 1
const PORT_CONTRACT_ID := &"ysbzs.run-history-port.v1"
const REQUIRED_PORT_METHODS := [
	&"contract_id",
	&"capture_context",
	&"apply_patch",
	&"checksum",
	&"capture_checkpoint_state",
]
const RunHistoryCommitLifecycleScript := preload("res://persistence/run_history_commit_lifecycle.gd")

var _repository: RefCounted = null
var _save_document_builder: RefCounted = null
var _lifecycle := RunHistoryCommitLifecycleScript.new()


func configure(repository: RefCounted, save_document_builder: RefCounted) -> void:
	_repository = repository
	_save_document_builder = save_document_builder


func metadata(port: RefCounted) -> Dictionary:
	if not _valid_port(port):
		return {}
	var context := Dictionary(port.capture_context(&"metadata"))
	return {
		"schema": HISTORY_SCHEMA,
		"schemaVersion": HISTORY_SCHEMA_VERSION,
		"runId": String(context.get("historyRunId", "")),
		"branchId": String(context.get("historyBranchId", "")),
		"parentRunId": String(context.get("historyParentRunId", "")),
		"parentCheckpointId": String(context.get("historyParentCheckpointId", "")),
		"commandIndex": int(context.get("historyCommandIndex", 0)),
		"contentRevision": int(context.get("historyContentRevision", 0)),
		"contentPath": String(context.get("historyContentPath", "")),
	}


func record(port: RefCounted, commit: Dictionary) -> Dictionary:
	if not _valid_port(port):
		return _failure("历史记录失败：历史端口协议不匹配。")
	var context := Dictionary(port.capture_context(&"status"))
	if not bool(context.get("historyRecordingEnabled", false)) or bool(context.get("historySuspended", false)):
		return {"ok": true}
	var lifecycle: Dictionary = _lifecycle.plan(
		String(commit.get("actionType", "")),
		String(context.get("historyRunId", "")) != "",
		String(commit.get("beforePhase", "")),
		String(context.get("phase", ""))
	)
	var begin_reason := String(lifecycle.get("beginReason", ""))
	if begin_reason != "":
		var begin_result := begin(port, begin_reason, {}, false)
		if not bool(begin_result.get("ok", false)):
			return begin_result
		context = Dictionary(port.capture_context(&"status"))
	var command_index := int(context.get("historyCommandIndex", 0)) + 1
	if not context.has("historyCommandIndex"):
		context = Dictionary(port.capture_context(&"record"))
		command_index = int(context.get("historyCommandIndex", 0)) + 1
	port.apply_patch({"historyCommandIndex": command_index})
	context = Dictionary(port.capture_context(&"record"))
	var entry := {
		"schema": "ysbzs.run-history.command",
		"schemaVersion": 1,
		"runId": String(context.get("historyRunId", "")),
		"branchId": String(context.get("historyBranchId", "")),
		"commandIndex": command_index,
		"command": Dictionary(commit.get("command", {})).duplicate(true),
		"beforeVersion": int(commit.get("beforeVersion", 0)),
		"beforeHash": String(commit.get("beforeHash", "")),
		"beforePhase": String(commit.get("beforePhase", "")),
		"afterVersion": int(context.get("stateVersion", 0)),
		"afterHash": String(commit.get("afterHash", "")),
		"afterPhase": String(context.get("phase", "")),
		"day": int(context.get("day", 1)),
		"result": context.get("lastCommandResult", null),
	}
	if not _repository.append_command(
		String(context.get("historyRoot", "")),
		String(context.get("historyRunId", "")),
		entry
	):
		return _failure("历史记录失败：无法追加命令。")
	var first_failure: Dictionary = {}
	for kind_value in Array(lifecycle.get("checkpointKinds", [])):
		var checkpoint_result := write_checkpoint(port, String(kind_value))
		if not bool(checkpoint_result.get("ok", false)) and first_failure.is_empty():
			first_failure = checkpoint_result
	return {"ok": true} if first_failure.is_empty() else first_failure


func begin(port: RefCounted, reason: String, parent: Dictionary, write_initial: bool) -> Dictionary:
	if not _valid_port(port):
		return _failure("历史记录失败：历史端口协议不匹配。")
	var context := Dictionary(port.capture_context(&"begin"))
	var now_ms := int(Time.get_unix_time_from_system() * 1000.0)
	var suffix := String(port.checksum({
		"seed": String(context.get("runSeed", "")),
		"time": now_ms,
		"ticks": Time.get_ticks_usec(),
		"parent": parent,
	}))
	var run_id := "run_%d_%s" % [now_ms, suffix]
	port.apply_patch({
		"historyRunId": run_id,
		"historyBranchId": run_id,
		"historyParentRunId": String(parent.get("parentRunId", "")),
		"historyParentCheckpointId": String(parent.get("parentCheckpointId", "")),
		"historyCommandIndex": 0,
	})
	context = Dictionary(port.capture_context(&"begin"))
	var content := Dictionary(context.get("gameData", {})).duplicate(true)
	var content_reference := Dictionary(_repository.ensure_content_revision(
		String(context.get("historyRoot", "")),
		String(context.get("contentHash", "")),
		content
	))
	if content_reference.is_empty():
		_reset_run_identity(port)
		return _failure("历史记录失败：无法登记内容修订。")
	port.apply_patch({
		"historyContentRevision": int(content_reference.get("revision", 0)),
		"historyContentPath": String(content_reference.get("contentPath", "")),
	})
	context = Dictionary(port.capture_context(&"begin"))
	var timestamp := Time.get_datetime_string_from_system(true, true)
	var history_determinism := Dictionary(context.get("determinism", {})).duplicate(true)
	history_determinism["contentRevision"] = int(context.get("historyContentRevision", 0))
	history_determinism["contentPath"] = String(context.get("historyContentPath", ""))
	var manifest := {
		"schema": HISTORY_SCHEMA,
		"schemaVersion": HISTORY_SCHEMA_VERSION,
		"runId": run_id,
		"branchId": run_id,
		"parentRunId": String(context.get("historyParentRunId", "")),
		"parentCheckpointId": String(context.get("historyParentCheckpointId", "")),
		"createdAt": timestamp,
		"updatedAt": timestamp,
		"reason": reason,
		"seed": String(context.get("runSeed", "")),
		"initialDay": int(context.get("day", 1)),
		"determinism": history_determinism,
		"checkpoints": [],
	}
	if not _repository.create_run(
		String(context.get("historyRoot", "")),
		run_id,
		manifest,
		content
	):
		_reset_run_identity(port)
		return _failure("历史记录失败：无法创建运行目录。")
	if write_initial:
		return write_checkpoint(port, "start")
	return {"ok": true}


func write_checkpoint(port: RefCounted, kind: String) -> Dictionary:
	if not _valid_port(port):
		return _failure("历史记录失败：历史端口协议不匹配。")
	var context := Dictionary(port.capture_context(&"checkpoint"))
	var run_id := String(context.get("historyRunId", ""))
	if run_id == "":
		return _failure("")
	var day := int(context.get("day", 1))
	var command_index := int(context.get("historyCommandIndex", 0))
	var checkpoint_id := "day_%03d_%s_c%06d" % [day, kind, command_index]
	var document: Dictionary = _save_document_builder.build(
		Dictionary(port.capture_checkpoint_state()),
		"p1",
		{
			"createdAt": Time.get_datetime_string_from_system(true, true),
			"embedContentPack": false,
			"historyCheckpoint": true,
		},
		Dictionary(context.get("determinism", {})),
		metadata(port)
	)
	var summary := {
		"kind": kind,
		"day": day,
		"phase": String(context.get("phase", "")),
		"stateVersion": int(context.get("stateVersion", 0)),
		"stateHash": String(context.get("stateHash", "")),
		"commandIndex": command_index,
		"restoreMode": "direct_checkpoint",
		"contentRevision": int(context.get("historyContentRevision", 0)),
		"createdAt": Time.get_datetime_string_from_system(true, true),
	}
	if not _repository.write_checkpoint(
		String(context.get("historyRoot", "")),
		run_id,
		checkpoint_id,
		document,
		summary
	):
		return _failure("历史记录失败：无法保存每日检查点。")
	return {"ok": true}


func _valid_port(port: RefCounted) -> bool:
	if port == null:
		return false
	for method_name in REQUIRED_PORT_METHODS:
		if not port.has_method(method_name):
			return false
	return StringName(port.call(&"contract_id")) == PORT_CONTRACT_ID


func _reset_run_identity(port: RefCounted) -> void:
	port.apply_patch({"historyRunId": "", "historyBranchId": ""})


func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
