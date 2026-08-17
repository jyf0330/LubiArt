extends RefCounted

const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")

## Pure target selection for an already resolved action shape.


func targets_in_option(
	attacker: Dictionary,
	option: Dictionary,
	units: Array,
	opposing_leader: Dictionary,
	target_side: String
) -> Array:
	var targets: Array = []
	for unit_value in units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != target_side or int(unit.get("hp", 0)) <= 0:
			continue
		if ShapeGeometryScript.option_contains_cell(option, int(unit.get("x", -1)), int(unit.get("y", -1))):
			targets.append(unit)
	if (
		bool(opposing_leader.get("alive", false))
		and ShapeGeometryScript.option_contains_cell(
			option,
			int(opposing_leader.get("x", -1)),
			int(opposing_leader.get("y", -1))
		)
	):
		targets.append(opposing_leader)
	return targets
