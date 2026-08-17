extends SceneTree

const SessionProtocol := preload("res://session/session_protocol.gd")
const SessionAuthorityHost := preload("res://session/session_authority_host.gd")
const LoopbackSessionTransport := preload("res://session/transport/loopback_session_transport.gd")
const RemoteGameSession := preload("res://session/remote_game_session.gd")
const SessionBridgeScript := preload("res://core_ui/scripts/artist_flow/controllers/artist_flow_session_bridge.gd")

var _failed := false
var _completed_count := 0
var _rejected_count := 0
var _snapshot_count := 0
var _connection_count := 0
var _last_rejection_code := ""
var _last_completion_duplicate := false


class ContractAuthority extends RefCounted:
	var state_version := 0
	var run_seed := "initial"

	func set_run_seed(value: String) -> void:
		run_seed = value

	func snapshot() -> Dictionary:
		return {
			"stateVersion": state_version,
			"stateHash": "contract-v%d-%s" % [state_version, run_seed],
			"run_seed": run_seed
		}

	func run_command(command: Dictionary) -> Dictionary:
		var action_type := String(command.get("type", ""))
		if command.has("baseStateVersion") and int(command.get("baseStateVersion", -1)) != state_version:
			return {
				"accepted": false,
				"command": action_type,
				"error": {"code": "STATE_VERSION_MISMATCH", "message": "stale contract command"},
				"snapshot": snapshot()
			}
		if action_type == "NEW_RUN":
			run_seed = String(command.get("seed", run_seed))
			state_version += 1
		return {
			"accepted": true,
			"command": action_type,
			"stateVersion": state_version,
			"stateHash": String(snapshot().get("stateHash", "")),
			"snapshot": snapshot()
		}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var authority := ContractAuthority.new()
	authority.set_run_seed("remote-session-foundation")
	var host = SessionAuthorityHost.new(authority)
	_expect(host.register_actor("player-a", {"role": "player"}), "authority registers a valid actor")

	var transport = LoopbackSessionTransport.new(host, "player-a")
	var session = RemoteGameSession.new(transport, "player-a", "room-1")
	session.command_completed.connect(func(_command: Dictionary, response: Dictionary):
		_completed_count += 1
		_last_completion_duplicate = bool(response.get("duplicate", false))
	)
	session.command_rejected.connect(func(_command: Dictionary, response: Dictionary):
		_rejected_count += 1
		_last_rejection_code = String(Dictionary(response.get("error", {})).get("code", ""))
	)
	session.snapshot_received.connect(func(_snapshot: Dictionary, metadata: Dictionary):
		_snapshot_count += 1
		_expect(String(metadata.get("adapter", "")) == "remote", "remote snapshot identifies its adapter")
		_expect(bool(metadata.get("asynchronous", false)), "remote snapshot is asynchronous")
	)
	session.connection_state_changed.connect(func(_connected: bool, _metadata: Dictionary): _connection_count += 1)

	_expect(session.connect_session(), "remote session connects through transport")
	await process_frame
	await process_frame
	_expect(session.is_session_connected(), "remote session reports connected")
	_expect(_connection_count == 1, "connection state is published once")
	_expect(_snapshot_count == 1, "connect requests a full authoritative snapshot")
	_expect(_same_snapshot_identity(session.current_snapshot(), authority.snapshot()), "initial remote snapshot matches authority")

	var pending: Dictionary = session.submit_command({"type": "GET_CELL_DETAIL", "x": 0, "y": 0})
	_expect(not bool(pending.get("accepted", true)) and bool(pending.get("pending", false)), "remote pending receipt is not an authoritative acceptance")
	_expect(String(pending.get("status", "")) == "pending", "remote submit exposes an explicit pending status")
	_expect(session.pending_command_count() == 1, "pending command is retained until server response")
	await process_frame
	await process_frame
	_expect(_completed_count == 1, "accepted server response completes the command")
	_expect(session.pending_command_count() == 0, "server response clears pending command")
	_expect(_same_snapshot_identity(session.current_snapshot(), authority.snapshot()), "confirmed command snapshot matches authority")

	var awaited: Dictionary = await session.submit_command_and_wait({"type": "GET_CELL_DETAIL", "x": 0, "y": 0})
	_expect(bool(awaited.get("accepted", false)) and not bool(awaited.get("pending", true)), "awaited remote command returns only after authority confirmation")
	_expect(String(awaited.get("status", "")) == "completed", "awaited remote command shares the local final-response status")
	_expect(not session.supports_persistence(), "remote session does not advertise unimplemented local persistence")
	var bridge = SessionBridgeScript.new()
	bridge.call("bind_session", session)
	var bridged_response := Dictionary(await bridge.call("submit_command", {"type": "GET_CELL_DETAIL", "x": 0, "y": 0}))
	_expect(bool(bridged_response.get("accepted", false)), "Game's Session bridge can substitute a remote Session and wait for final acceptance")
	_expect(_same_snapshot_identity(Dictionary(bridged_response.get("snapshot", {})), authority.snapshot()), "bridge returns the confirmed remote snapshot instead of the pending receipt")
	bridge.call("dispose")

	var spoofed_metadata: Dictionary = session.submit_command({
		"type": "NEW_RUN",
		"baseStateVersion": int(authority.snapshot().get("stateVersion", 0)) + 100
	})
	_expect(not bool(spoofed_metadata.get("pending", true)), "UI metadata spoof is rejected before transport")
	_expect(String(Dictionary(spoofed_metadata.get("error", {})).get("code", "")) == "COMMAND_FIELD_NOT_ALLOWED", "remote Session applies the same intent schema as local")

	transport.drop_next_command_response()
	var lost_response: Dictionary = session.submit_command({"type": "NEW_RUN", "seed": "lost-response-retry"})
	_expect(bool(lost_response.get("pending", false)), "command enters pending before simulated response loss")
	await process_frame
	await process_frame
	_expect(session.pending_command_count() == 1, "lost response keeps original command pending")
	var authority_after_lost_response := authority.snapshot()
	session.disconnect_session()
	_expect(session.connect_session(), "session reconnects with an unconfirmed command")
	await process_frame
	await process_frame
	_expect(session.pending_command_count() == 0, "reconnect resends and confirms the original envelope")
	_expect(_last_completion_duplicate, "authority marks retried command as cached duplicate")
	_expect(_same_snapshot_identity(authority_after_lost_response, authority.snapshot()), "retried command is not executed twice")
	_expect(_same_snapshot_identity(session.current_snapshot(), authority.snapshot()), "retry and full recovery converge on authority")

	_test_protocol_and_idempotency(host, authority)
	await _test_unauthorized_actor(host)

	var cached_before_disconnect := session.current_snapshot()
	session.disconnect_session()
	_expect(not session.is_session_connected(), "disconnect updates remote session state")
	var disconnected: Dictionary = session.submit_command({"type": "GET_CELL_DETAIL", "x": 0, "y": 0})
	_expect(String(Dictionary(disconnected.get("error", {})).get("code", "")) == "SESSION_DISCONNECTED", "disconnected commands fail explicitly")

	var server_request := SessionProtocol.make_command_request(
		{"type": "NEW_RUN", "seed": "server-progress-while-offline"},
		authority.snapshot(),
		"player-a",
		88,
		"room-1",
		88
	)
	var server_progress: Dictionary = host.handle_command(server_request)
	_expect(bool(server_progress.get("accepted", false)), "authority can progress while client is offline")
	_expect(not _same_snapshot_identity(cached_before_disconnect, authority.snapshot()), "offline client cache does not advance itself")

	_expect(session.connect_session(), "remote session reconnects")
	await process_frame
	await process_frame
	_expect(_same_snapshot_identity(session.current_snapshot(), authority.snapshot()), "reconnect replaces cache with full authoritative snapshot")

	if _failed:
		quit(1)
		return
	print("SMOKE_REMOTE_GAME_SESSION_OK completed=%d rejected=%d snapshots=%d connections=%d" % [
		_completed_count,
		_rejected_count,
		_snapshot_count,
		_connection_count
	])
	quit()


func _test_protocol_and_idempotency(host: RefCounted, authority: RefCounted) -> void:
	var before := Dictionary(authority.call("snapshot"))
	var request := SessionProtocol.make_command_request(
		{"type": "NEW_RUN", "seed": "idempotent-command"},
		before,
		"player-a",
		50,
		"room-1",
		50
	)
	var first: Dictionary = host.call("handle_command", request)
	_expect(bool(first.get("accepted", false)), "first authoritative command is accepted")
	var version_after_first := int(Dictionary(authority.call("snapshot")).get("stateVersion", -1))
	var duplicate: Dictionary = host.call("handle_command", request)
	_expect(bool(duplicate.get("accepted", false)) and bool(duplicate.get("duplicate", false)), "same command delivery returns cached response")
	_expect(int(Dictionary(authority.call("snapshot")).get("stateVersion", -1)) == version_after_first, "duplicate command does not execute twice")

	var collision := request.duplicate(true)
	collision["seed"] = "different-payload"
	var collision_response: Dictionary = host.call("handle_command", collision)
	_expect(String(Dictionary(collision_response.get("error", {})).get("code", "")) == "COMMAND_ID_COLLISION", "same command ID with different payload is rejected")

	var invalid_version := request.duplicate(true)
	invalid_version["commandId"] = "unsupported-protocol"
	invalid_version["protocolVersion"] = 999
	var invalid_response: Dictionary = host.call("handle_command", invalid_version)
	_expect(String(Dictionary(invalid_response.get("error", {})).get("code", "")) == "PROTOCOL_VERSION_UNSUPPORTED", "unsupported wire protocol is rejected before core execution")

	host.call("set_authorization_policy", func(_actor_id: String, command: Dictionary, _snapshot: Dictionary, _permissions: Dictionary) -> Dictionary:
		if String(command.get("type", "")) == "SELL_UNIT":
			return {"allowed": false, "error": {"code": "UNIT_NOT_OWNED", "message": "unit ownership contract"}}
		return {"allowed": true}
	)
	var forbidden := SessionProtocol.make_command_request(
		{"type": "SELL_UNIT", "unitId": "other-player-unit"},
		Dictionary(authority.call("snapshot")),
		"player-a",
		70,
		"room-1",
		70
	)
	var forbidden_response: Dictionary = host.call("handle_command", forbidden)
	_expect(String(Dictionary(forbidden_response.get("error", {})).get("code", "")) == "UNIT_NOT_OWNED", "injected ownership policy rejects unauthorized game objects")
	host.call("set_authorization_policy", Callable())

	var replayed_tick := SessionProtocol.make_command_request(
		{"type": "GET_CELL_DETAIL", "x": 0, "y": 0},
		Dictionary(authority.call("snapshot")),
		"player-a",
		49,
		"room-1",
		71
	)
	var replayed_response: Dictionary = host.call("handle_command", replayed_tick)
	_expect(String(Dictionary(replayed_response.get("error", {})).get("code", "")) == "CLIENT_TICK_REPLAYED", "new command IDs cannot replay an older client tick")


func _test_unauthorized_actor(host: RefCounted) -> void:
	var transport = LoopbackSessionTransport.new(host, "intruder")
	var session = RemoteGameSession.new(transport, "intruder", "room-1")
	var rejection_code := [""]
	session.command_rejected.connect(func(_command: Dictionary, response: Dictionary):
		rejection_code[0] = String(Dictionary(response.get("error", {})).get("code", ""))
	)
	_expect(session.connect_session(), "transport can connect before authority authorization")
	await process_frame
	await process_frame
	session.submit_command({"type": "GET_CELL_DETAIL", "x": 0, "y": 0})
	await process_frame
	await process_frame
	_expect(String(rejection_code[0]) == "ACTOR_NOT_AUTHORIZED", "unregistered actor cannot execute core commands")
	session.disconnect_session()


func _same_snapshot_identity(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("stateVersion", -1)) == int(right.get("stateVersion", -2)) \
		and String(left.get("stateHash", "")) == String(right.get("stateHash", "missing"))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_REMOTE_GAME_SESSION_FAIL: %s" % message)
