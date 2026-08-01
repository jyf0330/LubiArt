extends Control

signal command_requested(command: Dictionary)
signal direction_preview_changed(preview: Dictionary)

## Battle HUD that mirrors the three action-slot directions for up to four
## player pets. Mouse-wheel input only requests a public direction command; it
## never derives combat rules.

const ROW_COUNT := 4
const SLOT_COUNT := 3
const ROW_SIZE := Vector2(300.0, 110.0)
const ROW_VERTICAL_STEP := 91.0
const ARROW_SIZE := Vector2(64.0, 64.0)
const COLLAPSE_TAB_SIZE := Vector2(110.0, 47.0)
const COLLAPSE_TRIANGLE_SIZE := Vector2(40.0, 40.0)
const SCROLL_HINT_SIZE := Vector2(48.0, 48.0)
const SCROLL_HINT_OFFSET := Vector2(18.0, 18.0)
const EXPANDED_TAB_POSITION := Vector2(95.0, 374.0)
const COLLAPSED_TAB_POSITION := Vector2(95.0, 0.0)
const CLOCKWISE_DIRECTIONS: Array[String] = ["up", "right", "down", "left"]

@export var arrow_left_texture: Texture2D
@export var arrow_up_texture: Texture2D
@export var arrow_right_texture: Texture2D
@export var arrow_down_texture: Texture2D

@onready var rows: Control = $Rows
@onready var row_template: Control = $Rows/Row1
@onready var collapse_button: TextureButton = $CollapseButton
@onready var collapse_triangle: TextureRect = $CollapseButton/Triangle
@onready var scroll_hint: TextureRect = $ScrollHint
@onready var scroll_hint_highlight: TextureRect = $ScrollHint/WheelHighlight
@onready var scroll_hint_animation: AnimationPlayer = $ScrollHint/AnimationPlayer

var _expanded := true
var _display_directions: Array = []
var _hovered_arrow: TextureRect = null
var _hovered_row_index := -1
var _hovered_slot_index := -1


func _ready() -> void:
	collapse_button.pressed.connect(_on_collapse_button_pressed)
	_create_runtime_rows()
	_bind_arrow_hover_signals()
	_lock_authored_texture_sizes()
	_hide_scroll_hint()
	_apply_expanded_state(false)
	set_process(true)


func _process(_delta: float) -> void:
	if _hovered_arrow == null or not scroll_hint.visible:
		return
	_update_scroll_hint_position()


func render_snapshot(snapshot: Dictionary) -> void:
	visible = String(snapshot.get("phase", "")) == "battle"
	if not visible:
		_hide_scroll_hint()
		return
	var player_units := _player_units(snapshot)
	var action_dirs := Dictionary(snapshot.get("action_dirs", snapshot.get("actionDirs", {})))
	var previews := Dictionary(snapshot.get("action_preview_by_unit", snapshot.get("actionPreviewByUnit", {})))
	_display_directions.clear()
	for row_index in range(ROW_COUNT):
		var row := rows.get_node("Row%d" % (row_index + 1)) as Control
		row.visible = row_index < player_units.size()
		if not row.visible:
			continue
		var unit := Dictionary(player_units[row_index])
		var unit_id := String(unit.get("id", unit.get("unitId", "")))
		var unit_name := String(unit.get("name", unit_id))
		var unit_directions: Array[String] = []
		for slot_index in range(SLOT_COUNT):
			var direction := _direction_for_slot(unit, unit_id, slot_index, action_dirs, previews)
			unit_directions.append(direction)
			var arrow := row.get_node("Arrow%d" % (slot_index + 1)) as TextureRect
			arrow.texture = _texture_for_direction(direction)
			arrow.tooltip_text = _arrow_tooltip(unit_name, slot_index, direction)
		row.tooltip_text = "%s的三个攻击方向" % unit_name
		_display_directions.append({
			"unit_id": unit_id,
			"unit_name": unit_name,
			"directions": unit_directions,
		})
	_emit_hovered_direction_preview()


func is_expanded() -> bool:
	return _expanded


func debug_display_directions() -> Array:
	return _display_directions.duplicate(true)


func debug_locked_sizes() -> Dictionary:
	return {
		"row": ($Rows/Row1/Background as TextureRect).size,
		"arrow": ($Rows/Row1/Arrow1 as TextureRect).size,
		"collapse_tab": collapse_button.size,
		"collapse_triangle": collapse_triangle.size,
	}


func _on_collapse_button_pressed() -> void:
	_expanded = not _expanded
	_apply_expanded_state(true)


func _apply_expanded_state(animate: bool) -> void:
	rows.visible = _expanded
	if not _expanded:
		_hide_scroll_hint()
	collapse_button.position = EXPANDED_TAB_POSITION if _expanded else COLLAPSED_TAB_POSITION
	collapse_button.tooltip_text = "收起攻击方向" if _expanded else "展开攻击方向"
	collapse_triangle.pivot_offset = COLLAPSE_TRIANGLE_SIZE * 0.5
	var target_rotation := 0.0 if _expanded else PI
	if animate:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(collapse_triangle, "rotation", target_rotation, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		collapse_triangle.rotation = target_rotation


func _create_runtime_rows() -> void:
	for row_index in range(1, ROW_COUNT):
		var row := row_template.duplicate() as Control
		row.name = "Row%d" % (row_index + 1)
		row.position = row_template.position + Vector2(0.0, ROW_VERTICAL_STEP * row_index)
		rows.add_child(row)


func _bind_arrow_hover_signals() -> void:
	for row_index in range(ROW_COUNT):
		var row := rows.get_node("Row%d" % (row_index + 1)) as Control
		for slot_index in range(SLOT_COUNT):
			var arrow := row.get_node("Arrow%d" % (slot_index + 1)) as TextureRect
			arrow.mouse_filter = Control.MOUSE_FILTER_STOP
			arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			arrow.mouse_entered.connect(_on_arrow_mouse_entered.bind(arrow, row_index, slot_index))
			arrow.mouse_exited.connect(_on_arrow_mouse_exited.bind(arrow))
			arrow.gui_input.connect(_on_arrow_gui_input.bind(row_index, slot_index))


func _on_arrow_gui_input(event: InputEvent, row_index: int, slot_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed \
			or mouse_event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return
	if row_index < 0 or row_index >= _display_directions.size():
		return
	var row_state := Dictionary(_display_directions[row_index]).duplicate(true)
	var directions := Array(row_state.get("directions", [])).duplicate()
	if slot_index < 0 or slot_index >= directions.size():
		return
	var current := _normalized_direction(String(directions[slot_index]))
	var step := 1 if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
	var wheel_steps: int = max(1, int(round(abs(mouse_event.factor))))
	var next := current
	for _index in range(wheel_steps):
		next = _rotated_direction(next, step)
	directions[slot_index] = next
	row_state["directions"] = directions
	_display_directions[row_index] = row_state

	var arrow := rows.get_node("Row%d/Arrow%d" % [row_index + 1, slot_index + 1]) as TextureRect
	arrow.texture = _texture_for_direction(next)
	arrow.tooltip_text = _arrow_tooltip(String(row_state.get("unit_name", "")), slot_index, next)
	arrow.accept_event()
	if _hovered_arrow == arrow:
		_emit_hovered_direction_preview()
	command_requested.emit({
		"type": "SET_ACTION_DIRECTION",
		"unitId": String(row_state.get("unit_id", "")),
		"slotId": slot_index,
		"dir": next,
	})


func _on_arrow_mouse_entered(arrow: TextureRect, row_index: int, slot_index: int) -> void:
	_hovered_arrow = arrow
	_hovered_row_index = row_index
	_hovered_slot_index = slot_index
	scroll_hint.visible = true
	scroll_hint_animation.play(&"scroll_hint_blink")
	_update_scroll_hint_position()
	_emit_hovered_direction_preview()


func _on_arrow_mouse_exited(arrow: TextureRect) -> void:
	if _hovered_arrow == arrow:
		_hide_scroll_hint()


func _hide_scroll_hint() -> void:
	var had_hovered_arrow := _hovered_arrow != null
	_hovered_arrow = null
	_hovered_row_index = -1
	_hovered_slot_index = -1
	scroll_hint.visible = false
	scroll_hint_animation.stop()
	scroll_hint_highlight.modulate.a = 1.0
	if had_hovered_arrow:
		direction_preview_changed.emit({})


func _emit_hovered_direction_preview() -> void:
	if _hovered_arrow == null \
			or _hovered_row_index < 0 \
			or _hovered_row_index >= _display_directions.size():
		return
	var row_state := Dictionary(_display_directions[_hovered_row_index])
	var directions := Array(row_state.get("directions", []))
	if _hovered_slot_index < 0 or _hovered_slot_index >= directions.size():
		return
	direction_preview_changed.emit({
		"unit_id": String(row_state.get("unit_id", "")),
		"slot_index": _hovered_slot_index,
		"direction": _normalized_direction(String(directions[_hovered_slot_index])),
	})


func _update_scroll_hint_position() -> void:
	var viewport_size := get_viewport_rect().size
	var target_global_position := get_global_mouse_position() + SCROLL_HINT_OFFSET
	target_global_position.x = clampf(target_global_position.x, 0.0, maxf(0.0, viewport_size.x - SCROLL_HINT_SIZE.x))
	target_global_position.y = clampf(target_global_position.y, 0.0, maxf(0.0, viewport_size.y - SCROLL_HINT_SIZE.y))
	scroll_hint.global_position = target_global_position


func _lock_authored_texture_sizes() -> void:
	for row_index in range(ROW_COUNT):
		var row := rows.get_node("Row%d" % (row_index + 1)) as Control
		row.custom_minimum_size = ROW_SIZE
		row.size = ROW_SIZE
		_lock_control_size(row.get_node("Background") as Control, ROW_SIZE)
		for slot_index in range(SLOT_COUNT):
			_lock_control_size(row.get_node("Arrow%d" % (slot_index + 1)) as Control, ARROW_SIZE)
	_lock_control_size(collapse_button, COLLAPSE_TAB_SIZE)
	_lock_control_size(collapse_triangle, COLLAPSE_TRIANGLE_SIZE)
	_lock_control_size(scroll_hint, SCROLL_HINT_SIZE)
	_lock_control_size(scroll_hint_highlight, SCROLL_HINT_SIZE)


func _lock_control_size(control: Control, locked_size: Vector2) -> void:
	control.custom_minimum_size = locked_size
	control.size = locked_size


func _player_units(snapshot: Dictionary) -> Array:
	var result: Array = []
	for value in Array(snapshot.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("side", unit.get("unitSide", ""))) != "player":
			continue
		if not bool(unit.get("active", true)):
			continue
		result.append(unit)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_slot := int(a.get("slot", 999))
		var b_slot := int(b.get("slot", 999))
		if a_slot == b_slot:
			return String(a.get("id", "")) < String(b.get("id", ""))
		return a_slot < b_slot
	)
	if result.size() > ROW_COUNT:
		result.resize(ROW_COUNT)
	return result


func _direction_for_slot(
	unit: Dictionary,
	unit_id: String,
	slot_index: int,
	action_dirs: Dictionary,
	previews: Dictionary
) -> String:
	var key := "%s:slot%d" % [unit_id, slot_index]
	if action_dirs.has(key):
		return _normalized_direction(String(action_dirs[key]))
	var slots := Array(unit.get("action_slots", unit.get("actionSlots", unit.get("slots", []))))
	if slot_index < slots.size():
		return _normalized_direction(String(Dictionary(slots[slot_index]).get("direction", "right")))
	if slot_index == 0 and previews.has(unit_id):
		return _normalized_direction(String(Dictionary(previews[unit_id]).get("direction", "right")))
	return "right"


func _normalized_direction(direction: String) -> String:
	var value := direction.to_lower()
	return value if value in ["left", "up", "right", "down"] else "right"


func _texture_for_direction(direction: String) -> Texture2D:
	match direction:
		"left":
			return arrow_left_texture
		"up":
			return arrow_up_texture
		"down":
			return arrow_down_texture
		_:
			return arrow_right_texture


func _direction_label(direction: String) -> String:
	return {"left": "向左", "up": "向上", "right": "向右", "down": "向下"}.get(direction, "向右")


func _rotated_direction(direction: String, step: int) -> String:
	var index := CLOCKWISE_DIRECTIONS.find(_normalized_direction(direction))
	return CLOCKWISE_DIRECTIONS[posmod(index + step, CLOCKWISE_DIRECTIONS.size())]


func _arrow_tooltip(unit_name: String, slot_index: int, direction: String) -> String:
	return "%s · 第%d槽 · %s\n滚轮向下顺时针，向上逆时针" % [
		unit_name,
		slot_index + 1,
		_direction_label(direction),
	]
