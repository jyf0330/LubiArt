extends RefCounted

const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")

## Pure projection shared by command previews and battle resolution. It owns no
## unit/board state and receives the two authority-derived facts explicitly.


func cell_damage_delta(option: Dictionary, target: Dictionary) -> int:
	var cell_index := ShapeGeometryScript.option_cell_index(option, target)
	var cells := Array(option.get("cells", []))
	if cell_index < 0 or cell_index >= cells.size():
		return 0
	return int(Dictionary(cells[cell_index]).get("quality_damage_delta", 0))


func build(
	attacker: Dictionary,
	option: Dictionary,
	targets: Array,
	target: Dictionary,
	hit_index: int,
	damage: int,
	all_cells_occupied: bool,
	marked_match: bool
) -> Dictionary:
	var runtime := Dictionary(attacker.get("quality_runtime", {}))
	var target_count := targets.size()
	var cell_index := ShapeGeometryScript.option_cell_index(option, target)
	var core_index := core_cell_index(option)
	var farthest_index := farthest_cell_index(attacker, option)
	var distance: int = (
		abs(int(target.get("x", 0)) - int(attacker.get("x", 0)))
		+ abs(int(target.get("y", 0)) - int(attacker.get("y", 0)))
	)
	var marked_cell := Dictionary(runtime.get("marked_cell", {}))
	var mode := String(runtime.get("mode", ""))
	return {
		"damage": damage,
		"attacker": attacker,
		"mode": mode,
		"mode_is_guard": mode == "守",
		"mode_is_stable": mode == "稳",
		"mode_is_same": mode == "同",
		"hit_index": hit_index,
		"first_hit": hit_index == 0,
		"last_hit": target_count > 0 and hit_index == target_count - 1,
		"target_count": target_count,
		"cell_index": cell_index,
		"core_cell": cell_index == core_index,
		"farthest_cell": cell_index == farthest_index,
		"first_cell": cell_index == 0,
		"farthest_positive": farthest_index > 0,
		"distance": distance,
		"target_hp": int(target.get("hp", 0)),
		"off_axis": int(target.get("y", 0)) != int(attacker.get("y", 0)),
		"has_mark": not marked_cell.is_empty(),
		"marked_match": marked_match,
		"core_or_single": cell_index == core_index or Array(option.get("cells", [])).size() == 1,
		"core_or_first": cell_index == core_index or cell_index == 0,
		"g28_active": bool(runtime.get("g28Active", all_cells_occupied)),
		"first_target_exists": target_exists_at_cell_index(option, targets, 0),
	}


func core_cell_index(option: Dictionary) -> int:
	var cells := Array(option.get("cells", []))
	return max(0, int(floor(float(max(0, cells.size() - 1)) / 2.0)))


func farthest_cell_index(attacker: Dictionary, option: Dictionary) -> int:
	var cells := Array(option.get("cells", []))
	var best_index := -1
	var best_distance := -1
	var unit_x := int(attacker.get("x", 0))
	var unit_y := int(attacker.get("y", 0))
	for index in range(cells.size()):
		var cell := Dictionary(cells[index])
		var distance: int = abs(int(cell.get("x", 0)) - unit_x) + abs(int(cell.get("y", 0)) - unit_y)
		if distance > best_distance:
			best_index = index
			best_distance = distance
	return best_index


func target_exists_at_cell_index(option: Dictionary, targets: Array, wanted_index: int) -> bool:
	for target in targets:
		if ShapeGeometryScript.option_cell_index(option, Dictionary(target)) == wanted_index:
			return true
	return false
