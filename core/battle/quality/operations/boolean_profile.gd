extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")


func plugin_id() -> String:
	return "boolean_profile"


func profile(params: Dictionary) -> Dictionary:
	var result := {}
	for key_value in params.keys():
		result[String(key_value)] = bool(params[key_value])
	return result


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {}, {
		"preview_damage": "bool",
		"supports_mark": "bool",
		"changes_shape_name": "bool",
	}, true)
