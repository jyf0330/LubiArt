extends RefCounted

## Presentation-facing port for local or remote authoritative game sessions.
## UI code submits commands and consumes snapshots through this contract; it
## never needs to know where the authoritative rules execute.

signal command_completed(command: Dictionary, response: Dictionary)
signal command_rejected(command: Dictionary, response: Dictionary)
signal command_settled(response: Dictionary)
signal snapshot_received(snapshot: Dictionary, metadata: Dictionary)
signal connection_state_changed(connected: bool, metadata: Dictionary)
signal session_error(error: Dictionary)


func submit_command(command: Dictionary) -> Dictionary:
	var response := {
		"accepted": false,
		"pending": false,
		"status": "rejected",
		"command": String(command.get("type", "")),
		"error": {
			"code": "SESSION_NOT_READY",
			"message": "Game session has no authoritative adapter."
		},
		"snapshot": current_snapshot()
	}
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
