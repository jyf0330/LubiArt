extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")


func plugin_id() -> String:
	return "sort_lowest_hp"


func sort_targets(targets: Array, _option: Dictionary, _params: Dictionary) -> Array:
	var result := targets.duplicate()
	result.sort_custom(func(a, b):
		var left := Dictionary(a)
		var right := Dictionary(b)
		var left_hp := int(left.get("hp", 0))
		var right_hp := int(right.get("hp", 0))
		if left_hp != right_hp:
			return left_hp < right_hp
		return String(left.get("id", "")) < String(right.get("id", ""))
	)
	return result


func profile(_params: Dictionary) -> Dictionary:
	return {"target_order": "lowest_hp"}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params)
