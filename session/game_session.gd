extends RefCounted

## Presentation-facing port for local or remote authoritative game sessions.
## UI code submits commands and consumes snapshots through this contract; it
## never needs to know where the authoritative rules execute.

signal command_completed(command: Dictionary, response: Dictionary)
signal command_rejected(command: Dictionary, response: Dictionary)
signal command_settled(response: Dictionary)
signal action_lifecycle_changed(action: Dictionary)
signal snapshot_received(snapshot: Dictionary, metadata: Dictionary)
signal connection_state_changed(connected: bool, metadata: Dictionary)
signal session_error(error: Dictionary)

const ActionLifecycleScript := preload("res://session/action_lifecycle.gd")

var _action_lifecycle: RefCounted = ActionLifecycleScript.new()


func submit_command(command: Dictionary) -> Dictionary:
	var action := _queue_submitted_action(command)
	var response := {
		"accepted": false,
		"pending": false,
		"status": "rejected",
		"command": String(command.get("type", "")),
		"error": {
			"code": "SESSION_NOT_READY",
			"message": "Game session has no authoritative adapter."
		},
		"snapshot": current_snapshot(),
		"actionId": String(action.get("id", "")),
		"actionStatus": "rejected",
	}
	_settle_submitted_action(String(action.get("id", "")), response)
	command_rejected.emit(command, response)
	command_settled.emit(response)
	return response


func submit_command_and_wait(command: Dictionary) -> Dictionary:
	return submit_command(command)


func current_snapshot() -> Dictionary:
	return {}


func connect_session() -> bool:
	return false


func disconnect_session() -> void:
	pass


func is_session_connected() -> bool:
	return false


func pending_command_count() -> int:
	return 0


func prepare_action(command: Dictionary, choice_request: Dictionary = {}) -> Dictionary:
	var action := Dictionary(_lifecycle().call("queue", command))
	if not choice_request.is_empty():
		_lifecycle().await_choice(String(action.get("id", "")), choice_request)
	return action_snapshot(String(action.get("id", "")))


func start_action(action_id: String) -> bool:
	return _lifecycle().start(action_id)


func await_action_choice(action_id: String, choice_request: Dictionary = {}) -> bool:
	return _lifecycle().await_choice(action_id, choice_request)


func resume_action(action_id: String, choice: Dictionary = {}) -> bool:
	return _lifecycle().resume(action_id, choice)


func cancel_action(action_id: String, reason: String = "") -> bool:
	return _lifecycle().cancel(action_id, reason)


func complete_action(action_id: String, response: Dictionary = {}) -> bool:
	return _lifecycle().complete(action_id, response)


func reject_action(action_id: String, response: Dictionary = {}) -> bool:
	return _lifecycle().reject(action_id, response)


func action_snapshot(action_id: String) -> Dictionary:
	return _lifecycle().snapshot(action_id)


func recent_actions(limit: int = 20) -> Array:
	return _lifecycle().recent(limit)


func active_action_count() -> int:
	return _lifecycle().active_count()


func supports_persistence() -> bool:
	return false


func persistence_slot_count() -> int:
	return 0


func save_to_slot(_slot: int = 1) -> bool:
	return false


func load_from_slot(_slot: int = 1) -> bool:
	return false


func export_replay() -> bool:
	return false


func export_battle_trace() -> bool:
	return false


func supports_run_history() -> bool:
	return false


func run_history_runs() -> Array:
	return []


func run_history_checkpoints(_run_id: String = "") -> Array:
	return []


func run_history_checkpoint_for_day(_run_id: String, _day: int, _kind: String = "start") -> Dictionary:
	return {}


func resume_from_run_history(_run_id: String, _checkpoint_id: String) -> bool:
	return false


func resume_from_run_history_day(_run_id: String, _day: int, _kind: String = "start") -> bool:
	return false


func _queue_submitted_action(command: Dictionary, preferred_id: String = "") -> Dictionary:
	var action := Dictionary(_lifecycle().call("queue", command, preferred_id))
	_lifecycle().start(String(action.get("id", "")))
	return action_snapshot(String(action.get("id", "")))


func _settle_submitted_action(action_id: String, response: Dictionary) -> void:
	if action_id == "":
		return
	if bool(response.get("accepted", false)):
		_lifecycle().complete(action_id, response)
	else:
		_lifecycle().reject(action_id, response)


func _lifecycle() -> RefCounted:
	var callback := Callable(self, "_on_action_lifecycle_changed")
	if not _action_lifecycle.is_connected("changed", callback):
		_action_lifecycle.connect("changed", callback)
	return _action_lifecycle


func _on_action_lifecycle_changed(action: Dictionary) -> void:
	action_lifecycle_changed.emit(action.duplicate(true))
