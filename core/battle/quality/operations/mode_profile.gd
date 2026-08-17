extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")


func plugin_id() -> String:
	return "mode_profile"


func profile(params: Dictionary) -> Dictionary:
	var options: Array[String] = []
	for option_value in Array(params.get("options", [])):
		options.append(String(option_value))
	return {
		"mode_options": options,
		"mode_aliases": Dictionary(params.get("aliases", {})).duplicate(true),
	}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_mode_profile(params)
