@tool
extends Control
class_name BattleMapControls

signal settings_requested
signal attack_order_requested
signal bag_requested
signal auto_arrange_requested
signal reset_requested
signal speed_toggled(active: bool)
signal all_out_requested

const MAP_IDS := [
	"lowland_evening",
	"grassland_evening",
	"grassland_morning",
	"pond_evening",
	"pond_morning",
	"mountain_evening",
	"mountain_morning",
	"lowland_morning",
]
const MAP_TEXTURES := [
	preload("res://art/images/battle/map_controls/maps/lowland_evening.png"),
	preload("res://art/images/battle/map_controls/maps/grassland_evening.png"),
	preload("res://art/images/battle/map_controls/maps/grassland_morning.png"),
	preload("res://art/images/battle/map_controls/maps/pond_evening.png"),
	preload("res://art/images/battle/map_controls/maps/pond_morning.png"),
	preload("res://art/images/battle/map_controls/maps/mountain_evening.png"),
	preload("res://art/images/battle/map_controls/maps/mountain_morning.png"),
	preload("res://art/images/battle/map_controls/maps/lowland_morning.png"),
]
const SPEED_NORMAL_TEXTURE := preload(
	"res://art/images/battle/map_controls/buttons/speed_normal.png"
)
const SPEED_ACTIVE_TEXTURE := preload(
	"res://art/images/battle/map_controls/buttons/speed_active.png"
)
const PRESS_SCALE := Vector2(0.92, 0.92)
const PRESS_DURATION_SECONDS := 0.06
const RELEASE_DURATION_SECONDS := 0.08
const SHORTCUT_BUTTON_PATHS := {
	KEY_A: ^"AutoArrangeButton",
	KEY_R: ^"ResetButton",
	KEY_D: ^"SpeedButton",
	KEY_TAB: ^"AttackOrderButton",
	KEY_B: ^"BagButton",
	KEY_ESCAPE: ^"SettingsButton",
	KEY_SPACE: ^"AllOutButton",
}

@export var speed_active := false:
	set(value):
		speed_active = value
		_apply_speed_state()

@onready var settings_button: TextureButton = $SettingsButton
@onready var auto_arrange_button: TextureButton = $AutoArrangeButton
@onready var reset_button: TextureButton = $ResetButton
@onready var speed_button: TextureButton = $SpeedButton
@onready var attack_order_button: TextureButton = $AttackOrderButton
@onready var bag_button: TextureButton = $BagButton
@onready var all_out_button: TextureButton = $AllOutButton

var _button_tweens: Dictionary = {}
var _held_shortcut_buttons: Dictionary = {}
var _map_index := 2


func _ready() -> void:
	_apply_speed_state()
	if Engine.is_editor_hint():
		return
	_connect_button(settings_button, _on_settings_pressed)
	_connect_button(auto_arrange_button, _on_auto_arrange_pressed)
	_connect_button(reset_button, _on_reset_pressed)
	_connect_button(attack_order_button, _on_attack_order_pressed)
	_connect_button(bag_button, _on_bag_pressed)
	_connect_button(all_out_button, _on_all_out_pressed)
	_connect_button(speed_button, Callable())
	speed_button.toggled.connect(_on_speed_button_toggled)


func set_map_by_index(index: int) -> bool:
	if index < 0 or index >= MAP_TEXTURES.size():
		return false
	_map_index = index
	return true


func set_map_by_id(map_id: String) -> bool:
	var index := MAP_IDS.find(map_id.strip_edges().to_lower())
	return set_map_by_index(index)


func get_map_id() -> String:
	return String(MAP_IDS[_map_index])


func get_map_ids() -> PackedStringArray:
	return PackedStringArray(MAP_IDS)


func get_map_index() -> int:
	return _map_index


func get_map_texture() -> Texture2D:
	return MAP_TEXTURES[_map_index] as Texture2D


func get_map_display_name() -> String:
	return {
		"lowland_evening": "洼地（晚）",
		"grassland_evening": "草原（晚）",
		"grassland_morning": "草原（早）",
		"pond_evening": "池塘（晚）",
		"pond_morning": "池塘（早）",
		"mountain_evening": "山脉（晚）",
		"mountain_morning": "山脉（早）",
		"lowland_morning": "洼地（早）",
	}.get(get_map_id(), get_map_id())


func set_speed_active(active: bool) -> void:
	speed_active = active


func get_keyboard_shortcuts() -> Dictionary:
	return {
		"A": "AutoArrangeButton",
		"R": "ResetButton",
		"D": "SpeedButton",
		"Tab": "AttackOrderButton",
		"B": "BagButton",
		"Escape": "SettingsButton",
		"Space": "AllOutButton",
	}


func set_shortcut_hints_visible(hints_visible: bool) -> void:
	var hints := get_node_or_null("ShortcutHints") as TextureRect
	if hints != null:
		hints.visible = hints_visible


func are_shortcut_hints_visible() -> bool:
	var hints := get_node_or_null("ShortcutHints") as TextureRect
	return hints != null and hints.visible


func toggle_shortcut_hints() -> bool:
	var next_visible := not are_shortcut_hints_visible()
	set_shortcut_hints_visible(next_visible)
	return next_visible


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	var keycode := key_event.keycode
	var physical_keycode := key_event.physical_keycode
	if keycode == KEY_NONE:
		keycode = physical_keycode
	var button := _get_shortcut_button(keycode)
	if button == null and physical_keycode != KEY_NONE and physical_keycode != keycode:
		button = _get_shortcut_button(physical_keycode)
		if button != null:
			keycode = physical_keycode
	if button == null or button.disabled:
		return
	if key_event.pressed:
		if key_event.echo or _held_shortcut_buttons.has(keycode):
			return
		_held_shortcut_buttons[keycode] = button
		button.button_down.emit()
	else:
		if not _held_shortcut_buttons.has(keycode):
			return
		button = _held_shortcut_buttons[keycode] as TextureButton
		_held_shortcut_buttons.erase(keycode)
		button.button_up.emit()
		_activate_shortcut_button(button)
	get_viewport().set_input_as_handled()


func _get_shortcut_button(keycode: int) -> TextureButton:
	var path := SHORTCUT_BUTTON_PATHS.get(keycode, NodePath()) as NodePath
	if path.is_empty():
		return null
	return get_node_or_null(path) as TextureButton


func _activate_shortcut_button(button: TextureButton) -> void:
	if button == speed_button:
		var active := not button.button_pressed
		button.set_pressed_no_signal(active)
		button.toggled.emit(active)
	else:
		button.pressed.emit()


func _apply_speed_state() -> void:
	var button := get_node_or_null("SpeedButton") as TextureButton
	if button == null:
		return
	button.set_pressed_no_signal(speed_active)
	button.texture_normal = SPEED_ACTIVE_TEXTURE if speed_active else SPEED_NORMAL_TEXTURE
	button.set_meta("speed_active", speed_active)


func _connect_button(button: TextureButton, callback: Callable) -> void:
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))
	if callback.is_valid():
		button.pressed.connect(callback)


func _on_speed_button_toggled(active: bool) -> void:
	speed_active = active
	speed_toggled.emit(active)


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_auto_arrange_pressed() -> void:
	auto_arrange_requested.emit()


func _on_reset_pressed() -> void:
	reset_requested.emit()


func _on_attack_order_pressed() -> void:
	attack_order_requested.emit()


func _on_bag_pressed() -> void:
	bag_requested.emit()


func _on_all_out_pressed() -> void:
	all_out_requested.emit()


func _on_button_down(button: TextureButton) -> void:
	if button == reset_button:
		_set_button_scale_immediate(button, PRESS_SCALE)
		return
	_tween_button_scale(button, PRESS_SCALE, PRESS_DURATION_SECONDS)


func _on_button_up(button: TextureButton) -> void:
	_tween_button_scale(button, Vector2.ONE, RELEASE_DURATION_SECONDS)


func _set_button_scale_immediate(button: TextureButton, target: Vector2) -> void:
	var existing := _button_tweens.get(button) as Tween
	if existing != null and existing.is_valid():
		existing.kill()
	button.scale = target
	_button_tweens.erase(button)


func _tween_button_scale(button: TextureButton, target: Vector2, duration: float) -> void:
	var existing := _button_tweens.get(button) as Tween
	if existing != null and existing.is_valid():
		existing.kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target, duration)
	_button_tweens[button] = tween
