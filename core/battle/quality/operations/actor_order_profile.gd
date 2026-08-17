extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")


func plugin_id() -> String:
	return "actor_order_profile"


func profile(params: Dictionary) -> Dictionary:
	return {"actor_order": int(params.get("order", 0))}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"order": "int"})
