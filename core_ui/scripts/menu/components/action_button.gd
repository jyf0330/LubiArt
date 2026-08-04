@tool
class_name ActionButton
extends Control

signal button_pressed(action: ActionType)

enum ActionType {
	AUTO,
	SPEED,
	MENU,
	SETTINGS,
	ADD,
	BACK,
	CLOSE,
	REFRESH,
	BLANK,
}

const DESIGN_SIZE := Vector2(64.0, 64.0)
@export var action_type: ActionType = ActionType.AUTO:
	set(value):
		action_type = value
		tooltip_text = _action_name()
		queue_redraw()
@export_group("Auto Toggle")
@export var auto_enabled_mark_color := Color("#ffe06b")
@export var auto_disabled_mark_color := Color("#8b929c")
@export_group("Speed Indicator")
@export_range(1, 3, 1) var speed_multiplier := 1:
	set(value):
		speed_multiplier = clampi(value, 1, 3)
		tooltip_text = _action_name()
		queue_redraw()
@export var speed_active_mark_color := Color("#ffe06b")

var _hovered := false
var _pressed := false
var _active := false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = _action_name()
	queue_redraw()


func set_active(active: bool) -> void:
	_active = active
	queue_redraw()


func is_active() -> bool:
	return _active


func set_speed_multiplier(multiplier: int) -> void:
	speed_multiplier = multiplier


func get_speed_multiplier() -> int:
	return speed_multiplier


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			queue_redraw()
		else:
			var activate := _pressed and Rect2(Vector2.ZERO, size).has_point(event.position)
			_pressed = false
			queue_redraw()
			if activate:
				button_pressed.emit(action_type)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovered = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovered = false
		_pressed = false
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var scale_factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var origin := (size - DESIGN_SIZE * scale_factor) * 0.5
	var press_offset := Vector2(0, 2) if _pressed else Vector2.ZERO

	_draw_classic_frame(scale_factor, origin + press_offset)

	match action_type:
		ActionType.AUTO:
			_draw_auto_icon(scale_factor, origin + press_offset)
		ActionType.SPEED:
			if speed_multiplier <= 1:
				_draw_speed_icon(scale_factor, origin + press_offset)
			else:
				_draw_speed_multiplier(scale_factor, origin + press_offset)
		ActionType.MENU:
			_draw_menu_icon(scale_factor, origin + press_offset)
		ActionType.SETTINGS:
			_draw_settings_icon(scale_factor, origin + press_offset)
		ActionType.ADD:
			_draw_add_icon(scale_factor, origin + press_offset)
		ActionType.BACK:
			_draw_back_icon(scale_factor, origin + press_offset)
		ActionType.CLOSE:
			_draw_close_icon(scale_factor, origin + press_offset)
		ActionType.REFRESH:
			_draw_refresh_icon(scale_factor, origin + press_offset)
		ActionType.BLANK:
			pass


func _draw_classic_frame(scale_factor: float, origin: Vector2) -> void:
	# The stepped octagon and colour sequence deliberately match StartGameButton.
	_pixel_polygon(_octagon(0), Color("#140807"), scale_factor, origin + Vector2(0, 2))
	_pixel_polygon(_octagon(2), Color("#b86613"), scale_factor, origin)
	_pixel_polygon(_octagon(5), Color("#f0a52b"), scale_factor, origin)
	_pixel_polygon(_octagon(9), Color("#043b66"), scale_factor, origin)
	_pixel_polygon(_octagon(12), Color("#119fc0") if _hovered else Color("#0b8bb3"), scale_factor, origin)
	for rect in [Rect2(18, 5, 12, 2), Rect2(34, 5, 12, 2), Rect2(5, 20, 2, 10), Rect2(8, 14, 3, 6)]:
		_rect(rect, Color("#ffe06b"), scale_factor, origin)
	for rect in [Rect2(25, 14, 9, 2), Rect2(37, 15, 5, 2), Rect2(20, 17, 5, 2), Rect2(17, 21, 2, 4), Rect2(15, 27, 2, 3)]:
		_rect(rect, Color("#57d6dc"), scale_factor, origin)


func _draw_settings_icon(scale_factor: float, origin: Vector2) -> void:
	# Compact 8-tooth gear assembled from square clusters for a hard pixel edge.
	_draw_mark([
		Rect2(29, 20, 6, 4), Rect2(29, 40, 6, 4),
		Rect2(20, 29, 4, 6), Rect2(40, 29, 4, 6),
		Rect2(23, 23, 5, 5), Rect2(36, 23, 5, 5),
		Rect2(23, 36, 5, 5), Rect2(36, 36, 5, 5),
		Rect2(28, 23, 8, 18), Rect2(23, 28, 18, 8),
		Rect2(25, 25, 14, 14),
	], scale_factor, origin)
	var hole_color := Color("#119fc0") if _hovered else Color("#0b8bb3")
	_rect(Rect2(29, 29, 6, 6), hole_color, scale_factor, origin)


func _draw_auto_icon(scale_factor: float, origin: Vector2) -> void:
	var mark_color := auto_enabled_mark_color if _active else auto_disabled_mark_color
	_draw_mark(
		[Rect2(30, 21, 4, 3), Rect2(27, 24, 3, 5), Rect2(34, 24, 3, 5), Rect2(25, 29, 3, 12), Rect2(36, 29, 3, 12), Rect2(28, 31, 8, 3)],
		scale_factor,
		origin,
		mark_color
	)


func _draw_speed_icon(scale_factor: float, origin: Vector2) -> void:
	_draw_mark([Rect2(22, 26, 3, 13), Rect2(26, 27, 3, 11), Rect2(29, 29, 3, 7), Rect2(32, 31, 3, 3), Rect2(33, 27, 3, 11), Rect2(36, 29, 3, 7), Rect2(39, 31, 3, 3)], scale_factor, origin)


func _draw_speed_multiplier(scale_factor: float, origin: Vector2) -> void:
	var text := "×%d" % speed_multiplier
	var font := ThemeDB.fallback_font
	var baseline := origin + Vector2(14.0, 39.0) * scale_factor
	var width := 36.0 * scale_factor
	var font_size := maxi(12, int(round(19.0 * scale_factor)))
	draw_string(font, baseline + Vector2.ONE * scale_factor, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color("#273a77"))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, speed_active_mark_color)


func _draw_menu_icon(scale_factor: float, origin: Vector2) -> void:
	_draw_mark([Rect2(23, 24, 18, 4), Rect2(23, 30, 18, 4), Rect2(23, 36, 18, 4)], scale_factor, origin)


func _draw_add_icon(scale_factor: float, origin: Vector2) -> void:
	# Three block widths create the chamfered tips from the reference without
	# introducing smooth diagonal edges.
	_draw_mark([
		Rect2(29, 21, 6, 22),
		Rect2(23, 28, 18, 8),
		Rect2(21, 30, 22, 4),
	], scale_factor, origin)


func _draw_back_icon(scale_factor: float, origin: Vector2) -> void:
	# A stepped triangle and short rectangular tail reproduce the reference arrow.
	_draw_mark([
		Rect2(21, 31, 4, 4), Rect2(24, 28, 4, 10),
		Rect2(27, 25, 4, 16), Rect2(30, 23, 5, 20),
		Rect2(34, 29, 10, 8),
	], scale_factor, origin)


func _draw_close_icon(scale_factor: float, origin: Vector2) -> void:
	# Overlapping 4 px squares make both diagonals visibly stair-stepped.
	_draw_mark([
		Rect2(22, 22, 4, 4), Rect2(25, 25, 4, 4),
		Rect2(28, 28, 8, 8), Rect2(35, 35, 4, 4),
		Rect2(38, 38, 4, 4), Rect2(38, 22, 4, 4),
		Rect2(35, 25, 4, 4), Rect2(25, 35, 4, 4),
		Rect2(22, 38, 4, 4),
	], scale_factor, origin)


func _draw_refresh_icon(scale_factor: float, origin: Vector2) -> void:
	# Two separated stepped arcs form a refresh mark. The left and right breaks
	# stay several pixels wide so the mark never reads as one continuous ring.
	_draw_mark([
		# Upper arc and its downward-facing arrowhead.
		Rect2(21, 27, 4, 4), Rect2(23, 24, 6, 4),
		Rect2(27, 22, 12, 4), Rect2(37, 24, 5, 4),
		Rect2(40, 27, 4, 4), Rect2(37, 29, 10, 4),
		Rect2(39, 32, 6, 3),
		# Lower arc starts after the right break and finishes with an
		# upward-facing arrowhead after the left break.
		Rect2(40, 39, 4, 4), Rect2(37, 41, 5, 4),
		Rect2(26, 43, 13, 4), Rect2(22, 41, 6, 4),
		Rect2(20, 39, 4, 4), Rect2(17, 36, 10, 4),
		Rect2(19, 33, 6, 3),
	], scale_factor, origin)


func _draw_mark(
	rects: Array,
	scale_factor: float,
	origin: Vector2,
	mark_color: Color = Color("#eef0ff")
) -> void:
	for rect in rects:
		_rect(Rect2(rect.position + Vector2(1, 1), rect.size), Color("#273a77"), scale_factor, origin)
	for rect in rects:
		_rect(rect, mark_color, scale_factor, origin)


func _octagon(inset: float) -> Array:
	var unit := (64.0 - inset * 2.0) / 64.0
	var profile := [Vector2(16, 0), Vector2(48, 0), Vector2(48, 4), Vector2(56, 4), Vector2(56, 12), Vector2(60, 12), Vector2(60, 20), Vector2(64, 20), Vector2(64, 44), Vector2(60, 44), Vector2(60, 52), Vector2(56, 52), Vector2(56, 60), Vector2(48, 60), Vector2(48, 64), Vector2(16, 64), Vector2(16, 60), Vector2(8, 60), Vector2(8, 52), Vector2(4, 52), Vector2(4, 44), Vector2(0, 44), Vector2(0, 20), Vector2(4, 20), Vector2(4, 12), Vector2(8, 12), Vector2(8, 4), Vector2(16, 4)]
	var result := []
	for point in profile:
		result.append(Vector2(inset, inset) + point * unit)
	return result


func _action_name() -> String:
	match action_type:
		ActionType.AUTO:
			return "自动"
		ActionType.SPEED:
			return "加速 ×%d" % speed_multiplier
		ActionType.MENU:
			return "菜单"
		ActionType.SETTINGS:
			return "设置"
		ActionType.ADD:
			return "添加"
		ActionType.BACK:
			return "后退"
		ActionType.CLOSE:
			return "关闭"
		ActionType.REFRESH:
			return "刷新"
		ActionType.BLANK:
			return ""
	return ""


func _pixel_polygon(points: Array, color: Color, scale_factor: float, origin: Vector2) -> void:
	var scaled_points := PackedVector2Array()
	for point in points:
		scaled_points.append(origin + point * scale_factor)
	draw_colored_polygon(scaled_points, color)


func _rect(rect: Rect2, color: Color, scale_factor: float, origin: Vector2) -> void:
	draw_rect(Rect2(origin + rect.position * scale_factor, rect.size * scale_factor), color, true, -1.0, false)
