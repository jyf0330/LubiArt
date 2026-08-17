extends RefCounted

## Compatibility adapter for the in-process authoritative state. LocalGameSession
## consumes this stable capability surface instead of probing methods itself.

var _authority: RefCounted = null


func _init(authority: RefCounted = null) -> void:
	bind(authority)


func bind(authority: RefCounted) -> void:
	_authority = authority


func authority() -> RefCounted:
	return _authority


func ready() -> bool:
	return _has(&"run_command") and _has(&"snapshot")


func run_command(command: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("run_command", command)) if _has(&"run_command") else {}


func can_run_incremental_command(command: Dictionary) -> bool:
	return _has(&"can_run_incremental_command") and bool(_authority.call("can_run_incremental_command", command))


func run_incremental_command(command: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("run_incremental_command", command)) if _has(&"run_incremental_command") else run_command(command)


func snapshot() -> Dictionary:
	return Dictionary(_authority.call("snapshot")) if _has(&"snapshot") else {}


func command_baseline() -> Dictionary:
	if _authority == null:
		return {}
	if _authority.has_method("_state_hash"):
		return {
			"stateVersion": int(_authority.get("state_version")),
			"stateHash": String(_authority.call("_state_hash")),
		}
	var snap := snapshot()
	return {
		"stateVersion": int(snap.get("stateVersion", 0)),
		"stateHash": String(snap.get("stateHash", "")),
	}


func command_version() -> int:
	if _authority == null:
		return 0
	return int(_authority.get("state_version"))


func supports_persistence() -> bool:
	return (not _has(&"supports_persistence") or bool(_authority.call("supports_persistence"))) \
		and _has(&"save_to_user") \
		and _has(&"load_from_user") \
		and _has(&"save_replay_to_user") \
		and _has(&"save_battle_trace_to_user")


func save_to_slot(slot: int) -> bool:
	return _call_bool(&"save_to_user", [slot])


func load_from_slot(slot: int) -> bool:
	return _call_bool(&"load_from_user", [slot])


func export_replay() -> bool:
	return _call_bool(&"save_replay_to_user")


func export_battle_trace() -> bool:
	return _call_bool(&"save_battle_trace_to_user")

func supports_run_history() -> bool:
	return _has(&"supports_run_history") \
		and _has(&"run_history_runs") \
		and _has(&"run_history_checkpoints") \
		and _has(&"resume_from_run_history") \
		and bool(_authority.call("supports_run_history"))

func run_history_runs() -> Array:
	return Array(_authority.call("run_history_runs")).duplicate(true) if supports_run_history() else []

func run_history_checkpoints(run_id: String = "") -> Array:
	return Array(_authority.call("run_history_checkpoints", run_id)).duplicate(true) if supports_run_history() else []

func run_history_checkpoint_for_day(run_id: String, day: int, kind: String = "start") -> Dictionary:
	return (
		Dictionary(_authority.call("run_history_checkpoint_for_day", run_id, day, kind)).duplicate(true)
		if supports_run_history() and _has(&"run_history_checkpoint_for_day")
		else {}
	)

func resume_from_run_history(run_id: String, checkpoint_id: String) -> bool:
	return _call_bool(&"resume_from_run_history", [run_id, checkpoint_id]) if supports_run_history() else false

func resume_from_run_history_day(run_id: String, day: int, kind: String = "start") -> bool:
	return (
		_call_bool(&"resume_from_run_history_day", [run_id, day, kind])
		if supports_run_history() and _has(&"resume_from_run_history_day")
		else false
	)


func _has(method_name: StringName) -> bool:
	return _authority != null and _authority.has_method(method_name)


func _call_bool(method_name: StringName, args: Array = []) -> bool:
	return bool(_authority.callv(method_name, args)) if _has(method_name) else false
