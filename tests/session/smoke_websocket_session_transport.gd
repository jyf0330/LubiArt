extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const SessionTokenScript := preload("res://session/auth/session_token.gd")
const ServerScript := preload("res://session/server/websocket_authority_server.gd")
const TransportScript := preload("res://session/transport/websocket_session_transport.gd")
const RemoteGameSessionScript := preload("res://session/remote_game_session.gd")

const SECRET := "0123456789abcdef0123456789abcdef"
const SESSION_ID := "websocket-smoke"
const ACTOR_ID := "player-a"
const PORT := 19127

var _failed := false
var _snapshot_received := false
var _settled: Dictionary = {}
var _session_errors: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var authority := StateScript.new({"mode": "test"})
	var server := ServerScript.new()
	var started := Dictionary(server.start(authority, SECRET, SESSION_ID, PORT))
	_expect(bool(started.get("ok", false)), "authority WebSocket server listens")
	if not bool(started.get("ok", false)):
		quit(1)
		return
	var token := SessionTokenScript.issue(SECRET, ACTOR_ID, SESSION_ID, 60, "player")
	var transport := TransportScript.new("ws://127.0.0.1:%d" % PORT, token)
	var session := RemoteGameSessionScript.new(transport, ACTOR_ID, SESSION_ID)
	session.snapshot_received.connect(func(_snapshot: Dictionary, _metadata: Dictionary): _snapshot_received = true)
	session.session_error.connect(func(error: Dictionary): _session_errors.append(error.duplicate(true)))
	_expect(session.connect_session(), "remote session begins WebSocket connection")
	for _frame in range(600):
		server.poll()
		await process_frame
		if session.is_session_connected() and _snapshot_received:
			break
	_expect(session.is_session_connected(), "HMAC authentication completes before session connection")
	if not _session_errors.is_empty():
		print("WEBSOCKET_SESSION_ERRORS ", _session_errors)
	_expect(_snapshot_received and not session.current_snapshot().is_empty(), "remote session receives an authoritative full snapshot")
	var receipt := session.submit_command({"type": "NEW_RUN"})
	_expect(bool(receipt.get("pending", false)), "authenticated player command enters the wire pipeline")
	session.command_settled.connect(func(response: Dictionary): _settled = response.duplicate(true), CONNECT_ONE_SHOT)
	for _frame in range(600):
		server.poll()
		await process_frame
		if not _settled.is_empty():
			break
	_expect(bool(_settled.get("accepted", false)), "authority accepts and settles the command over WebSocket")
	_expect(String(_settled.get("actorId", "")) == ACTOR_ID, "response retains authenticated actor identity")
	session.disconnect_session()
	server.stop()
	if _failed:
		quit(1)
		return
	print("SMOKE_WEBSOCKET_SESSION_TRANSPORT_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_WEBSOCKET_SESSION_TRANSPORT_FAIL: %s" % message)
