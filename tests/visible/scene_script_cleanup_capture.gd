extends SceneTree

const MAIN_SCENE := preload("res://art/scenes/app/game.tscn")
const SETTLE_FRAMES := 36

var _capture_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_capture_dir = OS.get_environment("UI_CAPTURE_DIR").strip_edges()
	if _capture_dir == "":
		_fail("UI_CAPTURE_DIR is required")
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await _settle(SETTLE_FRAMES)

	var view := game.get_node("ThreeChoiceScene") as Control
	print("SCENE_SCRIPT_CLEANUP_RUNTIME_TREE: nodes=%d scripted_nodes=%d" % [
		_count_tree_nodes(view),
		_count_scripted_nodes(view),
	])
	var route_button := view.get_node(
		"MainBG/Containers/Middle/Middle_Three_Option/CardGrid/Three_Option_Slot/Three_Button"
	) as TextureButton
	route_button.mouse_entered.emit()
	await _settle(8)
	await _capture("01_route_card_hover.png")

	route_button.mouse_exited.emit()
	await _settle(8)
	await _capture("02_route_card_hover_exit.png")

	var shop_snapshot := Dictionary(game.call("get_game_session").call("current_snapshot"))
	shop_snapshot["phase"] = "shop"
	await view.call("render_snapshot", shop_snapshot, false)
	await _settle(SETTLE_FRAMES)
	var shop_grid := view.get_node("MainBG/Containers/Middle/Middle_Shop/Slots") as Control
	var shop_button := _first_available_texture_button(shop_grid, "purchasable")
	if shop_button == null:
		_fail("shop did not expose a purchasable slot")
		return
	await _capture("03_enter_shop.png")

	shop_button.mouse_entered.emit()
	await _settle(8)
	await _capture("04_shop_slot_hover.png")

	shop_button.mouse_exited.emit()
	shop_button.button_down.emit()
	await _settle(8)
	view.call("_update_drag_preview", Vector2(960, 540))
	await _settle(4)
	if not _drag_preview_visible(view):
		_fail("shop drag preview was not visible")
		return
	await _capture("05_shop_drag_preview.png")
	view.call("_clear_drag_state")
	await _settle(4)

	var bag_button := view.get_node("MainBG/Containers/Bags/Bag_Button") as TextureButton
	bag_button.pressed.emit()
	await _settle(SETTLE_FRAMES)
	await _capture("06_open_bag.png")

	var bag_grid := view.get_node("MainBG/Containers/Middle/Middle_Bag/Slots") as Control
	var bag_slot_button := _first_texture_button(bag_grid)
	if bag_slot_button == null:
		_fail("bag did not expose a slot")
		return
	bag_slot_button.mouse_entered.emit()
	await _settle(8)
	await _capture("07_bag_slot_hover.png")

	bag_slot_button.mouse_exited.emit()
	await _settle(8)
	await _capture("08_bag_slot_hover_exit.png")

	var party_grid := view.get_node("MainBG/Containers/Party/Party_Container") as Control
	var party_button := _first_available_texture_button(party_grid, "drag_record")
	if party_button == null:
		_fail("party did not expose an occupied slot")
		return
	party_button.mouse_entered.emit()
	await _settle(8)
	await _capture("09_party_slot_hover.png")

	party_button.mouse_exited.emit()
	party_button.button_down.emit()
	await _settle(8)
	view.call("_update_drag_preview", Vector2(960, 540))
	await _settle(4)
	if not _drag_preview_visible(view):
		_fail("party drag preview was not visible")
		return
	await _capture("10_party_drag_preview.png")
	view.call("_clear_drag_state")
	await _settle(4)

	bag_button.pressed.emit()
	await _settle(SETTLE_FRAMES)
	await _capture("11_close_bag.png")

	print("SCENE_SCRIPT_CLEANUP_VISIBLE_CAPTURE_PASS: %s" % _capture_dir)
	quit(0)


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var output_path := _capture_dir.path_join(file_name)
	var error := image.save_png(output_path)
	if error != OK:
		_fail("%s: %s" % [file_name, error_string(error)])
		return
	print("SCENE_SCRIPT_CLEANUP_VISIBLE_CAPTURE_SAVED: %s" % output_path)


func _first_texture_button(root_node: Node) -> TextureButton:
	for child in root_node.get_children():
		if child is TextureButton:
			return child as TextureButton
		var nested := _first_texture_button(child)
		if nested != null:
			return nested
	return null


func _first_available_texture_button(root_node: Node, metadata_name: String) -> TextureButton:
	var candidates: Array[TextureButton] = []
	_collect_texture_buttons(root_node, candidates)
	for button in candidates:
		if button.disabled or not button.has_meta(metadata_name):
			continue
		var value: Variant = button.get_meta(metadata_name)
		if value is bool and bool(value):
			return button
		if value is Dictionary and not Dictionary(value).is_empty():
			return button
	return null


func _collect_texture_buttons(root_node: Node, result: Array[TextureButton]) -> void:
	for child in root_node.get_children():
		if child is TextureButton:
			result.append(child as TextureButton)
		_collect_texture_buttons(child, result)


func _drag_preview_visible(view: Control) -> bool:
	var preview := view.get_node_or_null("DragPreview") as TextureRect
	return preview != null and preview.visible and preview.texture != null


func _count_tree_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_tree_nodes(child)
	return total


func _count_scripted_nodes(node: Node) -> int:
	var total := 1 if node.get_script() != null else 0
	for child in node.get_children():
		total += _count_scripted_nodes(child)
	return total


func _fail(message: String) -> void:
	push_error("SCENE_SCRIPT_CLEANUP_VISIBLE_CAPTURE_FAIL: %s" % message)
	quit(1)
