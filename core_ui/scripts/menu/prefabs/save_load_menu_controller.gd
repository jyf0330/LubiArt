extends Control

signal slot_selected(slot_number: int)
signal back_requested

@export var hover_inner_border: StyleBox

@onready var back_button: Button = find_child("Back", true, false) as Button

var _slot_buttons: Array[Button] = []
var _normal_inner_borders: Dictionary = {}


func _ready() -> void:
	for slot_number in range(1, 6):
		var button := find_child("SaveSlot%d" % slot_number, true, false) as Button
		if button == null:
			continue
		_slot_buttons.append(button)
		button.pressed.connect(_on_slot_pressed.bind(slot_number))
		_bind_inner_border_hover(button)

	_bind_inner_border_hover(back_button)
	back_button.pressed.connect(_on_back_pressed)
	if not _slot_buttons.is_empty():
		_slot_buttons[0].grab_focus()


func open() -> void:
	show()
	if not _slot_buttons.is_empty():
		_slot_buttons[0].grab_focus()


func close() -> void:
	hide()


func set_save_time(slot_number: int, day: int, hour: int) -> void:
	var button := _get_slot_button(slot_number)
	if button == null:
		return
	button.text = "存档 %02d · 第%s天 · 第%s小时" % [
		slot_number,
		_format_fixed_width_value(day, 3),
		_format_fixed_width_value(hour, 4),
	]


func clear_save_time(slot_number: int) -> void:
	set_save_time(slot_number, -1, -1)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_slot_pressed(slot_number: int) -> void:
	slot_selected.emit(slot_number)


func _on_back_pressed() -> void:
	back_requested.emit()
	close()


func _get_slot_button(slot_number: int) -> Button:
	var index := slot_number - 1
	if index < 0 or index >= _slot_buttons.size():
		return null
	return _slot_buttons[index]


func _format_fixed_width_value(value: int, width: int) -> String:
	if value < 0:
		return " ".repeat(width)
	var digits := str(value)
	return "-".repeat(width) if digits.length() > width else digits.lpad(width, " ")


func _bind_inner_border_hover(button: Button) -> void:
	if button == null:
		return
	var inner_border := button.get_node_or_null("InnerBorder") as Panel
	if inner_border == null:
		return
	_normal_inner_borders[button] = inner_border.get_theme_stylebox("panel")
	button.mouse_entered.connect(_set_button_hovered.bind(button, true))
	button.mouse_exited.connect(_set_button_hovered.bind(button, false))


func _set_button_hovered(button: Button, hovered: bool) -> void:
	var inner_border := button.get_node_or_null("InnerBorder") as Panel
	if inner_border == null:
		return
	var normal_border := _normal_inner_borders.get(button) as StyleBox
	inner_border.add_theme_stylebox_override(
		"panel", hover_inner_border if hovered and hover_inner_border != null else normal_border
	)
