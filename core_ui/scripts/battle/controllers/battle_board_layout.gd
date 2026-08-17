extends RefCounted

## Pixel-locked 8-column perspective geometry extracted from the authored
## 1920x1080 board. Cells remain data-driven instances while the art geometry
## stays in one deterministic source.

const PERSPECTIVE_COLUMNS := 8
const Y_BOUNDARIES := [
	1.0, 110.57143, 229.14285, 355.85715, 490.7143, 635.1429, 791.1429, 959.0,
]
const TOP_X_BOUNDARIES := [
	[133.0, 253.0, 374.0, 493.99999, 615.0, 735.0, 855.0, 976.0, 1096.0],
	[117.788098, 241.67685, 366.45124, 490.34, 615.0, 738.888756, 862.777486, 987.4375, 1111.440636],
	[101.326718, 229.42364, 358.28244, 486.37936, 615.0, 743.09692, 871.19382, 999.81449, 1128.14957],
	[83.734868, 216.32897, 349.55263, 482.14671, 615.00002, 747.5941, 880.1882, 1013.04147, 1146.00595],
	[65.012523, 202.392786, 340.26186, 477.64212, 615.0, 752.38025, 889.7605, 1027.1184, 1165.00983],
	[44.961379, 187.467489, 330.31166, 472.81778, 615.00001, 757.50612, 900.01222, 1042.19442, 1185.36256],
	[23.303759, 171.3464, 319.56427, 467.60692, 615.0, 763.04265, 911.08531, 1058.47838, 1207.34583],
	[0.0, 154.0, 308.0, 462.0, 615.0, 769.0, 923.00001, 1076.0, 1231.00002],
]
const BOTTOM_X_BOUNDARIES := [
	[117.7881, 241.676856, 366.45124, 490.339986, 615.0, 738.888756, 862.77751, 987.43752, 1111.44064],
	[101.32672, 229.42364, 358.28243, 486.37936, 615.0, 743.09692, 871.19383, 999.81449, 1128.14955],
	[83.73486, 216.32896, 349.55264, 482.14674, 615.0, 747.5941, 880.18816, 1013.04145, 1146.00597],
	[65.01253, 202.39278, 340.26186, 477.64209, 615.00002, 752.38025, 889.76051, 1027.1184, 1165.00982],
	[44.961376, 187.467496, 330.31166, 472.8178, 615.0, 757.50612, 900.01222, 1042.19444, 1185.36251],
	[23.303759, 171.346409, 319.56426, 467.60692, 615.00001, 763.04265, 911.08528, 1058.47836, 1207.34585],
	[0.0, 154.0, 308.0, 462.0, 615.0, 769.0, 923.00001, 1076.0, 1231.00002],
]
const AUTHORED_RIGHT_EDGE_GEOMETRY := [
	[976.0, 1.0, 1111.4407, 110.57143, 0.0, 0.0, 120.0, 0.0, 135.44064, 109.57143, 11.437519, 109.57143],
	[987.4375, 110.57143, 1128.1495, 229.14285, 0.0, 0.0, 124.003136, 0.0, 140.71205, 118.57143, 12.376976, 118.57143],
	[999.8145, 229.14285, 1146.006, 355.85715, 0.0, 0.0, 128.33507, 0.0, 146.19147, 126.71429, 13.226961, 126.71429],
	[1013.04144, 355.85715, 1165.0099, 490.7143, 0.0, 0.0, 132.96451, 0.0, 151.96838, 134.85715, 14.076946, 134.85715],
	[1027.1184, 490.7143, 1185.3625, 635.1429, 0.0, 0.0, 137.89143, 0.0, 158.24411, 144.42857, 15.076051, 144.42857],
	[1042.1945, 635.1429, 1207.3458, 791.1429, 0.0, 0.0, 143.16806, 0.0, 165.15135, 156.0, 16.283924, 156.0],
	[1058.4784, 791.1429, 1231.0, 959.0, 0.0, 0.0, 148.86743, 0.0, 172.52162, 167.85715, 17.521622, 167.85715],
]
const LEGACY_ROW8_Y := Vector2(811.0, 959.0)
const LEGACY_ROW8_TOP := [
	20.546972, 169.29436, 318.19623, 466.94363, 615.0, 763.74738, 912.49478, 1060.55115, 1210.144,
]
const LEGACY_ROW8_BOTTOM := [
	0.0, 154.0, 308.0, 462.0, 615.0, 769.0, 923.00002, 1076.0, 1230.99995,
]


func apply_cell_geometry(
	cell: Control,
	x: int,
	y: int,
	dimensions: Vector2i,
	board_size: Vector2,
	gap: Vector2
) -> void:
	if dimensions.x == PERSPECTIVE_COLUMNS and y < Y_BOUNDARIES.size() - 1:
		if x == PERSPECTIVE_COLUMNS - 1:
			_apply_authored_edge_cell(cell, x, y, AUTHORED_RIGHT_EDGE_GEOMETRY[y])
			return
		_apply_perspective_cell(
			cell,
			x,
			y,
			Y_BOUNDARIES[y],
			Y_BOUNDARIES[y + 1],
			TOP_X_BOUNDARIES[y],
			BOTTOM_X_BOUNDARIES[y]
		)
		return
	if dimensions.x == PERSPECTIVE_COLUMNS and y == 7:
		_apply_perspective_cell(cell, x, y, LEGACY_ROW8_Y.x, LEGACY_ROW8_Y.y, LEGACY_ROW8_TOP, LEGACY_ROW8_BOTTOM)
		return
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


func _apply_authored_edge_cell(cell: Control, x: int, y: int, geometry: Array) -> void:
	var rect := Rect2(
		Vector2(float(geometry[0]), float(geometry[1])),
		Vector2(float(geometry[2]) - float(geometry[0]), float(geometry[3]) - float(geometry[1]))
	)
	var polygon := PackedVector2Array([
		Vector2(float(geometry[4]), float(geometry[5])),
		Vector2(float(geometry[6]), float(geometry[7])),
		Vector2(float(geometry[8]), float(geometry[9])),
		Vector2(float(geometry[10]), float(geometry[11])),
	])
	cell.set("use_perspective_geometry", true)
	cell.call(
		"setup_authored_grid_position",
		x,
		y,
		rect,
		polygon,
		Y_BOUNDARIES[Y_BOUNDARIES.size() - 1] - Y_BOUNDARIES[Y_BOUNDARIES.size() - 2]
	)


func _apply_perspective_cell(
	cell: Control,
	x: int,
	y: int,
	top_y: float,
	bottom_y: float,
	top_x: Array,
	bottom_x: Array
) -> void:
	var top_left := float(top_x[x])
	var top_right := float(top_x[x + 1])
	var bottom_left := float(bottom_x[x])
	var bottom_right := float(bottom_x[x + 1])
	var left := minf(top_left, bottom_left)
	var right := maxf(top_right, bottom_right)
	var height := bottom_y - top_y
	var polygon := PackedVector2Array([
		Vector2(top_left - left, 0.0),
		Vector2(top_right - left, 0.0),
		Vector2(bottom_right - left, height),
		Vector2(bottom_left - left, height),
	])
	cell.set("use_perspective_geometry", true)
	cell.call(
		"setup_authored_grid_position",
		x,
		y,
		Rect2(Vector2(left, top_y), Vector2(right - left, height)),
		polygon,
		Y_BOUNDARIES[Y_BOUNDARIES.size() - 1] - Y_BOUNDARIES[Y_BOUNDARIES.size() - 2]
	)
