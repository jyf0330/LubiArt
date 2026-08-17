extends RefCounted

const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")
const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")


func plugin_id() -> String:
	return "damage_multiply_when"


func modify_hit_damage(hit_context: Dictionary, current: int, params: Dictionary) -> int:
	if not SupportScript.matches(Dictionary(params.get("when", {})), hit_context):
		return current
	return max(0, current * int(params.get("value", 1)))


func profile(params: Dictionary) -> Dictionary:
	return {"damage_rules": [SupportScript.damage_rule("multiply", params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(
		params,
		{"value": "nonnegative_int"},
		{"when": "condition_map"}
	)
