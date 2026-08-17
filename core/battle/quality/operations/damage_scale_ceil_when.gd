extends RefCounted

const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")
const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")


func plugin_id() -> String:
	return "damage_scale_ceil_when"


func modify_hit_damage(hit_context: Dictionary, current: int, params: Dictionary) -> int:
	if not SupportScript.matches(Dictionary(params.get("when", {})), hit_context):
		return current
	var denominator: int = max(1, int(params.get("denominator", 1)))
	return max(0, int(ceil(float(current * int(params.get("numerator", 1))) / float(denominator))))


func profile(params: Dictionary) -> Dictionary:
	return {"damage_rules": [SupportScript.damage_rule("scale_ceil", params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {
		"numerator": "nonnegative_int",
		"denominator": "positive_int",
	}, {
		"when": "condition_map",
	})
