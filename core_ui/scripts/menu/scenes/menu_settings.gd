extends Control

signal option_selected(option_number: int)
signal close_requested

@export var hover_inner_border: StyleBox

@onready var close_button: ActionButton = $"CompleteStartSceneSettingsPrefab/01_StartSceneSettingsVisual/CloseButton"

var _option_buttons: Array[Button] = []
var _normal_inner_borders: Dictionary = {}


func _ready() -> void:
	for option_number in range(1, 8):
		var button := find_child("Option%02d" % option_number, true, false) as Button
		if button == null:
			continue
		_option_buttons.append(button)
		button.pressed.connect(_on_option_pressed.bind(option_number))
		_bind_inner_border_hover(button, option_number < 7)
	close_button.button_pressed.connect(_on_close_button_pressed)


func open() -> void:
	show()
	if not _option_buttons.is_empty():
		_option_buttons[0].grab_focus()


func close() -> void:
	hide()
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_option_pressed(option_number: int) -> void:
	option_selected.emit(option_number)


func _on_close_button_pressed(action: ActionButton.ActionType) -> void:
	if action == ActionButton.ActionType.CLOSE:
		close()


func _bind_inner_border_hover(button: Button, use_hover_style: bool) -> void:
	var inner_border := button.get_node_or_null("InnerBorder") as Panel
	if inner_border == null:
		return
	_normal_inner_borders[button] = inner_border.get_theme_stylebox("panel")
	button.mouse_entered.connect(_set_button_hovered.bind(button, use_hover_style))
	button.mouse_exited.connect(_set_button_hovered.bind(button, false))


func _set_button_hovered(button: Button, hovered: bool) -> void:
	var inner_border := button.get_node_or_null("InnerBorder") as Panel
	if inner_border == null:
		return
	var normal_border := _normal_inner_borders.get(button) as StyleBox
	inner_border.add_theme_stylebox_override(
		"panel", hover_inner_border if hovered and hover_inner_border != null else normal_border
	)
