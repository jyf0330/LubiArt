extends Control
class_name UiValueBar

## Reusable, state-agnostic value bar. Consumers pass explicit values and labels;
## this component never reads gameplay state or emits commands.

@export_group("Appearance")
@export var fill_color := Color("2eaf35")
@export var track_color := Color("050b09")
@export var border_color := Color("35564e")
@export var preview_color := Color("ef332b")
@export var label_color := Color("f3ffe9")
@export var show_value_text := true
@export var border_width := 2
@export var corner_radius := 1

@onready var bar: ProgressBar = $Bar
@onready var preview_segment: ColorRect = $PreviewSegment
@onready var value_label: Label = $Value

var _maximum := 1
var _current := 0
var _projected := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_palette()
	value_label.visible = show_value_text
	preview_segment.visible = false
	resized.connect(_layout_preview)


func present(current: int, maximum: int, text_override: String = "") -> void:
	_maximum = maxi(1, maximum)
	_current = clampi(current, 0, _maximum)
	bar.max_value = float(_maximum)
	bar.value = float(_current)
	value_label.text = text_override if text_override != "" else "%d / %d" % [_current, _maximum]
	clear_preview()


func update_value(value: int, text_override: String = "") -> void:
	_current = clampi(value, 0, _maximum)
	bar.value = float(_current)
	value_label.text = text_override if text_override != "" else "%d / %d" % [_current, _maximum]
	clear_preview()


func set_fill_color(value: Color) -> void:
	fill_color = value
	if is_node_ready():
		_apply_palette()


func show_loss_preview(projected_value: int) -> void:
	_projected = clampi(projected_value, 0, _current)
	_layout_preview()


func clear_preview() -> void:
	_projected = -1
	if preview_segment != null:
		preview_segment.visible = false


func get_data_rect() -> Rect2:
	return Rect2(bar.position, bar.size)


func get_value_snapshot() -> Dictionary:
	return {
		"current": _current,
		"maximum": _maximum,
		"projected": _projected,
		"preview_visible": preview_segment.visible,
	}


func _layout_preview() -> void:
	if not is_node_ready() or _projected < 0 or _projected >= _current:
		if preview_segment != null:
			preview_segment.visible = false
		return
	var start_x := bar.size.x * float(_projected) / float(_maximum)
	var end_x := bar.size.x * float(_current) / float(_maximum)
	preview_segment.position = bar.position + Vector2(start_x, 0.0)
	preview_segment.size = Vector2(maxf(0.0, end_x - start_x), bar.size.y)
	preview_segment.color = preview_color
	preview_segment.visible = preview_segment.size.x > 0.5


func _apply_palette() -> void:
	bar.add_theme_stylebox_override("background", _style(track_color, border_color, border_width))
	bar.add_theme_stylebox_override("fill", _style(fill_color, fill_color.darkened(0.3), 1))
	value_label.add_theme_color_override("font_color", label_color)
	preview_segment.color = preview_color


func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(corner_radius)
	style.anti_aliasing = false
	return style
