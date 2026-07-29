extends Control

## Read-only battle HUD that mirrors the three action-slot directions for up
## to four player pets. It only presents public Snapshot data; it never derives
## combat rules or writes direction state.

const ROW_COUNT := 4
const SLOT_COUNT := 3
const ROW_SIZE := Vector2(300.0, 110.0)
const ARROW_SIZE := Vector2(64.0, 64.0)
const COLLAPSE_TAB_SIZE := Vector2(110.0, 47.0)
const COLLAPSE_TRIANGLE_SIZE := Vector2(40.0, 40.0)
const EXPANDED_TAB_POSITION := Vector2(95.0, 374.0)
const COLLAPSED_TAB_POSITION := Vector2(95.0, 0.0)

@export var arrow_left_texture: Texture2D
@export var arrow_up_texture: Texture2D
@export var arrow_right_texture: Texture2D
@export var arrow_down_texture: Texture2D

@onready var rows: Control = $Rows
@onready var collapse_button: TextureButton = $CollapseButton
@onready var collapse_triangle: TextureRect = $CollapseButton/Triangle

var _expanded := true
var _display_directions: Array = []


func _ready() -> void:
	collapse_button.pressed.connect(_on_collapse_button_pressed)
	_lock_authored_texture_sizes()
	_apply_expanded_state(false)


func render_snapshot(snapshot: Dictionary) -> void:
	visible = String(snapshot.get("phase", "")) == "battle"
	if not visible:
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
			arrow.tooltip_text = "%s · 第%d槽 · %s" % [unit_name, slot_index + 1, _direction_label(direction)]
		row.tooltip_text = "%s的三个攻击方向" % unit_name
		_display_directions.append({"unit_id": unit_id, "directions": unit_directions})


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
	collapse_button.position = EXPANDED_TAB_POSITION if _expanded else COLLAPSED_TAB_POSITION
	collapse_button.tooltip_text = "收起攻击方向" if _expanded else "展开攻击方向"
	collapse_triangle.pivot_offset = COLLAPSE_TRIANGLE_SIZE * 0.5
	var target_rotation := 0.0 if _expanded else PI
	if animate:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(collapse_triangle, "rotation", target_rotation, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		collapse_triangle.rotation = target_rotation


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
