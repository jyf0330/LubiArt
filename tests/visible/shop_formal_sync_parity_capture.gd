extends SceneTree

const MAIN_SCENE := preload("res://art/scenes/app/game.tscn")
const WINDOW_SIZE := Vector2i(1920, 1080)
const OPTION_ID := "node_shop_basic"
const NEUTRAL_MOUSE_POSITION := Vector2(1850.0, 1030.0)

var _output_dir := ""
var _expected_project_root := ""
var _project_root := ""
var _git_root := ""
var _failed := false
var _captures: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = _argument_value("--output-dir=")
	_expected_project_root = _argument_value("--expected-project-root=").trim_suffix("/").simplify_path()
	_project_root = ProjectSettings.globalize_path("res://").trim_suffix("/").simplify_path()
	_git_root = _find_git_root(_project_root)
	_expect(_output_dir != "", "output directory is required")
	_expect(_expected_project_root != "", "expected project root is required")
	_expect(_project_root == _expected_project_root, "res root matches the expected art project")
	_expect(_git_root == _project_root, "Git root and res root are identical")
	if _failed:
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_output_dir)
	DisplayServer.window_set_size(WINDOW_SIZE)
	root.size = WINDOW_SIZE

	var game := MAIN_SCENE.instantiate() as Control
	root.add_child(game)
	await _settle(36)
	var route_button := _find_command_button(game, "CHOOSE_ROUTE", OPTION_ID)
	_expect(route_button != null, "route exposes node_shop_basic")
	if route_button == null:
		_finish()
		return
	await _click(route_button)
	var route_confirm := game.get_node("ThreeChoiceScene/RouteSharedUi/ExitButton") as TextureButton
	await _click(route_confirm)
	var shop := await _wait_for_shop(game)
	_expect(shop != null, "real route pointer flow mounts the authored ShopScene")
	if shop == null:
		_finish()
		return
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	var offers := shop.get_node("Offers") as Control
	_expect(_visible_offer_count(offers) == 3, "three synchronized formal offers are visible")
	_expect(_empty_offer_count(offers) == 2, "two authored shelf slots remain intentionally empty")
	await _capture("01_shop_entry", "进入基础商店", shop)

	var first_offer := offers.get_node("Offer01") as Button
	await _move_mouse(first_offer.get_global_rect().get_center())
	await _settle(8)
	await _capture("02_offer_hover", "悬停第一件商品", shop)

	var refresh := shop.get_node("RefreshButton") as TextureButton
	await _click(refresh, false)
	await create_timer(0.18).timeout
	var curtain := shop.get_node("RefreshCurtain") as TextureRect
	_expect(curtain.visible, "refresh curtain is visible during the operation")
	await _capture("03_refresh_curtain", "点击刷新后的红帘过程", shop)
	await create_timer(0.55).timeout
	_expect(not curtain.visible and not refresh.disabled, "refresh completes and unlocks input")
	_expect(_visible_offer_count(offers) == 3, "refresh keeps the formal three-offer shape")
	await _capture("04_refresh_complete", "刷新动画完成", shop)

	first_offer = offers.get_node("Offer01") as Button
	var purchase_id := String(Dictionary(first_offer.get_meta("offer", {})).get("id", ""))
	var coins_before_purchase := int(Dictionary(shop.call("preview_snapshot")).get("coins", 0))
	await _click(first_offer)
	await _settle(24)
	var purchased_snapshot := Dictionary(shop.call("preview_snapshot"))
	_expect(purchase_id != "" and _offer_is_sold(purchased_snapshot, purchase_id), "real click marks the captured first offer sold")
	_expect(int(purchased_snapshot.get("coins", 0)) < coins_before_purchase, "real purchase deducts formal coins")
	await _capture("05_purchase_complete", "购买第一件商品完成", shop)

	var exit_button := shop.get_node("RouteSharedUi/ExitButton") as TextureButton
	await _click(exit_button)
	await _settle(30)
	_expect(String(game.call("get_active_feature_id")) == "", "real exit returns to route")
	await _capture("06_exit_to_route", "退出商店返回路线", null)
	_finish()


func _find_command_button(parent: Node, command_type: String, option_id := "") -> BaseButton:
	for node in parent.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) != command_type:
			continue
		if option_id != "" and String(command.get("option_id", command.get("optionId", ""))) != option_id:
			continue
		return button
	return null


func _wait_for_shop(game: Control) -> Control:
	for _frame in range(240):
		var active := game.call("get_active_feature_view") as Control
		if String(game.call("get_active_feature_id")) == "shop" and active != null:
			return active
		await process_frame
	return null


func _visible_offer_ids(offers: Control) -> PackedStringArray:
	var result := PackedStringArray()
	for child in offers.get_children():
		var button := child as Button
		if button == null:
			continue
		var offer_id := String(Dictionary(button.get_meta("offer", {})).get("id", ""))
		if offer_id != "":
			result.append(offer_id)
	return result


func _visible_offer_count(offers: Control) -> int:
	return _visible_offer_ids(offers).size()


func _empty_offer_count(offers: Control) -> int:
	return 5 - _visible_offer_count(offers)


func _offer_is_sold(snapshot: Dictionary, offer_id: String) -> bool:
	for value in Array(snapshot.get("shop_offers", [])):
		var offer := Dictionary(value)
		if String(offer.get("id", "")) == offer_id:
			return bool(offer.get("sold", false))
	return false


func _click(control: Control, settle_after := true) -> void:
	var position := control.get_global_rect().get_center()
	await _move_mouse(position)
	await _mouse_button(position, true)
	await process_frame
	await _mouse_button(position, false)
	if settle_after:
		await _settle(5)


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


func _settle(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _capture(name: String, operation: String, shop: Control) -> void:
	await RenderingServer.frame_post_draw
	var path := _output_dir.path_join(name + ".png")
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "viewport image exists for %s" % name)
	if image != null and not image.is_empty():
		_expect(image.save_png(path) == OK, "capture writes %s" % path)
	var snapshot := Dictionary(shop.call("preview_snapshot")) if shop != null else {}
	_captures.append({
		"name": name,
		"operation": operation,
		"file": name + ".png",
		"phase": String(snapshot.get("phase", "route")),
		"coins": int(snapshot.get("coins", 0)),
		"offer_count": Array(snapshot.get("shop_offers", [])).size(),
	})


func _finish() -> void:
	if _output_dir != "":
		var manifest := {
			"schema": "lubiart.shop-formal-sync-parity-capture.v1",
			"side": "art_package",
			"project_root": _project_root,
			"git_root": _git_root,
			"window_size": [WINDOW_SIZE.x, WINDOW_SIZE.y],
			"selected_option_id": OPTION_ID,
			"capture_script": "res://tests/visible/shop_formal_sync_parity_capture.gd",
			"captures": _captures,
			"passed": not _failed,
		}
		var file := FileAccess.open(_output_dir.path_join("capture_manifest.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(manifest, "  ") + "\n")
			file.close()
	print("SHOP_FORMAL_SYNC_PARITY_CAPTURE_%s output=%s captures=%d" % ["FAIL" if _failed else "PASS", _output_dir, _captures.size()])
	quit(1 if _failed else 0)


func _argument_value(prefix: String) -> String:
	for value in OS.get_cmdline_user_args():
		var argument := String(value)
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _find_git_root(start_path: String) -> String:
	var candidate := start_path
	while candidate != "":
		if DirAccess.dir_exists_absolute(candidate.path_join(".git")) or FileAccess.file_exists(candidate.path_join(".git")):
			return candidate
		var parent := candidate.get_base_dir()
		if parent == candidate:
			break
		candidate = parent
	return ""


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SHOP_FORMAL_SYNC_PARITY_CAPTURE_FAIL: %s" % message)
