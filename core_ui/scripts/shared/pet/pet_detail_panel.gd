extends Control

signal confirm_requested(command: Dictionary)

const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")

@onready var dim: ColorRect = $Dim
@onready var info_card: Control = $Panel/SpriteInfoCard
@onready var close_button: Button = get_node_or_null("Panel/Actions/CloseButton") as Button
@onready var confirm_button: Button = get_node_or_null("Panel/Actions/ConfirmButton") as Button
@onready var debug_panel: Control = get_node_or_null("DebugPanel") as Control
@onready var debug_toggle_button: Button = get_node_or_null("DebugToggleButton") as Button

var _detail_snapshot := {}
var _confirm_command := {}
var _is_context_detail := false
var _mouse_filters_by_id := {}
var _developer_tools := false


func _ready() -> void:
	RuntimeUiPolicy.install()
	_developer_tools = RuntimeUiPolicy.developer_tools_enabled()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if close_button != null:
		close_button.pressed.connect(close)
	if confirm_button != null:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if debug_toggle_button != null:
		debug_toggle_button.pressed.connect(_on_debug_toggle_pressed)
	_apply_button_style()
	_apply_debug_button_style()
	if debug_toggle_button != null:
		debug_toggle_button.visible = _developer_tools
	if debug_panel != null:
		debug_panel.visible = false
	_capture_mouse_filters(self)


func show_detail(record: Dictionary, texture: Texture2D = null, confirm_command: Dictionary = {}) -> void:
	_is_context_detail = false
	_restore_mouse_filters(self)
	dim.visible = true
	_confirm_command = confirm_command.duplicate(true)
	if info_card.has_method("set_info"):
		_detail_snapshot = Dictionary(info_card.call("set_info", record, texture))
	else:
		_detail_snapshot = record.duplicate(true)
	if debug_panel != null and debug_panel.has_method("inspect_record"):
		debug_panel.call("inspect_record", record, texture)
	if confirm_button != null:
		confirm_button.visible = not _confirm_command.is_empty()
	_set_debug_enabled(false)
	if debug_toggle_button != null:
		debug_toggle_button.visible = _developer_tools
	visible = true
	move_to_front()


func show_context_detail(record: Dictionary, texture: Texture2D = null) -> void:
	show_detail(record, texture)
	_is_context_detail = true
	dim.visible = false
	if close_button != null:
		close_button.visible = false
	if confirm_button != null:
		confirm_button.visible = false
	_set_debug_enabled(false)
	if debug_toggle_button != null:
		debug_toggle_button.visible = false
	_set_mouse_passthrough(self)
	move_to_front()


func close() -> void:
	visible = false
	_confirm_command = {}
	_is_context_detail = false
	dim.visible = true
	_set_debug_enabled(false)
	_restore_mouse_filters(self)
	if close_button != null:
		close_button.visible = true
	if debug_toggle_button != null:
		debug_toggle_button.visible = _developer_tools


func close_context_detail() -> void:
	if _is_context_detail:
		close()


func is_context_detail() -> bool:
	return _is_context_detail


func get_detail_snapshot() -> Dictionary:
	return _detail_snapshot.duplicate(true)


func set_info(record: Dictionary, texture: Texture2D = null) -> Dictionary:
	if not info_card.has_method("set_info"):
		_detail_snapshot = record.duplicate(true)
	else:
		_detail_snapshot = Dictionary(info_card.call("set_info", record, texture))
	return get_detail_snapshot()


func get_attack_shape_cell_count() -> int:
	return int(info_card.call("get_attack_shape_cell_count")) if info_card.has_method("get_attack_shape_cell_count") else 0


func get_target_cell_indices() -> Array:
	return Array(info_card.call("get_target_cell_indices")) if info_card.has_method("get_target_cell_indices") else []


func get_source_canvas_size() -> Vector2:
	return Vector2(info_card.call("get_source_canvas_size")) if info_card.has_method("get_source_canvas_size") else Vector2.ZERO


func get_source_psd() -> String:
	return String(info_card.call("get_source_psd")) if info_card.has_method("get_source_psd") else ""


func get_component_source() -> String:
	return String(info_card.call("get_component_source")) if info_card.has_method("get_component_source") else ""


func get_info_card() -> Control:
	return info_card


func get_display_text() -> String:
	return String(info_card.call("get_display_text")) if info_card.has_method("get_display_text") else ""


func set_debug_enabled(enabled: bool) -> void:
	_set_debug_enabled(enabled and _developer_tools)


func is_debug_enabled() -> bool:
	return debug_panel != null and debug_panel.visible


func debug_record_count() -> int:
	return int(debug_panel.call("debug_record_count")) if debug_panel != null and debug_panel.has_method("debug_record_count") else 0


func debug_current_index() -> int:
	return int(debug_panel.call("debug_current_index")) if debug_panel != null and debug_panel.has_method("debug_current_index") else -1


func debug_next_pet() -> Dictionary:
	return Dictionary(debug_panel.call("debug_next")) if debug_panel != null and debug_panel.has_method("debug_next") else {}


func debug_previous_pet() -> Dictionary:
	return Dictionary(debug_panel.call("debug_previous")) if debug_panel != null and debug_panel.has_method("debug_previous") else {}


func debug_last_result() -> Dictionary:
	return Dictionary(debug_panel.call("debug_last_result")) if debug_panel != null and debug_panel.has_method("debug_last_result") else {}


func _capture_mouse_filters(node: Node) -> void:
	if node is Control:
		var control := node as Control
		_mouse_filters_by_id[control.get_instance_id()] = control.mouse_filter
	for child in node.get_children():
		_capture_mouse_filters(child)


func _set_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough(child)


func _restore_mouse_filters(node: Node) -> void:
	if node is Control:
		var control := node as Control
		var instance_id := control.get_instance_id()
		if _mouse_filters_by_id.has(instance_id):
			control.mouse_filter = int(_mouse_filters_by_id[instance_id]) as Control.MouseFilter
	for child in node.get_children():
		_restore_mouse_filters(child)


func _on_confirm_pressed() -> void:
	if _confirm_command.is_empty():
		return
	var command := _confirm_command.duplicate(true)
	close()
	confirm_requested.emit(command)


func _on_debug_toggle_pressed() -> void:
	if not _developer_tools:
		return
	_set_debug_enabled(not is_debug_enabled())


func _set_debug_enabled(enabled: bool) -> void:
	enabled = enabled and _developer_tools
	if debug_panel != null:
		debug_panel.visible = enabled
	if debug_toggle_button != null:
		debug_toggle_button.text = RuntimeUiPolicy.text("UI_DEBUG_COLLAPSE" if enabled else "UI_DEBUG_DATA")


func _apply_button_style() -> void:
	for button in [close_button, confirm_button]:
		if button == null:
			continue
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Color("3a2410"))
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.94, 0.78, 0.47, 0.96)
		normal.border_color = Color(0.45, 0.27, 0.10, 0.95)
		normal.set_border_width_all(2)
		normal.set_corner_radius_all(7)
		button.add_theme_stylebox_override("normal", normal)


func _apply_debug_button_style() -> void:
	if debug_toggle_button == null:
		return
	debug_toggle_button.add_theme_font_size_override("font_size", 18)
	debug_toggle_button.add_theme_color_override("font_color", Color("e8f3ff"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("274866")
	normal.border_color = Color("6fa8d7")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	debug_toggle_button.add_theme_stylebox_override("normal", normal)
