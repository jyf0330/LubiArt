extends SceneTree

const PREFAB := preload("res://art/prefabs/battle/hud/battle_map_controls.tscn")
const OUTPUT_DIR := "res://output/validation/battle_map_controls"

var _prefab: Control
var _counts := {
	"auto_arrange": 0,
	"reset": 0,
	"settings": 0,
	"attack_order": 0,
	"bag": 0,
	"all_out": 0,
	"speed": 0,
}
var _operations: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var background := TextureRect.new()
	background.size = Vector2(1920.0, 1080.0)
	background.texture = preload("res://art/images/battle/map_controls/maps/grassland_morning.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(background)
	_prefab = PREFAB.instantiate() as Control
	_prefab.position = Vector2(1621.0, 295.0)
	root.add_child(_prefab)
	_prefab.auto_arrange_requested.connect(_increment.bind("auto_arrange"))
	_prefab.reset_requested.connect(_increment.bind("reset"))
	_prefab.settings_requested.connect(_increment.bind("settings"))
	_prefab.attack_order_requested.connect(_increment.bind("attack_order"))
	_prefab.bag_requested.connect(_increment.bind("bag"))
	_prefab.all_out_requested.connect(_increment.bind("all_out"))
	_prefab.speed_toggled.connect(_on_speed_toggled)
	await process_frame
	await process_frame

	await _capture_click_operation(
		"01_auto_arrange",
		_prefab.get_node("AutoArrangeButton") as TextureButton,
		"auto_arrange"
	)
	await _capture_click_operation(
		"02_reset",
		_prefab.get_node("ResetButton") as TextureButton,
		"reset"
	)
	await _capture_click_operation(
		"03_settings",
		_prefab.get_node("SettingsButton") as TextureButton,
		"settings"
	)
	await _capture_click_operation(
		"04_all_out",
		_prefab.get_node("AllOutButton") as TextureButton,
		"all_out"
	)
	await _capture_speed_operation()
	await _capture_click_operation(
		"06_attack_order",
		_prefab.get_node("AttackOrderButton") as TextureButton,
		"attack_order"
	)
	await _capture_click_operation(
		"07_bag",
		_prefab.get_node("BagButton") as TextureButton,
		"bag"
	)
	await _capture_shortcut_hint_toggle()

	var manifest_path := OUTPUT_DIR.path_join("operations.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"operations": _operations,
		"signal_counts": _counts,
	}, "\t") + "\n")
	file.close()
	print("BATTLE_MAP_CONTROLS_VISIBLE_PASS")
	quit(0)


func _capture_click_operation(name: String, button: TextureButton, counter: String) -> void:
	var before_count := int(_counts[counter])
	var before_file := "%s_before.png" % name
	var pressed_file := "%s_pressed.png" % name
	var after_file := "%s_after.png" % name
	await _capture(before_file)
	await _press(button)
	await _capture(pressed_file)
	assert(button.scale.is_equal_approx(Vector2(0.92, 0.92)))
	await _release(button)
	await _capture(after_file)
	_operations.append({"name": name, "before": before_file, "after": after_file})
	assert(int(_counts[counter]) == before_count + 1)
	assert(button.scale.is_equal_approx(Vector2.ONE))


func _capture_speed_operation() -> void:
	var button := _prefab.get_node("SpeedButton") as TextureButton
	var before_count := int(_counts.speed)
	await _capture("05_speed_before.png")
	await _press(button)
	await _capture("05_speed_pressed.png")
	assert(button.scale.is_equal_approx(Vector2(0.92, 0.92)))
	await _release(button)
	assert(button.button_pressed)
	assert(button.texture_normal.resource_path.get_file() == "speed_active.png")
	await _capture("05_speed_active.png")
	await _press(button)
	await _release(button)
	assert(not button.button_pressed)
	assert(button.texture_normal.resource_path.get_file() == "speed_normal.png")
	assert(int(_counts.speed) == before_count + 2)
	await _capture("05_speed_after.png")
	_operations.append({
		"name": "05_speed_toggle_round_trip",
		"before": "05_speed_before.png",
		"after": "05_speed_after.png",
	})


func _capture_shortcut_hint_toggle() -> void:
	await _capture("08_shortcut_hints_before.png")
	_prefab.call("set_shortcut_hints_visible", false)
	assert(not bool(_prefab.call("are_shortcut_hints_visible")))
	await _capture("08_shortcut_hints_hidden.png")
	_prefab.call("set_shortcut_hints_visible", true)
	assert(bool(_prefab.call("are_shortcut_hints_visible")))
	await _capture("08_shortcut_hints_after.png")
	_operations.append({
		"name": "08_shortcut_hints_round_trip",
		"before": "08_shortcut_hints_before.png",
		"after": "08_shortcut_hints_after.png",
	})


func _press(button: TextureButton) -> void:
	button.button_down.emit()
	await create_timer(0.09).timeout


func _release(button: TextureButton) -> void:
	button.button_up.emit()
	if button.toggle_mode:
		var active := not button.button_pressed
		button.set_pressed_no_signal(active)
		button.toggled.emit(active)
	else:
		button.pressed.emit()
	await create_timer(0.12).timeout


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	assert(image.save_png(OUTPUT_DIR.path_join(file_name)) == OK)


func _increment(counter: String) -> void:
	_counts[counter] = int(_counts[counter]) + 1


func _on_speed_toggled(_active: bool) -> void:
	_increment("speed")
