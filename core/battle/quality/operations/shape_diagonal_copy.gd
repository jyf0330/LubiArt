extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")

const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")
const SupportScript := preload("res://core/battle/quality/quality_shape_operation_support.gd")


func plugin_id() -> String:
	return "shape_diagonal_copy"


func profile(_params: Dictionary) -> Dictionary:
	return {"shape_mutation": "diagonal_copy", "changes_shape_name": true}


func mutate_shape(
	_unit: Dictionary,
	_direction: String,
	cells: Array,
	width: int,
	height: int,
	source_id: String,
	_params: Dictionary
) -> Array:
	var mutated := cells.duplicate(true)
	if cells.is_empty():
		return mutated
	var first := Dictionary(cells[0])
	ShapeGeometryScript.append_unique_cell(
		mutated,
		int(first.get("x", 0)) + 1,
		int(first.get("y", 0)) - 1,
		width,
		height,
		SupportScript.extra(source_id, 0)
	)
	return mutated


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params)
