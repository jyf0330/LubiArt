extends "res://core/battle/quality/quality_trace_operation_base.gd"

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")


func plugin_id() -> String:
	return "talisman_trace"


func trace_element_application_count(
	traces: Array,
	current: int,
	params: Dictionary
) -> int:
	return current + int(params.get("amount", 1)) if not traces.is_empty() else current


func _default_persistent() -> bool:
	return true


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_trace(params, {
		"amount": "int",
	})
