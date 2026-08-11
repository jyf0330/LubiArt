extends RefCounted

class_name BattleBoardDimensions

const DEFAULT_WIDTH := 8
const DEFAULT_HEIGHT := 8
const LEGACY_WIDTH := 8
const LEGACY_HEIGHT := 7
const MIN_WIDTH := 8
const MIN_HEIGHT := 8
const MAX_WIDTH := 8
const MAX_HEIGHT := 8


static func defaults() -> Vector2i:
	return Vector2i(DEFAULT_WIDTH, DEFAULT_HEIGHT)


static func legacy_defaults() -> Vector2i:
	return Vector2i(LEGACY_WIDTH, LEGACY_HEIGHT)


static func is_valid(width: int, height: int) -> bool:
	return (
		width >= MIN_WIDTH
		and width <= MAX_WIDTH
		and height >= MIN_HEIGHT
		and height <= MAX_HEIGHT
	)


static func normalized(width: int, height: int, fallback: Vector2i = Vector2i(DEFAULT_WIDTH, DEFAULT_HEIGHT)) -> Vector2i:
	var fallback_width := fallback.x if fallback.x > 0 else DEFAULT_WIDTH
	var fallback_height := fallback.y if fallback.y > 0 else DEFAULT_HEIGHT
	var resolved_width := width if width > 0 else fallback_width
	var resolved_height := height if height > 0 else fallback_height
	return Vector2i(
		clampi(resolved_width, MIN_WIDTH, MAX_WIDTH),
		clampi(resolved_height, MIN_HEIGHT, MAX_HEIGHT)
	)


static func from_board(board: Dictionary, fallback: Vector2i = Vector2i(DEFAULT_WIDTH, DEFAULT_HEIGHT)) -> Vector2i:
	var legacy_size := 0
	var raw_size: Variant = board.get("size", 0)
	if typeof(raw_size) == TYPE_INT or typeof(raw_size) == TYPE_FLOAT:
		legacy_size = int(raw_size)
	elif typeof(raw_size) == TYPE_DICTIONARY:
		var size_dict := Dictionary(raw_size)
		return normalized(
			int(size_dict.get("width", size_dict.get("x", fallback.x))),
			int(size_dict.get("height", size_dict.get("y", fallback.y))),
			fallback
		)
	var width := int(board.get("width", board.get("columns", board.get("cols", legacy_size))))
	var height := int(board.get("height", board.get("rows", legacy_size)))
	return normalized(width, height, fallback)


static func to_snapshot(width: int, height: int) -> Dictionary:
	var dimensions := normalized(width, height)
	return {
		"width": dimensions.x,
		"height": dimensions.y,
		"columns": dimensions.x,
		"rows": dimensions.y,
		"cellCount": dimensions.x * dimensions.y,
		"cell_count": dimensions.x * dimensions.y,
		"label": "%dx%d" % [dimensions.x, dimensions.y]
	}


static func contains(dimensions: Vector2i, x: int, y: int) -> bool:
	return x >= 0 and x < dimensions.x and y >= 0 and y < dimensions.y


static func leader_cell(dimensions: Vector2i, player_side: bool) -> Vector2i:
	var resolved := normalized(dimensions.x, dimensions.y)
	return Vector2i(0, resolved.y - 1) if player_side else Vector2i(resolved.x - 1, 0)


static func side_spawn_region_cells(dimensions: Vector2i, player_side: bool, region_size: int) -> Array[Vector2i]:
	var resolved := normalized(dimensions.x, dimensions.y)
	var width := mini(maxi(1, region_size), resolved.x)
	var height := mini(maxi(1, region_size), resolved.y)
	var start_x := 0 if player_side else resolved.x - width
	var start_y := resolved.y - height if player_side else 0
	var cells: Array[Vector2i] = []
	for y in range(start_y, start_y + height):
		for x in range(start_x, start_x + width):
			cells.append(Vector2i(x, y))
	return cells


static func cell_count(dimensions: Vector2i) -> int:
	return max(0, dimensions.x) * max(0, dimensions.y)
