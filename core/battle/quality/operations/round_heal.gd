extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "round_heal"


func round_start(context: RefCounted, unit: Dictionary, params: Dictionary) -> Array:
	var healed := int(context.call(&"heal_unit", unit, int(params.get("amount", 0))))
	return ["%s 触发%s：恢复%d生命。" % [
		String(unit.get("name", "我方")),
		SupportScript.effect_name(unit),
		healed,
	]]


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"amount": "nonnegative_int"})
