extends Control
class_name BattleSettingsMenu

## Presentation-only pause/settings overlay used by the standalone battle Mock.
## It owns local button feedback, visibility, and menu-prefab composition, but
## never accesses Session or formal save data directly.

signal mock_action_requested(action: StringName)
signal session_operation_requested(operation: StringName, arguments: Dictionary)
signal button_shortcut_hints_visibility_changed(hints_visible: bool)
signal shortcut_bindings_changed(bindings: Dictionary)

const MenuSettingsScene := preload("res://art/prefabs/menu/screens/menu_settings.tscn")
const MenuStartScene := preload("res://art/prefabs/menu/screens/menu_start.tscn")
const SaveGameDialogScene := preload("res://art/prefabs/menu/dialogs/save_game_dialog.tscn")
const LoadGameDialogScene := preload("res://art/prefabs/menu/dialogs/load_game_dialog.tscn")
const AbandonGameDialogScene := preload("res://art/prefabs/menu/dialogs/abandon_game_dialog.tscn")

@export var hover_inner_border: StyleBox

@onready var menu_visual: Control = get_node("CompleteUISettingsButtonPrefab") as Control
@onready var menu_panel: Control = get_node("CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu") as Control
@onready var settings_button: Button = get_node("CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/Settings") as Button
@onready var continue_button: Button = get_node("CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/Continue") as Button
@onready var save_game_button: Button = get_node("CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/SaveGame") as Button
@onready var load_game_button: Button = get_node("CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/LoadGame") as Button
@onready var main_menu_button: Button = get_node("CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/MainMenu") as Button
@onready var resign_button: Button = get_node("CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/Resign") as Button

var _normal_inner_borders := {}
var _active_panel: Control
var _active_panel_closes_menu := false
var _button_shortcut_hints_visible := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(close_menu)
	settings_button.pressed.connect(_open_settings_panel)
	save_game_button.pressed.connect(_open_save_dialog)
	load_game_button.pressed.connect(_open_load_dialog)
	main_menu_button.pressed.connect(_open_main_menu)
	resign_button.pressed.connect(_open_abandon_dialog)
	for button in [settings_button, continue_button, save_game_button, load_game_button, main_menu_button]:
		_bind_inner_border_feedback(button)


func _gui_input(event: InputEvent) -> void:
	if not menu_visual.visible or is_instance_valid(_active_panel):
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if menu_panel.get_global_rect().has_point(mouse_event.global_position):
		return
	accept_event()
	close_menu()


func open_menu() -> void:
	visible = true
	if is_instance_valid(_active_panel):
		_active_panel.show()
	else:
		menu_visual.show()
		settings_button.grab_focus()


func close_menu() -> void:
	_dispose_active_panel()
	visible = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()


func handle_cancel() -> void:
	if is_instance_valid(_active_panel):
		if _active_panel_closes_menu:
			close_menu()
		else:
			_close_active_panel()
	else:
		close_menu()


func is_open() -> bool:
	return visible


func configure_formal_session_mode() -> void:
	main_menu_button.disabled = true
	main_menu_button.tooltip_text = "正式流程尚未开放从战斗直接返回主菜单"
	resign_button.disabled = true
	resign_button.tooltip_text = "正式流程尚未开放从战斗直接认输"


func has_active_panel() -> bool:
	return is_instance_valid(_active_panel)


func is_capturing_shortcut() -> bool:
	return is_instance_valid(_active_panel) \
			and _active_panel.has_method("is_capturing_shortcut") \
			and bool(_active_panel.call("is_capturing_shortcut"))


func set_button_shortcut_hints_visible(hints_visible: bool) -> void:
	_button_shortcut_hints_visible = hints_visible
	if is_instance_valid(_active_panel) \
			and _active_panel.has_method("set_button_shortcut_hints_visible"):
		_active_panel.call("set_button_shortcut_hints_visible", hints_visible)


func are_button_shortcut_hints_visible() -> bool:
	return _button_shortcut_hints_visible


func _open_settings_panel() -> void:
	var panel := _mount_panel(MenuSettingsScene, true)
	panel.call("set_button_shortcut_hints_visible", _button_shortcut_hints_visible)
	panel.connect("close_requested", close_menu)
	panel.connect("option_selected", _on_settings_option_selected)
	panel.connect("button_shortcut_hints_toggled", _on_button_shortcut_hints_toggled)
	panel.connect("shortcut_bindings_changed", _on_shortcut_bindings_changed)
	mock_action_requested.emit(&"settings")


func _open_save_dialog() -> void:
	var panel := _mount_panel(SaveGameDialogScene)
	panel.connect("slot_selected", _on_slot_selected.bind(&"save"))
	panel.connect("back_requested", _close_active_panel)
	mock_action_requested.emit(&"save_game")


func _open_load_dialog() -> void:
	var panel := _mount_panel(LoadGameDialogScene)
	panel.connect("slot_selected", _on_slot_selected.bind(&"load"))
	panel.connect("back_requested", _close_active_panel)
	mock_action_requested.emit(&"load_game")


func _open_main_menu() -> void:
	_show_start_screen(true)
	mock_action_requested.emit(&"main_menu")


func _open_abandon_dialog() -> void:
	var panel := _mount_panel(AbandonGameDialogScene)
	panel.connect("abandon_confirmed", _on_abandon_confirmed.bind(&"resign"))
	panel.connect("cancel_requested", _close_active_panel)
	mock_action_requested.emit(&"resign")


func _mount_panel(scene: PackedScene, closes_menu := false) -> Control:
	_dispose_active_panel()
	menu_visual.hide()
	_active_panel = scene.instantiate() as Control
	_active_panel_closes_menu = closes_menu
	add_child(_active_panel)
	_active_panel.tree_exited.connect(_on_active_panel_tree_exited.bind(_active_panel))
	return _active_panel


func _close_active_panel() -> void:
	_dispose_active_panel()
	if visible:
		menu_visual.show()
		settings_button.grab_focus()


func _dispose_active_panel() -> void:
	if is_instance_valid(_active_panel):
		var panel := _active_panel
		_active_panel = null
		panel.queue_free()
	_active_panel_closes_menu = false
	menu_visual.show()


func _on_active_panel_tree_exited(panel: Control) -> void:
	if _active_panel == panel:
		_active_panel = null
	if visible and not is_instance_valid(_active_panel):
		menu_visual.show()


func _on_slot_selected(slot_number: int, operation: StringName) -> void:
	session_operation_requested.emit(operation, {"slot": slot_number})
	mock_action_requested.emit(StringName("%s_slot_%d" % [operation, slot_number]))
	_close_active_panel()


func _on_settings_option_selected(option_number: int) -> void:
	mock_action_requested.emit(StringName("settings_option_%d" % option_number))


func _on_button_shortcut_hints_toggled(hints_visible: bool) -> void:
	_button_shortcut_hints_visible = hints_visible
	button_shortcut_hints_visibility_changed.emit(hints_visible)


func _on_shortcut_bindings_changed(bindings: Dictionary) -> void:
	shortcut_bindings_changed.emit(bindings.duplicate(true))


func _on_continue_from_main_menu(_continue_existing: bool) -> void:
	mock_action_requested.emit(&"continue_from_main_menu")
	close_menu()


func _on_main_menu_settings_requested() -> void:
	mock_action_requested.emit(&"main_menu_settings")


func _on_abandon_confirmed(source: StringName) -> void:
	mock_action_requested.emit(StringName("%s_confirmed" % source))
	_show_start_screen(false)


func _show_start_screen(has_active_game: bool) -> void:
	var panel := _mount_panel(MenuStartScene)
	panel.call("set_has_active_game", has_active_game)
	panel.call("set_button_shortcut_hints_visible", _button_shortcut_hints_visible)
	panel.connect("start_game_requested", _on_continue_from_main_menu)
	panel.connect("settings_requested", _on_main_menu_settings_requested)
	panel.connect("abandon_confirmed", _on_abandon_confirmed.bind(&"main_menu"))
	panel.connect(
		"button_shortcut_hints_visibility_changed",
		_on_button_shortcut_hints_toggled
	)
	panel.connect("shortcut_bindings_changed", _on_shortcut_bindings_changed)


func _bind_inner_border_feedback(button: Button) -> void:
	var inner_border := button.get_node_or_null("InnerBorder") as Panel
	if inner_border == null:
		return
	_normal_inner_borders[button] = inner_border.get_theme_stylebox("panel")
	button.mouse_entered.connect(_set_inner_border_hovered.bind(button, true))
	button.mouse_exited.connect(_set_inner_border_hovered.bind(button, false))


func _set_inner_border_hovered(button: Button, hovered: bool) -> void:
	var inner_border := button.get_node_or_null("InnerBorder") as Panel
	if inner_border == null:
		return
	var normal_style := _normal_inner_borders.get(button) as StyleBox
	inner_border.add_theme_stylebox_override(
		"panel",
		hover_inner_border if hovered and hover_inner_border != null else normal_style
	)
