extends SceneTree

const GameSessionScript := preload("res://session/game_session.gd")
const LocalGameSessionScript := preload("res://session/local_game_session.gd")
const YsbzsStateScript := preload("res://core/state/game_state.gd")
const SessionFactoryScript := preload("res://session/session_factory.gd")
const GameScene := preload("res://art/scenes/app/game.tscn")

var _failed := false
var _completed_count := 0
var _rejected_count := 0
var _snapshot_count := 0
var _load_snapshot_count := 0


class PersistenceAuthority extends RefCounted:
	var saved_slots: Array[int] = []
	var loaded_slots: Array[int] = []
	var replay_exports := 0
	var trace_exports := 0
	var history_resumes: Array = []
	var history_day_resumes: Array = []

	func snapshot() -> Dictionary:
		return {"stateVersion": 7, "stateHash": "fake-state"}

	func save_to_user(slot: int = 1) -> bool:
		saved_slots.append(slot)
		return true

	func load_from_user(slot: int = 1) -> bool:
		loaded_slots.append(slot)
		return true

	func save_replay_to_user() -> bool:
		replay_exports += 1
		return true

	func save_battle_trace_to_user() -> bool:
		trace_exports += 1
		return true

	func supports_run_history() -> bool:
		return true

	func run_history_runs() -> Array:
		return [{"runId": "run-fixture"}]

	func run_history_checkpoints(run_id: String = "") -> Array:
		return [{"runId": run_id, "checkpointId": "day_001_end"}]

	func run_history_checkpoint_for_day(run_id: String, day: int, kind: String = "start") -> Dictionary:
		return {
			"runId": run_id,
			"checkpointId": "day_%03d_%s" % [day, kind],
			"day": day,
			"kind": kind
		}

	func resume_from_run_history(run_id: String, checkpoint_id: String) -> bool:
		history_resumes.append([run_id, checkpoint_id])
		return true

	func resume_from_run_history_day(run_id: String, day: int, kind: String = "start") -> bool:
		history_day_resumes.append([run_id, day, kind])
		return true


class EmptyContentRepository extends RefCounted:
	func read_content_pack(_path: String) -> Dictionary:
		return {}

	func content_errors() -> Array[String]:
		return []

	func read_dictionary(_path: String) -> Dictionary:
		return {"nodes": []}


func _initialize() -> void:
	_test_controller_source_boundary()
	_test_unbound_session_rejects()
	_test_local_authority_commands_and_snapshots()
	_test_factory_rejects_uninitialized_authority()
	_test_persistence_delegation()
	_test_game_shell_uses_replaceable_session()

	if _failed:
		quit(1)
		return
	print("SMOKE_GAME_SESSION_BOUNDARY_OK completed=%d rejected=%d snapshots=%d" % [
		_completed_count,
		_rejected_count,
		_snapshot_count
	])
	quit()


func _test_controller_source_boundary() -> void:
	var game_source := FileAccess.get_file_as_string("res://core_ui/scripts/app/game_controller.gd")
	var view_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/scenes/three_choice_scene.gd")
	var bridge_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/artist_flow_session_bridge.gd")
	var battle_debug_source := FileAccess.get_file_as_string("res://core_ui/scripts/debug/battle_debug.gd")
	_expect(game_source.contains("SessionBridgeScript") and game_source.contains("SessionFactoryScript.create_local_result"), "Game owns validated Session creation and delegates its port operations")
	_expect(not bridge_source.contains("SessionFactoryScript"), "session bridge cannot create a fallback authority")
	_expect(not view_source.contains("SessionBridgeScript") and not view_source.contains("YsbzsStateScript"), "presentation view owns neither Session nor core authority")
	_expect(not view_source.contains("state.run_command("), "presentation view does not bypass session command port")
	_expect(not view_source.contains("state.snapshot()"), "presentation view does not bypass session query port")
	_expect(not view_source.contains("state.save_to_user("), "presentation view does not bypass session persistence port")
	_expect(not view_source.contains("state.load_from_user("), "presentation view does not bypass session load port")
	_expect(battle_debug_source.contains("SessionFactoryScript.create_isolated_developer_result"), "battle debug harness creates a deny-I/O simulation authority only through SessionFactory")
	_expect(battle_debug_source.contains("submit_command") and battle_debug_source.contains("current_snapshot"), "battle debug harness uses public session command and query ports")
	_expect(not battle_debug_source.contains("core/state/game_state.gd") and not battle_debug_source.contains(".dispatch("), "battle debug harness cannot bypass the session boundary")
	_expect(not FileAccess.file_exists("res://core_ui/scripts/debug/legacy_singleplayer_controller.gd"), "unrouted legacy debug controller is retired instead of maintaining a second write path")


func _test_unbound_session_rejects() -> void:
	var session = GameSessionScript.new()
	var response: Dictionary = session.submit_command({"type": "NEW_RUN"})
	_expect(not bool(response.get("accepted", true)), "unbound port rejects commands")
	_expect(String(response.get("status", "")) == "rejected" and not bool(response.get("pending", true)), "unbound rejection uses the final response contract")
	_expect(String(Dictionary(response.get("error", {})).get("code", "")) == "SESSION_NOT_READY", "unbound rejection is explicit")


func _test_local_authority_commands_and_snapshots() -> void:
	var authority = YsbzsStateScript.new()
	var session = LocalGameSessionScript.new(authority)
	_expect(session.is_session_connected(), "local session is connected when authority is bound")
	_expect(session.connect_session(), "local connect remains a synchronous no-op")
	_expect(session.pending_command_count() == 0, "local session never owns asynchronous pending commands")
	session.command_completed.connect(func(_command: Dictionary, _response: Dictionary): _completed_count += 1)
	session.command_rejected.connect(func(_command: Dictionary, _response: Dictionary): _rejected_count += 1)
	session.snapshot_received.connect(func(_snapshot: Dictionary, metadata: Dictionary):
		_snapshot_count += 1
		_expect(String(metadata.get("adapter", "")) == "local", "snapshot identifies local adapter")
		_expect(not bool(metadata.get("asynchronous", true)), "local snapshot is marked synchronous")
	)

	var initial_snapshot: Dictionary = session.current_snapshot()
	_expect(not initial_snapshot.is_empty(), "local session exposes authoritative snapshot")
	_expect(String(initial_snapshot.get("stateHash", "")) == String(authority.snapshot().get("stateHash", "")), "session snapshot matches authority")

	var accepted: Dictionary = session.submit_command({"type": "GET_CELL_DETAIL", "x": 0, "y": 0})
	_expect(bool(accepted.get("accepted", false)), "local session forwards accepted command")
	_expect(String(accepted.get("status", "")) == "completed" and not bool(accepted.get("pending", true)), "local accepted command is final")
	_expect(_completed_count == 1, "accepted command emits completion")
	_expect(_snapshot_count == 1, "accepted command emits returned snapshot")

	var spoofed_metadata: Dictionary = session.submit_command({
		"type": "NEW_RUN",
		"baseStateVersion": int(initial_snapshot.get("stateVersion", 0)) + 100
	})
	_expect(not bool(spoofed_metadata.get("accepted", true)), "UI cannot submit authoritative baseline metadata")
	_expect(String(Dictionary(spoofed_metadata.get("error", {})).get("code", "")) == "COMMAND_FIELD_NOT_ALLOWED", "metadata rejection happens before authority execution")
	_expect(String(spoofed_metadata.get("status", "")) == "rejected" and not bool(spoofed_metadata.get("pending", true)), "local rejection is final")
	_expect(_rejected_count == 1, "rejected command emits rejection")

	var invalid_authority_session = LocalGameSessionScript.new(RefCounted.new())
	_expect(not invalid_authority_session.is_session_connected(), "local session rejects an authority without the command and snapshot contract")
	_expect(not invalid_authority_session.connect_session(), "invalid local authority cannot report a successful connection")


func _test_factory_rejects_uninitialized_authority() -> void:
	var result := Dictionary(SessionFactoryScript.create_local_result({
		"core_overrides": {"game_data_repository": EmptyContentRepository.new()},
	}))
	_expect(not bool(result.get("ok", true)), "SessionFactory reports failed authority initialization")
	_expect(result.get("session") == null, "SessionFactory does not expose a Session for failed initialization")
	_expect(Array(Dictionary(result.get("initialization", {})).get("errors", [])) == ["CONTENT_PACK_EMPTY"], "SessionFactory preserves the stable initialization error")


func _test_persistence_delegation() -> void:
	var authority := PersistenceAuthority.new()
	var session = LocalGameSessionScript.new(authority)
	_expect(session.supports_persistence(), "local session advertises persistence only when the authority implements it")
	_expect(session.persistence_slot_count() == 3, "local persistence capability exposes the supported slot count")
	session.snapshot_received.connect(func(_snapshot: Dictionary, metadata: Dictionary):
		if String(metadata.get("reason", "")) == "load":
			_load_snapshot_count += 1
	)
	_expect(session.save_to_slot(2), "save delegates through session")
	_expect(session.load_from_slot(3), "load delegates through session")
	_expect(session.export_replay(), "replay export delegates through session")
	_expect(session.export_battle_trace(), "battle trace export delegates through session")
	_expect(session.supports_run_history(), "local session advertises run-history capability explicitly")
	_expect(String(Dictionary(session.run_history_runs()[0]).get("runId", "")) == "run-fixture", "history run index delegates through session")
	_expect(String(Dictionary(session.run_history_checkpoints("run-fixture")[0]).get("checkpointId", "")) == "day_001_end", "history checkpoint index delegates through session")
	_expect(String(session.run_history_checkpoint_for_day("run-fixture", 7).get("checkpointId", "")) == "day_007_start", "day lookup delegates through the direct time-point index")
	_expect(session.resume_from_run_history("run-fixture", "day_001_end"), "history resume delegates through session")
	_expect(session.resume_from_run_history_day("run-fixture", 7), "day resume delegates without replaying earlier commands")
	_expect(authority.saved_slots == [2] and authority.loaded_slots == [3], "slot arguments reach authority")
	_expect(authority.replay_exports == 1 and authority.trace_exports == 1, "export calls reach authority once")
	_expect(authority.history_resumes == [["run-fixture", "day_001_end"]], "history resume ids reach authority")
	_expect(authority.history_day_resumes == [["run-fixture", 7, "start"]], "direct day resume reaches authority")
	_expect(_load_snapshot_count == 1, "successful load publishes refreshed snapshot")


func _test_game_shell_uses_replaceable_session() -> void:
	var first_authority = YsbzsStateScript.new()
	first_authority.set_run_seed("session-first")
	var game = GameScene.instantiate()
	game.set("state", first_authority)
	var first_session = game.call("get_game_session")
	_expect(first_session.call("get_authority") == first_authority, "Game creates a local adapter for injected state")
	var command_response := Dictionary(first_session.call("submit_command", {"type": "GET_CELL_DETAIL", "x": 0, "y": 0}))
	_expect(bool(command_response.get("accepted", false)), "Game-owned Session submits commands")

	var second_authority = YsbzsStateScript.new()
	second_authority.set_run_seed("session-second")
	game.set("state", second_authority)
	var second_session = game.call("get_game_session")
	var rebound_snapshot: Dictionary = Dictionary(second_session.call("current_snapshot"))
	_expect(second_session != first_session and second_session.call("get_authority") == second_authority, "Game replaces the local adapter with the injected authority")
	_expect(String(rebound_snapshot.get("run_seed", "")) == "session-second", "Game reads replacement authority through its Session")
	var external_session = GameSessionScript.new()
	game.call("set_game_session", external_session)
	_expect(game.call("get_game_session") == external_session, "Game preserves an explicitly injected non-local Session")
	game.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_GAME_SESSION_BOUNDARY_FAIL: %s" % message)
