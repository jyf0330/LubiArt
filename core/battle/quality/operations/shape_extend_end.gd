extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")

const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")


func plugin_id() -> String:
	return "shape_extend_end"


func profile(_params: Dictionary) -> Dictionary:
	return {"shape_mutation": "extend_end", "changes_shape_name": true}


func mutate_shape(
	unit: Dictionary,
	direction: String,
	cells: Array,
	width: int,
	height: int,
	_source_id: String,
	_params: Dictionary
) -> Array:
	var mutated := cells.duplicate(true)
	if mutated.is_empty():
		return mutated
	var farthest := ShapeGeometryScript.farthest_cell(unit, mutated)
	var delta := ShapeGeometryScript.direction_delta(direction)
	ShapeGeometryScript.append_unique_cell(
		mutated,
		int(farthest.get("x", 0)) + delta.x,
		int(farthest.get("y", 0)) + delta.y,
		width,
		height
	)
	return mutated


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params)
