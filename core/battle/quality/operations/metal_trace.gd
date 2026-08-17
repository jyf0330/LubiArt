extends "res://core/battle/quality/quality_trace_operation_base.gd"

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_trace_operation_support.gd")


func plugin_id() -> String:
	return "metal_trace"


func trace_enter(context: RefCounted, unit: Dictionary, trace: Dictionary, params: Dictionary) -> String:
	if not SupportScript.is_live_side(unit, "enemy") or context == null or not context.has_method(&"add_incoming_damage_bonus"):
		return ""
	var amount := int(params.get("amount", 2))
	context.call(&"add_incoming_damage_bonus", unit, amount)
	return "%s 触发%s：下次受伤+%d。" % [
		SupportScript.unit_name(unit, "敌人"),
		SupportScript.trace_name(trace),
		amount,
	]


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_trace(params, {
		"amount": "int",
	})
