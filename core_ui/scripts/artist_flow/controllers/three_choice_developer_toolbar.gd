extends RefCounted

## Owns the optional local developer toolbar. It receives a narrow operation
## Callable and never knows about GameSession, repositories, or gameplay state.

const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")

const VIEW_BATTLE := &"battle"
const RUN_TOOL_SIZE := Vector2(92.0, 48.0)

var _host: Control = null
var _request_operation := Callable()
var _operation_completed := Callable()
var _panel: PanelContainer = null
var _status_label: Label = null
var _enabled := false
var _quick_access_override_active := false
var _quick_access_visible := false
var _supports_persistence := false
var _slot_count := 0
var _current_view := &"three_option"
var _requested_visible := true
var _capabilities_configured := false


func configure(host: Control, request_operation: Callable, operation_completed: Callable) -> void:
	RuntimeUiPolicy.install()
	_host = host
	_request_operation = request_operation
	_operation_completed = operation_completed


func configure_session_capabilities(supports_persistence: bool, slot_count: int) -> void:
	_supports_persistence = supports_persistence
	_slot_count = maxi(0, slot_count)
	_capabilities_configured = true
	if _enabled or _quick_access_visible:
		_ensure_toolbar()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if enabled:
		_ensure_toolbar()
	_refresh_visibility()


func set_visible_for_view(view: StringName, requested_visible: bool) -> void:
	_current_view = view
	_requested_visible = requested_visible
	if _panel == null:
		return
	_panel.position.y = 14.0 if view == VIEW_BATTLE else 22.0
	_refresh_visibility()


func toggle_quick_access() -> bool:
	var currently_visible := is_quick_access_visible()
	if _panel == null:
		currently_visible = _requested_visible and _enabled and _current_view == VIEW_BATTLE
	_quick_access_override_active = true
	_quick_access_visible = not currently_visible
	if _quick_access_visible:
		_ensure_toolbar()
	_refresh_visibility()
	return is_quick_access_visible()


func is_quick_access_visible() -> bool:
	return is_instance_valid(_panel) and _panel.visible


func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func dispose() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_status_label = null
	_host = null
	_request_operation = Callable()
	_operation_completed = Callable()


func _ensure_toolbar() -> void:
	if (
		(not _enabled and not _quick_access_visible)
		or not _capabilities_configured
		or _panel != null
		or _host == null
		or not is_instance_valid(_host)
	):
		return
	_panel = PanelContainer.new()
	_panel.name = "RunTools"
	_panel.z_index = 90
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(28.0, 22.0)
	_panel.custom_minimum_size = Vector2(1180.0, 62.0)
	_panel.add_theme_stylebox_override("panel", _make_style())

	var row := HBoxContainer.new()
	row.name = "RunToolsRow"
	row.add_theme_constant_override("separation", 10)
	_panel.add_child(row)

	for slot in range(1, _slot_count + 1):
		var save_name := "SaveButton" if slot == 1 else "SaveSlot%dButton" % slot
		var load_name := "LoadButton" if slot == 1 else "LoadSlot%dButton" % slot
		_add_button(row, RuntimeUiPolicy.text("UI_SAVE_SLOT", [slot]), save_name, _on_save_pressed.bind(slot))
		_add_button(row, RuntimeUiPolicy.text("UI_LOAD_SLOT", [slot]), load_name, _on_load_pressed.bind(slot))
	_add_button(row, RuntimeUiPolicy.text("UI_EXPORT_REPLAY"), "ExportReplayButton", _on_export_replay_pressed)
	_add_button(row, RuntimeUiPolicy.text("UI_EXPORT_TRACE"), "ExportBattleTraceButton", _on_export_battle_trace_pressed)

	_status_label = Label.new()
	_status_label.name = "RunToolsStatus"
	_status_label.custom_minimum_size = Vector2(220.0, RUN_TOOL_SIZE.y)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color("#f4edd8"))
	_status_label.text = RuntimeUiPolicy.text("UI_LOCAL_SAVE")
	row.add_child(_status_label)
	_host.add_child.call_deferred(_panel)
	_refresh_visibility.call_deferred()


func _refresh_visibility() -> void:
	if _panel == null:
		return
	var mode_visible := _quick_access_visible if _quick_access_override_active else (
		_enabled and _current_view == VIEW_BATTLE
	)
	_panel.visible = _requested_visible and mode_visible


func _add_button(row: HBoxContainer, label_text: String, button_name: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = label_text
	button.custom_minimum_size = RUN_TOOL_SIZE
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	row.add_child(button)


func _make_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.05, 0.78)
	style.border_color = Color(0.84, 0.68, 0.38, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style


func _on_save_pressed(slot: int) -> void:
	if not _supports_persistence:
		set_status("当前会话不支持本地存档")
		return
	var result := await _request(&"save", {"slot": slot})
	set_status("已保存槽%d" % slot if bool(result.get("ok", false)) else "槽%d保存失败" % slot)
	await _notify_completed(&"save", result)


func _on_load_pressed(slot: int) -> void:
	if not _supports_persistence:
		set_status("当前会话不支持本地读档")
		return
	var result := await _request(&"load", {"slot": slot})
	set_status("已读档槽%d" % slot if bool(result.get("ok", false)) else "槽%d读档失败" % slot)
	await _notify_completed(&"load", result)


func _on_export_replay_pressed() -> void:
	if not _supports_persistence:
		set_status("当前会话不支持本地导出")
		return
	var result := await _request(&"export_replay", {})
	set_status("已导出回放" if bool(result.get("ok", false)) else "导出失败")
	await _notify_completed(&"export_replay", result)


func _on_export_battle_trace_pressed() -> void:
	if not _supports_persistence:
		set_status("当前会话不支持本地导出")
		return
	var result := await _request(&"export_battle_trace", {})
	set_status("已导出战报" if bool(result.get("ok", false)) else "导出失败")
	await _notify_completed(&"export_battle_trace", result)


func _request(operation: StringName, arguments: Dictionary) -> Dictionary:
	if not _request_operation.is_valid():
		return {"ok": false, "error": {"code": "PRESENTATION_OPERATION_PORT_MISSING"}}
	return Dictionary(await _request_operation.call(operation, arguments)).duplicate(true)


func _notify_completed(operation: StringName, result: Dictionary) -> void:
	if _operation_completed.is_valid():
		await _operation_completed.call(operation, result.duplicate(true))
