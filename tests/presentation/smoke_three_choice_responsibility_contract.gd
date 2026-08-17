extends SceneTree

const RequestBrokerScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_request_broker.gd")
const FocusCoordinatorScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_focus_coordinator.gd")
const DeveloperToolbarScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_developer_toolbar.gd")
const DragControllerScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_drag_controller.gd")

var _failed := false
var _operation_calls: Array[Dictionary] = []
var _completed_operations: Array[Dictionary] = []
var _active_broker: RefCounted = null
var _request_ids: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_request_broker()
	await _test_focus_coordinator()
	await _test_developer_toolbar()
	_test_source_boundaries()
	print("SMOKE_THREE_CHOICE_RESPONSIBILITY_CONTRACT_%s" % ["FAIL" if _failed else "OK"])
	quit(1 if _failed else 0)


func _test_request_broker() -> void:
	var broker := RequestBrokerScript.new()
	_active_broker = broker
	_request_ids.clear()
	broker.command_requested.connect(_complete_test_command)
	broker.session_operation_requested.connect(_complete_test_operation)
	var command := {"type": "CHOOSE_ROUTE", "route_id": "node_shop"}
	var command_result := Dictionary(await broker.request_command(command))
	_expect(bool(command_result.get("accepted", false)), "request broker returns the paired command response")
	_expect(not command.has("mutated_by_receiver"), "request broker deep-copies outgoing commands")
	var operation_arguments := {"slot": 2}
	var operation_result := Dictionary(await broker.request_session_operation(&"load", operation_arguments))
	_expect(bool(operation_result.get("ok", false)) and int(operation_result.get("slot", -1)) == 2, "request broker pairs session-operation responses")
	_expect(not operation_arguments.has("mutated_by_receiver"), "request broker deep-copies operation arguments")
	_expect(_request_ids == [1, 2], "request broker owns one monotonic correlation sequence")
	broker.dispose()
	_active_broker = null

	var cancelled_broker := RequestBrokerScript.new()
	_active_broker = cancelled_broker
	cancelled_broker.command_requested.connect(_cancel_test_request)
	var cancelled := Dictionary(await cancelled_broker.request_command({"type": "CHOOSE_ROUTE"}))
	_expect(bool(cancelled.get("cancelled", false)), "disposing the broker resumes pending requests as cancelled")
	_expect(String(Dictionary(cancelled.get("error", {})).get("code", "")) == "PRESENTATION_REQUEST_CANCELLED", "broker cancellation has a stable error code")
	_active_broker = null


func _complete_test_command(command: Dictionary, request_id: int) -> void:
	_request_ids.append(request_id)
	command["mutated_by_receiver"] = true
	_active_broker.call("complete_command", request_id, {
		"accepted": true,
		"snapshot": {"stateVersion": request_id},
	})


func _complete_test_operation(_operation: StringName, arguments: Dictionary, request_id: int) -> void:
	_request_ids.append(request_id)
	arguments["mutated_by_receiver"] = true
	_active_broker.call("complete_session_operation", request_id, {"ok": true, "slot": arguments.get("slot", -1)})


func _cancel_test_request(_command: Dictionary, _request_id: int) -> void:
	_active_broker.call_deferred("dispose")


func _test_focus_coordinator() -> void:
	var host := Control.new()
	root.add_child(host)
	var first := Button.new()
	var second := Button.new()
	host.add_child(first)
	host.add_child(second)
	var coordinator := FocusCoordinatorScript.new()
	coordinator.configure(host, [first, second], [], [], [], null, null, null)
	coordinator.refresh(&"three_option")
	_expect(first.focus_neighbor_right == first.get_path_to(second), "focus coordinator owns forward navigation")
	_expect(second.focus_neighbor_left == second.get_path_to(first), "focus coordinator owns reverse navigation")
	first.set_meta("base_tint", Color(0.4, 0.5, 0.6, 1.0))
	first.focus_entered.emit()
	_expect(first.get_parent().modulate != Color(0.4, 0.5, 0.6, 1.0), "focus coordinator applies focus tint")
	first.focus_exited.emit()
	_expect(first.get_parent().modulate == Color(0.4, 0.5, 0.6, 1.0), "focus coordinator restores authored base tint")
	host.modulate = Color.WHITE
	second.set_meta("slot_surface_self", true)
	second.set_meta("focus_tint_disabled", true)
	second.set_meta("base_tint", Color(0.7, 0.8, 0.9, 1.0))
	second.modulate = Color(0.3, 0.2, 0.1, 1.0)
	second.focus_entered.emit()
	_expect(host.modulate == Color.WHITE and second.modulate == Color(0.3, 0.2, 0.1, 1.0), "focus coordinator preserves authored surfaces with focus tint disabled")
	second.focus_exited.emit()
	_expect(second.modulate == Color(0.7, 0.8, 0.9, 1.0), "focus coordinator restores slot-surface tint on the button itself")
	coordinator.dispose()
	host.queue_free()
	await process_frame


func _test_developer_toolbar() -> void:
	_operation_calls.clear()
	_completed_operations.clear()
	var host := Control.new()
	root.add_child(host)
	var toolbar := DeveloperToolbarScript.new()
	toolbar.configure(host, Callable(self, "_fake_operation_request"), Callable(self, "_record_completed_operation"))
	toolbar.configure_session_capabilities(true, 2)
	toolbar.set_enabled(true)
	toolbar.set_visible_for_view(&"battle", true)
	await process_frame
	await process_frame
	var panel := host.get_node_or_null("RunTools") as Control
	_expect(panel != null and panel.visible, "developer toolbar builds only when explicitly enabled")
	var load_button := host.get_node_or_null("RunTools/RunToolsRow/LoadSlot2Button") as Button
	_expect(load_button != null, "developer toolbar owns capability-driven slot controls")
	if load_button != null:
		load_button.pressed.emit()
		await process_frame
		await process_frame
	_expect(_operation_calls == [{"operation": &"load", "arguments": {"slot": 2}}], "developer toolbar submits through its narrow operation port")
	_expect(_completed_operations.size() == 1 and StringName(_completed_operations[0].get("operation", &"")) == &"load", "developer toolbar returns operation results to the page facade")
	toolbar.dispose()
	host.queue_free()
	await process_frame


func _test_source_boundaries() -> void:
	var root_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/scenes/three_choice_scene.gd")
	var broker_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_request_broker.gd")
	var focus_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_focus_coordinator.gd")
	var toolbar_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_developer_toolbar.gd")
	var drag_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_drag_controller.gd")
	_expect(root_source.contains("RequestBrokerScript") and root_source.contains("FocusCoordinatorScript") and root_source.contains("DeveloperToolbarScript") and root_source.contains("DragControllerScript"), "ThreeChoiceScene composes the extracted responsibilities")
	_expect(not root_source.contains("var _request_sequence") and not root_source.contains("var _command_responses") and not root_source.contains("var _session_operation_responses"), "ThreeChoiceScene no longer owns request correlation state")
	_expect(not root_source.contains("var _drag_candidate_source") and not root_source.contains("var _drag_preview") and not root_source.contains("func _drop_target_for_position"), "ThreeChoiceScene no longer owns transient drag state or hit testing")
	_expect(not root_source.contains("PanelContainer.new()") and not root_source.contains("func _focus_controls_for_view"), "ThreeChoiceScene no longer implements developer toolbar construction or focus policy")
	for source in [broker_source, focus_source, toolbar_source, drag_source]:
		_expect(not source.contains('preload("res://session') and not source.contains("YsbzsState") and not source.contains('preload("res://core/state/'), "extracted presentation responsibilities own no gameplay authority")
	_expect(not focus_source.contains("snapshot.get") and not focus_source.contains("signal command_requested"), "focus coordinator is independent of state and commands")
	_expect(not toolbar_source.contains('preload("res://persistence') and not toolbar_source.contains('preload("res://session'), "developer toolbar depends only on the operation callable")
	_expect(not drag_source.contains("await ") and not drag_source.contains("command_requested.emit") and not drag_source.contains("_submit_core_command"), "drag controller returns plans while the page facade owns asynchronous command submission")


func _fake_operation_request(operation: StringName, arguments: Dictionary) -> Dictionary:
	_operation_calls.append({"operation": operation, "arguments": arguments.duplicate(true)})
	return {"ok": true, "snapshot": {"phase": "route"}}


func _record_completed_operation(operation: StringName, result: Dictionary) -> void:
	_completed_operations.append({"operation": operation, "result": result.duplicate(true)})


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_THREE_CHOICE_RESPONSIBILITY_CONTRACT_FAIL: %s" % message)
