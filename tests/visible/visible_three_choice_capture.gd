extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var main_instance := MainScene.instantiate()
	root.add_child(main_instance)
	for _frame in range(12):
		await process_frame
	_save_capture("/private/tmp/lubi_three_choice_current.png")

	var second_button := main_instance.get_node_or_null(
		"ThreeChoiceScene/MainBG/Containers/Middle/Middle_Three_Option/CardGrid/Three_Option_Slot2/Three_Button"
	) as TextureButton
	if second_button != null:
		second_button.mouse_entered.emit()
		for _frame in range(4):
			await process_frame
		_save_capture("/private/tmp/lubi_three_choice_hover.png")
		second_button.mouse_exited.emit()
		for _frame in range(4):
			await process_frame

	var bag_button := main_instance.get_node_or_null("ThreeChoiceScene/RouteSharedUi/Bags/Bag_Button") as TextureButton
	if bag_button != null:
		bag_button.pressed.emit()
		for _frame in range(20):
			await process_frame
		_save_capture("/private/tmp/lubi_three_choice_bag.png")

	var party_button := main_instance.get_node_or_null(
		"ThreeChoiceScene/RouteSharedUi/Party/Party_Container/Party_Slot"
	) as TextureButton
	if party_button != null:
		if bag_button != null:
			bag_button.pressed.emit()
			for _frame in range(20):
				await process_frame
		party_button.mouse_entered.emit()
		for _frame in range(8):
			await process_frame
		_save_capture("/private/tmp/lubi_three_choice_pet_hover.png")
		party_button.mouse_exited.emit()
		for _frame in range(4):
			await process_frame
		_save_capture("/private/tmp/lubi_three_choice_pet_exit.png")

	var first_button := main_instance.get_node_or_null(
		"ThreeChoiceScene/MainBG/Containers/Middle/Middle_Three_Option/CardGrid/Three_Option_Slot/Three_Button"
	) as TextureButton
	var exit_button := main_instance.get_node_or_null("ThreeChoiceScene/RouteSharedUi/ExitButton") as TextureButton
	if first_button != null and exit_button != null:
		first_button.pressed.emit()
		exit_button.mouse_entered.emit()
		for _frame in range(8):
			await process_frame
		_save_capture("/private/tmp/lubi_three_choice_exit_hover.png")

	print("VISIBLE_THREE_CHOICE_CAPTURE_PASS /private/tmp/lubi_three_choice_current.png")
	quit()


func _save_capture(path: String) -> void:
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(path)
