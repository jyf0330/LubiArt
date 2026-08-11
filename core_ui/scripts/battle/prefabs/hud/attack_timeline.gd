extends Control

## Authored attack timeline presentation. It projects the authoritative shared
## A/B skill control bar and emits one semantic reorder intent after a drag.

signal command_requested(command: Dictionary)
signal order_changed(entry_ids: Array[String])
signal release_preview(entry_id: String, order: int)
signal close_requested

const MARKER_WIDTH := 170.0
const MARKER_Y := 4.0
const MIN_MARKER_X := 32.0
const DRAG_MARKER_Z_INDEX := 100

@onready var marker_layer: Control = $TimelineArea/MarkerLayer
@onready var backdrop: ColorRect = $Backdrop
@onready var playback_cursor: Control = $TimelineArea/PlaybackCursor
@onready var play_button: Button = $PlayButton
@onready var reset_button: Button = $ResetButton
@onready var status_label: Label = $StatusPanel/StatusLabel
@onready var order_label: Label = $OrderLabel

var _markers: Array[Control] = []
var _dragging_marker: Control = null
var _drag_offset_x := 0.0
var _playing := false
var _marker_position_ratios: Dictionary = {}


func _ready() -> void:
	backdrop.gui_input.connect(_on_backdrop_gui_input)
	_markers.assign(marker_layer.get_children().filter(func(child: Node) -> bool:
		return child.name.begins_with("Marker")
	))
	play_button.pressed.connect(_play_sequence)
	reset_button.pressed.connect(_reset_positions)
	for marker in _markers:
		var pet_frame := marker.get_node("PetFrame") as TextureButton
		pet_frame.gui_input.connect(_on_marker_gui_input.bind(marker))
		pet_frame.mouse_entered.connect(_on_marker_mouse_entered.bind(marker))
		pet_frame.mouse_exited.connect(_on_marker_mouse_exited.bind(marker))
	visibility_changed.connect(_on_visibility_changed)
	_reset_positions(false)


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	backdrop.accept_event()
	if get_global_rect().has_point(mouse_event.global_position):
		return
	close_requested.emit()


func _exit_tree() -> void:
	_set_cursor_grabbing(false)


func _game_cursor() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"game_cursor")


func _set_cursor_grabbing(active: bool) -> void:
	var cursor := _game_cursor()
	if cursor != null and cursor.has_method("set_grabbing"):
		cursor.call("set_grabbing", active)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_finish_drag(false)


func _input(event: InputEvent) -> void:
	if _dragging_marker == null:
		return
	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		var local_position := marker_layer.get_global_transform_with_canvas().affine_inverse() * mouse_event.position
		var max_x := maxf(0.0, marker_layer.size.x - MARKER_WIDTH)
		_dragging_marker.position.x = clampf(local_position.x - _drag_offset_x, MIN_MARKER_X, max_x)
		_update_order_badges()
		status_label.text = "正在调整：%s · 松开鼠标确认位置" % _marker_name(_dragging_marker)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_finish_drag()


func render_snapshot(snapshot: Dictionary) -> void:
	_remember_marker_positions()
	var units_by_id := {}
	for unit_value in Array(snapshot.get("units", [])):
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != "player":
			continue
		var unit_id := String(unit.get("id", unit.get("pet_id", "")))
		if unit_id != "":
			units_by_id[unit_id] = unit
	var control_bar := Array(snapshot.get("skillControlBar", snapshot.get("skill_control_bar", [])))
	for index in range(_markers.size()):
		var marker := _markers[index]
		var has_entry := index < control_bar.size()
		marker.visible = has_entry
		if not has_entry:
			marker.set_meta("entry_id", "")
			marker.set_meta("unit_id", "")
			marker.set_meta("skill_slot", "")
			continue
		var entry := Dictionary(control_bar[index])
		var entry_id := String(entry.get("entryId", entry.get("entry_id", ""))).strip_edges()
		var unit_id := String(entry.get("unitId", entry.get("unit_id", ""))).strip_edges()
		var skill_slot := String(entry.get("skillSlot", entry.get("skill_slot", ""))).strip_edges().to_lower()
		var unit := Dictionary(units_by_id.get(unit_id, {})).duplicate(true)
		unit["id"] = unit_id
		unit["name"] = String(entry.get("unitName", entry.get("unit_name", unit.get("name", "精灵"))))
		var slot_label := skill_slot.to_upper()
		var skill_label := String(entry.get("label", entry.get("skillId", entry.get("skill_id", slot_label))))
		marker.set_meta("entry_id", entry_id)
		marker.set_meta("unit_id", unit_id)
		marker.set_meta("skill_slot", skill_slot)
		marker.set_meta("marker_name", "%s %s" % [String(unit["name"]), slot_label])
		(marker.get_node("NameLabel") as Label).text = "%s · %s" % [slot_label, skill_label]
		var pet_frame := marker.get_node("PetFrame") as TextureButton
		if pet_frame.has_method("configure"):
			pet_frame.call("configure", unit)
	_restore_or_initialize_positions()
	play_button.disabled = _visible_markers().is_empty()
	reset_button.disabled = _visible_markers().is_empty()


func set_interaction_locked(locked: bool) -> void:
	if locked:
		_finish_drag(false)
	play_button.disabled = locked or _visible_markers().is_empty()
	reset_button.disabled = locked or _visible_markers().is_empty()
	for marker in _markers:
		(marker.get_node("PetFrame") as TextureButton).disabled = locked


func _on_marker_gui_input(event: InputEvent, marker: Control) -> void:
	if _playing or not marker.visible:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_dragging_marker = marker
			_drag_offset_x = marker.get_local_mouse_position().x
			_sync_marker_stack_order(_sorted_markers())
			_set_cursor_grabbing(true)
			(marker.get_node("PetFrame") as TextureButton).call("set_drag_visual", true)
			_animate_marker_scale(marker, Vector2(1.06, 1.06), 0.08)
			status_label.text = "正在调整：%s · 拖到时间轴任意位置" % _marker_name(marker)


func _finish_drag(emit_change: bool = true) -> void:
	if _dragging_marker == null:
		return
	var marker := _dragging_marker
	_dragging_marker = null
	_set_cursor_grabbing(false)
	(marker.get_node("PetFrame") as TextureButton).call("set_drag_visual", false)
	_animate_marker_scale(marker, Vector2.ONE, 0.10)
	_remember_marker_positions()
	_update_order_badges()
	status_label.text = "顺序已更新 · 可继续拖动调整"
	if emit_change:
		_emit_order_intent()


func _emit_order_intent() -> void:
	var ordered_entry_ids := debug_order_ids()
	order_changed.emit(ordered_entry_ids)
	command_requested.emit({
		"type": "SET_SKILL_CONTROL_ORDER",
		"orderedEntryIds": ordered_entry_ids,
	})


func _on_marker_mouse_entered(marker: Control) -> void:
	if _playing or _dragging_marker != null or not marker.visible:
		return
	_animate_marker_scale(marker, Vector2(1.035, 1.035), 0.10)
	status_label.text = "拖动 %s 调整它的释放时机" % _marker_name(marker)


func _on_marker_mouse_exited(marker: Control) -> void:
	if _playing or marker == _dragging_marker:
		return
	_animate_marker_scale(marker, Vector2.ONE, 0.10)


func _animate_marker_scale(marker: Control, target: Vector2, duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(marker, "scale", target, duration)


func _reset_positions(update_status: bool = true) -> void:
	if _playing:
		return
	_finish_drag(false)
	var max_x := maxf(0.0, marker_layer.size.x - MARKER_WIDTH)
	var visible_markers := _visible_markers()
	for index in range(visible_markers.size()):
		var marker := visible_markers[index]
		var ratio := float(index) / float(visible_markers.size() - 1) if visible_markers.size() > 1 else 0.5
		marker.position = Vector2(roundf(lerpf(MIN_MARKER_X, max_x, ratio)), MARKER_Y)
		marker.scale = Vector2.ONE
		marker.modulate = Color.WHITE
	playback_cursor.visible = false
	_remember_marker_positions()
	if update_status:
		status_label.text = "拖动任意精灵到时间轴上的位置"
	_update_order_badges()


func _restore_or_initialize_positions() -> void:
	var max_x := _max_marker_x()
	var visible_markers := _visible_markers()
	for index in range(visible_markers.size()):
		var marker := visible_markers[index]
		var entry_id := String(marker.get_meta("entry_id", ""))
		var default_ratio := (
			float(index) / float(visible_markers.size() - 1)
			if visible_markers.size() > 1
			else 0.5
		)
		var ratio := clampf(float(_marker_position_ratios.get(entry_id, default_ratio)), 0.0, 1.0)
		marker.position = Vector2(lerpf(MIN_MARKER_X, max_x, ratio), MARKER_Y)
		marker.scale = Vector2.ONE
		marker.modulate = Color.WHITE
	playback_cursor.visible = false
	_remember_marker_positions()
	_update_order_badges()


func _remember_marker_positions() -> void:
	var max_x := _max_marker_x()
	var travel := maxf(0.0, max_x - MIN_MARKER_X)
	for marker in _visible_markers():
		var entry_id := String(marker.get_meta("entry_id", ""))
		if entry_id.is_empty():
			continue
		var ratio := 0.0 if is_zero_approx(travel) else (marker.position.x - MIN_MARKER_X) / travel
		_marker_position_ratios[entry_id] = clampf(ratio, 0.0, 1.0)


func _max_marker_x() -> float:
	return maxf(MIN_MARKER_X, marker_layer.size.x - MARKER_WIDTH)


func _visible_markers() -> Array[Control]:
	var result: Array[Control] = []
	for marker in _markers:
		if marker.visible:
			result.append(marker)
	return result


func _sorted_markers() -> Array[Control]:
	var ordered := _visible_markers()
	ordered.sort_custom(func(a: Control, b: Control) -> bool:
		if is_equal_approx(a.position.x, b.position.x):
			return String(a.get_meta("entry_id", "")) < String(b.get_meta("entry_id", ""))
		return a.position.x < b.position.x
	)
	return ordered


func _update_order_badges() -> void:
	var ordered := _sorted_markers()
	_sync_marker_stack_order(ordered)
	var names: Array[String] = []
	for index in range(ordered.size()):
		var marker := ordered[index]
		(marker.get_node("OrderBadge") as Label).text = str(index + 1)
		names.append(_marker_name(marker))
	order_label.text = "释放顺序　" + "  →  ".join(names) if not names.is_empty() else "暂无可用精灵"


func _sync_marker_stack_order(ordered: Array[Control]) -> void:
	for index in range(ordered.size()):
		ordered[index].z_index = index
	if _dragging_marker != null and is_instance_valid(_dragging_marker):
		_dragging_marker.z_index = DRAG_MARKER_Z_INDEX


func _play_sequence() -> void:
	if _playing or _visible_markers().is_empty():
		return
	_finish_drag(false)
	_playing = true
	set_interaction_locked(true)
	playback_cursor.visible = true
	playback_cursor.modulate.a = 1.0
	playback_cursor.position.x = 54.0
	status_label.text = "演示开始 · 按时间轴从左向右释放"
	var ordered := _sorted_markers()
	for index in range(ordered.size()):
		var marker := ordered[index]
		var target_x := marker.position.x + marker.size.x * 0.5 - playback_cursor.size.x * 0.5
		var distance := absf(target_x - playback_cursor.position.x)
		var move_tween := create_tween()
		move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		move_tween.tween_property(playback_cursor, "position:x", target_x, maxf(0.18, distance / 880.0))
		await move_tween.finished
		await _release_marker(marker, index + 1)
	status_label.text = "演示完成 · 可继续拖动精灵调整顺序"
	var fade_tween := create_tween()
	fade_tween.tween_property(playback_cursor, "modulate:a", 0.0, 0.25)
	await fade_tween.finished
	playback_cursor.visible = false
	playback_cursor.modulate.a = 1.0
	_playing = false
	set_interaction_locked(false)


func _release_marker(marker: Control, order: int) -> void:
	status_label.text = "第 %d 位释放：%s" % [order, _marker_name(marker)]
	release_preview.emit(String(marker.get_meta("entry_id", "")), order)
	var pet_frame := marker.get_node("PetFrame") as TextureButton
	var pulse := create_tween()
	pulse.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_parallel(true)
	pulse.tween_property(marker, "scale", Vector2(1.13, 1.13), 0.14)
	pulse.tween_property(pet_frame, "modulate", Color("fff0a6"), 0.10)
	await pulse.finished
	var settle := create_tween()
	settle.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_parallel(true)
	settle.tween_property(marker, "scale", Vector2.ONE, 0.26)
	settle.tween_property(pet_frame, "modulate", Color.WHITE, 0.20)
	await settle.finished
	await get_tree().create_timer(0.08).timeout


func _marker_name(marker: Control) -> String:
	return String(marker.get_meta("marker_name", "精灵"))


func debug_marker_count() -> int:
	return _visible_markers().size()


func debug_set_marker_position(entry_or_unit_id: String, normalized_position: float, attack_index: int = 0) -> bool:
	for marker in _markers:
		var expected_entry_id := entry_or_unit_id
		if not expected_entry_id.contains(":"):
			expected_entry_id = "%s:%s" % [entry_or_unit_id, "a" if attack_index == 0 else "b"]
		if String(marker.get_meta("entry_id", "")) != expected_entry_id:
			continue
		var max_x := maxf(0.0, marker_layer.size.x - MARKER_WIDTH)
		marker.position.x = lerpf(MIN_MARKER_X, max_x, clampf(normalized_position, 0.0, 1.0))
		_remember_marker_positions()
		_update_order_badges()
		return true
	return false


func debug_marker_position(entry_id: String) -> float:
	for marker in _markers:
		if String(marker.get_meta("entry_id", "")) != entry_id:
			continue
		var travel := maxf(0.0, _max_marker_x() - MIN_MARKER_X)
		return 0.0 if is_zero_approx(travel) else (marker.position.x - MIN_MARKER_X) / travel
	return -1.0


func debug_order_ids() -> Array[String]:
	var result: Array[String] = []
	for marker in _sorted_markers():
		result.append(String(marker.get_meta("entry_id", "")))
	return result


func debug_commit_order() -> void:
	_emit_order_intent()


func debug_play_sequence() -> void:
	_play_sequence()
