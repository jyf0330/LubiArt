extends RefCounted

## Pure projection of preview values already exported in a public Snapshot.
## It never owns Nodes, mutates Snapshot state or calculates combat values.


func action_cells_for_drag(
	snapshot: Dictionary,
	unit_id: String,
	target: Vector2i,
	dimensions: Vector2i
) -> Array[Vector2i]:
	var preview := _preview_for_unit(snapshot, unit_id)
	if preview.is_empty():
		return []
	var origin_value = preview.get("origin", null)
	var cells_value = preview.get("cells", null)
	if not (origin_value is Dictionary) or not (cells_value is Array):
		return []
	var origin_data := Dictionary(origin_value)
	var origin := Vector2i(
		int(origin_data.get("x", -1)),
		int(origin_data.get("y", -1))
	)
	if origin.x < 0 or origin.y < 0:
		return []
	return _translated_cells(Array(cells_value), target - origin, dimensions)


func direction_cells(
	snapshot: Dictionary,
	unit_id: String,
	direction: String,
	dimensions: Vector2i
) -> Array[Vector2i]:
	var preview := _preview_for_unit(snapshot, unit_id)
	if preview.is_empty():
		return []
	var origin_value = preview.get("origin", null)
	var cells_value = preview.get("cells", null)
	var source_direction := String(preview.get("direction", "")).strip_edges().to_lower()
	var target_direction := direction.strip_edges().to_lower()
	if not (origin_value is Dictionary) or not (cells_value is Array) \
			or not _is_direction(source_direction) or not _is_direction(target_direction):
		return []
	var origin_data := Dictionary(origin_value)
	var origin := Vector2i(
		int(origin_data.get("x", -1)),
		int(origin_data.get("y", -1))
	)
	if origin.x < 0 or origin.y < 0:
		return []
	var current_origin := _unit_grid(snapshot, unit_id)
	if current_origin.x < 0 or current_origin.y < 0:
		return []
	var turns := posmod(_direction_index(target_direction) - _direction_index(source_direction), 4)
	var by_key := {}
	for value in Array(cells_value):
		if not (value is Dictionary):
			continue
		var row := Dictionary(value)
		var source_grid := Vector2i(
			int(row.get("x", row.get("c", -1))),
			int(row.get("y", row.get("r", -1)))
		)
		var grid := current_origin + _rotate(source_grid - origin, turns)
		if _contains(grid, dimensions):
			by_key[_grid_key(grid)] = grid
	return _sorted_grids(by_key)


func incoming_preview(snapshot: Dictionary, unit_id: String) -> Dictionary:
	if unit_id == "":
		return {}
	var by_unit_value = snapshot.get(
		"placement_damage_by_unit",
		snapshot.get("placementDamageByUnit", {})
	)
	if not (by_unit_value is Dictionary):
		return {}
	var by_unit := Dictionary(by_unit_value)
	var value = by_unit.get(unit_id, null)
	return Dictionary(value).duplicate(true) if value is Dictionary else {}


func target_preview(cell_data: Dictionary, actor_id: String) -> Dictionary:
	if actor_id == "":
		return {}
	for value in _preview_candidates(cell_data):
		var preview := Dictionary(value)
		var preview_actor := String(preview.get(
			"actorId",
			preview.get("actor_id", preview.get("unitId", preview.get("unit_id", "")))
		))
		if preview_actor == actor_id and _is_enemy_preview(preview):
			return preview.duplicate(true)
	return {}


func _preview_for_unit(snapshot: Dictionary, unit_id: String) -> Dictionary:
	var previews_value = snapshot.get(
		"action_preview_by_unit",
		snapshot.get("actionPreviewByUnit", {})
	)
	if not (previews_value is Dictionary):
		return {}
	var previews := Dictionary(previews_value)
	var value = previews.get(unit_id, null)
	return Dictionary(value) if value is Dictionary else {}


func _translated_cells(source_cells: Array, delta: Vector2i, dimensions: Vector2i) -> Array[Vector2i]:
	var by_key := {}
	for value in source_cells:
		if not (value is Dictionary):
			continue
		var row := Dictionary(value)
		var grid := Vector2i(
			int(row.get("x", row.get("c", -1))) + delta.x,
			int(row.get("y", row.get("r", -1))) + delta.y
		)
		if _contains(grid, dimensions):
			by_key[_grid_key(grid)] = grid
	return _sorted_grids(by_key)


func _unit_grid(snapshot: Dictionary, unit_id: String) -> Vector2i:
	var board_value = snapshot.get("board", null)
	if not (board_value is Dictionary):
		return Vector2i(-1, -1)
	var cells_value = Dictionary(board_value).get("cells", null)
	if not (cells_value is Array):
		return Vector2i(-1, -1)
	for value in Array(cells_value):
		if not (value is Dictionary):
			continue
		var cell := Dictionary(value)
		if String(cell.get("unitId", cell.get("unit_id", ""))) == unit_id:
			return Vector2i(
				int(cell.get("x", cell.get("c", -1))),
				int(cell.get("y", cell.get("r", -1)))
			)
	return Vector2i(-1, -1)


func _preview_candidates(cell_data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in ["action_preview_data", "actionPreviewData", "preview"]:
		var value = cell_data.get(key, null)
		if value is Dictionary and not Dictionary(value).is_empty():
			result.append(Dictionary(value))
	var previews_value = cell_data.get("previews", null)
	if previews_value is Array:
		for value in Array(previews_value):
			if value is Dictionary:
				result.append(Dictionary(value))
	return result


func _is_enemy_preview(preview: Dictionary) -> bool:
	return String(preview.get("preview_type", preview.get("previewType", ""))) == "enemy" \
		or bool(preview.get("hitEnemy", preview.get("hit_enemy", false)))


func _is_direction(direction: String) -> bool:
	return direction in ["up", "right", "down", "left"]


func _direction_index(direction: String) -> int:
	return ["up", "right", "down", "left"].find(direction)


func _rotate(offset: Vector2i, turns: int) -> Vector2i:
	match posmod(turns, 4):
		1:
			return Vector2i(-offset.y, offset.x)
		2:
			return -offset
		3:
			return Vector2i(offset.y, -offset.x)
		_:
			return offset


func _contains(grid: Vector2i, dimensions: Vector2i) -> bool:
	return grid.x >= 0 and grid.y >= 0 and grid.x < dimensions.x and grid.y < dimensions.y


func _grid_key(grid: Vector2i) -> String:
	return "%d,%d" % [grid.x, grid.y]


func _sorted_grids(by_key: Dictionary) -> Array[Vector2i]:
	var keys := PackedStringArray(by_key.keys())
	keys.sort()
	var result: Array[Vector2i] = []
	for key in keys:
		result.append(by_key[String(key)] as Vector2i)
	return result
