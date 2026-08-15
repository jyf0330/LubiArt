extends SceneTree

const RequestBrokerScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_request_broker.gd")
const FocusCoordinatorScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_focus_coordinator.gd")
const DragControllerScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_drag_controller.gd")

var _failed := false
var _active_broker: RefCounted = null
var _request_ids: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_request_broker()
	await _test_focus_coordinator()
	_test_source_boundaries()
	print("SMOKE_THREE_CHOICE_RESPONSIBILITY_CONTRACT_%s" % ["FAIL" if _failed else "OK"])
	quit(1 if _failed else 0)


func _test_request_broker() -> void:
	var broker := RequestBrokerScript.new()
	_active_broker = broker
	_request_ids.clear()
	broker.command_requested.connect(_complete_test_command)
	var command := {"type": "CHOOSE_ROUTE", "route_id": "node_shop"}
	var command_result := Dictionary(await broker.request_command(command))
	_expect(bool(command_result.get("accepted", false)), "request broker returns the paired command response")
	_expect(not command.has("mutated_by_receiver"), "request broker deep-copies outgoing commands")
	_expect(_request_ids == [1], "request broker owns one monotonic command correlation sequence")
	broker.dispose()
	_active_broker = null

	var cancelled_broker := RequestBrokerScript.new()
	_active_broker = cancelled_broker
	cancelled_broker.command_requested.connect(_cancel_test_request)
	var cancelled := Dictionary(await cancelled_broker.request_command({"type": "CHOOSE_ROUTE"}))
	_expect(bool(cancelled.get("cancelled", false)), "disposing the broker resumes pending requests as cancelled")
	_expect(String(Dictionary(cancelled.get("error", {})).get("code", "")) == "PRESENTATION_REQUEST_CANCELLED", "broker cancellation has a stable error code")
	_active_broker = null

	var timeout_broker := RequestBrokerScript.new()
	var timed_out := Dictionary(await timeout_broker.request_command({"type": "ROLL_SHOP"}))
	_expect(bool(timed_out.get("timed_out", false)), "unanswered presentation requests terminate instead of hanging the page")
	_expect(String(Dictionary(timed_out.get("error", {})).get("code", "")) == "PRESENTATION_REQUEST_TIMEOUT", "request timeout has a stable error code")
	timeout_broker.call("complete_command", 1, {"accepted": true})
	_expect(Dictionary(timeout_broker.get("_command_responses")).is_empty(), "late responses are discarded after timeout")
	timeout_broker.dispose()


func _complete_test_command(command: Dictionary, request_id: int) -> void:
	_request_ids.append(request_id)
	command["mutated_by_receiver"] = true
	_active_broker.call("complete_command", request_id, {
		"accepted": true,
		"snapshot": {"stateVersion": request_id},
	})


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
	coordinator.configure(host, [first, second], [], [], null, null)
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


func _test_source_boundaries() -> void:
	var root_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/scenes/three_choice_scene.gd")
	var scene_source := FileAccess.get_file_as_string("res://art/scenes/three_choice/three_choice_scene.tscn")
	var shared_scene_source := FileAccess.get_file_as_string("res://art/prefabs/route/route_shared_ui.tscn")
	var shared_script_source := FileAccess.get_file_as_string("res://core_ui/scripts/route/prefabs/route_shared_ui.gd")
	var manifest_source := FileAccess.get_file_as_string("res://art/manifests/route/three_choice/psd_layer_manifest.json")
	var broker_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_request_broker.gd")
	var focus_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_focus_coordinator.gd")
	var drag_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_drag_controller.gd")
	var photoshop_export_source := FileAccess.get_file_as_string("res://tools/photoshop_export_three_choice_v3.jsx")
	var photoshop_build_source := FileAccess.get_file_as_string("res://tools/photoshop_build_three_choice_godot_v3.jsx")
	var postprocess_source := FileAccess.get_file_as_string("res://tools/postprocess_three_choice_v3.py")
	_expect(root_source.contains("RequestBrokerScript") and root_source.contains("FocusCoordinatorScript") and root_source.contains("DragControllerScript"), "ThreeChoiceScene composes its active extracted responsibilities")
	_expect(not root_source.contains("var _request_sequence") and not root_source.contains("var _command_responses") and not root_source.contains("var _session_operation_responses"), "ThreeChoiceScene no longer owns request correlation state")
	_expect(not root_source.contains("session_operation_requested") and not broker_source.contains("session_operation_requested") and not root_source.contains("DeveloperToolbarScript"), "ThreeChoiceScene contains no unreachable battle-only developer operation chain")
	_expect(broker_source.contains("COMMAND_WAIT_FRAME_LIMIT") and broker_source.contains("_pending_command_ids") and broker_source.contains("PRESENTATION_REQUEST_TIMEOUT"), "shared request broker prevents infinite waits and rejects late responses")
	_expect(not root_source.contains("var _drag_candidate_source") and not root_source.contains("var _drag_preview") and not root_source.contains("func _drop_target_for_position"), "ThreeChoiceScene no longer owns transient drag state or hit testing")
	_expect(not root_source.contains("PanelContainer.new()") and not root_source.contains("func _focus_controls_for_view"), "ThreeChoiceScene no longer implements developer toolbar construction or focus policy")
	_expect(not root_source.contains("ShopPresenterScript") and not root_source.contains("func _render_shop") and not root_source.contains("_shop_buttons") and not root_source.contains("VIEW_SHOP"), "ThreeChoiceScene contains no legacy shop presentation branch")
	for source in [broker_source, focus_source, drag_source]:
		_expect(not source.contains('preload("res://session') and not source.contains("YsbzsState") and not source.contains('preload("res://core/state/'), "extracted presentation responsibilities own no gameplay authority")
	_expect(not focus_source.contains("snapshot.get") and not focus_source.contains("signal command_requested"), "focus coordinator is independent of state and commands")
	_expect(not drag_source.contains("await ") and not drag_source.contains("command_requested.emit") and not drag_source.contains("_submit_core_command"), "drag controller returns plans while the page facade owns asynchronous command submission")
	_expect(scene_source.contains("three_choice_psd/building.png") and manifest_source.contains('"name": "building"'), "ThreeChoiceScene and its manifest use the current building resource identity")
	_expect(shared_scene_source.contains("shared/pets/battle_complete/shadow.png"), "shared party slots reuse the pet ground-shadow texture")
	_expect(shared_scene_source.count('shader_parameter/shadow_enabled = true') == 1 and shared_scene_source.count('shader_parameter/shadow_enabled = false') == 3, "shared authored party shadows match default occupancy")
	_expect(shared_scene_source.count('shader_parameter/shadow_offset = Vector2(42.5, 110)') == 4, "party shadow position is authored consistently below the sprite feet")
	_expect(not root_source.contains("button.has_focus()"), "party shadow highlight is driven by pointer hover, not persistent click focus")
	_expect(not root_source.contains("PARTY_SLOT_HIGHLIGHT_TEXTURE"), "party hover no longer loads or shows the yellow slot-ring texture")
	var detail_source := FileAccess.get_file_as_string("res://core_ui/scripts/shared/pet/pet_detail_panel.gd")
	_expect(detail_source.contains("@export var context_follow_pointer := true"), "shared pet detail keeps pointer-following context layout as its default")
	_expect(shared_scene_source.contains("context_follow_pointer = false"), "shared route UI opts into the fixed context-detail layout")
	_expect(shared_scene_source.contains('[node name="Panel" parent="ArtistPetDetailPanel" index="1"'), "shared route UI authors the existing detail Panel directly")
	_expect(shared_scene_source.contains("offset_left = 8.0\noffset_top = 390.0\noffset_right = 368.0\noffset_bottom = 850.0\nscale = Vector2(0.64, 0.64)"), "shared route UI authors the fixed left-edge detail geometry")
	_expect(not detail_source.contains("@export var context_panel_position") and not detail_source.contains("@export var context_panel_scale"), "fixed context geometry is not hidden in runtime layout parameters")
	_expect(shared_script_source.contains("get_global_transform_with_canvas().affine_inverse() * slot_canvas_origin") and shared_script_source.contains("highlight.position = slot_position_in_shared + item_slot_highlight_offset"), "shared bag highlight converts slots into the prefab coordinate system")
	_expect(shared_scene_source.contains("item_slot_highlight_offset = Vector2(-10, -14)"), "bag highlight alignment offset is authored in RouteSharedUi")
	_expect(shared_scene_source.contains("custom_minimum_size = Vector2(183, 177)") and shared_scene_source.contains("offset_right = 183.0\noffset_bottom = 177.0"), "bag highlight authored size matches the painted slot frame")
	_expect(shared_scene_source.contains("theme_override_constants/h_separation = 31") and shared_scene_source.contains("theme_override_constants/v_separation = 32"), "bag slot grid spacing matches the measured painted frame centers")
	_expect(shared_scene_source.contains('[node name="Party" type="Control" parent="."]\nz_index = 12'), "party sprites are authored above the bag overlay mask")
	_expect(shared_scene_source.contains('[node name="Bags" type="Control" parent="."]\nz_index = 11'), "bag chest and party shelf are authored above the bag overlay mask")
	_expect(shared_scene_source.contains('[node name="Top" type="Control" parent="."]\nz_index = 13'), "coin panel, icon, and amount are authored above the bag overlay mask")
	_expect(shared_script_source.contains("button.texture_normal = state_texture") and shared_script_source.contains("button.texture_pressed = state_texture") and shared_script_source.contains("button.texture_hover = state_texture") and shared_script_source.contains("button.texture_focused = state_texture"), "RouteSharedUi owns all Bag_Button draw states")
	_expect(photoshop_export_source.contains('{name: "bag_open", paths: ["调色", "三选/背包/背包打开"]}') and photoshop_export_source.contains('{name: "bag_open_ungraded", paths: ["三选/背包/背包打开"]}'), "open bag export uses only the authored open-state layer")
	_expect(not photoshop_export_source.contains('{name: "bag_open", paths: ["调色", "三选/背包/背包", "三选/背包/背包打开"]}'), "open bag export does not bake the closed-state layer behind the open chest")
	_expect(postprocess_source.contains("remove_open_bag_closed_state_fragment") and postprocess_source.contains("alpha.paste(0, (313, 865, 359, 919))"), "open bag postprocess removes the legacy closed-state stair strip from the authored state layer")
	_expect(photoshop_build_source.contains('placePng(doc, state, "bag_open_full.png", "bag_open", 314, 796, false);'), "Godot-dedicated PSD keeps the open bag visible alpha aligned with its authored texture canvas")
	_expect(photoshop_build_source.contains("var layer = placePng(doc, group, fileName, layerName, 0, 0, true);") and photoshop_build_source.contains("layer.visible = visible;"), "Photoshop 2025 positions alternate portraits before restoring authored hidden states")
	_expect(manifest_source.contains("Open state exports only the authored open-chest layer; the legacy closed-state stair fragment behind the lid is transparent."), "three-choice manifest records the open-state transparency contract")
	var open_bag_image := Image.load_from_file(ProjectSettings.globalize_path("res://art/images/route/three_choice_psd/bag_open_full.png"))
	_expect(open_bag_image != null and open_bag_image.get_pixel(33, 74).a <= 0.01 and open_bag_image.get_pixel(45, 90).a <= 0.01, "open bag texture keeps the authored rear-left gap transparent instead of leaking the closed chest")
	_expect(root_source.contains("_apply_standalone_drag_release_plan(release_plan)"), "standalone art preview executes a local visual drop without creating a Session")
	_expect(shared_scene_source.contains("vec3 normal_shadow = vec3(0.035, 0.055, 0.055);"), "authored shared party shader uses the darker resting ground shadow")
	_expect(shared_script_source.contains("ensure_bag_buttons") and root_source.contains('route_shared_ui.call("ensure_bag_buttons")'), "both pages use RouteSharedUi as the single bag-slot construction owner")
	for obsolete_name in ["temple_base", "pet_shadow", "sell_highlight", "item_bar_base", "item_selected_highlight", "PartyShadow", "party_highlight"]:
		_expect(not scene_source.contains(obsolete_name) and not root_source.contains(obsolete_name) and not manifest_source.contains(obsolete_name), "obsolete three-choice visual is absent: %s" % obsolete_name)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_THREE_CHOICE_RESPONSIBILITY_CONTRACT_FAIL: %s" % message)
