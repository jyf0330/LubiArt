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
	var route_button := view.get_node(
		"MainBG/Containers/Middle/Middle_Three_Option/CardGrid/Three_Option_Slot/Three_Button"
	) as TextureButton
	route_button.mouse_entered.emit()
	await _settle(8)
	await _capture("01_route_card_hover.png")

	route_button.mouse_exited.emit()
	await _settle(8)
	await _capture("02_route_card_hover_exit.png")

	var bag_button := view.get_node("MainBG/Containers/Bags/Bag_Button") as TextureButton
	bag_button.pressed.emit()
	await _settle(SETTLE_FRAMES)
	await _capture("03_open_bag.png")

	var bag_slot_button := view.get_node(
		"MainBG/Containers/Middle/Middle_Bag/Slots/Bag_Slot/Bag_Button"
	) as TextureButton
	bag_slot_button.mouse_entered.emit()
	await _settle(8)
	await _capture("04_bag_slot_hover.png")

	bag_slot_button.mouse_exited.emit()
	await _settle(8)
	await _capture("05_bag_slot_hover_exit.png")

	bag_button.pressed.emit()
	await _settle(SETTLE_FRAMES)
	await _capture("06_close_bag.png")

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


func _fail(message: String) -> void:
	push_error("SCENE_SCRIPT_CLEANUP_VISIBLE_CAPTURE_FAIL: %s" % message)
	quit(1)
