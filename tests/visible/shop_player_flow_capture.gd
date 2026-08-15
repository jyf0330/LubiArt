extends SceneTree

const MAIN_SCENE := preload("res://art/scenes/app/game.tscn")
const MAIN_SCENE_PATH := "res://art/scenes/app/game.tscn"
const SHOP_SCENE_PATH := "res://art/scenes/shop/shop_scene.tscn"
const FACADE_PATH := "res://art/images/shop/screen_shop_godot_v1/shop_facade.png"

var _output_dir := "/private/tmp/lubi_shop_player_flow_20260814/current"
var _project_root := ""
var _expected_project_root := ""
var _git_root := ""
var _expected_git_root := ""
var _failed := false
var _diagnostics := {}
var _shop_commands := []
var _shop_command_records := []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_output_dir = _argument_value("--output-dir=", _output_dir)
	_expected_project_root = _argument_value("--expected-project-root=", "").trim_suffix("/").simplify_path()
	_project_root = ProjectSettings.globalize_path("res://").trim_suffix("/").simplify_path()
	_expected_git_root = _argument_value("--expected-git-root=", _expected_project_root).trim_suffix("/").simplify_path()
	_git_root = _find_git_root(_project_root)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_write_provenance()
	_expect(not _expected_project_root.is_empty(), "expected project root is required")
	_expect(_project_root == _expected_project_root, "res root matches the user Git worktree")
	_expect(_git_root == _expected_git_root and _git_root == _project_root, "Git root, res root, and launched project root are identical")
	if _failed:
		_finish()
		return

	var game := MAIN_SCENE.instantiate() as Control
	root.add_child(game)
	await _settle(36)
	_expect(String(game.call("get_active_feature_id")) == "", "player flow starts on the authored route page")
	await _capture("operation_01_route_entry.png")

	var route_button := game.get_node(
		"ThreeChoiceScene/MainBG/Containers/Middle/Middle_Three_Option/CardGrid/Three_Option_Slot/Three_Button"
	) as TextureButton
	await _click(route_button)
	await _settle(12)
	await _capture("operation_02_route_selected.png")
	var route_exit := game.get_node("ThreeChoiceScene/RouteSharedUi/ExitButton") as TextureButton
	await _click(route_exit)
	var shop := await _wait_for_shop(game)
	_diagnostics["real_pointer_route_entered_shop"] = shop != null
	if shop == null and _has_argument("--diagnostic-route-fallback"):
		# Repair evidence only: record the real-pointer failure first, then traverse
		# the same Game/Session chain so shop-internal pointer defects can still be
		# captured without booting ShopScene directly.
		route_button.pressed.emit()
		await _settle(4)
		route_exit.pressed.emit()
		shop = await _wait_for_shop(game)
		_diagnostics["diagnostic_route_fallback_used"] = true
	_expect(bool(_diagnostics.get("real_pointer_route_entered_shop", false)), "route selection and exit mount ShopScene through real pointer input")
	_expect(shop != null, "route selection and exit mount ShopScene through Game")
	if shop == null:
		_finish()
		return
	shop.command_requested.connect(_on_shop_command_requested)
	await _settle(24)
	await _capture("operation_03_shop_normal.png")

	var offers := shop.get_node("Offers") as Control
	var offer_icons := 0
	var visible_prices := 0
	for child in offers.get_children():
		var button := child as Button
		if button != null and button.icon != null:
			offer_icons += 1
		if button != null and not String(button.get_meta("price", "")).is_empty():
			visible_prices += 1
	_diagnostics["offer_icon_count"] = offer_icons
	_diagnostics["offer_price_count"] = visible_prices
	_expect(offer_icons == 5, "all five shop pets resolve from the route Snapshot")
	_expect(visible_prices == 5, "all five authored price tags have data")

	var first_offer := offers.get_node("Offer01") as Button
	await _move_mouse(first_offer.get_global_rect().get_center())
	await _settle(8)
	await _capture("operation_04_offer_hover.png")

	var refresh := shop.get_node("RefreshButton") as TextureButton
	var offer_ids_before_roll := _visible_offer_ids(offers)
	await _click(refresh, false)
	await create_timer(0.18).timeout
	var curtain := shop.get_node("RefreshCurtain") as TextureRect
	_diagnostics["refresh_curtain_visible_after_real_click"] = curtain.visible
	await _capture("operation_05_refresh_curtain.png")
	await create_timer(0.55).timeout
	_diagnostics["refresh_commands"] = _shop_commands.count("ROLL_SHOP")
	_diagnostics["refresh_button_reenabled"] = not refresh.disabled
	var offer_ids_after_roll := _visible_offer_ids(offers)
	_diagnostics["offer_ids_before_roll"] = offer_ids_before_roll
	_diagnostics["offer_ids_after_roll"] = offer_ids_after_roll
	_expect(_shop_commands.count("ROLL_SHOP") == 1, "real bell click submits exactly one ROLL_SHOP")
	_expect(not refresh.disabled and not curtain.visible, "refresh curtain clears and the real bell recovers")
	_expect(not _has_overlap(offer_ids_after_roll, offer_ids_before_roll), "ROLL_SHOP replaces all five visible exported offers before the curtain rises")
	_expect(_visible_offer_icon_count(offers) == 5, "all five refreshed offers resolve existing pet art")
	await _capture("operation_06_refresh_complete.png")

	var party_slot := shop.get_node("RouteSharedUi/Party/Party_Container/Party_Slot") as TextureButton
	var party_material := party_slot.material as ShaderMaterial
	await _move_mouse(party_slot.get_global_rect().get_center())
	await _settle(8)
	var shadow_hover := float(party_material.get_shader_parameter("shadow_highlight")) if party_material != null else -1.0
	_diagnostics["party_shadow_hover"] = shadow_hover
	_expect(party_slot.visible and party_slot.has_meta("pet_texture") and party_slot.get_meta("pet_texture") != null, "party pet remains visible in ShopScene")
	_expect(shadow_hover > 0.5, "real party hover brightens the authored ground shadow")
	await _capture("operation_07_party_hover.png")

	var bag_button := shop.get_node("RouteSharedUi/Bags/Bag_Button") as TextureButton
	await _click(bag_button)
	await _settle(18)
	var bag_slots := shop.get_node("RouteSharedUi/Middle_Bag/Slots") as GridContainer
	var highlight := shop.get_node("RouteSharedUi/ItemSlotHoverHighlight") as TextureRect
	var highlighted_slots := 0
	for index in range(bag_slots.get_child_count()):
		var slot := bag_slots.get_child(index) as TextureButton
		await _move_mouse(slot.get_global_rect().get_center())
		await _settle(5)
		if highlight.visible:
			highlighted_slots += 1
		await _capture("bag_slot_%02d_hover.png" % [index + 1])
	_diagnostics["bag_highlighted_slot_count"] = highlighted_slots
	_expect(highlighted_slots == 8, "all eight existing bag slots show the authored hover highlight")

	var first_bag_slot := bag_slots.get_child(0) as TextureButton
	var second_bag_slot := bag_slots.get_child(1) as TextureButton
	await _mouse_button(party_slot.get_global_rect().get_center(), true)
	await _settle(3)
	await _move_mouse(Vector2(960.0, 540.0))
	await _settle(5)
	var preview := shop.get_node_or_null("DragPreview") as TextureRect
	_diagnostics["drag_preview_visible"] = preview != null and preview.visible
	_expect(preview != null and preview.visible, "real party press creates the shared drag preview")
	await _capture("operation_08_party_drag.png")
	await _move_mouse(first_bag_slot.get_global_rect().get_center())
	await _mouse_button(first_bag_slot.get_global_rect().get_center(), false)
	await _settle(24)
	_diagnostics["drop_commands"] = _shop_commands.count("DROP_ITEM_ON_TARGET")
	_expect(_shop_commands.count("DROP_ITEM_ON_TARGET") == 1, "real party drop submits the existing semantic command")
	_expect(first_bag_slot.has_meta("pet_texture") and first_bag_slot.get_meta("pet_texture") != null, "Snapshot reconciliation places the party pet in the selected bag slot")
	await _capture("operation_09_party_drop_to_bag.png")
	await _click(bag_button)
	await _settle(12)
	_expect(not (bag_slots.get_parent() as Control).visible, "bag closes before interacting with the shop shelf")

	var offer_for_drag := offers.get_node("Offer01") as Button
	var dragged_offer_id := String(Dictionary(offer_for_drag.get_meta("offer", {})).get("id", ""))
	var following_offer_id := String(Dictionary((offers.get_node("Offer02") as Button).get_meta("offer", {})).get("id", ""))
	await _mouse_button(offer_for_drag.get_global_rect().get_center(), true)
	await _move_mouse(Vector2(960.0, 540.0))
	await _settle(4)
	preview = shop.get_node_or_null("DragPreview") as TextureRect
	_expect(preview != null and preview.visible, "real offer press creates the shared pet drag preview")
	await _capture("operation_10_offer_drag.png")
	await _move_mouse(party_slot.get_global_rect().get_center())
	await _mouse_button(party_slot.get_global_rect().get_center(), false)
	await _settle(24)
	_diagnostics["dragged_offer_id"] = dragged_offer_id
	_expect(_shop_commands.count("DROP_ITEM_ON_TARGET") == 2, "real offer drop submits the existing semantic purchase command")
	_expect(not _visible_offer_ids(offers).has(dragged_offer_id), "purchased dragged offer disappears after Snapshot reconciliation")
	_expect(offer_for_drag.icon == null and String(Dictionary(offer_for_drag.get_meta("offer", {})).get("id", "")).is_empty(), "formal purchase leaves the dragged shelf position empty")
	_expect(String(Dictionary((offers.get_node("Offer02") as Button).get_meta("offer", {})).get("id", "")) == following_offer_id, "formal Snapshot keeps the following offer in its original shelf position")
	_expect(party_slot.has_meta("pet_texture") and party_slot.get_meta("pet_texture") != null, "dragged shop pet is placed in the selected party slot")
	await _capture("operation_11_offer_drop_to_party.png")

	var offer_for_click := offers.get_node("Offer02") as Button
	var clicked_offer_id := String(Dictionary(offer_for_click.get_meta("offer", {})).get("id", ""))
	await _click(offer_for_click)
	await _settle(24)
	_diagnostics["clicked_offer_id"] = clicked_offer_id
	_expect(_shop_commands.count("BUY_OFFER") == 1, "real offer click submits BUY_OFFER exactly once")
	_expect(not _visible_offer_ids(offers).has(clicked_offer_id), "clicked purchase removes the offer after Snapshot reconciliation")
	_expect(offer_for_click.icon == null and String(Dictionary(offer_for_click.get_meta("offer", {})).get("id", "")).is_empty(), "formal clicked purchase leaves its shelf position empty")
	await _click(bag_button)
	await _settle(12)
	_expect(second_bag_slot.has_meta("pet_texture") and second_bag_slot.get_meta("pet_texture") != null, "clicked purchase reaches the first free bag slot")
	await _capture("operation_12_offer_click_purchase.png")

	var exit_button := shop.get_node("RouteSharedUi/ExitButton") as TextureButton
	await _click(exit_button)
	await _settle(30)
	_diagnostics["exit_commands"] = _shop_commands.count("EXIT_SHOP")
	_expect(_shop_commands.count("EXIT_SHOP") == 1, "real exit click submits EXIT_SHOP")
	_expect(String(game.call("get_active_feature_id")) == "", "EXIT_SHOP restores the route page")
	await _capture("operation_13_exit_to_route.png")
	_finish()


func _wait_for_shop(game: Control) -> Control:
	for _frame in range(240):
		var active := game.call("get_active_feature_view") as Control
		if String(game.call("get_active_feature_id")) == "shop" and active != null:
			return active
		await process_frame
	return null


func _on_shop_command_requested(command: Dictionary, _request_id: int) -> void:
	_shop_commands.append(String(command.get("type", "")))
	_shop_command_records.append(command.duplicate(true))


func _visible_offer_ids(offers: Control) -> PackedStringArray:
	var result := PackedStringArray()
	for child in offers.get_children():
		result.append(String(Dictionary((child as Button).get_meta("offer", {})).get("id", "")))
	return result


func _visible_offer_icon_count(offers: Control) -> int:
	var count := 0
	for child in offers.get_children():
		if (child as Button).icon != null:
			count += 1
	return count


func _has_overlap(left: PackedStringArray, right: PackedStringArray) -> bool:
	for value in left:
		if right.has(value):
			return true
	return false


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


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(_output_dir.path_join(file_name))
	_expect(error == OK, "capture writes %s" % file_name)


func _write_provenance() -> void:
	var file := FileAccess.open(_output_dir.path_join("run_provenance.json"), FileAccess.WRITE)
	if file == null:
		_failed = true
		return
	file.store_string(JSON.stringify({
		"project_root": _project_root,
		"expected_project_root": _expected_project_root,
		"git_root": _git_root,
		"expected_git_root": _expected_git_root,
		"res_root": _project_root,
		"running_editor_project_root": _expected_project_root,
		"running_godot_project_root": _project_root,
		"running_editor_verification": "capture process res root and discovered Git root verified before player flow",
		"project_file": _project_root.path_join("project.godot"),
		"main_scene": MAIN_SCENE_PATH,
		"tested_scene": SHOP_SCENE_PATH,
		"capture_script": "res://tests/visible/shop_player_flow_capture.gd",
		"entry_mode": "route_player_flow_real_pointer",
		"facade_source": FACADE_PATH,
		"facade_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(FACADE_PATH)),
		"renderer": RenderingServer.get_current_rendering_method(),
	}, "\t"))


func _find_git_root(start_path: String) -> String:
	var candidate := start_path.trim_suffix("/").simplify_path()
	while not candidate.is_empty():
		var marker := candidate.path_join(".git")
		if DirAccess.dir_exists_absolute(marker) or FileAccess.file_exists(marker):
			return candidate
		var parent := candidate.get_base_dir()
		if parent == candidate:
			break
		candidate = parent
	return ""


func _write_diagnostics() -> void:
	var file := FileAccess.open(_output_dir.path_join("diagnostics.json"), FileAccess.WRITE)
	if file != null:
		_diagnostics["commands"] = _shop_commands
		_diagnostics["command_records"] = _shop_command_records
		_diagnostics["passed"] = not _failed
		file.store_string(JSON.stringify(_diagnostics, "\t"))


func _argument_value(prefix: String, fallback: String) -> String:
	for value in OS.get_cmdline_user_args():
		var argument := String(value)
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _has_argument(expected: String) -> bool:
	for value in OS.get_cmdline_user_args():
		if String(value) == expected:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SHOP_PLAYER_FLOW_CAPTURE_FAIL: %s" % message)


func _finish() -> void:
	_write_diagnostics()
	print("SHOP_PLAYER_FLOW_CAPTURE_%s: %s" % ["FAIL" if _failed else "PASS", _output_dir])
	quit(1 if _failed else 0)
