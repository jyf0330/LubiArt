extends SceneTree

const CoordinatorScript := preload("res://core_ui/scripts/app/presentation_coordinator.gd")
const ThreeChoiceScene := preload("res://art/scenes/three_choice/three_choice_scene.tscn")

var _failed := false


class FakeBridge extends RefCounted:
	var active_submissions := 0
	var max_active_submissions := 0
	var submit_order: Array[String] = []
	var next_version := 0
	var delay_frames := 2

	func submit_command(command: Dictionary) -> Dictionary:
		active_submissions += 1
		max_active_submissions = maxi(max_active_submissions, active_submissions)
		submit_order.append(String(command.get("label", command.get("type", ""))))
		for _frame in range(delay_frames):
			await Engine.get_main_loop().process_frame
		next_version += 1
		active_submissions -= 1
		var snapshot := {
			"stateVersion": next_version,
			"stateHash": "fake-v%d" % next_version,
			"phase": String(command.get("phase", "route")),
			"battleTrace": Array(command.get("battleTrace", [])),
		}
		return {
			"accepted": true,
			"command": String(command.get("type", "")),
			"snapshot": snapshot,
		}

	func current_snapshot() -> Dictionary:
		return {
			"stateVersion": next_version,
			"stateHash": "fake-v%d" % next_version,
			"phase": "route",
		}


class FakeBattleView extends Control:
	var cursor := -1

	func configure_trace_cursor(value: int) -> void:
		cursor = value

	func get_trace_cursor() -> int:
		return cursor


class FakeView extends Control:
	var command_ids: Array[int] = []
	var battle_commands: Array[String] = []
	var external_versions: Array[int] = []
	var operation_ids: Array[int] = []
	var timeline: Array[String] = []
	var busy := false
	var render_delay_frames := 2

	func complete_command_request(request_id: int, _response: Dictionary) -> void:
		command_ids.append(request_id)
		busy = true
		_clear_busy_after_frame()

	func complete_session_operation_request(request_id: int, _result: Dictionary) -> void:
		operation_ids.append(request_id)
		busy = true
		_clear_busy_after_frame()

	func render_battle_command_response(command: Dictionary, _response: Dictionary) -> void:
		battle_commands.append(String(command.get("label", command.get("type", ""))))
		timeline.append("battle_start")
		for _frame in range(render_delay_frames):
			await get_tree().process_frame
		timeline.append("battle_end")

	func render_snapshot(snapshot: Dictionary, _animate_transition: bool = true) -> void:
		external_versions.append(int(snapshot.get("stateVersion", -1)))
		timeline.append("external_start")
		for _frame in range(render_delay_frames):
			await get_tree().process_frame
		timeline.append("external_end")

	func is_presentation_busy() -> bool:
		return busy

	func _clear_busy_after_frame() -> void:
		await get_tree().process_frame
		busy = false


class Harness extends RefCounted:
	var prepared_versions: Array[int] = []
	var released_versions: Array[int] = []
	var battle_view: FakeBattleView = null
	var timeline: Array[String] = []

	func prepare(snapshot: Dictionary) -> void:
		prepared_versions.append(int(snapshot.get("stateVersion", -1)))

	func release(snapshot: Dictionary) -> void:
		released_versions.append(int(snapshot.get("stateVersion", -1)))
		timeline.append("release_%d" % int(snapshot.get("stateVersion", -1)))

	func current_battle_view() -> Node:
		return battle_view


class LockedBattleView extends Control:
	signal command_requested(command: Dictionary)
	signal trace_sequence_finished

	var locked := true

	func get_runtime_view() -> Control:
		return self

	func is_battle_input_locked() -> bool:
		return locked


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_serial_commands_and_external_collapse()
	await _test_session_reset_cancels_stale_response()
	await _test_battle_settlement_precedes_external_snapshot()
	await _test_operation_and_trace_cursor_remount()
	await _test_battle_view_destruction_does_not_hang()
	print("SMOKE_PRESENTATION_REGRESSIONS_%s" % ["FAIL" if _failed else "OK"])
	quit(1 if _failed else 0)


func _test_serial_commands_and_external_collapse() -> void:
	var bridge := FakeBridge.new()
	var view := FakeView.new()
	root.add_child(view)
	var harness := Harness.new()
	var coordinator := CoordinatorScript.new()
	coordinator.call("configure", bridge, view, Callable(harness, "prepare"), Callable(harness, "release"), Callable(harness, "current_battle_view"))
	var completions := {}
	_wait_for_command(coordinator, {"type": "TEST", "label": "first"}, 1, completions)
	_wait_for_command(coordinator, {"type": "TEST", "label": "second"}, 2, completions)
	coordinator.call("enqueue_external_snapshot", {"stateVersion": 2, "stateHash": "external-v2", "phase": "route"}, {"reason": "reconnect", "asynchronous": true})
	coordinator.call("enqueue_external_snapshot", {"stateVersion": 4, "stateHash": "external-v4", "phase": "route"}, {"reason": "reconnect", "asynchronous": true})
	coordinator.call("enqueue_external_snapshot", {"stateVersion": 3, "stateHash": "external-v3", "phase": "route"}, {"reason": "reconnect", "asynchronous": true})
	_expect(await _wait_until(func(): return completions.size() == 2 and not bool(coordinator.call("is_processing")), 2.0), "queued commands and external presentation settle before timeout")
	_expect(bridge.max_active_submissions == 1, "rapid commands never overlap session submission")
	_expect(bridge.submit_order == ["first", "second"], "rapid commands keep FIFO order")
	_expect(view.command_ids == [1, 2], "command responses complete in FIFO order")
	_expect(view.external_versions == [4], "queued external snapshots collapse to the newest version")
	_expect(harness.released_versions == [1, 2, 4], "feature release happens once after each settled presentation")
	view.queue_free()
	await process_frame


func _test_session_reset_cancels_stale_response() -> void:
	var bridge := FakeBridge.new()
	bridge.delay_frames = 4
	var view := FakeView.new()
	root.add_child(view)
	var harness := Harness.new()
	var coordinator := CoordinatorScript.new()
	coordinator.call("configure", bridge, view, Callable(harness, "prepare"), Callable(harness, "release"), Callable(harness, "current_battle_view"))
	var completions := {}
	_wait_for_command(coordinator, {"type": "TEST", "label": "stale_session"}, 31, completions)
	await process_frame
	coordinator.call("reset_for_session")
	_expect(await _wait_until(func(): return completions.has(31), 2.0), "session reset wakes the command waiter")
	_expect(bool(Dictionary(completions.get(31, {})).get("cancelled", false)), "session reset returns an explicit cancelled result")
	_expect(await _wait_until(func(): return bridge.active_submissions == 0, 2.0), "cancelled session submission finishes without touching the view")
	_expect(view.command_ids.is_empty(), "stale command response never completes a request in the replacement session")
	_expect(harness.released_versions.is_empty(), "stale command response never releases replacement-session features")
	view.queue_free()
	await process_frame


func _test_battle_settlement_precedes_external_snapshot() -> void:
	var bridge := FakeBridge.new()
	var view := FakeView.new()
	view.render_delay_frames = 4
	root.add_child(view)
	var harness := Harness.new()
	harness.timeline = view.timeline
	var coordinator := CoordinatorScript.new()
	coordinator.call("configure", bridge, view, Callable(harness, "prepare"), Callable(harness, "release"), Callable(harness, "current_battle_view"))
	var completion := [false]
	_wait_for_battle_command(coordinator, {"type": "RUN_COMBAT_ROUND", "label": "battle_finish", "phase": "settlement"}, completion)
	await process_frame
	coordinator.call("enqueue_external_snapshot", {
		"stateVersion": 3,
		"stateHash": "external-v3",
		"phase": "route",
	}, {"reason": "reconnect", "asynchronous": true})
	_expect(await _wait_until(func(): return bool(completion[0]) and not bool(coordinator.call("is_processing")), 2.0), "battle settlement and queued external snapshot settle before timeout")
	_expect(view.battle_commands == ["battle_finish"], "battle settlement response renders exactly once")
	_expect(view.external_versions == [3], "external snapshot waits behind the active battle presentation")
	_expect(view.timeline == ["battle_start", "battle_end", "release_1", "external_start", "external_end", "release_3"], "battle trace presentation settles and releases before the queued external snapshot starts")
	view.queue_free()
	await process_frame


func _test_operation_and_trace_cursor_remount() -> void:
	var bridge := FakeBridge.new()
	var view := FakeView.new()
	root.add_child(view)
	var first_battle := FakeBattleView.new()
	first_battle.cursor = 9
	root.add_child(first_battle)
	var harness := Harness.new()
	harness.battle_view = first_battle
	var coordinator := CoordinatorScript.new()
	coordinator.call("configure", bridge, view, Callable(harness, "prepare"), Callable(harness, "release"), Callable(harness, "current_battle_view"))
	var existing_trace: Array = []
	for index in range(9):
		existing_trace.append({"eventId": "bt_%06d" % (index + 1)})
	coordinator.call("adopt_presented_snapshot", {
		"stateVersion": 5,
		"stateHash": "battle-v5",
		"phase": "battle",
		"battleTrace": existing_trace,
	})
	coordinator.call("complete_session_operation", 77, {
		"ok": true,
		"snapshot": {"stateVersion": 6, "stateHash": "loaded-v6", "phase": "battle", "battleTrace": existing_trace},
	})
	_expect(await _wait_until(func(): return view.operation_ids == [77] and not bool(coordinator.call("is_processing")), 2.0), "session operation completes through the serialized presentation barrier")
	_expect(int(coordinator.call("last_applied_version")) == 6, "load result becomes the applied presentation version")
	_expect(int(coordinator.call("last_trace_cursor")) == 9, "Coordinator retains BattleScene trace progress")
	var remounted := FakeBattleView.new()
	root.add_child(remounted)
	harness.battle_view = remounted
	coordinator.call("configure_battle_view", remounted)
	_expect(remounted.cursor == 9, "remounted BattleScene receives the persistent trace cursor")
	coordinator.call("complete_session_operation", 78, {
		"ok": true,
		"snapshot": {
			"stateVersion": 7,
			"stateHash": "loaded-v7",
			"phase": "battle",
			"battleTrace": [
				{"eventId": "bt_000001"},
				{"eventId": "bt_000002"},
			],
		},
	}, &"load")
	_expect(await _wait_until(func(): return view.operation_ids == [77, 78] and not bool(coordinator.call("is_processing")), 2.0), "load presentation completes through the same serialized barrier")
	_expect(int(coordinator.call("last_trace_cursor")) == 2, "load resets trace progress to the loaded snapshot instead of replaying stale events")
	_expect(remounted.cursor == 2, "active BattleScene receives the reset load cursor")
	first_battle.queue_free()
	remounted.queue_free()
	view.queue_free()
	await process_frame


func _test_battle_view_destruction_does_not_hang() -> void:
	var three_choice := ThreeChoiceScene.instantiate() as Control
	root.add_child(three_choice)
	await process_frame
	await process_frame
	var battle := LockedBattleView.new()
	root.add_child(battle)
	three_choice.call("attach_feature_view", &"battle", battle)
	var completed := [false]
	_wait_for_battle_trace(three_choice, completed)
	await process_frame
	battle.queue_free()
	_expect(await _wait_until(func(): return bool(completed[0]), 2.0), "destroying a locked BattleScene cannot strand the trace wait")
	three_choice.queue_free()
	await process_frame


func _wait_for_command(coordinator: RefCounted, command: Dictionary, request_id: int, completions: Dictionary) -> void:
	completions[request_id] = await coordinator.call("submit_command_request", command, request_id)


func _wait_for_battle_command(coordinator: RefCounted, command: Dictionary, completed: Array) -> void:
	completed[0] = await coordinator.call("submit_battle_command", command)


func _wait_for_battle_trace(three_choice: Control, completed: Array) -> void:
	await three_choice.call("_await_battle_trace_sequence")
	completed[0] = true


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_PRESENTATION_REGRESSIONS_FAIL: %s" % message)
