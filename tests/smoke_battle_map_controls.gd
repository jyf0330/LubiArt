extends SceneTree

const PREFAB := preload("res://art/prefabs/battle/hud/battle_map_controls.tscn")
const EXPECTED_MAP_IDS := [
	"lowland_evening",
	"grassland_evening",
	"grassland_morning",
	"pond_evening",
	"pond_morning",
	"mountain_evening",
	"mountain_morning",
	"lowland_morning",
]
const EXPECTED_BUTTON_RECTS := {
	"AutoArrangeButton": Rect2(220.0, 0.0, 66.0, 62.0),
	"ResetButton": Rect2(221.0, 82.0, 66.0, 62.0),
	"SpeedButton": Rect2(221.0, 164.0, 65.0, 62.0),
	"SettingsButton": Rect2(222.0, 246.0, 65.0, 62.0),
	"AttackOrderButton": Rect2(222.0, 328.0, 65.0, 62.0),
	"BagButton": Rect2(221.0, 410.0, 66.0, 62.0),
	"AllOutButton": Rect2(14.0, 688.0, 272.0, 64.0),
}
const EXPECTED_SHORTCUTS := {
	"A": "AutoArrangeButton",
	"R": "ResetButton",
	"D": "SpeedButton",
	"Escape": "SettingsButton",
	"Tab": "AttackOrderButton",
	"B": "BagButton",
	"Space": "AllOutButton",
}

var _attack_order_count := 0
var _bag_count := 0
var _reset_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var prefab := PREFAB.instantiate() as Control
	root.add_child(prefab)
	await process_frame
	assert(prefab.scene_file_path == "res://art/prefabs/battle/hud/battle_map_controls.tscn")
	assert(prefab.custom_minimum_size == Vector2(287.0, 752.0))
	assert(prefab.size == Vector2(287.0, 752.0))
	assert(Array(prefab.call("get_map_ids")) == EXPECTED_MAP_IDS)
	assert(prefab.call("get_keyboard_shortcuts") == EXPECTED_SHORTCUTS)
	assert(prefab.get_node_or_null("MapBackground") == null)
	for index in range(EXPECTED_MAP_IDS.size()):
		assert(bool(prefab.call("set_map_by_index", index)))
		var map_texture := prefab.call("get_map_texture") as Texture2D
		assert(map_texture != null)
		assert(map_texture.get_size() == Vector2(1920.0, 1080.0))
		assert(String(prefab.call("get_map_id")) == EXPECTED_MAP_IDS[index])
	for node_name in EXPECTED_BUTTON_RECTS:
		var button := prefab.get_node(node_name) as TextureButton
		assert(button != null)
		assert(Rect2(button.position, button.size) == EXPECTED_BUTTON_RECTS[node_name])
		assert(button.texture_normal != null)
	var hints := prefab.get_node("ShortcutHints") as TextureRect
	assert(hints != null)
	assert(Rect2(hints.position, hints.size) == Rect2(0.0, 34.0, 259.0, 716.0))
	assert(hints.texture != null)
	assert(bool(prefab.call("are_shortcut_hints_visible")))
	assert(not bool(prefab.call("toggle_shortcut_hints")))
	assert(not hints.visible)
	prefab.call("set_shortcut_hints_visible", true)
	assert(hints.visible)
	for node_name in EXPECTED_BUTTON_RECTS:
		var button := prefab.get_node(node_name) as TextureButton
		prefab.call("_on_button_down", button)
		if node_name == "ResetButton":
			assert(button.scale.is_equal_approx(Vector2(0.92, 0.92)))
		else:
			var press_tween := (prefab.get("_button_tweens") as Dictionary).get(button) as Tween
			press_tween.custom_step(0.1)
			assert(button.scale.is_equal_approx(Vector2(0.92, 0.92)))
		prefab.call("_on_button_up", button)
		var release_tween := (prefab.get("_button_tweens") as Dictionary).get(button) as Tween
		release_tween.custom_step(0.12)
		assert(button.scale.is_equal_approx(Vector2.ONE))
	prefab.attack_order_requested.connect(_on_attack_order_requested)
	prefab.bag_requested.connect(_on_bag_requested)
	prefab.reset_requested.connect(_on_reset_requested)
	(prefab.get_node("AttackOrderButton") as TextureButton).pressed.emit()
	(prefab.get_node("BagButton") as TextureButton).pressed.emit()
	assert(_attack_order_count == 1)
	assert(_bag_count == 1)
	var physical_r_down := InputEventKey.new()
	physical_r_down.keycode = KEY_NONE
	physical_r_down.physical_keycode = KEY_R
	physical_r_down.pressed = true
	prefab._unhandled_key_input(physical_r_down)
	assert((prefab.get_node("ResetButton") as TextureButton).scale.is_equal_approx(Vector2(0.92, 0.92)))
	var physical_r_up := InputEventKey.new()
	physical_r_up.keycode = KEY_NONE
	physical_r_up.physical_keycode = KEY_R
	physical_r_up.pressed = false
	prefab._unhandled_key_input(physical_r_up)
	var reset_release_tween := (prefab.get("_button_tweens") as Dictionary).get(prefab.get_node("ResetButton")) as Tween
	reset_release_tween.custom_step(0.12)
	assert((prefab.get_node("ResetButton") as TextureButton).scale.is_equal_approx(Vector2.ONE))
	assert(_reset_count == 1)
	var speed_button := prefab.get_node("SpeedButton") as TextureButton
	prefab.call("set_speed_active", true)
	assert(speed_button.button_pressed)
	assert(bool(speed_button.get_meta("speed_active")))
	assert(speed_button.texture_normal.resource_path.get_file() == "speed_active.png")
	prefab.call("set_speed_active", false)
	assert(not speed_button.button_pressed)
	assert(speed_button.texture_normal.resource_path.get_file() == "speed_normal.png")
	assert(not bool(prefab.call("set_map_by_index", 8)))
	assert(not bool(prefab.call("set_map_by_id", "missing")))
	print("BATTLE_MAP_CONTROLS_SMOKE_PASS")
	quit(0)


func _on_attack_order_requested() -> void:
	_attack_order_count += 1


func _on_bag_requested() -> void:
	_bag_count += 1


func _on_reset_requested() -> void:
	_reset_count += 1
