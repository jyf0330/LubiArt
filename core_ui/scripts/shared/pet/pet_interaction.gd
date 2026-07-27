extends Node
class_name PetInteraction

var _view: Control = null
var _frame: TextureRect = null
var _context := &"none"
var _side := ""
var _unit_id := ""
var _selected := false
var _dragging := false


func configure(view: Control, frame: TextureRect) -> void:
	_view = view
	_frame = frame
	reset()


func reset() -> void:
	_context = &"none"
	_side = ""
	_unit_id = ""
	_selected = false
	_dragging = false
	if _view != null:
		_view.visible = true
		_view.modulate = Color.WHITE
		_view.z_index = 0
	if _frame != null:
		_frame.modulate = Color.WHITE


func bind_context(context: StringName, unit_side: String, unit_id: String) -> void:
	_context = context
	_side = unit_side
	_unit_id = unit_id


func set_selected(selected: bool) -> void:
	_selected = selected
	if _frame != null:
		_frame.modulate = Color(1.0, 0.92, 0.45, 1.0) if selected else Color.WHITE


func set_dragging(is_dragging: bool) -> void:
	_dragging = is_dragging
	if _view == null:
		return
	_view.visible = not is_dragging
	_view.modulate.a = 0.62 if is_dragging else 1.0
	_view.z_index = 40 if is_dragging else 0


func snapshot() -> Dictionary:
	return {
		"context": String(_context),
		"side": _side,
		"unit_id": _unit_id,
		"selected": _selected,
		"dragging": _dragging
	}
