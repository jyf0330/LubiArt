@tool
extends Control
class_name BattleMapControls

const ShortcutCatalog := preload("res://core_ui/scripts/shared/shortcut_catalog.gd")

signal settings_requested
signal attack_order_requested
signal bag_requested
signal auto_arrange_requested
signal reset_requested
signal speed_toggled(active: bool)
signal all_out_requested
signal shortcut_blocked(shortcut: String, button_name: String)

const MAP_IDS := [
	"lowland_evening",
	"grassland_evening",
	"grassland_morning",
	"pond_evening",
	"pond_morning",
	"mountain_evening",
	"mountain_morning",
	"lowland_morning",
	"forest_spring",
	"forest_autumn",
	"mountain_new",
]
const MAP_TEXTURES := [
	preload("res://art/images/battle/map_controls/maps/lowland_evening.png"),
	preload("res://art/images/battle/map_controls/maps/grassland_evening.png"),
	preload("res://art/images/battle/map_controls/maps/forest_clearing_trial.png"),
	preload("res://art/images/battle/map_controls/maps/pond_evening.png"),
	preload("res://art/images/battle/map_controls/maps/pond_morning.png"),
	preload("res://art/images/battle/map_controls/maps/mountain_evening.png"),
	preload("res://art/images/battle/map_controls/maps/mountain_morning.png"),
	preload("res://art/images/battle/map_controls/maps/lowland_morning.png"),
	preload("res://art/images/battle/map_controls/maps/forest_spring.png"),
	preload("res://art/images/battle/map_controls/maps/forest_autumn.png"),
	preload("res://art/images/battle/map_controls/maps/mountain_new.png"),
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
const RESET_WAITING_MODULATE := Color(0.46, 0.46, 0.46, 1.0)
const RESET_MIN_PRESS_VISIBLE_SECONDS := 0.10
const SHORTCUT_MIN_PRESS_VISIBLE_SECONDS := 0.10
const ALL_OUT_IDLE_PROMPT_DELAY_SECONDS := 3.0
const ALL_OUT_HIGHLIGHT_DURATION_SECONDS := 1.15
const ALL_OUT_HIGHLIGHT_PROGRESS := &"sweep_progress"
const SHORTCUT_BUTTON_ACTIONS := ShortcutCatalog.BATTLE_BUTTON_ACTIONS

@export var speed_active := false:
	set(value):
		speed_active = value
		_apply_speed_state()

@onready var settings_button: TextureButton = $SettingsButton
@onready var auto_arrange_button: TextureButton = $AutoArrangeButton
@onready var reset_button: TextureButton = $ResetButton
@onready var reset_cooldown_label: Label = $ResetButton/ResetCooldownLabel
@onready var speed_button: TextureButton = $SpeedButton
@onready var attack_order_button: TextureButton = $AttackOrderButton
@onready var bag_button: TextureButton = $BagButton
@onready var all_out_button: TextureButton = $AllOutButton

var _button_tweens: Dictionary = {}
var _held_shortcut_buttons: Dictionary = {}
var _shortcut_pressed_at_seconds: Dictionary = {}
var _map_index := 10
var _reset_pressed_at_seconds := -1.0
var _last_player_activity_msec := 0
var _next_all_out_prompt_msec := 0
var _all_out_idle_prompt_played := false
var _all_out_highlight_tween: Tween = null


func _ready() -> void:
	_apply_speed_state()
	if Engine.is_editor_hint():
		return
	_mark_player_activity()
	_connect_button(settings_button, _on_settings_pressed)
	_connect_button(auto_arrange_button, _on_auto_arrange_pressed)
	_connect_button(reset_button, _on_reset_pressed)
	_connect_button(attack_order_button, _on_attack_order_pressed)
	_connect_button(bag_button, _on_bag_pressed)
	_connect_button(all_out_button, _on_all_out_pressed)
	_connect_button(speed_button, Callable())
	speed_button.toggled.connect(_on_speed_button_toggled)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _can_show_all_out_idle_prompt():
		_mark_player_activity()
		return
	if _all_out_highlight_tween != null and _all_out_highlight_tween.is_valid():
		return
	if Time.get_ticks_msec() >= _next_all_out_prompt_msec:
		_play_all_out_idle_prompt()


func _input(event: InputEvent) -> void:
	if _is_player_activity(event):
		_mark_player_activity()


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
		"forest_spring": "森林（春）",
		"forest_autumn": "森林（秋）",
		"mountain_new": "山脉",
	}.get(get_map_id(), get_map_id())


func set_speed_active(active: bool) -> void:
	speed_active = active


func set_reset_charge_state(charges: int, rounds_until_next_charge: int) -> void:
	var available_charges := maxi(0, charges)
	var remaining := maxi(0, rounds_until_next_charge)
	var waiting_for_charge := available_charges == 0
	reset_cooldown_label.visible = available_charges != 1
	if waiting_for_charge:
		reset_cooldown_label.text = str(remaining)
		reset_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reset_cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		reset_cooldown_label.text = "×%d" % available_charges if available_charges > 1 else ""
		reset_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		reset_cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	reset_button.self_modulate = RESET_WAITING_MODULATE if waiting_for_charge else Color.WHITE
	reset_button.set_meta("charges", available_charges)
	reset_button.set_meta("cooldown_remaining", remaining)
	reset_button.set_meta("rounds_until_next_charge", remaining)
	reset_button.set_meta("cooling_down", false)
	reset_button.set_meta("waiting_for_charge", waiting_for_charge)


func set_reset_cooldown_state(charges: int, cooldown_remaining: int) -> void:
	# Compatibility for snapshots exported before the recurring-charge field rename.
	set_reset_charge_state(charges, cooldown_remaining)


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
	if handle_shortcut_input(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and handle_shortcut_input(event):
		get_viewport().set_input_as_handled()


func handle_shortcut_input(event: InputEvent, activate_button := true) -> bool:
	if not event is InputEventKey and not event is InputEventMouseButton:
		return false
	var action_id := ShortcutCatalog.action_for_event(event, SHORTCUT_BUTTON_ACTIONS.keys())
	var button := _get_shortcut_button(action_id)
	if button == null:
		return false
	_mark_player_activity()
	var pressed := (
		(event as InputEventKey).pressed
		if event is InputEventKey
		else (event as InputEventMouseButton).pressed
	)
	var is_echo := event is InputEventKey and (event as InputEventKey).echo
	if pressed:
		if is_echo or _held_shortcut_buttons.has(action_id):
			return true
		_held_shortcut_buttons[action_id] = button
		_shortcut_pressed_at_seconds[button] = Time.get_ticks_msec() / 1000.0
		button.button_down.emit()
		# A quick keyboard tap can release before the regular press tween becomes
		# visible. Snap to the authored pressed scale, then keep it visible briefly.
		_set_button_scale_immediate(button, PRESS_SCALE)
		if button.disabled:
			if activate_button:
				shortcut_blocked.emit(
					ShortcutCatalog.display_binding_name(ShortcutCatalog.get_binding(action_id)),
					String(button.name)
				)
			return true
		# Escape participates in the page-level cancel flow, which is press-based.
		# Activate it immediately so consuming the key does not suppress that flow.
		if activate_button and button == settings_button:
			_activate_shortcut_button(button)
	else:
		if not _held_shortcut_buttons.has(action_id):
			return true
		button = _held_shortcut_buttons[action_id] as TextureButton
		_held_shortcut_buttons.erase(action_id)
		button.button_up.emit()
		_shortcut_pressed_at_seconds.erase(button)
		if activate_button and button != settings_button and not button.disabled:
			_activate_shortcut_button(button)
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_held_shortcut_buttons()


func _release_held_shortcut_buttons() -> void:
	var held_buttons := _held_shortcut_buttons.values()
	_held_shortcut_buttons.clear()
	for value in held_buttons:
		var button := value as TextureButton
		if button == null or not is_instance_valid(button):
			continue
		button.button_up.emit()
		_shortcut_pressed_at_seconds.erase(button)


func _get_shortcut_button(action_id: StringName) -> TextureButton:
	var path := SHORTCUT_BUTTON_ACTIONS.get(action_id, NodePath()) as NodePath
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
	_mark_player_activity()
	if button == reset_button:
		_reset_pressed_at_seconds = Time.get_ticks_msec() / 1000.0
		_set_button_scale_immediate(button, PRESS_SCALE)
		return
	_tween_button_scale(button, PRESS_SCALE, PRESS_DURATION_SECONDS)


func _on_button_up(button: TextureButton) -> void:
	if _shortcut_pressed_at_seconds.has(button):
		_tween_button_release(
			button,
			float(_shortcut_pressed_at_seconds[button]),
			SHORTCUT_MIN_PRESS_VISIBLE_SECONDS
		)
		return
	if button == reset_button:
		_tween_reset_button_release(button)
		return
	_tween_button_scale(button, Vector2.ONE, RELEASE_DURATION_SECONDS)


func _tween_reset_button_release(button: TextureButton) -> void:
	_tween_button_release(button, _reset_pressed_at_seconds, RESET_MIN_PRESS_VISIBLE_SECONDS)
	_reset_pressed_at_seconds = -1.0


func _tween_button_release(
	button: TextureButton,
	pressed_at_seconds: float,
	minimum_visible_seconds: float
) -> void:
	var existing := _button_tweens.get(button) as Tween
	if existing != null and existing.is_valid():
		existing.kill()
	var elapsed := 0.0
	if pressed_at_seconds >= 0.0:
		elapsed = Time.get_ticks_msec() / 1000.0 - pressed_at_seconds
	var remaining_hold := maxf(minimum_visible_seconds - elapsed, 0.0)
	var tween := create_tween()
	if remaining_hold > 0.0:
		tween.tween_interval(remaining_hold)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, RELEASE_DURATION_SECONDS)
	_button_tweens[button] = tween


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


func _is_player_activity(event: InputEvent) -> bool:
	if event is InputEventKey:
		return true
	if event is InputEventMouseButton:
		return true
	if event is InputEventMouseMotion:
		return not (event as InputEventMouseMotion).relative.is_zero_approx()
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return true
	if event is InputEventJoypadButton:
		return true
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) > 0.2
	return event is InputEventAction


func _can_show_all_out_idle_prompt() -> bool:
	return (
		is_visible_in_tree()
		and all_out_button != null
		and all_out_button.visible
		and not all_out_button.disabled
	)


func _mark_player_activity() -> void:
	_last_player_activity_msec = Time.get_ticks_msec()
	_next_all_out_prompt_msec = (
		_last_player_activity_msec
		+ int(ALL_OUT_IDLE_PROMPT_DELAY_SECONDS * 1000.0)
	)
	_all_out_idle_prompt_played = false
	_hide_all_out_highlight()


func _play_all_out_idle_prompt() -> void:
	if not _can_show_all_out_idle_prompt():
		return
	var highlight_material := all_out_button.material as ShaderMaterial
	if highlight_material == null:
		return
	_all_out_idle_prompt_played = true
	_next_all_out_prompt_msec = (
		Time.get_ticks_msec()
		+ int(ALL_OUT_IDLE_PROMPT_DELAY_SECONDS * 1000.0)
	)
	if _all_out_highlight_tween != null and _all_out_highlight_tween.is_valid():
		_all_out_highlight_tween.kill()
	highlight_material.set_shader_parameter(ALL_OUT_HIGHLIGHT_PROGRESS, 0.0)
	_all_out_highlight_tween = create_tween()
	_all_out_highlight_tween.set_trans(Tween.TRANS_SINE)
	_all_out_highlight_tween.set_ease(Tween.EASE_IN_OUT)
	_all_out_highlight_tween.tween_method(
		_set_all_out_highlight_progress,
		0.0,
		1.0,
		ALL_OUT_HIGHLIGHT_DURATION_SECONDS
	)
	_all_out_highlight_tween.tween_callback(_hide_all_out_highlight.bind(false))


func _set_all_out_highlight_progress(progress: float) -> void:
	var highlight_material := all_out_button.material as ShaderMaterial
	if highlight_material != null:
		highlight_material.set_shader_parameter(ALL_OUT_HIGHLIGHT_PROGRESS, progress)


func _hide_all_out_highlight(kill_tween := true) -> void:
	if kill_tween and _all_out_highlight_tween != null \
			and _all_out_highlight_tween.is_valid():
		_all_out_highlight_tween.kill()
	_all_out_highlight_tween = null
	var button := get_node_or_null("AllOutButton") as TextureButton
	if button == null:
		return
	var highlight_material := button.material as ShaderMaterial
	if highlight_material != null:
		highlight_material.set_shader_parameter(ALL_OUT_HIGHLIGHT_PROGRESS, -1.0)
