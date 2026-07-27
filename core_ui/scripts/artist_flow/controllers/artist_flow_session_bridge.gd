extends RefCounted

signal asynchronous_snapshot_received(snapshot: Dictionary)

const SessionFactoryScript := preload("res://session/session_factory.gd")

var _session: RefCounted = null
var _authority: RefCounted = null
var _connected_session: RefCounted = null
var _awaiting_commands := 0
var _last_command_snapshot: Dictionary = {}


func bind_authority(authority: RefCounted) -> void:
	if authority == null:
		return
	_authority = authority
	_last_command_snapshot.clear()
	if _session != null and _session.has_method("bind_authority"):
		_session.call("bind_authority", authority)
	else:
		bind_session(SessionFactoryScript.wrap_local_authority(authority))


func bind_session(session: RefCounted) -> void:
	_disconnect_session_signals()
	_session = session
	_authority = _session.call("get_authority") as RefCounted if _session != null and _session.has_method("get_authority") else null
	_connect_session_signals()


func ensure_default(run_seed: String) -> void:
	if _session == null:
		if _authority != null:
			_session = SessionFactoryScript.wrap_local_authority(_authority)
		else:
			_session = SessionFactoryScript.create_local({
				"run_seed": run_seed,
				"board_dimensions": SessionFactoryScript.command_line_board_dimensions()
			})
			_authority = _session.call("get_authority") as RefCounted
	elif _authority != null and _session.has_method("get_authority") and _session.has_method("bind_authority"):
		if _session.call("get_authority") != _authority:
			_session.call("bind_authority", _authority)
	_connect_session_signals()


func session() -> RefCounted:
	return _session


func authority() -> RefCounted:
	return _authority


func dispose() -> void:
	_disconnect_session_signals()
	_last_command_snapshot.clear()
	_authority = null
	_session = null


func current_snapshot() -> Dictionary:
	if _session == null:
		return {}
	return Dictionary(_session.current_snapshot())


func submit_command(command: Dictionary) -> Dictionary:
	_last_command_snapshot.clear()
	if _session == null:
		return {}
	_awaiting_commands += 1
	var response := Dictionary(await _session.submit_command_and_wait(command))
	_awaiting_commands -= 1
	if bool(response.get("accepted", false)):
		_last_command_snapshot = Dictionary(response.get("snapshot", {}))
	return response


func take_command_snapshot() -> Dictionary:
	var snapshot := _last_command_snapshot
	_last_command_snapshot = {}
	return snapshot if not snapshot.is_empty() else current_snapshot()


func supports_persistence() -> bool:
	return _session != null \
		and _session.has_method("supports_persistence") \
		and bool(_session.supports_persistence())


func persistence_slot_count() -> int:
	return int(_session.persistence_slot_count()) if _session != null and _session.has_method("persistence_slot_count") else 0


func save_to_slot(slot: int) -> bool:
	return bool(_session.save_to_slot(slot)) if supports_persistence() else false


func load_from_slot(slot: int) -> bool:
	return bool(_session.load_from_slot(slot)) if supports_persistence() else false


func export_replay() -> bool:
	return bool(_session.export_replay()) if supports_persistence() else false


func export_battle_trace() -> bool:
	return bool(_session.export_battle_trace()) if supports_persistence() else false


func _connect_session_signals() -> void:
	if _session == null or _connected_session == _session:
		return
	_disconnect_session_signals()
	if _session.has_signal("snapshot_received"):
		var callback := Callable(self, "_on_snapshot_received")
		if not _session.is_connected("snapshot_received", callback):
			_session.connect("snapshot_received", callback)
	_connected_session = _session


func _disconnect_session_signals() -> void:
	if _connected_session != null:
		var callback := Callable(self, "_on_snapshot_received")
		if _connected_session.has_signal("snapshot_received") and _connected_session.is_connected("snapshot_received", callback):
			_connected_session.disconnect("snapshot_received", callback)
	_connected_session = null


func _on_snapshot_received(snapshot: Dictionary, metadata: Dictionary) -> void:
	if not bool(metadata.get("asynchronous", false)) or _awaiting_commands > 0:
		return
	asynchronous_snapshot_received.emit(snapshot.duplicate(true))
