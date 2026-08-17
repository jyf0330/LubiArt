extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")


func plugin_id() -> String:
	return "shape_reverse"


func profile(_params: Dictionary) -> Dictionary:
	return {"shape_mutation": "reverse", "changes_shape_name": true}


func mutate_shape(
	_unit: Dictionary,
	_direction: String,
	cells: Array,
	_width: int,
	_height: int,
	_source_id: String,
	_params: Dictionary
) -> Array:
	var mutated := cells.duplicate(true)
	mutated.reverse()
	return mutated


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params)
