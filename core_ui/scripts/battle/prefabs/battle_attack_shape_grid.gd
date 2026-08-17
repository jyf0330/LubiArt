extends GridContainer
class_name BattleAttackShapeGrid

## Pure visual projection of relative attack offsets onto an authored grid.

@export var grid_columns := 7
@export var grid_rows := 3
@export var origin_index := 10
@export var cell_size := Vector2(27.0, 30.0)
@export var neutral_color := Color("07110e")
@export var neutral_border := Color("284742")
@export var origin_color := Color("ef7850")
@export var target_color := Color("c13b2a")

var _cells: Array[PanelContainer] = []
var _target_indices: Array[int] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild()


func present(shape: Dictionary) -> void:
	_ensure_cells()
	_target_indices.clear()
	for value in Array(shape.get("offsets", [])):
		var offset := Dictionary(value) if value is Dictionary else {}
		var row := int(offset.get("dr", 0)) + grid_rows / 2
		var column := int(offset.get("dc", 0)) + grid_columns / 2
		if row < 0 or row >= grid_rows or column < 0 or column >= grid_columns:
			continue
		var index := row * grid_columns + column
		if index != origin_index and not _target_indices.has(index):
			_target_indices.append(index)
	_refresh_styles()


func get_target_cell_indices() -> Array[int]:
	return _target_indices.duplicate()


func get_cell_count() -> int:
	return grid_columns * grid_rows


func _ensure_cells() -> void:
	if _cells.size() != grid_columns * grid_rows:
		_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_cells.clear()
	columns = grid_columns
	for index in range(grid_columns * grid_rows):
		var cell := PanelContainer.new()
		cell.name = "Cell%02d" % index
		cell.custom_minimum_size = cell_size
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cell)
		_cells.append(cell)
	_refresh_styles()


func _refresh_styles() -> void:
	for index in range(_cells.size()):
		var background := neutral_color
		var border := neutral_border
		var width := 2
		if index == origin_index:
			background = origin_color
			border = Color("183f42")
			width = 3
		elif _target_indices.has(index):
			background = target_color
			border = Color("611d18")
		_cells[index].add_theme_stylebox_override("panel", _style(background, border, width))


func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(1)
	style.anti_aliasing = false
	return style
