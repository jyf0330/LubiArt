extends "res://session/transport/session_transport.gd"

## Production WebSocket client transport. Authentication completes before the
## connected signal is emitted, so RemoteGameSession never sends unauthenticated
## commands. TLS is selected by the wss:// URL and normally terminates at nginx.

const MAX_PACKET_BYTES := 1024 * 1024

var _url := ""
var _token := ""
var _peer := WebSocketPeer.new()
var _polling := false
var _authenticated := false


func _init(url: String = "", token: String = "") -> void:
	_url = url
	_token = token


func configure(url: String, token: String) -> void:
	_url = url
	_token = token


func connect_transport() -> bool:
	if _url.is_empty() or _token.is_empty() or _polling:
		return false
	_peer.inbound_buffer_size = MAX_PACKET_BYTES * 2
	_peer.outbound_buffer_size = MAX_PACKET_BYTES * 2
	var error := _peer.connect_to_url(_url)
	if error != OK:
		transport_error.emit({"code": "TRANSPORT_CONNECT_FAILED", "nativeCode": error})
		return false
	_polling = true
	_authenticated = false
	_poll_loop()
	return true


func disconnect_transport() -> void:
	_polling = false
	if _peer.get_ready_state() in [WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_OPEN]:
		_peer.close(1000, "client_disconnect")
	if _authenticated:
		_authenticated = false
		disconnected.emit({"transport": "websocket", "reason": "client_disconnect"})


func is_transport_connected() -> bool:
	return _authenticated and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN


func send_command(request: Dictionary) -> bool:
	return _send({"type": "command", "request": request})


func request_full_snapshot() -> bool:
	return _send({"type": "snapshot_request"})


func _poll_loop() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	while _polling and tree != null:
		_peer.poll()
		var state := _peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			if not _authenticated and not bool(_peer.get_meta("auth_sent", false)):
				_peer.set_meta("auth_sent", true)
				_peer.send_text(JSON.stringify({"type": "authenticate", "token": _token}))
			while _peer.get_available_packet_count() > 0:
				_receive_packet(_peer.get_packet())
		elif state == WebSocketPeer.STATE_CLOSED:
			var was_authenticated := _authenticated
			_polling = false
			_authenticated = false
			if was_authenticated:
				disconnected.emit({"transport": "websocket", "code": _peer.get_close_code(), "reason": _peer.get_close_reason()})
			else:
				transport_error.emit({"code": "TRANSPORT_CLOSED_BEFORE_AUTH", "nativeCode": _peer.get_close_code()})
			return
		await tree.process_frame


func _receive_packet(packet: PackedByteArray) -> void:
	if packet.size() > MAX_PACKET_BYTES:
		transport_error.emit({"code": "TRANSPORT_PACKET_TOO_LARGE"})
		disconnect_transport()
		return
	var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		transport_error.emit({"code": "TRANSPORT_JSON_INVALID"})
		return
	var message := Dictionary(_normalize_json_numbers(parsed))
	match String(message.get("type", "")):
		"authenticated":
			_authenticated = true
			connected.emit({"transport": "websocket", "actorId": String(message.get("actorId", ""))})
		"command_response":
			command_response.emit(Dictionary(message.get("response", {})))
		"snapshot_response":
			full_snapshot_received.emit(Dictionary(message.get("response", {})))
		"error":
			transport_error.emit(Dictionary(message.get("error", {})))


func _send(message: Dictionary) -> bool:
	if not is_transport_connected():
		return false
	return _peer.send_text(JSON.stringify(message)) == OK


func _normalize_json_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), round(float(value))):
		return int(value)
	if typeof(value) == TYPE_ARRAY:
		var rows: Array = []
		for row in Array(value):
			rows.append(_normalize_json_numbers(row))
		return rows
	if typeof(value) == TYPE_DICTIONARY:
		var result := {}
		for key in Dictionary(value):
			result[key] = _normalize_json_numbers(Dictionary(value)[key])
		return result
	return value
