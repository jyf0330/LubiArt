extends Control

signal confirm_requested(command: Dictionary)

const MODAL_PANEL_SCALE := Vector2.ONE
const CONTEXT_PANEL_SCALE := Vector2.ONE
const PANEL_SIZE := Vector2(360.0, 460.0)
const VIEWPORT_MARGIN := 16.0
const POINTER_OFFSET := Vector2(24.0, 20.0)

@onready var dim: ColorRect = $Dim
@onready var panel: Control = $Panel
@onready var info_card: Control = $Panel/SpriteInfoCard
@onready var close_button: Button = get_node_or_null("Panel/Actions/CloseButton") as Button
@onready var confirm_button: Button = get_node_or_null("Panel/Actions/ConfirmButton") as Button

var _detail_snapshot := {}
var _confirm_command := {}
var _is_context_detail := false
var _mouse_filters_by_id := {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if close_button != null:
		close_button.pressed.connect(close)
	if confirm_button != null:
		confirm_button.pressed.connect(_on_confirm_pressed)
	_apply_button_style()
	_capture_mouse_filters(self)


func show_detail(record: Dictionary, texture: Texture2D = null, confirm_command: Dictionary = {}) -> void:
	_is_context_detail = false
	_restore_mouse_filters(self)
	_apply_modal_layout()
	dim.visible = false
	_confirm_command = confirm_command.duplicate(true)
	if info_card.has_method("set_info"):
		_detail_snapshot = Dictionary(info_card.call("set_info", record, texture))
	else:
		_detail_snapshot = record.duplicate(true)
	if confirm_button != null:
		confirm_button.visible = not _confirm_command.is_empty()
	visible = true
	move_to_front()


func show_context_detail(record: Dictionary, texture: Texture2D = null) -> void:
	show_detail(record, texture)
	_is_context_detail = true
	_apply_context_layout()
	dim.visible = false
	if close_button != null:
		close_button.visible = false
	if confirm_button != null:
		confirm_button.visible = false
	_set_mouse_passthrough(self)
	move_to_front()


func close() -> void:
	visible = false
	_confirm_command = {}
	_is_context_detail = false
	dim.visible = false
	_restore_mouse_filters(self)
	if close_button != null:
		close_button.visible = true
	_apply_modal_layout()


func close_context_detail() -> void:
	if _is_context_detail:
		close()


func is_context_detail() -> bool:
	return _is_context_detail


func _apply_modal_layout() -> void:
	if panel != null:
		panel.scale = MODAL_PANEL_SCALE
		var viewport_size := get_viewport_rect().size
		panel.position = (viewport_size - PANEL_SIZE) * 0.5


func _apply_context_layout() -> void:
	if panel != null:
		panel.scale = CONTEXT_PANEL_SCALE
		var viewport_size := get_viewport_rect().size
		var pointer := get_viewport().get_mouse_position()
		var desired := pointer + POINTER_OFFSET
		if desired.x + PANEL_SIZE.x > viewport_size.x - VIEWPORT_MARGIN:
			desired.x = pointer.x - PANEL_SIZE.x - POINTER_OFFSET.x
		if desired.y + PANEL_SIZE.y > viewport_size.y - VIEWPORT_MARGIN:
			desired.y = pointer.y - PANEL_SIZE.y - POINTER_OFFSET.y
		panel.position = Vector2(
			clampf(desired.x, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.x - PANEL_SIZE.x - VIEWPORT_MARGIN)),
			clampf(desired.y, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.y - PANEL_SIZE.y - VIEWPORT_MARGIN))
		)


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
