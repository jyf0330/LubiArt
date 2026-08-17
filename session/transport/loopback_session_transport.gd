extends "res://session/transport/session_transport.gd"

## Asynchronous in-memory transport used for deterministic end-to-end tests
## and listen-server mode. Delivery is deferred to preserve remote semantics.

var _host: RefCounted = null
var _actor_id := ""
var _connected := false
var _drop_next_command_response := false


func _init(host: RefCounted = null, actor_id: String = "") -> void:
	_host = host
	_actor_id = actor_id


func bind_host(host: RefCounted, actor_id: String) -> void:
	_host = host
	_actor_id = actor_id


func drop_next_command_response() -> void:
	_drop_next_command_response = true


func connect_transport() -> bool:
	if _host == null or _actor_id.is_empty():
		transport_error.emit({"code": "TRANSPORT_NOT_CONFIGURED", "message": "Loopback host and actor are required."})
		return false
	if _connected:
		return true
	_connected = true
	connected.emit({"transport": "loopback", "actorId": _actor_id})
	return true


func disconnect_transport() -> void:
	if not _connected:
		return
	_connected = false
	disconnected.emit({"transport": "loopback", "actorId": _actor_id})


func is_transport_connected() -> bool:
	return _connected


func send_command(request: Dictionary) -> bool:
	if not _connected:
		transport_error.emit({"code": "TRANSPORT_DISCONNECTED", "message": "Cannot send command while disconnected."})
		return false
	call_deferred("_deliver_command", request.duplicate(true))
	return true


func request_full_snapshot() -> bool:
	if not _connected:
		return false
	call_deferred("_deliver_full_snapshot")
	return true


func _deliver_command(request: Dictionary) -> void:
	if not _connected:
		return
	var response := Dictionary(_host.call("handle_command", request))
	if _drop_next_command_response:
		_drop_next_command_response = false
		return
	command_response.emit(response)


func _deliver_full_snapshot() -> void:
	if not _connected:
		return
	full_snapshot_received.emit(Dictionary(_host.call("handle_snapshot_request", _actor_id)))
