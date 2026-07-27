extends RefCounted

## Pure board geometry adapter consumed by the battle feature.


func cell_key(grid: Vector2i) -> String:
	return "%d,%d" % [grid.x, grid.y]


func cell_origin(cell_size: Vector2, gap: Vector2, x: int, y: int) -> Vector2:
	return Vector2(float(x) * (cell_size.x + gap.x), float(y) * (cell_size.y + gap.y))


func grid_from_position(local_position: Vector2, dimensions: Vector2i, cell_size: Vector2, gap: Vector2) -> Vector2i:
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			if Rect2(cell_origin(cell_size, gap, x, y), cell_size).has_point(local_position):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func contains(dimensions: Vector2i, x: int, y: int) -> bool:
	return x >= 0 and x < dimensions.x and y >= 0 and y < dimensions.y
