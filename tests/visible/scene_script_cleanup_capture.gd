extends SceneTree

const MAIN_SCENE := preload("res://art/scenes/app/game.tscn")
const TESTED_SCENE_PATH := "res://art/scenes/app/game.tscn"

var _capture_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_capture_dir = OS.get_environment("UI_CAPTURE_DIR").strip_edges()
	var actual_root := ProjectSettings.globalize_path("res://").trim_suffix("/").simplify_path()
	var expected_root := OS.get_environment("EXPECTED_PROJECT_ROOT").trim_suffix("/").simplify_path()
	if _capture_dir == "" or expected_root == "" or actual_root != expected_root:
		_fail("invalid capture directory or project root: actual=%s expected=%s" % [actual_root, expected_root])
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	_write_provenance(actual_root, expected_root)

	var game := MAIN_SCENE.instantiate() as Control
	root.add_child(game)
	await _settle(36)
	var route := game.call("get_three_choice_view") as Control
	var route_button := route.get_node("MainBG/Containers/Middle/Middle_Three_Option/CardGrid/Three_Option_Slot/Three_Button") as TextureButton
	route_button.mouse_entered.emit()
	await _settle(8)
	await _capture("01_route_card_hover.png")
	route_button.mouse_exited.emit()
	await _settle(8)
	await _capture("02_route_card_hover_exit.png")

	route_button.pressed.emit()
	await process_frame
	var route_exit := route.get_node("RouteSharedUi/ExitButton") as TextureButton
	route_exit.pressed.emit()
	await _settle(36)
	var shop := game.call("get_active_feature_view") as Control
	if shop == null or shop.name != "ShopScene":
		_fail("dedicated ShopScene did not mount")
		return
	await _capture("03_enter_shop.png")
	(shop.get_node("Offers/Offer01") as Button).grab_focus()
	await _settle(8)
	await _capture("04_shop_slot_focus.png")

	var refresh := shop.get_node("RefreshButton") as TextureButton
	refresh.pressed.emit()
	await _settle(12)
	await _capture("05_shop_refresh_curtain.png")
	await create_timer(0.5).timeout
	await _capture("06_shop_refresh_complete.png")

	var bag_button := shop.get_node("RouteSharedUi/Bags/Bag_Button") as TextureButton
	bag_button.pressed.emit()
	await _settle(16)
	await _capture("07_bag_open.png")
	var first_bag_slot := shop.get_node("RouteSharedUi/Middle_Bag/Slots/Bag_Slot") as TextureButton
	first_bag_slot.grab_focus()
	await _settle(8)
	await _capture("08_bag_slot_focus.png")
	bag_button.pressed.emit()
	await _settle(12)
	await _capture("09_bag_closed.png")
	var first_party_slot := shop.get_node("RouteSharedUi/Party/Party_Container/Party_Slot") as TextureButton
	first_party_slot.grab_focus()
	await _settle(8)
	await _capture("10_party_focus.png")
	var shop_exit := shop.get_node("RouteSharedUi/ExitButton") as TextureButton
	shop_exit.grab_focus()
	await _settle(8)
	await _capture("11_exit_focus.png")

	print("SCENE_SCRIPT_CLEANUP_VISIBLE_CAPTURE_PASS: %s" % _capture_dir)
	quit(0)


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(_capture_dir.path_join(file_name))
	if error != OK:
		_fail("%s: %s" % [file_name, error_string(error)])


func _write_provenance(actual_root: String, expected_root: String) -> void:
	var file := FileAccess.open(_capture_dir.path_join("run_provenance.json"), FileAccess.WRITE)
	if file == null:
		_fail("could not write run provenance")
		return
	file.store_string(JSON.stringify({
		"project_root": actual_root,
		"expected_project_root": expected_root,
		"project_file": actual_root.path_join("project.godot"),
		"tested_scene": TESTED_SCENE_PATH,
		"capture_script": "res://tests/visible/scene_script_cleanup_capture.gd",
	}, "\t"))


func _fail(message: String) -> void:
	push_error("SCENE_SCRIPT_CLEANUP_VISIBLE_CAPTURE_FAIL: %s" % message)
	quit(1)
