extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")

const SupportScript := preload("res://core/battle/quality/quality_shape_operation_support.gd")


func plugin_id() -> String:
	return "shape_mirror"


func profile(_params: Dictionary) -> Dictionary:
	return {"shape_mutation": "mirror", "changes_shape_name": true}


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
	SupportScript.append_mirror(
		unit,
		cells,
		mutated,
		width,
		height,
		SupportScript.extra(source_id, 0)
	)
	return mutated


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params)
