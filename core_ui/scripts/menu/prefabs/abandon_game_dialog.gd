extends Control

signal abandon_confirmed
signal cancel_requested

@export var hover_inner_border: StyleBox

@onready var confirm_button: Button = $"CompleteUIAbandonGamePrefab/01_UIAbandonGameVisual/Dialog/Buttons/Confirm"
@onready var cancel_button: Button = $"CompleteUIAbandonGamePrefab/01_UIAbandonGameVisual/Dialog/Buttons/Cancel"

var _normal_inner_borders: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_inner_border_hover(confirm_button)
	_bind_inner_border_hover(cancel_button)
	confirm_button.pressed.connect(_confirm_abandon)
	cancel_button.pressed.connect(_cancel)
	cancel_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()


func _confirm_abandon() -> void:
	abandon_confirmed.emit()
	queue_free()


func _cancel() -> void:
	cancel_requested.emit()
	queue_free()


func _bind_inner_border_hover(button: Button) -> void:
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
