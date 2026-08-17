extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")

const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")
const SupportScript := preload("res://core/battle/quality/quality_shape_operation_support.gd")


func plugin_id() -> String:
	return "shape_double_ends"


func profile(_params: Dictionary) -> Dictionary:
	return {"shape_mutation": "double_ends", "changes_shape_name": true}


func mutate_shape(
	unit: Dictionary,
	_direction: String,
	cells: Array,
	width: int,
	height: int,
	source_id: String,
	_params: Dictionary
) -> Array:
	var mutated := cells.duplicate(true)
	var unit_x := int(unit.get("x", 0))
	var unit_y := int(unit.get("y", 0))
	for cell_value in cells:
		var cell := Dictionary(cell_value)
		var x := int(cell.get("x", 0))
		var y := int(cell.get("y", 0))
		ShapeGeometryScript.append_unique_cell(
			mutated,
			x + int(sign(x - unit_x)),
			y + int(sign(y - unit_y)),
			width,
			height,
			SupportScript.extra(source_id, -2)
		)
	return mutated


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params)
