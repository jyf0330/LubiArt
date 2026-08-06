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
	_prefab.position = Vector2.ZERO
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

	await _capture_shortcut("keyboard_01_auto_arrange", KEY_A, _prefab.get_node("AutoArrangeButton") as TextureButton, "auto_arrange")
	await _capture_shortcut("keyboard_02_reset", KEY_R, _prefab.get_node("ResetButton") as TextureButton, "reset")
	await _capture_shortcut("keyboard_03_settings", KEY_ESCAPE, _prefab.get_node("SettingsButton") as TextureButton, "settings")
	await _capture_shortcut("keyboard_04_all_out", KEY_SPACE, _prefab.get_node("AllOutButton") as TextureButton, "all_out")
	await _capture_speed_shortcut()
	await _capture_shortcut("keyboard_06_attack_order", KEY_TAB, _prefab.get_node("AttackOrderButton") as TextureButton, "attack_order")
	await _capture_shortcut("keyboard_07_bag", KEY_B, _prefab.get_node("BagButton") as TextureButton, "bag")

	var file := FileAccess.open(OUTPUT_DIR.path_join("shortcut_operations.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"operations": _operations,
		"signal_counts": _counts,
	}, "\t") + "\n")
	file.close()
	print("BATTLE_MAP_CONTROLS_SHORTCUT_VISIBLE_PASS")
	quit(0)


func _capture_shortcut(name: String, keycode: int, button: TextureButton, counter: String) -> void:
	var start_file := "%s_start.png" % name
	var pressed_file := "%s_pressed.png" % name
	var after_file := "%s_after.png" % name
	var before_count := int(_counts[counter])
	await _capture(start_file)
	_dispatch_key(keycode, true)
	await create_timer(0.09).timeout
	await _capture(pressed_file)
	assert(button.scale.is_equal_approx(Vector2(0.92, 0.92)))
	_dispatch_key(keycode, false)
	await create_timer(0.12).timeout
	await _capture(after_file)
	assert(button.scale.is_equal_approx(Vector2.ONE))
	assert(int(_counts[counter]) == before_count + 1)
	_operations.append({"name": name, "before": start_file, "after": after_file})


func _capture_speed_shortcut() -> void:
	var button := _prefab.get_node("SpeedButton") as TextureButton
	var before_count := int(_counts.speed)
	await _capture("keyboard_05_speed_start.png")
	_dispatch_key(KEY_D, true)
	await create_timer(0.09).timeout
	await _capture("keyboard_05_speed_pressed.png")
	assert(button.scale.is_equal_approx(Vector2(0.92, 0.92)))
	_dispatch_key(KEY_D, false)
	await create_timer(0.12).timeout
	assert(button.button_pressed)
	assert(button.texture_normal.resource_path.get_file() == "speed_active.png")
	await _capture("keyboard_05_speed_active.png")
	_dispatch_key(KEY_D, true)
	await create_timer(0.09).timeout
	_dispatch_key(KEY_D, false)
	await create_timer(0.12).timeout
	assert(not button.button_pressed)
	assert(button.texture_normal.resource_path.get_file() == "speed_normal.png")
	assert(int(_counts.speed) == before_count + 2)
	await _capture("keyboard_05_speed_after.png")
	_operations.append({
		"name": "keyboard_05_speed_toggle_round_trip",
		"before": "keyboard_05_speed_start.png",
		"after": "keyboard_05_speed_after.png",
	})


func _dispatch_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	_prefab._unhandled_key_input(event)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	assert(image.save_png(OUTPUT_DIR.path_join(file_name)) == OK)


func _increment(counter: String) -> void:
	_counts[counter] = int(_counts[counter]) + 1


func _on_speed_toggled(_active: bool) -> void:
	_increment("speed")
