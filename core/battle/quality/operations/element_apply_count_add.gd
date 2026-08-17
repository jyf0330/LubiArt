extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")


func plugin_id() -> String:
	return "element_apply_count_add"


func element_application_count(_context: RefCounted, _cell: Dictionary, current: int, params: Dictionary) -> int:
	return current + int(params.get("amount", 0))


func profile(params: Dictionary) -> Dictionary:
	return {"element_apply_bonus": int(params.get("amount", 0))}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"amount": "int"})
