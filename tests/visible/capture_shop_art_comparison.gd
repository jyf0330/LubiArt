extends SceneTree

## Deterministic before/after capture fixture for the formal shop view.
## Both sides of a visual comparison must run this exact script.

const WINDOW_SIZE := Vector2i(1920, 1080)
const EXPECTED_OFFER_COUNT := 10
const SETTLE_FRAMES := 12

var _game: Node = null
var _output_dir := ""
var _capture_label := "capture"
var _capture_rows: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("SHOP_ART_CAPTURE_DIR").strip_edges()
	_capture_label = OS.get_environment("SHOP_ART_CAPTURE_LABEL").strip_edges()
	if _output_dir == "":
		_fail("SHOP_ART_CAPTURE_DIR is required.")
		return
	if _capture_label == "":
		_capture_label = "capture"
	if DirAccess.make_dir_recursive_absolute(_output_dir) != OK:
		_fail("Could not create capture directory: %s" % _output_dir)
		return

	DisplayServer.window_set_size(WINDOW_SIZE)
	root.size = WINDOW_SIZE
	var packed: PackedScene = load("res://art/scenes/app/game.tscn")
	if packed == null:
		_fail("Could not load the formal Game Scene.")
		return
	_game = packed.instantiate()
	root.add_child(_game)
	await _settle()
	if _game.get("state") == null:
		_fail("The formal state fixture is unavailable.")
		return
	_game.state.call("set_run_seed", "shop-art-comparison-v1")
	if not _game.state.dispatch({
		"type": "ENTER_SHOP",
		"poolId": "elem_草",
		"stallId": "merchant_curio",
		"slots": EXPECTED_OFFER_COUNT,
		"seedContext": "shop-art-comparison",
	}):
		_fail("Could not enter the formal shop through ENTER_SHOP.")
		return
	_game.call("render_current_view")
	await _settle()
	if not _assert_ready_shop():
		return
	if not await _capture("01_initial", "正式商店初始状态，10 件商品"):
		return

	var view := _shop_view()
	var freeze_button := _find_command_button(view, "FREEZE_OFFER")
	if freeze_button == null:
		_fail("The formal shop did not expose FREEZE_OFFER.")
		return
	freeze_button.emit_signal("pressed")
	await _settle()
	if not await _capture("02_frozen", "冻结首件商品"):
		return

	view = _shop_view()
	var roll_button := _find_command_button(view, "ROLL_SHOP")
	if roll_button == null:
		_fail("The formal shop did not expose ROLL_SHOP.")
		return
	roll_button.emit_signal("pressed")
	await _settle_frames(4)
	if not await _capture("03_refresh_transition", "正式刷新命令触发的揭幕瞬间"):
		return
	await _settle_frames(20)
	if not await _capture("04_refreshed", "正式刷新后的商品状态"):
		return

	view = _shop_view()
	var buy_button := _find_command_button(view, "BUY_OFFER")
	if buy_button == null:
		_fail("The refreshed formal shop did not expose BUY_OFFER.")
		return
	buy_button.emit_signal("pressed")
	await _settle()
	if not await _capture("05_purchased", "正式购买后的金币与队伍状态"):
		return

	view = _shop_view()
	var scroll := view.find_child("ShopScroll", true, false) as ScrollContainer
	if scroll == null:
		_fail("The formal shop did not expose its dynamic offer scroll.")
		return
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()
	if scroll.scroll_vertical <= 0:
		_fail("The 10-offer fixture should be scrollable at 1920x1080.")
		return
	if not await _capture("06_scrolled", "滚动到底部，验证动态 10 商品布局"):
		return

	var manifest := {
		"schema": "ysbzs.shop-art-comparison-capture.v1",
		"label": _capture_label,
		"window_size": [WINDOW_SIZE.x, WINDOW_SIZE.y],
		"run_seed": "shop-art-comparison-v1",
		"seed_context": "shop-art-comparison",
		"stall_id": "merchant_curio",
		"formal_offer_capacity": EXPECTED_OFFER_COUNT,
		"captures": _capture_rows,
	}
	var manifest_path := _output_dir.path_join("capture_manifest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write capture manifest: %s" % manifest_path)
		return
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	print("CAPTURE_SHOP_ART_COMPARISON_OK label=%s captures=%d output=%s" % [
		_capture_label,
		_capture_rows.size(),
		_output_dir,
	])
	quit(0)


func _capture(name: String, description: String) -> bool:
	var image: Image = null
	for _attempt in range(60):
		image = root.get_texture().get_image()
		if image != null and not image.is_empty() and not _is_black(image):
			break
		await process_frame
	if image == null or image.is_empty() or _is_black(image):
		_fail("Viewport remained empty or black for %s." % name)
		return false
	var output_path := _output_dir.path_join("%s.png" % name)
	if image.save_png(output_path) != OK:
		_fail("Could not save screenshot: %s" % output_path)
		return false
	var snapshot := Dictionary(_game.state.snapshot())
	_capture_rows.append({
		"name": name,
		"description": description,
		"file": "%s.png" % name,
		"phase": String(snapshot.get("phase", "")),
		"coins": int(snapshot.get("coins", 0)),
		"offer_count": Array(snapshot.get("shop_offers", [])).size(),
		"roster_count": Array(snapshot.get("roster", [])).size(),
	})
	return true


func _assert_ready_shop() -> bool:
	var view := _shop_view()
	if view == null or not view.visible:
		_fail("The formal shop view is not visible.")
		return false
	var offers := Array(_game.state.snapshot().get("shop_offers", []))
	if offers.size() != EXPECTED_OFFER_COUNT:
		_fail("Expected %d formal offers, got %d." % [EXPECTED_OFFER_COUNT, offers.size()])
		return false
	return true


func _shop_view() -> Control:
	return _game.find_child("LegacyCodeShopView", true, false) as Control


func _find_command_button(parent: Node, command_type: String) -> BaseButton:
	if parent == null:
		return null
	for node in parent.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null or button.disabled:
			continue
		if String(Dictionary(button.get_meta("command", {})).get("type", "")) == command_type:
			return button
	return null


func _settle() -> void:
	await _settle_frames(SETTLE_FRAMES)


func _settle_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _is_black(image: Image) -> bool:
	if image == null or image.is_empty():
		return true
	var samples := [
		Vector2i(image.get_width() / 4, image.get_height() / 4),
		Vector2i(image.get_width() / 2, image.get_height() / 2),
		Vector2i(image.get_width() * 3 / 4, image.get_height() * 3 / 4),
	]
	for point in samples:
		var color := image.get_pixelv(point)
		if color.r + color.g + color.b > 0.05:
			return false
	return true


func _fail(message: String) -> void:
	push_error("CAPTURE_SHOP_ART_COMPARISON_FAIL: %s" % message)
	quit(1)
