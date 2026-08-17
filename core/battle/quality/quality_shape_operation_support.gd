extends RefCounted

const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")


static func extra(source_id: String, damage_delta: int) -> Dictionary:
	return {
		"quality_damage_delta": damage_delta,
		"quality_source": source_id,
	}


static func append_mirror(
	unit: Dictionary,
	base_cells: Array,
	out_cells: Array,
	width: int,
	height: int,
	extra_fields: Dictionary
) -> void:
	var unit_x := int(unit.get("x", 0))
	var unit_y := int(unit.get("y", 0))
	for cell_value in base_cells:
		var cell := Dictionary(cell_value)
		ShapeGeometryScript.append_unique_cell(
			out_cells,
			2 * unit_x - int(cell.get("x", 0)),
			2 * unit_y - int(cell.get("y", 0)),
			width,
			height,
			extra_fields
		)


static func append_missing_corner(
	base_cells: Array,
	out_cells: Array,
	width: int,
	height: int,
	extra_fields: Dictionary
) -> void:
	var xs: Array = []
	var ys: Array = []
	for cell_value in base_cells:
		var cell := Dictionary(cell_value)
		var x := int(cell.get("x", 0))
		var y := int(cell.get("y", 0))
		if not xs.has(x):
			xs.append(x)
		if not ys.has(y):
			ys.append(y)
	if xs.size() != 2 or ys.size() != 2:
		return
	for x_value in xs:
		for y_value in ys:
			if has_cell(base_cells, int(x_value), int(y_value)):
				continue
			ShapeGeometryScript.append_unique_cell(
				out_cells,
				int(x_value),
				int(y_value),
				width,
				height,
				extra_fields
			)
			return


static func has_cell(cells: Array, x: int, y: int) -> bool:
	for cell_value in cells:
		var cell := Dictionary(cell_value)
		if int(cell.get("x", -1)) == x and int(cell.get("y", -1)) == y:
			return true
	return false
