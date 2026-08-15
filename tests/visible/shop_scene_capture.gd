extends SceneTree

const SHOP_SCENE := preload("res://art/scenes/shop/shop_scene.tscn")
const TESTED_SCENE_PATH := "res://art/scenes/shop/shop_scene.tscn"

var _capture_dir := "/private/tmp/lubi_shop_standalone_20260814/current"
var _expected_root := ""
var _actual_root := ""
var _git_root := ""
var _failed := false
var _diagnostics := {}


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_capture_dir = _argument_value("--output-dir=", _capture_dir)
	_expected_root = _argument_value("--expected-project-root=", "").trim_suffix("/").simplify_path()
	_actual_root = ProjectSettings.globalize_path("res://").trim_suffix("/").simplify_path()
	_git_root = _find_git_root(_actual_root)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	_expect(not _expected_root.is_empty(), "expected project root is required")
	_expect(_actual_root == _expected_root, "res root matches the user project root")
	_expect(_git_root == _actual_root, "Git root, res root, and launched project root are identical")
	if _failed:
		_finish()
		return

	var shop := SHOP_SCENE.instantiate() as Control
	root.add_child(shop)
	await _settle(24)
	_expect(bool(shop.call("is_standalone_art_preview")), "direct ShopScene enables its non-authoritative art preview")
	_expect(shop.command_requested.get_connections().is_empty(), "direct ShopScene has no external command owner")
	var offers := shop.get_node("Offers") as Control
	var party := shop.get_node("RouteSharedUi/Party/Party_Container") as Control
	var party_slots: Array[TextureButton] = []
	for index in range(4):
		party_slots.append(party.get_node("Party_Slot" if index == 0 else "Party_Slot%d" % (index + 1)) as TextureButton)
	_expect(_visible_offer_icon_count(offers) == 5, "direct ShopScene renders five draggable offers")
	_expect(_visible_offer_price_count(offers) == 5, "direct ShopScene renders five authored prices")
	_expect(_shader_bool(party_slots[0], "source_enabled") and _shader_bool(party_slots[0], "shadow_enabled"), "occupied party slot renders its pet and shadow")
	for index in range(1, 4):
		_expect(not _shader_bool(party_slots[index], "source_enabled") and not _shader_bool(party_slots[index], "shadow_enabled"), "empty party slot %d renders no pet and no shadow" % (index + 1))
	await _capture("operation_01_direct_normal.png")

	await _move_mouse(party_slots[0].get_global_rect().get_center())
	await _settle(6)
	_diagnostics["party_shadow_hover"] = _shader_float(party_slots[0], "shadow_highlight")
	_expect(float(_diagnostics["party_shadow_hover"]) > 0.5, "real pointer hover brightens the occupied party shadow")
	await _capture("operation_02_party_hover.png")

	await _drag(party_slots[0], party_slots[1])
	await _settle(12)
	_expect(not _shader_bool(party_slots[0], "source_enabled") and not _shader_bool(party_slots[0], "shadow_enabled"), "party drag clears pet and shadow from its old slot")
	_expect(_shader_bool(party_slots[1], "source_enabled") and _shader_bool(party_slots[1], "shadow_enabled"), "party drag moves pet and shadow to the new slot")
	await _capture("operation_03_party_drag_to_party.png")

	var offer_drag := offers.get_node("Offer01") as Button
	var dragged_offer_id := _offer_id(offer_drag)
	var following_offer_id := _offer_id(offers.get_node("Offer02") as Button)
	var coins_before_drag := int(Dictionary(shop.call("preview_snapshot")).get("coins", 0))
	await _drag(offer_drag, party_slots[2])
	await _settle(12)
	_expect(not _visible_offer_ids(offers).has(dragged_offer_id), "dragged shop offer is purchased and removed")
	_expect(offer_drag.icon == null and _offer_id(offer_drag).is_empty(), "purchased direct-preview shelf position stays empty")
	_expect(_offer_id(offers.get_node("Offer02") as Button) == following_offer_id, "direct preview does not compact the next offer forward")
	_expect(_shader_bool(party_slots[2], "source_enabled") and _shader_bool(party_slots[2], "shadow_enabled"), "dragged shop pet enters the chosen party slot with a shadow")
	_expect(int(Dictionary(shop.call("preview_snapshot")).get("coins", 0)) < coins_before_drag, "shop drag updates preview coins")
	await _capture("operation_04_offer_drag_to_party.png")

	var offer_click := offers.get_node("Offer02") as Button
	if offer_click.disabled:
		offer_click = offers.get_node("Offer03") as Button
	var clicked_offer_id := _offer_id(offer_click)
	await _click(offer_click)
	await _settle(12)
	_expect(not _visible_offer_ids(offers).has(clicked_offer_id), "real offer click purchases and removes the offer")
	_expect(offer_click.icon == null and _offer_id(offer_click).is_empty(), "clicked direct-preview shelf position stays empty")
	var bag_button := shop.get_node("RouteSharedUi/Bags/Bag_Button") as TextureButton
	await _click(bag_button)
	await _settle(8)
	var bag_slots := shop.get_node("RouteSharedUi/Middle_Bag/Slots") as GridContainer
	_expect((bag_slots.get_child(0) as TextureButton).get_meta("pet_texture", null) != null, "clicked purchase reaches the first free bag slot")
	await _capture("operation_05_offer_click_purchase.png")

	var highlight := shop.get_node("RouteSharedUi/ItemSlotHoverHighlight") as TextureRect
	var highlighted_slots := 0
	for index in range(bag_slots.get_child_count()):
		var slot := bag_slots.get_child(index) as TextureButton
		await _move_mouse(slot.get_global_rect().get_center())
		await _settle(3)
		if highlight.visible:
			highlighted_slots += 1
		await _capture("bag_slot_%02d_hover.png" % (index + 1))
	_diagnostics["bag_highlighted_slot_count"] = highlighted_slots
	_expect(highlighted_slots == 8, "all eight direct-preview bag slots show the shared authored highlight")
	await _click(bag_button)
	await _settle(6)

	var refresh := shop.get_node("RefreshButton") as TextureButton
	var curtain := shop.get_node("RefreshCurtain") as TextureRect
	var before_refresh := _visible_offer_ids(offers)
	await _click(refresh, false)
	await create_timer(0.18).timeout
	_expect(curtain.visible and refresh.disabled, "direct bell lowers the curtain and disables itself during refresh")
	await _capture("operation_06_refresh_curtain.png")
	await create_timer(0.55).timeout
	var after_refresh := _visible_offer_ids(offers)
	_diagnostics["offer_ids_before_roll"] = before_refresh
	_diagnostics["offer_ids_after_roll"] = after_refresh
	_expect(not curtain.visible and not refresh.disabled, "direct refresh raises the curtain and re-enables the bell")
	_expect(after_refresh.size() == 5 and not _has_overlap(before_refresh, after_refresh), "direct refresh replaces the visible offer set")
	_expect(_visible_offer_icon_count(offers) == 5, "all five refreshed direct-preview pets resolve existing art")
	await _capture("operation_07_refresh_complete.png")

	var exit_button := shop.get_node("RouteSharedUi/ExitButton") as TextureButton
	await _click(exit_button)
	await _settle(12)
	_expect(not curtain.visible and not refresh.disabled, "direct exit does not leave any pending command or curtain")
	await _capture("operation_08_direct_exit_safe.png")
	_write_provenance(shop)
	_finish()


func _drag(source: Control, target: Control) -> void:
	var source_position := source.get_global_rect().get_center()
	var target_position := target.get_global_rect().get_center()
	await _move_mouse(source_position)
	await _mouse_button(source_position, true)
	await _settle(2)
	await _move_mouse((source_position + target_position) * 0.5)
	await _settle(2)
	_expect(root.get_node_or_null("ShopScene/DragPreview") != null, "real pointer press creates a drag preview")
	await _move_mouse(target_position)
	await _mouse_button(target_position, false)


func _click(control: Control, settle_after := true) -> void:
	var position := control.get_global_rect().get_center()
	await _move_mouse(position)
	await _mouse_button(position, true)
	await process_frame
	await _mouse_button(position, false)
	if settle_after:
		await _settle(4)


func _move_mouse(position: Vector2) -> void:
	Input.warp_mouse(Vector2i(position))
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	await process_frame


func _mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _visible_offer_icon_count(offers: Control) -> int:
	var count := 0
	for child in offers.get_children():
		if (child as Button).icon != null:
			count += 1
	return count


func _visible_offer_price_count(offers: Control) -> int:
	var count := 0
	for child in offers.get_children():
		if not String((child as Button).get_meta("price", "")).is_empty():
			count += 1
	return count


func _visible_offer_ids(offers: Control) -> PackedStringArray:
	var result := PackedStringArray()
	for child in offers.get_children():
		var offer_id := _offer_id(child as Button)
		if not offer_id.is_empty():
			result.append(offer_id)
	return result


func _offer_id(button: Button) -> String:
	return String(Dictionary(button.get_meta("offer", {})).get("id", ""))


func _has_overlap(left: PackedStringArray, right: PackedStringArray) -> bool:
	for value in left:
		if right.has(value):
			return true
	return false


func _shader_bool(button: TextureButton, parameter: StringName) -> bool:
	var material := button.material as ShaderMaterial
	return material != null and bool(material.get_shader_parameter(parameter))


func _shader_float(button: TextureButton, parameter: StringName) -> float:
	var material := button.material as ShaderMaterial
	return float(material.get_shader_parameter(parameter)) if material != null else -1.0


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(_capture_dir.path_join(file_name))
	_expect(error == OK, "capture writes %s" % file_name)


func _write_provenance(shop: Control) -> void:
	var file := FileAccess.open(_capture_dir.path_join("run_provenance.json"), FileAccess.WRITE)
	if file == null:
		_expect(false, "run provenance is writable")
		return
	file.store_string(JSON.stringify({
		"project_root": _actual_root,
		"expected_project_root": _expected_root,
		"git_root": _git_root,
		"res_root": ProjectSettings.globalize_path("res://").trim_suffix("/").simplify_path(),
		"project_file": _actual_root.path_join("project.godot"),
		"entry_scene": TESTED_SCENE_PATH,
		"standalone_art_preview": bool(shop.call("is_standalone_art_preview")),
		"external_command_owner": not shop.command_requested.get_connections().is_empty(),
		"capture_script": "res://tests/visible/shop_scene_capture.gd",
		"renderer": RenderingServer.get_current_rendering_method(),
		"diagnostics": _diagnostics,
	}, "\t"))


func _find_git_root(start_path: String) -> String:
	var cursor := start_path
	while not cursor.is_empty():
		if DirAccess.dir_exists_absolute(cursor.path_join(".git")) or FileAccess.file_exists(cursor.path_join(".git")):
			return cursor
		var parent := cursor.get_base_dir()
		if parent == cursor:
			break
		cursor = parent
	return ""


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SHOP_STANDALONE_CAPTURE_FAIL: %s" % message)


func _finish() -> void:
	var file := FileAccess.open(_capture_dir.path_join("diagnostics.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"passed": not _failed, "diagnostics": _diagnostics}, "\t"))
	print("SHOP_STANDALONE_CAPTURE_%s: %s" % ["FAIL" if _failed else "PASS", _capture_dir])
	quit(1 if _failed else 0)
