extends SceneTree

const YsbzsStateScript := preload("res://core/state/game_state.gd")
const SessionFactoryScript := preload("res://session/session_factory.gd")
const SessionBridgeScript := preload("res://core_ui/scripts/artist_flow/controllers/artist_flow_session_bridge.gd")

var _failed := false


func _initialize() -> void:
	var state = YsbzsStateScript.new()
	var accepted_response: Dictionary = state.run_command({"type": "GET_CELL_DETAIL", "r": 0, "c": 0})
	_expect(bool(accepted_response.get("accepted", false)), "read-only command is accepted")
	_assert_response_snapshot(accepted_response, state, "accepted response")

	var rejected_response: Dictionary = state.run_command({"type": "NOT_A_REAL_COMMAND"})
	_expect(not bool(rejected_response.get("accepted", true)), "unknown command is rejected")
	_assert_response_snapshot(rejected_response, state, "rejected response")

	var session = SessionFactoryScript.wrap_local_authority(state)
	var bridge = SessionBridgeScript.new()
	bridge.call("bind_session", session)
	var bridged_response := Dictionary(await bridge.call("submit_command", {"type": "GET_CELL_DETAIL", "x": 0, "y": 0}))
	var response_snapshot := Dictionary(bridged_response.get("snapshot", {}))
	_expect(bool(bridged_response.get("accepted", false)), "Game's Session bridge accepts the core command")
	_expect(not response_snapshot.is_empty(), "bridge returns the command response Snapshot")
	var current_snapshot := Dictionary(bridge.call("current_snapshot"))
	_expect(String(current_snapshot.get("stateHash", "")) == String(response_snapshot.get("stateHash", "")), "bridge query converges on the returned authoritative Snapshot")
	bridge.call("dispose")

	if _failed:
		quit(1)
		return
	print("SMOKE_COMMAND_SNAPSHOT_REUSE_OK")
	quit()


func _assert_response_snapshot(response: Dictionary, state, label: String) -> void:
	var response_snapshot := Dictionary(response.get("snapshot", {}))
	_expect(not response_snapshot.is_empty(), "%s includes the full snapshot" % label)
	_expect(String(response_snapshot.get("stateHash", "")) == String(response.get("stateHash", "")), "%s snapshot hash matches envelope" % label)
	_expect(int(response_snapshot.get("stateVersion", -1)) == int(response.get("stateVersion", -2)), "%s snapshot version matches envelope" % label)
	_expect(Dictionary(response_snapshot.get("viewModel", {})) == Dictionary(response.get("viewModel", {})), "%s snapshot and compatibility ViewModel match" % label)
	_expect(int(Dictionary(response.get("timing", {})).get("snapshotDurationUs", -1)) >= 0, "%s reports snapshot timing" % label)
	_expect(String(response_snapshot.get("stateHash", "")) == String(state.snapshot().get("stateHash", "")), "%s snapshot reflects current state" % label)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_COMMAND_SNAPSHOT_REUSE_FAIL: %s" % message)
