extends SceneTree

const SessionBridgeScript := preload("res://core_ui/scripts/artist_flow/controllers/artist_flow_session_bridge.gd")
const CoordinatorScript := preload("res://core_ui/scripts/app/presentation_coordinator.gd")
const BattleSceneScript := preload("res://core_ui/scripts/battle/scenes/battle_scene.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_bridge_reason_contract()
	_test_source_boundaries()
	_test_trace_cursor_contract()
	print("SMOKE_PRESENTATION_FROZEN_CONTRACT_%s" % ["FAIL" if _failed else "OK"])
	quit(1 if _failed else 0)


func _test_bridge_reason_contract() -> void:
	var bridge := SessionBridgeScript.new()
	var received: Array[Dictionary] = []
	bridge.asynchronous_snapshot_received.connect(func(snapshot: Dictionary, metadata: Dictionary):
		received.append({"snapshot": snapshot, "metadata": metadata})
	)
	bridge.call("_on_snapshot_received", {"stateVersion": 1}, {
		"reason": "command",
		"asynchronous": true,
	})
	_expect(received.is_empty(), "command confirmation snapshots never reach presentation")
	bridge.call("_on_snapshot_received", {"stateVersion": 2}, {
		"reason": "load",
		"asynchronous": false,
	})
	_expect(received.is_empty(), "local load remains on the session-operation response path")
	bridge.call("_on_snapshot_received", {"stateVersion": 3}, {
		"reason": "reconnect",
		"asynchronous": true,
		"stateHash": "remote-v3",
	})
	_expect(received.size() == 1, "remote reconnect reaches presentation exactly once")
	if received.size() == 1:
		_expect(String(Dictionary(received[0]["metadata"]).get("reason", "")) == "reconnect", "bridge preserves external snapshot reason")
		_expect(int(Dictionary(received[0]["snapshot"]).get("stateVersion", -1)) == 3, "bridge preserves external snapshot value")


func _test_source_boundaries() -> void:
	var bridge_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/artist_flow_session_bridge.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://core_ui/scripts/app/presentation_coordinator.gd")
	var game_source := FileAccess.get_file_as_string("res://core_ui/scripts/app/game_controller.gd")
	var view_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/scenes/three_choice_scene.gd")
	_expect(not bridge_source.contains("_awaiting_commands"), "bridge no longer uses an awaiting-count heuristic")
	_expect(bridge_source.contains("metadata.get(\"reason\"") and bridge_source.contains("== \"command\""), "bridge classifies command snapshots by explicit reason")
	_expect(not coordinator_source.contains("core/state/game_state.gd") and not coordinator_source.contains("YsbzsState"), "presentation coordinator owns no gameplay authority")
	_expect(not coordinator_source.contains("save_to_user") and not coordinator_source.contains("load_from_user"), "presentation coordinator owns no repository path")
	_expect(game_source.contains("PresentationCoordinatorScript") and game_source.contains("submit_battle_command"), "Game owns and routes through the single presentation coordinator")
	_expect(view_source.contains("get_node_or_null(\"Board\")") and view_source.contains("missing_mapping_report"), "battle missing mappings route to the authored Board responsibility")


func _test_trace_cursor_contract() -> void:
	var battle := BattleSceneScript.new()
	battle.call("configure_trace_cursor", 7)
	_expect(int(battle.call("get_trace_cursor")) == 7, "BattleScene accepts the persistent presentation trace cursor")
	battle.call("configure_trace_cursor", -9)
	_expect(int(battle.call("get_trace_cursor")) == -1, "BattleScene clamps an uninitialized cursor to the legacy sentinel")
	battle.free()
	var coordinator := CoordinatorScript.new()
	_expect(int(coordinator.call("last_trace_cursor")) == -1, "Coordinator trace cursor starts at the legacy no-history sentinel")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_PRESENTATION_FROZEN_CONTRACT_FAIL: %s" % message)
