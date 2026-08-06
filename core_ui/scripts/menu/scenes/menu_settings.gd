extends Control

const ShortcutCatalog := preload("res://core_ui/scripts/shared/shortcut_catalog.gd")

signal option_selected(option_number: int)
signal close_requested
signal button_shortcut_hints_toggled(hints_visible: bool)
signal shortcut_bindings_changed(bindings: Dictionary)

@export var hover_inner_border: StyleBox

@onready var close_button: ActionButton = $"CompleteStartSceneSettingsPrefab/01_StartSceneSettingsVisual/CloseButton"
@onready var content_scroll: ScrollContainer = $"CompleteStartSceneSettingsPrefab/01_StartSceneSettingsVisual/ContentArea/ContentScroll"
@onready var content_stack: VBoxContainer = $"CompleteStartSceneSettingsPrefab/01_StartSceneSettingsVisual/ContentArea/ContentScroll/ContentStack"
@onready var shortcut_hints_check: CheckBox = $"CompleteStartSceneSettingsPrefab/01_StartSceneSettingsVisual/ContentArea/ContentScroll/ContentStack/GameplaySection/ShortcutHintsCheck"
@onready var keybinds_section: Control = $"CompleteStartSceneSettingsPrefab/01_StartSceneSettingsVisual/ContentArea/ContentScroll/ContentStack/KeybindsSection"

var _option_buttons: Array[Button] = []
var _normal_inner_borders: Dictionary = {}
var _sections: Array[Control] = []
var _selected_section := 0
var _button_shortcut_hints_visible := true
var _binding_buttons: Dictionary = {}
var _reset_buttons: Dictionary = {}
var _listening_action: StringName = &""


func _ready() -> void:
	_bind_keybind_controls()
	_refresh_keybind_display()
	_sections = [
		content_stack.get_node("AudioSection") as Control,
		content_stack.get_node("GraphicsSection") as Control,
		content_stack.get_node("GameplaySection") as Control,
		content_stack.get_node("KeybindsSection") as Control,
		content_stack.get_node("AccessibilitySection") as Control,
		content_stack.get_node("SupportSection") as Control,
	]
	for option_number in range(1, 8):
		var button := find_child("Option%02d" % option_number, true, false) as Button
		if button == null:
			continue
		_option_buttons.append(button)
		if option_number <= _sections.size():
			button.toggle_mode = true
		button.pressed.connect(_on_option_pressed.bind(option_number))
		_bind_inner_border_hover(button, option_number < 7)
	close_button.button_pressed.connect(_on_close_button_pressed)
	shortcut_hints_check.toggled.connect(_on_shortcut_hints_toggled)
	shortcut_hints_check.set_pressed_no_signal(_button_shortcut_hints_visible)
	content_scroll.get_v_scroll_bar().value_changed.connect(_on_content_scroll_changed)
	call_deferred("_select_section", 0, false)


func _refresh_keybind_display() -> void:
	for binding_value in ShortcutCatalog.DISPLAY_BINDINGS:
		var binding := Dictionary(binding_value)
		var action_id := StringName(binding.get("id", &""))
		var node_prefix := String(binding.get("node", ""))
		var label := keybinds_section.get_node_or_null("%sLabel" % node_prefix) as Label
		var key_button := keybinds_section.get_node_or_null("%sKeyButton" % node_prefix) as Button
		var reset_button := keybinds_section.get_node_or_null("%sResetButton" % node_prefix) as Button
		if label == null or key_button == null or reset_button == null:
			continue
		label.text = String(binding.get("label", ""))
		key_button.text = (
			"按下按键以设置"
			if action_id == _listening_action
			else ShortcutCatalog.display_binding_name(ShortcutCatalog.get_binding(action_id))
		)
		reset_button.visible = action_id != _listening_action and not ShortcutCatalog.is_default(action_id)


func _bind_keybind_controls() -> void:
	for binding_value in ShortcutCatalog.DISPLAY_BINDINGS:
		var binding := Dictionary(binding_value)
		var action_id := StringName(binding.get("id", &""))
		var node_prefix := String(binding.get("node", ""))
		var key_button := keybinds_section.get_node_or_null("%sKeyButton" % node_prefix) as Button
		var reset_button := keybinds_section.get_node_or_null("%sResetButton" % node_prefix) as Button
		if key_button == null or reset_button == null:
			continue
		_binding_buttons[action_id] = key_button
		_reset_buttons[action_id] = reset_button
		key_button.pressed.connect(_begin_binding_capture.bind(action_id))
		reset_button.pressed.connect(_restore_default_binding.bind(action_id))


func open() -> void:
	show()
	call_deferred("_select_section", _selected_section, false)
	if not _option_buttons.is_empty():
		_option_buttons[_selected_section].grab_focus()


func close() -> void:
	_cancel_binding_capture()
	hide()
	close_requested.emit()


func set_button_shortcut_hints_visible(hints_visible: bool) -> void:
	_button_shortcut_hints_visible = hints_visible
	if is_node_ready():
		shortcut_hints_check.set_pressed_no_signal(hints_visible)


func are_button_shortcut_hints_visible() -> bool:
	return _button_shortcut_hints_visible


func is_capturing_shortcut() -> bool:
	return _listening_action != &""


func _input(event: InputEvent) -> void:
	if _listening_action == &"" or not _is_binding_press(event):
		return
	var new_binding := ShortcutCatalog.binding_from_event(event)
	if new_binding.is_empty():
		return
	get_viewport().set_input_as_handled()
	var action_id := _listening_action
	_listening_action = &""
	ShortcutCatalog.assign_binding(action_id, new_binding)
	_refresh_keybind_display()
	shortcut_bindings_changed.emit(ShortcutCatalog.serialized_bindings())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _is_binding_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	return false


func _begin_binding_capture(action_id: StringName) -> void:
	_listening_action = action_id
	_refresh_keybind_display()


func _restore_default_binding(action_id: StringName) -> void:
	_listening_action = &""
	ShortcutCatalog.assign_binding(action_id, ShortcutCatalog.default_binding(action_id))
	_refresh_keybind_display()
	shortcut_bindings_changed.emit(ShortcutCatalog.serialized_bindings())


func _cancel_binding_capture() -> void:
	if _listening_action == &"":
		return
	_listening_action = &""
	_refresh_keybind_display()


func _on_option_pressed(option_number: int) -> void:
	if option_number <= _sections.size():
		_select_section(option_number - 1, true)
	option_selected.emit(option_number)


func _select_section(section_index: int, move_scroll: bool) -> void:
	if _sections.is_empty():
		return
	_selected_section = clampi(section_index, 0, _sections.size() - 1)
	for button_index in range(mini(_sections.size(), _option_buttons.size())):
		_option_buttons[button_index].set_pressed_no_signal(button_index == _selected_section)
	if move_scroll:
		var scroll_bar := content_scroll.get_v_scroll_bar()
		var target := int(_sections[_selected_section].position.y)
		content_scroll.scroll_vertical = mini(target, int(scroll_bar.max_value - scroll_bar.page))


func _on_content_scroll_changed(scroll_value: float) -> void:
	if _sections.is_empty():
		return
	var scroll_bar := content_scroll.get_v_scroll_bar()
	var maximum_scroll := scroll_bar.max_value - scroll_bar.page
	if scroll_value >= maximum_scroll - 2.0:
		_select_section(_sections.size() - 1, false)
		return
	var section_index := 0
	for index in range(_sections.size()):
		if scroll_value + 220.0 >= _sections[index].position.y:
			section_index = index
		else:
			break
	if section_index != _selected_section:
		_select_section(section_index, false)


func _on_close_button_pressed(action: ActionButton.ActionType) -> void:
	if action == ActionButton.ActionType.CLOSE:
		close()


func _on_shortcut_hints_toggled(hints_visible: bool) -> void:
	_button_shortcut_hints_visible = hints_visible
	button_shortcut_hints_toggled.emit(hints_visible)


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
