extends RefCounted

const SessionTokenScript := preload("res://session/auth/session_token.gd")
const SessionAuthorityHostScript := preload("res://session/session_authority_host.gd")

const MAX_PACKET_BYTES := 1024 * 1024
const MAX_MESSAGES_PER_WINDOW := 60
const RATE_WINDOW_MSEC := 1000

var _tcp := TCPServer.new()
var _host: RefCounted = null
var _secret := ""
var _session_id := ""
var _clients: Dictionary = {}
var _actor_connection_counts: Dictionary = {}
var _next_client_id := 0


func start(authority: RefCounted, secret: String, session_id: String, port: int, bind_address: String = "127.0.0.1") -> Dictionary:
	if authority == null or secret.length() < 32 or session_id.is_empty():
		return {"ok": false, "error": "SERVER_CONFIGURATION_INVALID"}
	var error := _tcp.listen(port, bind_address)
	if error != OK:
		return {"ok": false, "error": "SERVER_LISTEN_FAILED", "nativeCode": error}
	_host = SessionAuthorityHostScript.new(authority)
	_secret = secret
	_session_id = session_id
	return {"ok": true, "port": port, "bindAddress": bind_address}


func stop() -> void:
	for client_value in _clients.values():
		var peer := Dictionary(client_value).get("peer") as WebSocketPeer
		if peer != null:
			peer.close(1001, "server_shutdown")
	_clients.clear()
	_actor_connection_counts.clear()
	_tcp.stop()


func poll() -> void:
	while _tcp.is_connection_available():
		var stream := _tcp.take_connection()
		var peer := WebSocketPeer.new()
		peer.inbound_buffer_size = MAX_PACKET_BYTES * 2
		peer.outbound_buffer_size = MAX_PACKET_BYTES * 2
		if peer.accept_stream(stream) != OK:
			continue
		_next_client_id += 1
		_clients[_next_client_id] = {"peer": peer, "authenticated": false, "actorId": "", "windowAt": Time.get_ticks_msec(), "messageCount": 0}
	for client_id_value in _clients.keys().duplicate():
		_poll_client(int(client_id_value))


func _poll_client(client_id: int) -> void:
	var client := Dictionary(_clients.get(client_id, {}))
	var peer := client.get("peer") as WebSocketPeer
	if peer == null:
		_clients.erase(client_id)
		return
	peer.poll()
	if peer.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		var actor_id := String(client.get("actorId", ""))
		if actor_id != "":
			var remaining := maxi(0, int(_actor_connection_counts.get(actor_id, 1)) - 1)
			if remaining == 0:
				_actor_connection_counts.erase(actor_id)
				_host.unregister_actor(actor_id)
			else:
				_actor_connection_counts[actor_id] = remaining
		_clients.erase(client_id)
		return
	while peer.get_available_packet_count() > 0:
		var packet := peer.get_packet()
		if packet.size() > MAX_PACKET_BYTES or not _consume_rate(client):
			peer.close(1008, "policy_violation")
			break
		_handle_message(peer, client, packet)
	_clients[client_id] = client


func _consume_rate(client: Dictionary) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(client.get("windowAt", 0)) >= RATE_WINDOW_MSEC:
		client["windowAt"] = now
		client["messageCount"] = 0
	client["messageCount"] = int(client.get("messageCount", 0)) + 1
	return int(client.get("messageCount", 0)) <= MAX_MESSAGES_PER_WINDOW


func _handle_message(peer: WebSocketPeer, client: Dictionary, packet: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_send(peer, {"type": "error", "error": {"code": "WIRE_JSON_INVALID"}})
		return
	var message := Dictionary(_normalize_json_numbers(parsed))
	if not bool(client.get("authenticated", false)):
		_authenticate(peer, client, message)
		return
	match String(message.get("type", "")):
		"command":
			var request := Dictionary(message.get("request", {}))
			if String(request.get("actorId", "")) != String(client.get("actorId", "")) or String(request.get("sessionId", "")) != _session_id:
				_send(peer, {"type": "error", "error": {"code": "WIRE_IDENTITY_MISMATCH"}})
				return
			_send(peer, {"type": "command_response", "response": _host.handle_command(request)})
		"snapshot_request":
			_send(peer, {"type": "snapshot_response", "response": _host.handle_snapshot_request(String(client.get("actorId", "")))})
		_:
			_send(peer, {"type": "error", "error": {"code": "WIRE_MESSAGE_UNSUPPORTED"}})


func _authenticate(peer: WebSocketPeer, client: Dictionary, message: Dictionary) -> void:
	if String(message.get("type", "")) != "authenticate":
		peer.close(1008, "authentication_required")
		return
	var verified := SessionTokenScript.verify(_secret, String(message.get("token", "")))
	if not bool(verified.get("ok", false)):
		_send(peer, {"type": "error", "error": Dictionary(verified.get("error", {}))})
		peer.close(1008, "authentication_failed")
		return
	var claims := Dictionary(verified.get("claims", {}))
	if String(claims.get("sessionId", "")) != _session_id:
		peer.close(1008, "session_mismatch")
		return
	var actor_id := String(claims.get("actorId", ""))
	_host.register_actor(actor_id, {"scope": String(claims.get("scope", "player"))})
	_actor_connection_counts[actor_id] = int(_actor_connection_counts.get(actor_id, 0)) + 1
	client["authenticated"] = true
	client["actorId"] = actor_id
	_send(peer, {"type": "authenticated", "actorId": actor_id, "sessionId": _session_id})


func _send(peer: WebSocketPeer, message: Dictionary) -> void:
	peer.send_text(JSON.stringify(message))


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
