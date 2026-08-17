extends RefCounted

## Serializes authoritative responses into one presentation pipeline. It owns no
## gameplay state: queued values are deep copies of public Result/Snapshot data.

signal presentation_settled(snapshot: Dictionary)
signal job_completed(sequence: int)

const KIND_COMMAND := &"command"
const KIND_BATTLE := &"battle"
const KIND_EXTERNAL := &"external"
const KIND_OPERATION := &"operation"
const GameLogScript := preload("res://core/logging/game_log.gd")

var _session_bridge: RefCounted = null
var _view: Control = null
var _prepare_feature := Callable()
var _release_features := Callable()
var _battle_view_provider := Callable()

var _queue: Array[Dictionary] = []
var _completed_results := {}
var _processing := false
var _generation := 0
var _job_sequence := 0
var _last_applied_version := -1
var _last_applied_hash := ""
var _last_applied_phase := ""
var _last_trace_cursor := -1


func configure(
		session_bridge: RefCounted,
		view: Control,
		prepare_feature: Callable,
		release_features: Callable,
		battle_view_provider: Callable
) -> void:
	_session_bridge = session_bridge
	_view = view
	_prepare_feature = prepare_feature
	_release_features = release_features
	_battle_view_provider = battle_view_provider


func dispose() -> void:
	reset_for_session()
	_session_bridge = null
	_view = null
	_prepare_feature = Callable()
	_release_features = Callable()
	_battle_view_provider = Callable()


func reset_for_session() -> void:
	_generation += 1
	_queue.clear()
	_completed_results.clear()
	_processing = false
	_last_applied_version = -1
	_last_applied_hash = ""
	_last_applied_phase = ""
	_last_trace_cursor = -1
	job_completed.emit(-1)


func adopt_presented_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	_last_applied_version = int(snapshot.get("stateVersion", -1))
	_last_applied_hash = String(snapshot.get("stateHash", ""))
	_last_applied_phase = String(snapshot.get("phase", ""))
	if _last_applied_phase == "battle":
		_last_trace_cursor = _trace_size(snapshot)
	_sync_trace_cursor()


func submit_command_request(command: Dictionary, request_id: int) -> Dictionary:
	return await _enqueue_and_wait({
		"kind": KIND_COMMAND,
		"command": command.duplicate(true),
		"request_id": request_id,
	})


func submit_battle_command(command: Dictionary) -> bool:
	var result := await _enqueue_and_wait({
		"kind": KIND_BATTLE,
		"command": command.duplicate(true),
	})
	return bool(result.get("accepted", false))


func enqueue_external_snapshot(snapshot: Dictionary, metadata: Dictionary) -> void:
	if snapshot.is_empty() or String(metadata.get("reason", "")) == "command":
		return
	var safe_snapshot := snapshot.duplicate(true)
	var safe_metadata := metadata.duplicate(true)
	if not bool(safe_metadata.get("force", false)) and _external_snapshot_is_stale(safe_snapshot):
		return
	for index in range(_queue.size()):
		var queued := _queue[index]
		if int(queued.get("generation", -1)) != _generation \
				or StringName(queued.get("kind", &"")) != KIND_EXTERNAL:
			continue
		var queued_snapshot := Dictionary(queued.get("snapshot", {}))
		if _snapshot_is_newer_or_equal(safe_snapshot, queued_snapshot):
			queued["snapshot"] = safe_snapshot
			queued["metadata"] = safe_metadata
			_queue[index] = queued
		return
	_enqueue({
		"kind": KIND_EXTERNAL,
		"snapshot": safe_snapshot,
		"metadata": safe_metadata,
	}, false)


func complete_session_operation(request_id: int, result: Dictionary, operation: StringName = &"") -> void:
	_enqueue({
		"kind": KIND_OPERATION,
		"request_id": request_id,
		"result": result.duplicate(true),
		"operation": operation,
	}, false)


func configure_battle_view(view: Node) -> void:
	if not is_instance_valid(view) or _last_trace_cursor < 0:
		return
	if view.has_method("configure_trace_cursor"):
		view.call("configure_trace_cursor", _last_trace_cursor)


func is_processing() -> bool:
	return _processing


func last_applied_version() -> int:
	return _last_applied_version


func last_trace_cursor() -> int:
	return _last_trace_cursor


func _enqueue_and_wait(job: Dictionary) -> Dictionary:
	var handle := _enqueue(job, true)
	var sequence := int(handle.get("sequence", -1))
	var generation := int(handle.get("generation", -1))
	while generation == _generation and not _completed_results.has(sequence):
		await job_completed
	if generation != _generation:
		return {
			"accepted": false,
			"cancelled": true,
			"error": {"code": "PRESENTATION_SESSION_RESET"},
		}
	var result := Dictionary(_completed_results.get(sequence, {}))
	_completed_results.erase(sequence)
	return result


func _enqueue(job: Dictionary, expects_result: bool) -> Dictionary:
	_job_sequence += 1
	# Jobs already cross their mutable boundary before enqueueing. A shallow job
	# copy keeps queue metadata private without cloning a megabyte-scale Snapshot.
	var queued := job.duplicate(false)
	queued["sequence"] = _job_sequence
	queued["generation"] = _generation
	queued["expects_result"] = expects_result
	_queue.append(queued)
	if not _processing:
		_pump(_generation)
	return {"sequence": _job_sequence, "generation": _generation}


func _pump(pump_generation: int) -> void:
	if _processing or pump_generation != _generation:
		return
	_processing = true
	while pump_generation == _generation and not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		if int(job.get("generation", -1)) != pump_generation:
			continue
		var result: Dictionary = await _execute(job)
		if pump_generation != _generation:
			return
		if bool(job.get("expects_result", false)):
			_completed_results[int(job.get("sequence", -1))] = result
		job_completed.emit(int(job.get("sequence", -1)))
	_processing = false


func _execute(job: Dictionary) -> Dictionary:
	match StringName(job.get("kind", &"")):
		KIND_COMMAND:
			return await _execute_command(job)
		KIND_BATTLE:
			return await _execute_battle(job)
		KIND_EXTERNAL:
			return await _execute_external(job)
		KIND_OPERATION:
			return await _execute_operation(job)
	return {"accepted": false, "error": {"code": "PRESENTATION_JOB_KIND_INVALID"}}


func _execute_command(job: Dictionary) -> Dictionary:
	if _session_bridge == null:
		return {"accepted": false, "error": {"code": "PRESENTATION_SESSION_MISSING"}}
	var started_usec := Time.get_ticks_usec()
	var response := Dictionary(await _session_bridge.call("submit_command", Dictionary(job.get("command", {}))))
	var session_done_usec := Time.get_ticks_usec()
	if not _job_is_current(job):
		return _cancelled_result()
	var snapshot := _snapshot_from_response(response)
	var snapshot_done_usec := Time.get_ticks_usec()
	if not snapshot.is_empty() and not response.has("snapshot"):
		# Delta responses stay small through Session/Core. The presentation edge
		# attaches its already-patched local read model for existing UI consumers.
		response["snapshot"] = snapshot
	_prepare_snapshot(snapshot)
	var prepare_done_usec := Time.get_ticks_usec()
	if is_instance_valid(_view) and _view.has_method("complete_command_request"):
		_view.call("complete_command_request", int(job.get("request_id", -1)), response)
	var view_done_usec := Time.get_ticks_usec()
	if String(response.get("snapshotMode", "")) == "delta":
		GameLogScript.info("界面/增量命令", "增量结果送达", {
			"命令": String(response.get("command", "")),
			"Session微秒": session_done_usec - started_usec,
			"读取投影微秒": snapshot_done_usec - session_done_usec,
			"准备Feature微秒": prepare_done_usec - snapshot_done_usec,
			"界面回调微秒": view_done_usec - prepare_done_usec,
		})
	await _await_resumed_view_presentation()
	if not _job_is_current(job):
		return _cancelled_result()
	_finish_snapshot(snapshot)
	return response


func _execute_battle(job: Dictionary) -> Dictionary:
	if _session_bridge == null:
		return {"accepted": false, "error": {"code": "PRESENTATION_SESSION_MISSING"}}
	var command := Dictionary(job.get("command", {}))
	var response := Dictionary(await _session_bridge.call("submit_command", command))
	if not _job_is_current(job):
		return _cancelled_result()
	var snapshot := _snapshot_from_response(response)
	_prepare_snapshot(snapshot)
	if is_instance_valid(_view) and _view.has_method("render_battle_command_response"):
		await _view.call("render_battle_command_response", command, response)
	if not _job_is_current(job):
		return _cancelled_result()
	_finish_snapshot(snapshot)
	return response


func _execute_external(job: Dictionary) -> Dictionary:
	var snapshot := Dictionary(job.get("snapshot", {})).duplicate(true)
	var metadata := Dictionary(job.get("metadata", {}))
	if snapshot.is_empty() or (not bool(metadata.get("force", false)) and _external_snapshot_is_stale(snapshot)):
		return {"accepted": false, "dropped": true}
	_prepare_snapshot(snapshot)
	if is_instance_valid(_view) and _view.has_method("render_snapshot"):
		await _view.call("render_snapshot", snapshot, bool(metadata.get("animate_transition", true)))
	if not _job_is_current(job):
		return _cancelled_result()
	_finish_snapshot(snapshot)
	return {"accepted": true, "snapshot": snapshot}


func _execute_operation(job: Dictionary) -> Dictionary:
	var result := Dictionary(job.get("result", {})).duplicate(true)
	var snapshot := Dictionary(result.get("snapshot", {})).duplicate(true)
	_prepare_snapshot(snapshot, StringName(job.get("operation", &"")) == &"load")
	if is_instance_valid(_view) and _view.has_method("complete_session_operation_request"):
		_view.call("complete_session_operation_request", int(job.get("request_id", -1)), result)
	await _await_resumed_view_presentation()
	if not _job_is_current(job):
		return _cancelled_result()
	_finish_snapshot(snapshot)
	return result


func _prepare_snapshot(snapshot: Dictionary, reset_trace_cursor: bool = false) -> void:
	if snapshot.is_empty():
		return
	var incoming_phase := String(snapshot.get("phase", ""))
	if incoming_phase == "battle":
		var trace_size := _trace_size(snapshot)
		if reset_trace_cursor or _last_applied_phase != "battle" or (_last_trace_cursor >= 0 and trace_size < _last_trace_cursor):
			_last_trace_cursor = trace_size
	if _prepare_feature.is_valid():
		_prepare_feature.call(snapshot)
	configure_battle_view(_battle_view())


func _finish_snapshot(snapshot: Dictionary) -> void:
	_sync_trace_cursor()
	if not snapshot.is_empty():
		_last_applied_version = int(snapshot.get("stateVersion", _last_applied_version))
		_last_applied_hash = String(snapshot.get("stateHash", _last_applied_hash))
		_last_applied_phase = String(snapshot.get("phase", _last_applied_phase))
	if _release_features.is_valid():
		_release_features.call(snapshot)
	presentation_settled.emit(snapshot)


func _await_resumed_view_presentation() -> void:
	if not is_instance_valid(_view) or not _view.is_inside_tree():
		return
	var tree := _view.get_tree()
	if tree == null:
		return
	await tree.process_frame
	while is_instance_valid(_view) \
			and _view.is_inside_tree() \
			and _view.has_method("is_presentation_busy") \
			and bool(_view.call("is_presentation_busy")):
		await tree.process_frame


func _snapshot_from_response(response: Dictionary) -> Dictionary:
	var snapshot_value: Variant = response.get("snapshot", {})
	if snapshot_value is Dictionary and not Dictionary(snapshot_value).is_empty():
		return Dictionary(snapshot_value)
	if _session_bridge != null and _session_bridge.has_method("current_presentation_snapshot"):
		var presentation_snapshot := Dictionary(_session_bridge.call("current_presentation_snapshot"))
		if not presentation_snapshot.is_empty():
			return presentation_snapshot
	if _session_bridge != null and _session_bridge.has_method("current_snapshot"):
		return Dictionary(_session_bridge.call("current_snapshot"))
	return {}


func _external_snapshot_is_stale(snapshot: Dictionary) -> bool:
	var version := int(snapshot.get("stateVersion", -1))
	if version < _last_applied_version:
		return true
	if version != _last_applied_version:
		return false
	var snapshot_hash := String(snapshot.get("stateHash", ""))
	return snapshot_hash != "" and snapshot_hash == _last_applied_hash


func _snapshot_is_newer_or_equal(candidate: Dictionary, existing: Dictionary) -> bool:
	return int(candidate.get("stateVersion", -1)) >= int(existing.get("stateVersion", -1))


func _job_is_current(job: Dictionary) -> bool:
	return int(job.get("generation", -1)) == _generation


func _cancelled_result() -> Dictionary:
	return {
		"accepted": false,
		"cancelled": true,
		"error": {"code": "PRESENTATION_SESSION_RESET"},
	}


func _battle_view() -> Node:
	if not _battle_view_provider.is_valid():
		return null
	return _battle_view_provider.call() as Node


func _sync_trace_cursor() -> void:
	var view := _battle_view()
	if is_instance_valid(view) and view.has_method("get_trace_cursor"):
		_last_trace_cursor = maxi(-1, int(view.call("get_trace_cursor")))


func _trace_size(snapshot: Dictionary) -> int:
	return Array(snapshot.get("battleTrace", snapshot.get("battle_trace", []))).size()
