extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")

const SupportScript := preload("res://core/battle/quality/quality_shape_operation_support.gd")


func plugin_id() -> String:
	return "shape_fill_corner"


func profile(_params: Dictionary) -> Dictionary:
	return {"shape_mutation": "fill_corner", "changes_shape_name": true}


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
	SupportScript.append_missing_corner(
		cells,
		mutated,
		width,
		height,
		SupportScript.extra(source_id, -2)
	)
	return mutated


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params)
