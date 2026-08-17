extends "res://session/game_session.gd"

const SessionProtocol := preload("res://session/session_protocol.gd")
const SETTLED_RESPONSE_CACHE_LIMIT := 128

## Client-side session adapter. It only renders confirmed authoritative
## snapshots and never executes gameplay rules locally.

var _transport: RefCounted = null
var _actor_id := ""
var _session_id := ""
var _confirmed_snapshot: Dictionary = {}
var _pending: Dictionary = {}
var _settled_responses: Dictionary = {}
var _settled_response_order: Array[String] = []
var _sequence := 0
var _client_tick := 0
var _connected := false
var _command_scope := "player"


func _init(
	transport: RefCounted = null,
	actor_id: String = "",
	session_id: String = "session",
	command_scope: String = "player"
) -> void:
	_actor_id = actor_id
	_session_id = session_id
	_command_scope = "developer" if command_scope == "developer" else "player"
	bind_transport(transport)


func bind_transport(transport: RefCounted) -> void:
	_disconnect_transport_signals()
	_transport = transport
	_connect_transport_signals()
	_connected = _transport != null and bool(_transport.call("is_transport_connected"))


func connect_session() -> bool:
	if _transport == null or not _transport.has_method("connect_transport"):
		return false
	return bool(_transport.call("connect_transport"))


func disconnect_session() -> void:
	if _transport != null and _transport.has_method("disconnect_transport"):
		_transport.call("disconnect_transport")


func is_session_connected() -> bool:
	return _connected


func pending_command_count() -> int:
	return _pending.size()


func current_snapshot() -> Dictionary:
	return _confirmed_snapshot.duplicate(true)


func submit_command(command: Dictionary) -> Dictionary:
	var intent_error := SessionProtocol.validate_command_intent(command, _command_scope)
	if not intent_error.is_empty():
		return _reject_intent(command, intent_error)
	if not _connected or _transport == null:
		var disconnected_action := _queue_submitted_action(command)
		var disconnected_action_id := String(disconnected_action.get("id", ""))
		var disconnected_response := {
			"accepted": false,
			"pending": false,
			"status": "rejected",
			"command": String(command.get("type", "")),
			"error": {"code": "SESSION_DISCONNECTED", "message": "Remote session is disconnected."},
			"snapshot": current_snapshot(),
			"actionId": disconnected_action_id,
			"actionStatus": "rejected",
		}
		_settle_submitted_action(disconnected_action_id, disconnected_response)
		command_rejected.emit(command, disconnected_response)
		command_settled.emit(disconnected_response)
		return disconnected_response

	_sequence += 1
	_client_tick += 1
	var request := SessionProtocol.make_command_request(
		command,
		_confirmed_snapshot,
		_actor_id,
		_client_tick,
		_session_id,
		_sequence
	)
	var command_id := String(request.get("commandId", ""))
	var action := _queue_submitted_action(command, command_id)
	var action_id := String(action.get("id", command_id))
	_pending[command_id] = {
		"command": command.duplicate(true),
		"request": request.duplicate(true),
		"actionId": action_id,
	}
	if not bool(_transport.call("send_command", request)):
		_pending.erase(command_id)
		var send_response := {
			"accepted": false,
			"pending": false,
			"status": "rejected",
			"command": String(command.get("type", "")),
			"commandId": command_id,
			"actionId": action_id,
			"actionStatus": "rejected",
			"error": {"code": "TRANSPORT_SEND_FAILED", "message": "Transport rejected the command."},
			"snapshot": current_snapshot()
		}
		_settle_submitted_action(action_id, send_response)
		command_rejected.emit(command, send_response)
		command_settled.emit(send_response)
		return send_response
	return {
		"accepted": false,
		"pending": true,
		"status": "pending",
		"command": String(command.get("type", "")),
		"commandId": command_id,
		"actionId": action_id,
		"actionStatus": "executing",
		"snapshot": current_snapshot()
	}


func _reject_intent(command: Dictionary, error: Dictionary) -> Dictionary:
	var action := _queue_submitted_action(command)
	var action_id := String(action.get("id", ""))
	var response := {
		"accepted": false,
		"pending": false,
		"status": "rejected",
		"command": String(command.get("type", "")),
		"error": error.duplicate(true),
		"snapshot": current_snapshot(),
		"actionId": action_id,
		"actionStatus": "rejected",
	}
	_settle_submitted_action(action_id, response)
	command_rejected.emit(command, response)
	command_settled.emit(response)
	return response


func submit_command_and_wait(command: Dictionary) -> Dictionary:
	var receipt := submit_command(command)
	if not bool(receipt.get("pending", false)):
		return receipt
	var command_id := String(receipt.get("commandId", ""))
	if _settled_responses.has(command_id):
		return _take_settled_response(command_id)
	while true:
		var response: Dictionary = await command_settled
		if String(response.get("commandId", "")) == command_id:
			_settled_responses.erase(command_id)
			_settled_response_order.erase(command_id)
			return response
	return {
		"accepted": false,
		"pending": false,
		"status": "rejected",
		"commandId": command_id,
		"error": {"code": "COMMAND_WAIT_ABORTED", "message": "Command wait ended without a final response."},
		"snapshot": current_snapshot()
	}


func _connect_transport_signals() -> void:
	if _transport == null:
		return
	_bind_signal(&"connected", _on_transport_connected)
	_bind_signal(&"disconnected", _on_transport_disconnected)
	_bind_signal(&"command_response", _on_command_response)
	_bind_signal(&"full_snapshot_received", _on_full_snapshot_received)
	_bind_signal(&"transport_error", _on_transport_error)


func _disconnect_transport_signals() -> void:
	if _transport == null:
		return
	_unbind_signal(&"connected", _on_transport_connected)
	_unbind_signal(&"disconnected", _on_transport_disconnected)
	_unbind_signal(&"command_response", _on_command_response)
	_unbind_signal(&"full_snapshot_received", _on_full_snapshot_received)
	_unbind_signal(&"transport_error", _on_transport_error)


func _bind_signal(signal_name: StringName, callable: Callable) -> void:
	if _transport.has_signal(signal_name) and not _transport.is_connected(signal_name, callable):
		_transport.connect(signal_name, callable)


func _unbind_signal(signal_name: StringName, callable: Callable) -> void:
	if _transport.has_signal(signal_name) and _transport.is_connected(signal_name, callable):
		_transport.disconnect(signal_name, callable)


func _on_transport_connected(metadata: Dictionary) -> void:
	_connected = true
	connection_state_changed.emit(true, metadata)
	var pending_entries: Array = _pending.values()
	pending_entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(Dictionary(left.get("request", {})).get("clientTick", 0)) \
			< int(Dictionary(right.get("request", {})).get("clientTick", 0))
	)
	for pending_value in pending_entries:
		var pending_entry := Dictionary(pending_value)
		_transport.call("send_command", Dictionary(pending_entry.get("request", {})).duplicate(true))
	_transport.call("request_full_snapshot")


func _on_transport_disconnected(metadata: Dictionary) -> void:
	_connected = false
	connection_state_changed.emit(false, metadata)


func _on_command_response(response: Dictionary) -> void:
	var command_id := String(response.get("commandId", ""))
	if not _pending.has(command_id):
		return
	var pending_entry := Dictionary(_pending[command_id])
	_pending.erase(command_id)
	var command := Dictionary(pending_entry.get("command", {}))
	var action_id := String(pending_entry.get("actionId", command_id))
	if int(response.get("protocolVersion", -1)) != SessionProtocol.PROTOCOL_VERSION:
		var protocol_error := {"code": "PROTOCOL_RESPONSE_INVALID", "message": "Authority returned an unsupported protocol response."}
		var invalid_response := {"accepted": false, "pending": false, "status": "rejected", "commandId": command_id, "actionId": action_id, "actionStatus": "rejected", "error": protocol_error, "snapshot": current_snapshot()}
		_settle_submitted_action(action_id, invalid_response)
		session_error.emit(protocol_error)
		command_rejected.emit(command, invalid_response)
		_remember_settled_response(invalid_response)
		command_settled.emit(invalid_response)
		return
	response["pending"] = false
	response["status"] = "completed" if bool(response.get("accepted", false)) else "rejected"
	response["actionId"] = action_id
	response["actionStatus"] = String(response.get("status", ""))
	_settle_submitted_action(action_id, response)
	var snapshot := Dictionary(response.get("snapshot", {}))
	if not snapshot.is_empty():
		_apply_confirmed_snapshot(snapshot, &"command", false)
	if bool(response.get("accepted", false)):
		command_completed.emit(command, response)
	else:
		command_rejected.emit(command, response)
	_remember_settled_response(response)
	command_settled.emit(response)


func _remember_settled_response(response: Dictionary) -> void:
	var command_id := String(response.get("commandId", ""))
	if command_id.is_empty():
		return
	_settled_responses[command_id] = response.duplicate(true)
	_settled_response_order.erase(command_id)
	_settled_response_order.append(command_id)
	while _settled_response_order.size() > SETTLED_RESPONSE_CACHE_LIMIT:
		var expired_id: String = _settled_response_order.pop_front()
		_settled_responses.erase(expired_id)


func _take_settled_response(command_id: String) -> Dictionary:
	var response := Dictionary(_settled_responses.get(command_id, {})).duplicate(true)
	_settled_responses.erase(command_id)
	_settled_response_order.erase(command_id)
	return response


func _on_full_snapshot_received(response: Dictionary) -> void:
	if int(response.get("protocolVersion", -1)) != SessionProtocol.PROTOCOL_VERSION:
		session_error.emit({"code": "PROTOCOL_RESPONSE_INVALID", "message": "Authority returned an unsupported snapshot response."})
		return
	if not bool(response.get("accepted", false)):
		session_error.emit(Dictionary(response.get("error", {})))
		return
	var snapshot := Dictionary(response.get("snapshot", {}))
	if snapshot.is_empty():
		session_error.emit({"code": "FULL_SNAPSHOT_MISSING", "message": "Authority returned no recovery snapshot."})
		return
	_apply_confirmed_snapshot(snapshot, &"reconnect", true)


func _on_transport_error(error: Dictionary) -> void:
	session_error.emit(error)


func _apply_confirmed_snapshot(snapshot: Dictionary, reason: StringName, force: bool) -> void:
	var snapshot_error := SessionProtocol.validate_snapshot(snapshot)
	if not snapshot_error.is_empty():
		session_error.emit(snapshot_error)
		return
	var incoming_version := int(snapshot.get("stateVersion", -1))
	var current_version := int(_confirmed_snapshot.get("stateVersion", -1))
	if not force and incoming_version < current_version:
		session_error.emit({
			"code": "STALE_SERVER_SNAPSHOT",
			"message": "Ignored an older authoritative snapshot.",
			"incomingStateVersion": incoming_version,
			"currentStateVersion": current_version
		})
		return
	_confirmed_snapshot = snapshot.duplicate(true)
	snapshot_received.emit(current_snapshot(), {
		"adapter": "remote",
		"asynchronous": true,
		"reason": String(reason),
		"stateVersion": incoming_version,
		"stateHash": String(snapshot.get("stateHash", ""))
	})
