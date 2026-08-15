extends RefCounted

## Owns controller/keyboard focus policy for the current three-choice surface.
## It reads only existing Controls and never reads Snapshot or emits Commands.

const VIEW_BAG := &"bag"

var _host: Control = null
var _three_buttons: Array = []
var _party_buttons: Array = []
var _bag_buttons: Array = []
var _bag_button: BaseButton = null
var _exit_button: BaseButton = null
var _connections: Array[Dictionary] = []


func configure(
		host: Control,
		three_buttons: Array,
		party_buttons: Array,
		bag_buttons: Array,
		bag_button: BaseButton,
		exit_button: BaseButton = null
) -> void:
	dispose()
	_host = host
	_three_buttons = three_buttons
	_party_buttons = party_buttons
	_bag_buttons = bag_buttons
	_bag_button = bag_button
	_exit_button = exit_button
	for button in _all_focus_buttons():
		button.focus_mode = Control.FOCUS_ALL
		_connect(button.focus_entered, Callable(self, "_on_focus_entered").bind(button))
		_connect(button.focus_exited, Callable(self, "_on_focus_exited").bind(button))


func refresh(view: StringName) -> void:
	var controls := _focus_controls_for_view(view)
	if controls.is_empty():
		return
	for index in range(controls.size()):
		var control := controls[index]
		var previous := controls[(index - 1 + controls.size()) % controls.size()]
		var next := controls[(index + 1) % controls.size()]
		control.focus_neighbor_left = control.get_path_to(previous)
		control.focus_neighbor_right = control.get_path_to(next)
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)


func grab_if_current_focus_hidden(view: StringName) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	refresh(view)
	var focus_owner := _host.get_viewport().gui_get_focus_owner()
	if focus_owner == null or focus_owner.is_visible_in_tree():
		return
	var controls := _focus_controls_for_view(view)
	if not controls.is_empty():
		controls[0].grab_focus()


func restore_button_tint(button: BaseButton) -> void:
	if button == null:
		return
	var surface := _button_surface(button)
	if surface != null:
		surface.modulate = button.get_meta("base_tint", Color.WHITE) as Color


func dispose() -> void:
	for record in _connections:
		var signal_value: Signal = record.get("signal") as Signal
		var callback := record.get("callback") as Callable
		if signal_value.is_connected(callback):
			signal_value.disconnect(callback)
	_connections.clear()
	_host = null
	_three_buttons.clear()
	_party_buttons.clear()
	_bag_buttons.clear()
	_bag_button = null
	_exit_button = null


func _focus_controls_for_view(view: StringName) -> Array[Control]:
	var candidates: Array = []
	match view:
		VIEW_BAG:
			candidates.append_array(_bag_buttons)
		_:
			candidates.append_array(_three_buttons)
	candidates.append(_bag_button)
	if view != VIEW_BAG:
		candidates.append(_exit_button)
	var controls: Array[Control] = []
	for value in candidates:
		var control := value as Control
		if control == null or not control.visible:
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		controls.append(control)
	return controls


func _all_focus_buttons() -> Array[BaseButton]:
	var buttons: Array[BaseButton] = []
	for group in [_three_buttons, _party_buttons, _bag_buttons]:
		for value in group:
			var button := value as BaseButton
			if button != null:
				buttons.append(button)
	for button in [_bag_button, _exit_button]:
		if button != null:
			buttons.append(button)
	return buttons


func _connect(signal_value: Signal, callback: Callable) -> void:
	if not signal_value.is_connected(callback):
		signal_value.connect(callback)
	_connections.append({"signal": signal_value, "callback": callback})


func _on_focus_entered(button: BaseButton) -> void:
	if bool(button.get_meta("focus_tint_disabled", false)):
		return
	var surface := _button_surface(button)
	if surface != null:
		surface.modulate = Color(1.18, 1.08, 0.72, 1.0)


func _on_focus_exited(button: BaseButton) -> void:
	restore_button_tint(button)


func _button_surface(button: BaseButton) -> CanvasItem:
	if bool(button.get_meta("slot_surface_self", false)):
		return button
	return button.get_parent() as CanvasItem
