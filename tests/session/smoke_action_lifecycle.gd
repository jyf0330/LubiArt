extends SceneTree

const GameSessionScript := preload("res://session/game_session.gd")
const LocalGameSessionScript := preload("res://session/local_game_session.gd")
const YsbzsStateScript := preload("res://core/state/game_state.gd")

var _failed := false


func _initialize() -> void:
	_test_choice_pause_resume_and_cancel()
	_test_local_submission_lifecycle()
	if _failed:
		quit(1)
		return
	print("SMOKE_ACTION_LIFECYCLE_OK")
	quit(0)


func _test_choice_pause_resume_and_cancel() -> void:
	var session = GameSessionScript.new()
	var states: Array[String] = []
	session.action_lifecycle_changed.connect(func(action: Dictionary): states.append(String(action.get("state", ""))))
	var prepared: Dictionary = session.prepare_action(
		{"type": "RUN_PLAYER_ALL_OUT"},
		{"kind": "select_unit", "source": "authoritative_snapshot"}
	)
	var action_id := String(prepared.get("id", ""))
	_expect(action_id != "", "prepared action has a stable id")
	_expect(String(prepared.get("state", "")) == "awaiting_choice", "choice action pauses in awaiting_choice")
	_expect(states == ["queued", "awaiting_choice"], "queue and choice pause are observable in order")
	_expect(session.resume_action(action_id, {"unitId": "pal_001"}), "choice action resumes")
	_expect(String(session.action_snapshot(action_id).get("state", "")) == "executing", "resumed choice enters executing")
	_expect(session.complete_action(action_id, {
		"accepted": true,
		"status": "completed",
		"command": "RUN_PLAYER_ALL_OUT",
		"stateVersion": 8,
		"stateHash": "v8",
		"snapshot": {"coins": 999, "board": {"cells": [1, 2, 3]}},
	}), "executing action completes")
	var completed := session.action_snapshot(action_id)
	_expect(String(completed.get("state", "")) == "completed", "completed is terminal")
	_expect(not Dictionary(completed.get("result", {})).has("snapshot"), "lifecycle strips authoritative Snapshot payloads")
	_expect(not session.cancel_action(action_id, "too late"), "terminal actions reject later cancellation")
	_expect(session.active_action_count() == 0, "completed action is not active")

	var cancellable: Dictionary = session.prepare_action(
		{"type": "USE_ACTION_SLOT"},
		{"kind": "select_target"}
	)
	var cancel_id := String(cancellable.get("id", ""))
	_expect(session.cancel_action(cancel_id, "player_cancelled"), "awaiting choice can be cancelled")
	var cancelled := session.action_snapshot(cancel_id)
	_expect(String(cancelled.get("state", "")) == "cancelled", "cancelled action is explicit")
	_expect(String(cancelled.get("reason", "")) == "player_cancelled", "cancellation reason is retained")
	_expect(not session.resume_action(cancel_id, {}), "cancelled action cannot resume")


func _test_local_submission_lifecycle() -> void:
	var authority = YsbzsStateScript.new()
	var session = LocalGameSessionScript.new(authority)
	var states: Array[String] = []
	session.action_lifecycle_changed.connect(func(action: Dictionary): states.append(String(action.get("state", ""))))
	var response: Dictionary = session.submit_command({"type": "GET_CELL_DETAIL", "x": 0, "y": 0})
	var action_id := String(response.get("actionId", ""))
	_expect(bool(response.get("accepted", false)), "local command remains authoritative")
	_expect(String(response.get("actionStatus", "")) == "completed", "response exposes terminal action status")
	_expect(states == ["queued", "executing", "completed"], "local submit publishes the complete lifecycle")
	_expect(String(session.action_snapshot(action_id).get("state", "")) == "completed", "local lifecycle is queryable")

	states.clear()
	var rejected: Dictionary = session.submit_command({
		"type": "NEW_RUN",
		"baseStateVersion": int(authority.snapshot().get("stateVersion", 0)) + 100,
	})
	_expect(not bool(rejected.get("accepted", true)), "authoritative metadata from UI is rejected")
	_expect(states == ["queued", "executing", "rejected"], "local rejection has an explicit lifecycle")
	_expect(session.recent_actions(2).size() == 2, "recent lifecycle history retains both submissions")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_ACTION_LIFECYCLE_FAIL: %s" % message)
