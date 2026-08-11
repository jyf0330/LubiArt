extends RefCounted

## Uniform orthographic board geometry. Every cell keeps the same authored
## presentation size so units do not change scale when they move between rows.


func apply_cell_geometry(
	cell: Control,
	x: int,
	y: int,
	dimensions: Vector2i,
	board_size: Vector2,
	gap: Vector2
) -> void:
	var cell_size := Vector2(
		(board_size.x - gap.x * float(dimensions.x - 1)) / float(dimensions.x),
		(board_size.y - gap.y * float(dimensions.y - 1)) / float(dimensions.y)
	)
	cell.set("use_perspective_geometry", false)
	cell.call(
		"setup_grid_position",
		x,
		y,
		cell_size,
		Vector2(float(x) * (cell_size.x + gap.x), float(y) * (cell_size.y + gap.y)),
		cell_size.y
	)
