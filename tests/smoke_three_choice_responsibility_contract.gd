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
	var scene_source := FileAccess.get_file_as_string("res://art/scenes/three_choice/three_choice_scene.tscn")
	var manifest_source := FileAccess.get_file_as_string("res://art/manifests/route/three_choice/psd_layer_manifest.json")
	var broker_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_request_broker.gd")
	var focus_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_focus_coordinator.gd")
	var toolbar_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_developer_toolbar.gd")
	var drag_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_drag_controller.gd")
	var photoshop_export_source := FileAccess.get_file_as_string("res://tools/photoshop_export_three_choice_v3.jsx")
	var photoshop_build_source := FileAccess.get_file_as_string("res://tools/photoshop_build_three_choice_godot_v3.jsx")
	var postprocess_source := FileAccess.get_file_as_string("res://tools/postprocess_three_choice_v3.py")
	_expect(root_source.contains("RequestBrokerScript") and root_source.contains("FocusCoordinatorScript") and root_source.contains("DeveloperToolbarScript") and root_source.contains("DragControllerScript"), "ThreeChoiceScene composes the extracted responsibilities")
	_expect(not root_source.contains("var _request_sequence") and not root_source.contains("var _command_responses") and not root_source.contains("var _session_operation_responses"), "ThreeChoiceScene no longer owns request correlation state")
	_expect(not root_source.contains("var _drag_candidate_source") and not root_source.contains("var _drag_preview") and not root_source.contains("func _drop_target_for_position"), "ThreeChoiceScene no longer owns transient drag state or hit testing")
	_expect(not root_source.contains("PanelContainer.new()") and not root_source.contains("func _focus_controls_for_view"), "ThreeChoiceScene no longer implements developer toolbar construction or focus policy")
	for source in [broker_source, focus_source, toolbar_source, drag_source]:
		_expect(not source.contains('preload("res://session') and not source.contains("YsbzsState") and not source.contains('preload("res://core/state/'), "extracted presentation responsibilities own no gameplay authority")
	_expect(not focus_source.contains("snapshot.get") and not focus_source.contains("signal command_requested"), "focus coordinator is independent of state and commands")
	_expect(not toolbar_source.contains('preload("res://persistence') and not toolbar_source.contains('preload("res://session'), "developer toolbar depends only on the operation callable")
	_expect(not drag_source.contains("await ") and not drag_source.contains("command_requested.emit") and not drag_source.contains("_submit_core_command"), "drag controller returns plans while the page facade owns asynchronous command submission")
	_expect(scene_source.contains("three_choice_psd/building.png") and manifest_source.contains('"name": "building"'), "ThreeChoiceScene and its manifest use the current building resource identity")
	_expect(scene_source.contains("shared/pets/battle_complete/shadow.png"), "party slots reuse the shared pet ground-shadow texture")
	_expect(scene_source.count('shader_parameter/shadow_enabled = true') == 4, "all four authored party slots carry the same ground-shadow material contract")
	_expect(scene_source.count('shader_parameter/shadow_offset = Vector2(42.5, 110)') == 4, "party shadow position is authored consistently below the sprite feet in the Scene")
	_expect(not root_source.contains("button.has_focus()"), "party shadow highlight is driven by pointer hover, not persistent click focus")
	_expect(not root_source.contains("PARTY_SLOT_HIGHLIGHT_TEXTURE"), "party hover no longer loads or shows the yellow slot-ring texture")
	var detail_source := FileAccess.get_file_as_string("res://core_ui/scripts/shared/pet/pet_detail_panel.gd")
	_expect(detail_source.contains("@export var context_follow_pointer := true"), "shared pet detail keeps pointer-following context layout as its default")
	_expect(scene_source.contains("context_follow_pointer = false"), "three-choice opts into the fixed context-detail layout")
	_expect(scene_source.contains('[node name="Panel" parent="ArtistPetDetailPanel" index="1"'), "three-choice authors the existing detail Panel directly in the Scene")
	_expect(scene_source.contains("offset_left = 8.0\noffset_top = 390.0\noffset_right = 368.0\noffset_bottom = 850.0\nscale = Vector2(0.64, 0.64)"), "three-choice authors the fixed left-edge detail geometry in the Scene")
	_expect(not detail_source.contains("@export var context_panel_position") and not detail_source.contains("@export var context_panel_scale"), "fixed context geometry is not hidden in runtime layout parameters")
	_expect(root_source.contains("get_global_transform_with_canvas().affine_inverse() * slot_canvas_origin") and root_source.contains("_item_slot_hover_highlight.position = slot_position_in_scene + resolved_offset"), "bag highlight converts every slot back into the authored scene coordinate system")
	_expect(scene_source.contains("item_slot_highlight_offset = Vector2(-10, -14)"), "bag highlight alignment offset is authored in the three-choice Scene")
	_expect(scene_source.contains("custom_minimum_size = Vector2(183, 177)") and scene_source.contains("offset_right = 183.0\noffset_bottom = 177.0"), "bag highlight authored size matches the painted slot frame")
	_expect(scene_source.contains("theme_override_constants/h_separation = 31") and scene_source.contains("theme_override_constants/v_separation = 32"), "bag slot grid spacing matches the measured painted frame centers")
	_expect(not root_source.contains("BAG_SLOT_HIGHLIGHT_OFFSET") and root_source.contains("_show_item_slot_highlight(slot, item_slot_highlight_offset, BAG_SLOT_HIGHLIGHT_TEXTURE)"), "bag highlight runtime positioning reads the authored Scene offset")
	_expect(scene_source.contains('[node name="Party" type="Control" parent="MainBG/Containers" unique_id=99163385]\nz_index = 12'), "party sprites are authored above the bag overlay mask")
	_expect(scene_source.contains('[node name="Bags" type="Control" parent="MainBG/Containers" unique_id=489702172]\nz_index = 11'), "bag chest and party shelf are authored above the bag overlay mask")
	_expect(scene_source.contains('[node name="Top" type="Control" parent="MainBG/Containers" unique_id=219359528]\nz_index = 13'), "coin panel, icon, and amount are authored above the bag overlay mask")
	_expect(root_source.contains("bag_button.texture_normal = state_texture") and root_source.contains("bag_button.texture_pressed = state_texture") and root_source.contains("bag_button.texture_hover = state_texture") and root_source.contains("bag_button.texture_focused = state_texture"), "one Bag_Button switches every draw state between the open and closed textures")
	_expect(photoshop_export_source.contains('{name: "bag_open", paths: ["调色", "三选/背包/背包打开"]}') and photoshop_export_source.contains('{name: "bag_open_ungraded", paths: ["三选/背包/背包打开"]}'), "open bag export uses only the authored open-state layer")
	_expect(not photoshop_export_source.contains('{name: "bag_open", paths: ["调色", "三选/背包/背包", "三选/背包/背包打开"]}'), "open bag export does not bake the closed-state layer behind the open chest")
	_expect(postprocess_source.contains("remove_open_bag_closed_state_fragment") and postprocess_source.contains("alpha.paste(0, (313, 865, 359, 919))"), "open bag postprocess removes the legacy closed-state stair strip from the authored state layer")
	_expect(photoshop_build_source.contains('placePng(doc, state, "bag_open_full.png", "bag_open", 314, 796, false);'), "Godot-dedicated PSD keeps the open bag visible alpha aligned with its authored texture canvas")
	_expect(photoshop_build_source.contains("var layer = placePng(doc, group, fileName, layerName, 0, 0, true);") and photoshop_build_source.contains("layer.visible = visible;"), "Photoshop 2025 positions alternate portraits before restoring authored hidden states")
	_expect(manifest_source.contains("Open state exports only the authored open-chest layer; the legacy closed-state stair fragment behind the lid is transparent."), "three-choice manifest records the open-state transparency contract")
	var open_bag_image := Image.load_from_file(ProjectSettings.globalize_path("res://art/images/route/three_choice_psd/bag_open_full.png"))
	_expect(open_bag_image != null and open_bag_image.get_pixel(33, 74).a <= 0.01 and open_bag_image.get_pixel(45, 90).a <= 0.01, "open bag texture keeps the authored rear-left gap transparent instead of leaking the closed chest")
	_expect(root_source.contains("_apply_standalone_drag_release_plan(release_plan)"), "standalone art preview executes a local visual drop without creating a Session")
	_expect(scene_source.contains("vec3 normal_shadow = vec3(0.035, 0.055, 0.055);"), "authored party shader uses the darker resting ground shadow")
	_expect(root_source.contains("vec3 normal_shadow = vec3(0.035, 0.055, 0.055);"), "runtime slot shader matches the authored resting ground shadow")
	for obsolete_name in ["temple_base", "pet_shadow", "sell_highlight", "item_bar_base", "item_selected_highlight", "PartyShadow", "party_highlight"]:
		_expect(not scene_source.contains(obsolete_name) and not root_source.contains(obsolete_name) and not manifest_source.contains(obsolete_name), "obsolete three-choice visual is absent: %s" % obsolete_name)


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
