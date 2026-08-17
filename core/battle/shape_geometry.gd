extends RefCounted

## Pure attack-shape geometry. Quality-specific mutations live in
## core/battle/quality and call these generic geometry helpers.


static func direction_label(direction: String) -> String:
	match direction:
		"right":
			return "右"
		"down":
			return "下"
		"left":
			return "左"
		"up":
			return "上"
	return direction


static func normalize_direction(direction: String) -> String:
	var text := direction.strip_edges().to_lower()
	if ["right", "r", "east", "e", "右"].has(text):
		return "right"
	if ["down", "d", "south", "s", "下"].has(text):
		return "down"
	if ["left", "l", "west", "w", "左"].has(text):
		return "left"
	if ["up", "u", "north", "n", "上"].has(text):
		return "up"
	return "right"


static func direction_delta(direction: String) -> Vector2i:
	match direction:
		"down":
			return Vector2i(0, 1)
		"left":
			return Vector2i(-1, 0)
		"up":
			return Vector2i(0, -1)
	return Vector2i(1, 0)


static func offset_cell(unit: Dictionary, offset: Dictionary, direction: String) -> Dictionary:
	var dr := int(offset.get("dr", 0))
	var dc := int(offset.get("dc", 0))
	var row_offset := dr
	var col_offset := dc
	if direction == "down":
		row_offset = dc
		col_offset = -dr
	elif direction == "left":
		row_offset = -dr
		col_offset = -dc
	elif direction == "up":
		row_offset = -dc
		col_offset = dr
	return {
		"x": int(unit.get("x", 0)) + col_offset,
		"y": int(unit.get("y", 0)) + row_offset
	}


static func append_unique_cell(
	cells: Array,
	x: int,
	y: int,
	width: int,
	height: int,
	extra: Dictionary = {}
) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return false
	for existing in cells:
		var row := Dictionary(existing)
		if int(row.get("x", -1)) == x and int(row.get("y", -1)) == y:
			return false
	var cell := {"x": x, "y": y}
	for key in extra.keys():
		cell[key] = extra[key]
	cells.append(cell)
	return true


static func farthest_cell(unit: Dictionary, cells: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := -1
	var unit_x := int(unit.get("x", 0))
	var unit_y := int(unit.get("y", 0))
	for cell in cells:
		var row := Dictionary(cell)
		var distance: int = abs(int(row.get("x", 0)) - unit_x) + abs(int(row.get("y", 0)) - unit_y)
		if distance > best_distance:
			best = row
			best_distance = distance
	return best


static func option_contains_cell(option: Dictionary, x: int, y: int) -> bool:
	for cell in Array(option.get("cells", [])):
		var row := Dictionary(cell)
		if int(row.get("x", -1)) == x and int(row.get("y", -1)) == y:
			return true
	return false


static func option_cell_index(option: Dictionary, target: Dictionary) -> int:
	var target_x := int(target.get("x", -1))
	var target_y := int(target.get("y", -1))
	var cells := Array(option.get("cells", []))
	for index in range(cells.size()):
		var cell := Dictionary(cells[index])
		if int(cell.get("x", -1)) == target_x and int(cell.get("y", -1)) == target_y:
			return index
	return -1
