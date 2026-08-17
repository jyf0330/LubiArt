extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")


func plugin_id() -> String:
	return "element_layers_multiply_matching"


func element_layers(attacker: Dictionary, slot_element: String, current: int, params: Dictionary) -> int:
	if String(attacker.get("element", "")) != slot_element:
		return current
	return current * max(1, int(params.get("factor", 1)))


func profile(_params: Dictionary) -> Dictionary:
	return {"doubles_matching_element": true}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"factor": "positive_int"})
