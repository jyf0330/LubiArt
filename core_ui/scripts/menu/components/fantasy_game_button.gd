@tool
class_name FantasyGameButton
extends Control

signal button_pressed

const DESIGN_SIZE := Vector2(290.0, 120.0)
const PIXEL_SIZE := 2.0
const PIXEL_FONT = preload("res://art/images/shared/pets/info_card/fonts/fusion_pixel_zh_hans.ttf")

@export var button_text := "开始游戏":
	set(value):
		button_text = value
		if is_instance_valid(_label):
			_label.text = value

@onready var _label: Label = get_node_or_null("Caption") as Label
var _hovered := false
var _pressed := false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_create_caption()
	queue_redraw()


func _create_caption() -> void:
	if not is_instance_valid(_label):
		push_warning("FantasyGameButton requires a Caption child node.")
		return
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.text = button_text
	_label.size = Vector2(120, 38)
	_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Use the supplied Chinese pixel font, rendered small then enlarged with
	# nearest-neighbour sampling for a crisp, readable title.
	_label.add_theme_font_override("font", PIXEL_FONT)
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color("#b4efff"))
	_label.add_theme_color_override("font_shadow_color", Color("#173f83"))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_constant_override("shadow_outline_size", 1)
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_layout_caption()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var now_hovered := Rect2(Vector2.ZERO, size).has_point(event.position)
		if now_hovered != _hovered:
			_hovered = now_hovered
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_update_caption_position()
			queue_redraw()
		else:
			var activate := _pressed and Rect2(Vector2.ZERO, size).has_point(event.position)
			_pressed = false
			_update_caption_position()
			queue_redraw()
			if activate:
				button_pressed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovered = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovered = false
		_pressed = false
		_update_caption_position()
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		_layout_caption()
		queue_redraw()


func _update_caption_position() -> void:
	_layout_caption()


func _layout_caption() -> void:
	if not is_instance_valid(_label):
		return
	var scale_factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var origin := (size - DESIGN_SIZE * scale_factor) * 0.5
	_label.position = origin + Vector2(25, 25 if _pressed else 23) * scale_factor
	_label.scale = Vector2.ONE * 2.0 * scale_factor


func _draw() -> void:
	var scale_factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var origin := (size - DESIGN_SIZE * scale_factor) * 0.5
	var press_offset := Vector2(0, 2) if _pressed else Vector2.ZERO

	# Everything is drawn on a single 2 px grid.  The nested silhouettes use
	# deliberately stepped corners instead of a smooth polygon with a stroke.
	_pixel_polygon([Vector2(0, 48), Vector2(6, 48), Vector2(6, 38), Vector2(12, 38), Vector2(12, 28), Vector2(18, 28), Vector2(18, 18), Vector2(24, 18), Vector2(24, 8), Vector2(30, 8), Vector2(30, 2), Vector2(260, 2), Vector2(260, 8), Vector2(266, 8), Vector2(266, 18), Vector2(272, 18), Vector2(272, 28), Vector2(278, 28), Vector2(278, 38), Vector2(284, 38), Vector2(284, 48), Vector2(290, 48), Vector2(290, 72), Vector2(284, 72), Vector2(284, 82), Vector2(278, 82), Vector2(278, 92), Vector2(272, 92), Vector2(272, 102), Vector2(266, 102), Vector2(266, 112), Vector2(260, 112), Vector2(260, 118), Vector2(30, 118), Vector2(30, 112), Vector2(24, 112), Vector2(24, 102), Vector2(18, 102), Vector2(18, 92), Vector2(12, 92), Vector2(12, 82), Vector2(6, 82), Vector2(6, 72), Vector2(0, 72)], Color("#140807"), scale_factor, origin + press_offset + Vector2(0, PIXEL_SIZE))
	_pixel_polygon([Vector2(4, 48), Vector2(10, 48), Vector2(10, 38), Vector2(16, 38), Vector2(16, 28), Vector2(22, 28), Vector2(22, 18), Vector2(28, 18), Vector2(28, 8), Vector2(34, 8), Vector2(34, 4), Vector2(256, 4), Vector2(256, 8), Vector2(262, 8), Vector2(262, 18), Vector2(268, 18), Vector2(268, 28), Vector2(274, 28), Vector2(274, 38), Vector2(280, 38), Vector2(280, 48), Vector2(286, 48), Vector2(286, 72), Vector2(280, 72), Vector2(280, 82), Vector2(274, 82), Vector2(274, 92), Vector2(268, 92), Vector2(268, 102), Vector2(262, 102), Vector2(262, 112), Vector2(256, 112), Vector2(256, 116), Vector2(34, 116), Vector2(34, 112), Vector2(28, 112), Vector2(28, 102), Vector2(22, 102), Vector2(22, 92), Vector2(16, 92), Vector2(16, 82), Vector2(10, 82), Vector2(10, 72), Vector2(4, 72)], Color("#b86613"), scale_factor, origin + press_offset)
	_pixel_polygon([Vector2(12, 48), Vector2(18, 48), Vector2(18, 38), Vector2(24, 38), Vector2(24, 28), Vector2(30, 28), Vector2(30, 18), Vector2(36, 18), Vector2(36, 12), Vector2(254, 12), Vector2(254, 18), Vector2(260, 18), Vector2(260, 28), Vector2(266, 28), Vector2(266, 38), Vector2(272, 38), Vector2(272, 48), Vector2(278, 48), Vector2(278, 72), Vector2(272, 72), Vector2(272, 82), Vector2(266, 82), Vector2(266, 92), Vector2(260, 92), Vector2(260, 102), Vector2(254, 102), Vector2(254, 108), Vector2(36, 108), Vector2(36, 102), Vector2(30, 102), Vector2(30, 92), Vector2(24, 92), Vector2(24, 82), Vector2(18, 82), Vector2(18, 72), Vector2(12, 72)], Color("#f0a52b"), scale_factor, origin + press_offset)

	# A thin, broken gold bevel replaces the former even-width concentric strokes.
	for rect in [Rect2(36, 12, 42, 4), Rect2(88, 12, 56, 4), Rect2(154, 12, 64, 4), Rect2(226, 12, 28, 4), Rect2(20, 42, 4, 22), Rect2(266, 48, 4, 20), Rect2(36, 104, 38, 4), Rect2(84, 104, 66, 4), Rect2(160, 104, 58, 4)]:
		_rect(rect, Color("#ffe06b"), scale_factor, origin + press_offset)

	# Keep the original stepped silhouette, but draw it as axis-aligned strips.
	# Godot 4.7 can fail to triangulate these two concave polygons, leaving the
	# orange outer material visible through the button's centre.
	for rect in [Rect2(40, 22, 204, 8), Rect2(34, 30, 216, 10), Rect2(28, 40, 228, 10), Rect2(22, 50, 240, 20), Rect2(28, 70, 228, 10), Rect2(34, 80, 216, 10), Rect2(40, 90, 204, 8)]:
		_rect(rect, Color("#043b66"), scale_factor, origin + press_offset)
	var inner_color := Color("#119fc0") if _hovered else Color("#0b8bb3")
	for rect in [Rect2(48, 28, 194, 4), Rect2(42, 32, 206, 10), Rect2(36, 42, 218, 10), Rect2(30, 52, 230, 16), Rect2(36, 68, 218, 10), Rect2(42, 78, 206, 10), Rect2(48, 88, 194, 4)]:
		_rect(rect, inner_color, scale_factor, origin + press_offset)

	# Short, offset clusters make the material read as pixel-art rather than a UI gradient.
	for rect in [Rect2(50, 30, 44, 4), Rect2(104, 30, 24, 4), Rect2(138, 30, 52, 4), Rect2(200, 30, 28, 4), Rect2(42, 38, 8, 4), Rect2(232, 82, 8, 4), Rect2(224, 86, 8, 4), Rect2(52, 88, 24, 2), Rect2(188, 88, 28, 2)]:
		_rect(rect, Color("#57d6dc"), scale_factor, origin + press_offset)
	for rect in [Rect2(44, 34, 6, 4), Rect2(50, 34, 18, 2), Rect2(222, 34, 14, 2), Rect2(238, 38, 6, 4), Rect2(40, 76, 4, 8), Rect2(246, 72, 4, 8)]:
		_rect(rect, Color("#05749d"), scale_factor, origin + press_offset)
	for point in [Vector2(28, 24), Vector2(256, 24), Vector2(16, 52), Vector2(270, 66), Vector2(28, 92), Vector2(256, 92)]:
		_rect(Rect2(point, Vector2(4, 4)), Color("#fff0a0"), scale_factor, origin + press_offset)


func _pixel_polygon(points: Array, color: Color, scale_factor: float, origin: Vector2) -> void:
	draw_colored_polygon(_scaled_points(points, scale_factor, origin), color)


func _rect(rect: Rect2, color: Color, scale_factor: float, origin: Vector2) -> void:
	draw_rect(Rect2(origin + rect.position * scale_factor, rect.size * scale_factor), color, true, -1.0, false)


func _scaled_points(points: Array, scale_factor: float, origin: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(origin + point * scale_factor)
	return result
