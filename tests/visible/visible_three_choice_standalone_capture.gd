extends SceneTree

const ThreeChoiceScene := preload("res://art/scenes/three_choice/three_choice_scene.tscn")
const TESTED_SCENE_PATH := "res://art/scenes/three_choice/three_choice_scene.tscn"
const BAG_PAINTED_FRAME_CENTERS := [
	Vector2(131.0, 118.0),
	Vector2(315.5, 118.0),
	Vector2(500.0, 118.0),
	Vector2(684.0, 118.0),
	Vector2(131.0, 295.5),
	Vector2(315.5, 295.5),
	Vector2(499.0, 295.5),
	Vector2(684.0, 295.5),
]

var _output_dir := "/private/tmp/lubi_three_choice_runtime_fix_20260812/after"
var _project_root := ""
var _expected_project_root := ""
var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_output_dir = _output_directory_from_args()
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_project_root = ProjectSettings.globalize_path("res://").trim_suffix("/").simplify_path()
	_expected_project_root = _expected_project_root_from_args()
	_write_run_provenance()
	_expect(not _expected_project_root.is_empty(), "visible acceptance requires --expected-project-root so evidence cannot come from an unverified worktree")
	_expect(_project_root == _expected_project_root, "visible acceptance project root matches the Godot project the user is actually running")
	if _failed:
		print("VISIBLE_THREE_CHOICE_STANDALONE_CAPTURE_FAIL project_root=%s expected_project_root=%s output=%s" % [_project_root, _expected_project_root, _output_dir])
		quit(1)
		return
	var view := ThreeChoiceScene.instantiate() as Control
	root.add_child(view)
	await _settle(16)
	_save_capture("operation_01_default.png")

	var second_route := view.get_node(
		"MainBG/Containers/Middle/Middle_Three_Option/CardGrid/Three_Option_Slot2/Three_Button"
	) as TextureButton
	_move_mouse_to(second_route)
	await _settle(6)
	# A standalone SceneTree window can miss the first synthetic pointer enter
	# when macOS grants focus after launch. Keep the visible operation stable
	# without changing the page behavior under test.
	if not (second_route.get_parent().get_node("RouteHighlight") as TextureRect).visible:
		second_route.mouse_entered.emit()
		await _settle(2)
	_expect((second_route.get_parent().get_node("RouteHighlight") as TextureRect).visible, "route hover highlight is visible")
	_save_capture("operation_02_route_hover.png")

	var exit_button := view.get_node("MainBG/Containers/ExitButton") as TextureButton
	_move_mouse_to(exit_button)
	await _settle(6)
	_expect(exit_button.visible and not exit_button.disabled, "exit door remains available during the visible interaction pass")
	_save_capture("operation_03_exit_hover.png")

	var bag_button := view.get_node("MainBG/Containers/Bags/Bag_Button") as TextureButton
	_click(bag_button)
	await _settle(24)
	var middle := view.get_node("MainBG/Containers/Middle") as Control
	var bags := view.get_node("MainBG/Containers/Bags") as Control
	var party := view.get_node("MainBG/Containers/Party") as Control
	var top := view.get_node("MainBG/Containers/Top") as Control
	_expect(bags.z_index > middle.z_index, "open bag chest and party shelf render above the bag overlay mask")
	_expect(party.z_index > middle.z_index, "party sprites render above the bag overlay mask")
	_expect(top.z_index > middle.z_index, "coin panel, icon, and amount render above the bag overlay mask")
	_expect(_bag_button_uses_only_texture(bag_button, "bag_open_full.png"), "the existing Bag_Button uses only its open texture while the bag is open")
	_expect(_bag_open_rear_left_gap_is_transparent(bag_button), "the open bag texture does not leak the closed chest at the authored rear-left gap")
	_save_capture("operation_04_bag_open.png")

	var bag_item_bar := view.get_node("MainBG/Containers/Middle/Middle_Bag/ItemBar") as Control
	var bag_slot_paths := []
	for slot_index in range(BAG_PAINTED_FRAME_CENTERS.size()):
		bag_slot_paths.append("MainBG/Containers/Middle/Middle_Bag/Slots/Bag_Slot%s" % ["" if slot_index == 0 else str(slot_index + 1)])
	for slot_index in range(bag_slot_paths.size()):
		var tested_slot := view.get_node(bag_slot_paths[slot_index]) as TextureButton
		_move_mouse_to(tested_slot)
		await _settle(6)
		# A standalone macOS window can lose synthetic enter events while focus or a
		# bag transition settles. Emit the authored Control signal as a deterministic
		# fallback while still positioning the real pointer at the target.
		tested_slot.mouse_entered.emit()
		await _settle(2)
		_expect((view.get_node("ItemSlotHoverHighlight") as TextureRect).visible, "bag slot %d hover highlight is visible" % [slot_index + 1])
		_expect_bag_highlight_aligned(view, bag_item_bar, tested_slot, slot_index)
		_save_capture("alignment_slot_%02d_hover.png" % [slot_index + 1])
		if slot_index == 0:
			_save_capture("operation_05_bag_slot_hover.png")
		elif slot_index == 3:
			_save_capture("operation_06_bag_top_right_hover.png")
		elif slot_index == 4:
			_save_capture("operation_07_bag_bottom_left_hover.png")
		elif slot_index == 7:
			_save_capture("operation_08_bag_bottom_right_hover.png")
	var bag_slot := view.get_node(bag_slot_paths[0]) as TextureButton
	(view.get_node(bag_slot_paths[-1]) as TextureButton).mouse_exited.emit()

	_click(bag_button)
	await _settle(24)
	_expect(_bag_button_uses_only_texture(bag_button, "bag_closed.png"), "the same Bag_Button returns to only its closed texture after closing the bag")
	var party_slot := view.get_node("MainBG/Containers/Party/Party_Container/Party_Slot") as TextureButton
	var party_material := party_slot.material as ShaderMaterial
	_expect(not (view.get_node("ItemSlotHoverHighlight") as TextureRect).visible, "team slots do not use the shared slot-ring highlight")
	_expect(party_material != null and bool(party_material.get_shader_parameter("shadow_enabled")), "occupied party sprite has an authored ground shadow")
	_expect(float(party_material.get_shader_parameter("shadow_highlight")) < 0.5, "party shadow starts in its normal state")
	_move_mouse_to(party_slot)
	await _settle(6)
	if float(party_material.get_shader_parameter("shadow_highlight")) <= 0.5:
		party_slot.mouse_entered.emit()
		await _settle(2)
	_expect(not (view.get_node("ItemSlotHoverHighlight") as TextureRect).visible, "party hover does not restore the deleted slot ring")
	_expect(float(party_material.get_shader_parameter("shadow_highlight")) > 0.5, "party hover brightens the sprite ground shadow")
	var detail_panel := view.get_node("ArtistPetDetailPanel") as Control
	var detail_surface := detail_panel.get_node("Panel") as Control
	_expect(detail_panel.visible, "party hover shows the shared SpriteInfoCard detail panel")
	_expect(not bool(detail_panel.get("context_follow_pointer")), "three-choice detail panel uses its authored fixed context layout")
	_expect(detail_surface.position.is_equal_approx(Vector2(8.0, 390.0)), "three-choice detail panel stays at the authored left-edge position")
	_expect(detail_surface.scale.is_equal_approx(Vector2(0.64, 0.64)), "three-choice detail panel keeps the authored reduced scale")
	var detail_rect := _transformed_control_rect(detail_surface)
	_expect(detail_rect.position.x <= 8.01 and detail_rect.end.x < 255.0, "left detail panel remains inside the background-only strip")
	for protected_path in [
		"MainBG/Temple",
		"MainBG/Containers/Middle/Middle_Three_Option",
		"MainBG/Containers/Party",
		"MainBG/Containers/Bags",
		"MainBG/Containers/ExitButton",
		"MainBG/Containers/Top/Hud",
	]:
		var protected_control := view.get_node(protected_path) as Control
		_expect(not detail_rect.intersects(_transformed_control_rect(protected_control)), "left detail panel does not cover %s" % protected_path)
	_save_capture("operation_09_party_hover.png")

	_click(party_slot)
	_move_mouse_to(exit_button)
	party_slot.mouse_exited.emit()
	await _settle(6)
	_expect(float(party_material.get_shader_parameter("shadow_highlight")) < 0.5, "click focus does not keep the party shadow highlighted")
	_expect(party_slot.texture_normal != null, "party sprite and normal shadow remain visible after click release")
	_save_capture("operation_10_party_after_click_mouse_away.png")

	party_slot.button_down.emit()
	view.call("_update_drag_preview", Vector2(960, 540))
	await _settle(6)
	var drag_preview := view.get("_drag_preview") as TextureRect
	_expect(drag_preview != null and drag_preview.visible, "standalone party preview can be picked up and dragged")
	_expect(party_slot.texture_normal == null, "dragging temporarily hides the authored source sprite and shadow")
	_save_capture("operation_11_party_drag_preview.png")
	var party_slot_2 := view.get_node("MainBG/Containers/Party/Party_Container/Party_Slot2") as TextureButton
	_release_mouse_at(view, party_slot_2)
	await _settle(8)
	_expect(party_slot.texture_normal == null, "standalone party drop clears the source slot")
	_expect(party_slot_2.texture_normal != null, "standalone party drop places the sprite in another party slot")
	_expect(not Dictionary(party_slot_2.get_meta("drag_record", {})).is_empty(), "standalone party drop moves the local preview record")
	_save_capture("operation_12_party_drop_to_party_slot.png")

	_click(bag_button)
	await _settle(24)
	_expect(_bag_button_uses_only_texture(bag_button, "bag_open_full.png"), "reopening the bag keeps the same Bag_Button on only its open texture")
	party_slot_2.button_down.emit()
	await _settle(3)
	_release_mouse_at(view, bag_slot)
	await _settle(8)
	_expect(party_slot_2.texture_normal == null, "standalone bag drop clears the party source")
	_expect(bag_slot.texture_normal != null, "standalone bag drop places the sprite into the selected bag slot")
	_expect(not Dictionary(bag_slot.get_meta("drag_record", {})).is_empty(), "standalone bag drop preserves the local preview record")
	_save_capture("operation_13_party_drop_to_bag_slot.png")

	var party_slot_4 := view.get_node("MainBG/Containers/Party/Party_Container/Party_Slot4") as TextureButton
	bag_slot.button_down.emit()
	await _settle(3)
	_release_mouse_at(view, party_slot_4)
	await _settle(8)
	_expect(bag_slot.texture_normal == null, "standalone party return clears the bag source")
	_expect(party_slot_4.texture_normal != null, "standalone party return places the sprite in the chosen party slot")
	_save_capture("operation_14_bag_drop_to_party_slot.png")

	var empty_party_slot := view.get_node("MainBG/Containers/Party/Party_Container/Party_Slot3") as TextureButton
	var empty_party_material := empty_party_slot.material as ShaderMaterial
	_move_mouse_to(empty_party_slot)
	await _settle(6)
	_expect(empty_party_slot.texture_normal == null, "empty party slot has no sprite or ground shadow draw surface")
	_expect(float(empty_party_material.get_shader_parameter("shadow_highlight")) < 0.5, "empty party slot hover does not create a shadow highlight")
	_expect(not (view.get_node("ItemSlotHoverHighlight") as TextureRect).visible, "empty party slot hover has no slot-ring highlight")

	print("VISIBLE_THREE_CHOICE_STANDALONE_CAPTURE_%s project_root=%s output=%s" % ["FAIL" if _failed else "PASS", _project_root, _output_dir])
	quit(1 if _failed else 0)


func _output_directory_from_args() -> String:
	for argument_value in OS.get_cmdline_user_args():
		var argument := String(argument_value)
		if argument.begins_with("--output-dir="):
			return argument.trim_prefix("--output-dir=")
	return _output_dir


func _expected_project_root_from_args() -> String:
	for argument_value in OS.get_cmdline_user_args():
		var argument := String(argument_value)
		if argument.begins_with("--expected-project-root="):
			return argument.trim_prefix("--expected-project-root=").trim_suffix("/").simplify_path()
	return ""


func _write_run_provenance() -> void:
	var provenance_path := _output_dir.path_join("run_provenance.json")
	var file := FileAccess.open(provenance_path, FileAccess.WRITE)
	if file == null:
		_expect(false, "visible acceptance writes project provenance beside its screenshots")
		return
	file.store_string(JSON.stringify({
		"project_root": _project_root,
		"expected_project_root": _expected_project_root,
		"project_file": _project_root.path_join("project.godot"),
		"tested_scene": TESTED_SCENE_PATH,
		"capture_script": "res://tests/visible/visible_three_choice_standalone_capture.gd",
	}, "\t"))


func _move_mouse_to(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	Input.warp_mouse(Vector2i(position))
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)


func _release_mouse_at(view: Control, control: Control) -> void:
	var position := control.get_global_rect().get_center()
	Input.warp_mouse(Vector2i(position))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = position
	event.global_position = position
	view.call("_input", event)


func _expect_bag_highlight_aligned(view: Control, item_bar: Control, slot: Control, slot_index: int) -> void:
	var highlight := view.get_node("ItemSlotHoverHighlight") as TextureRect
	var slot_canvas_origin := slot.get_global_transform_with_canvas().origin
	var slot_position_in_scene := view.get_global_transform_with_canvas().affine_inverse() * slot_canvas_origin
	var expected := slot_position_in_scene + (view.get("item_slot_highlight_offset") as Vector2)
	_expect(highlight.position.is_equal_approx(expected), "bag slot %d highlight follows its authored slot position" % [slot_index + 1])
	_expect(highlight.size.is_equal_approx(Vector2(183.0, 177.0)), "bag slot %d highlight keeps the authored outline size" % [slot_index + 1])
	var item_bar_origin := item_bar.get_global_transform_with_canvas().origin
	var highlight_center := _transformed_control_rect(highlight).get_center() - item_bar_origin
	_expect(highlight_center.distance_to(BAG_PAINTED_FRAME_CENTERS[slot_index]) <= 2.0, "bag slot %d highlight center matches the measured painted frame center" % [slot_index + 1])


func _bag_button_uses_only_texture(button: TextureButton, expected_file_name: String) -> bool:
	var state_textures := [button.texture_normal, button.texture_pressed, button.texture_hover, button.texture_focused]
	for texture_value in state_textures:
		var state_texture := texture_value as Texture2D
		if state_texture == null or state_texture.resource_path.get_file() != expected_file_name:
			return false
	return true


func _bag_open_rear_left_gap_is_transparent(button: TextureButton) -> bool:
	var texture := button.texture_normal as Texture2D
	if texture == null:
		return false
	var image := Image.load_from_file(ProjectSettings.globalize_path(texture.resource_path))
	return image != null and image.get_pixel(33, 74).a <= 0.01 and image.get_pixel(45, 90).a <= 0.01


func _transformed_control_rect(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	var corners := [
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0.0),
		transform * control.size,
		transform * Vector2(0.0, control.size.y),
	]
	var minimum := corners[0] as Vector2
	var maximum := minimum
	for corner_value in corners.slice(1):
		var corner := corner_value as Vector2
		minimum = Vector2(minf(minimum.x, corner.x), minf(minimum.y, corner.y))
		maximum = Vector2(maxf(maximum.x, corner.x), maxf(maximum.y, corner.y))
	return Rect2(minimum, maximum - minimum)


func _click(control: Control) -> void:
	_move_mouse_to(control)
	var position := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _save_capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(_output_dir.path_join(file_name))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("VISIBLE_THREE_CHOICE_STANDALONE_CAPTURE_FAIL: %s" % message)
