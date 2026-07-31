extends SceneTree

const MainScene := preload("res://art/scenes/three_choice/three_choice_scene.tscn")


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
		"MainBG/Containers/Middle/Middle_Three_Option/CardGrid/Three_Option_Slot2/Three_Button"
	) as TextureButton
	if second_button != null:
		second_button.mouse_entered.emit()
		for _frame in range(4):
			await process_frame
		_save_capture("/private/tmp/lubi_three_choice_hover.png")

	var bag_button := main_instance.get_node_or_null("MainBG/Containers/Bags/Bag_Button") as TextureButton
	if bag_button != null:
		bag_button.pressed.emit()
		for _frame in range(20):
			await process_frame
		_save_capture("/private/tmp/lubi_three_choice_bag.png")

	var party_button := main_instance.get_node_or_null(
		"MainBG/Containers/Party/Party_Container/Party_Slot/PareyButton"
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

	print("VISIBLE_THREE_CHOICE_CAPTURE_PASS /private/tmp/lubi_three_choice_current.png")
	quit()


func _save_capture(path: String) -> void:
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(path)
