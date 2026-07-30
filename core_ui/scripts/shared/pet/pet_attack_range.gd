extends Control
class_name PetAttackRange

const MAX_ACTION_BLOCKS := 3
const ATTACK_RANGE_RED := Color("ff3b30")
const ATTACK_RANGE_TEXTURE := preload("res://art/images/shared/pets/battle_complete/attack_range_cell.png")

var _markers: Array[TextureRect] = []
var _visible_offsets: Array[Vector2i] = []
var _range_texture: Texture2D = ATTACK_RANGE_TEXTURE
var _render_cell_size := Vector2.ZERO
var _origin_grid := Vector2i(-1, -1)
var _uses_board_canvas := false
var _board_global_position := Vector2.ZERO
var _board_geometry: Dictionary = {}
var _overlay_layer: CanvasLayer = null
var _overlay_root: Control = null
var _overlay_markers: Array[TextureRect] = []


func _ready() -> void:
	_resolve_markers()
	reset()


func reset() -> void:
	_visible_offsets.clear()
	_render_cell_size = Vector2.ZERO
	_origin_grid = Vector2i(-1, -1)
	_uses_board_canvas = false
	_board_global_position = Vector2.ZERO
	_board_geometry = {}
	for marker in _markers:
		marker.visible = false
		marker.modulate = ATTACK_RANGE_RED
	for marker in _overlay_markers:
		marker.visible = false
	if _overlay_root != null:
		_overlay_root.visible = false
	visible = false
	queue_redraw()


func show_action_block_ranges(
	ranges: Array,
	grid_cell_size: Vector2 = Vector2.ZERO,
	origin_grid: Vector2i = Vector2i(-1, -1),
	board_size: Vector2 = Vector2.ZERO,
	board_global_position: Vector2 = Vector2.ZERO,
	board_geometry: Dictionary = {}
) -> void:
	_resolve_markers()
	_render_cell_size = grid_cell_size if grid_cell_size.x > 0.0 and grid_cell_size.y > 0.0 else size
	_origin_grid = origin_grid
	_board_global_position = board_global_position
	_board_geometry = board_geometry.duplicate(true)
	_uses_board_canvas = (
		origin_grid.x >= 0
		and origin_grid.y >= 0
		and board_size.x > 0.0
		and board_size.y > 0.0
	)
	if _uses_board_canvas:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		position = -Vector2(origin_grid.x * _render_cell_size.x, origin_grid.y * _render_cell_size.y)
		size = board_size
	var unique_offsets: Dictionary = {}
	for block_index in range(mini(MAX_ACTION_BLOCKS, ranges.size())):
		var block := Dictionary(ranges[block_index])
		if not bool(block.get("available", not bool(block.get("used", false)))):
			continue
		var origin := Dictionary(block.get("origin", {}))
		for cell_value in Array(block.get("cells", [])):
			var offset := _relative_offset(Dictionary(cell_value), origin)
			if offset == Vector2i.ZERO:
				continue
			unique_offsets[_offset_key(offset)] = offset
	var offsets: Array[Vector2i] = []
	for value in unique_offsets.values():
		offsets.append(value as Vector2i)
	offsets.sort_custom(func(a: Vector2i, b: Vector2i):
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	_visible_offsets.clear()
	for offset in offsets:
		_visible_offsets.append(offset)
	_layout_markers()


func snapshot() -> Dictionary:
	var cells: Array[Dictionary] = []
	for offset in _visible_offsets:
		cells.append({"x": offset.x, "y": offset.y})
	return {
		"actionBlockLimit": MAX_ACTION_BLOCKS,
		"color": ATTACK_RANGE_RED,
		"visibleCellCount": _visible_offsets.size(),
		"overlayVisibleMarkerCount": _overlay_visible_marker_count(),
		"renderMode": "front_target_cell_red_overlay" if _uses_board_canvas else "front_target_cell_canvas",
		"cells": cells,
	}


func _draw() -> void:
	if _range_texture == null or _uses_board_canvas:
		return
	var cell_size := _render_cell_size if _render_cell_size.x > 0.0 and _render_cell_size.y > 0.0 else size
	for offset in _visible_offsets:
		var target_grid := offset
		if _uses_board_canvas:
			target_grid += _origin_grid
		var target_rect := Rect2(
			Vector2(target_grid.x * cell_size.x, target_grid.y * cell_size.y),
			cell_size
		)
		draw_texture_rect(
			_range_texture,
			target_rect,
			false,
			ATTACK_RANGE_RED
		)
		draw_rect(target_rect.grow(-2.0), ATTACK_RANGE_RED, false, 4.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_markers()


func _resolve_markers() -> void:
	if not _markers.is_empty():
		return
	for direction_name in ["up", "front", "down", "left"]:
		var direction_root := get_node_or_null(direction_name)
		if direction_root == null:
			continue
		for child in direction_root.get_children():
			if child is TextureRect:
				var marker := child as TextureRect
				_markers.append(marker)
				if _range_texture == null:
					_range_texture = marker.texture


func _layout_markers() -> void:
	for marker in _markers:
		marker.visible = false
	if _uses_board_canvas:
		_layout_board_overlay()
	elif _overlay_root != null:
		_overlay_root.visible = false
	visible = not _visible_offsets.is_empty()
	queue_redraw()


func _layout_board_overlay() -> void:
	_ensure_board_overlay(_visible_offsets.size())
	for marker_index in range(_overlay_markers.size()):
		var marker := _overlay_markers[marker_index]
		if marker_index >= _visible_offsets.size():
			marker.visible = false
			continue
		var target_grid := _origin_grid + _visible_offsets[marker_index]
		var target_geometry := Dictionary(_board_geometry.get(_offset_key(target_grid), {}))
		if target_geometry.is_empty():
			marker.position = _board_global_position + Vector2(
				target_grid.x * _render_cell_size.x,
				target_grid.y * _render_cell_size.y
			)
			marker.size = _render_cell_size
		else:
			marker.position = Vector2(target_geometry.get("position", Vector2.ZERO))
			marker.size = Vector2(target_geometry.get("size", _render_cell_size))
		marker.visible = true
	if _overlay_root != null:
		_overlay_root.visible = not _visible_offsets.is_empty()


func _ensure_board_overlay(required_marker_count: int) -> void:
	if _overlay_layer == null:
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.name = "AttackRangeCanvas"
		_overlay_layer.layer = 35
		add_child(_overlay_layer)
		_overlay_root = Control.new()
		_overlay_root.name = "RedAttackRangeOverlay"
		_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay_layer.add_child(_overlay_root)
	while _overlay_markers.size() < required_marker_count:
		var marker_index := _overlay_markers.size()
		var marker := TextureRect.new()
		marker.name = "RedTarget_%02d" % marker_index
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.texture = _range_texture
		marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		marker.stretch_mode = TextureRect.STRETCH_SCALE
		marker.modulate = ATTACK_RANGE_RED
		marker.visible = false
		_overlay_root.add_child(marker)
		_overlay_markers.append(marker)


func _overlay_visible_marker_count() -> int:
	var count := 0
	for marker in _overlay_markers:
		if marker.visible:
			count += 1
	return count


func _relative_offset(cell: Dictionary, origin: Dictionary) -> Vector2i:
	if cell.has("dc") or cell.has("dr"):
		return Vector2i(int(cell.get("dc", 0)), int(cell.get("dr", 0)))
	var origin_x := int(origin.get("x", origin.get("c", 0)))
	var origin_y := int(origin.get("y", origin.get("r", 0)))
	return Vector2i(
		int(cell.get("x", cell.get("c", origin_x))) - origin_x,
		int(cell.get("y", cell.get("r", origin_y))) - origin_y
	)


func _offset_key(offset: Vector2i) -> String:
	return "%d:%d" % [offset.x, offset.y]
