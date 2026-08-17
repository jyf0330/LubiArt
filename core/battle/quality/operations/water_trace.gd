extends "res://core/battle/quality/quality_trace_operation_base.gd"

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_trace_operation_support.gd")


func plugin_id() -> String:
	return "water_trace"


func trace_enter(context: RefCounted, unit: Dictionary, trace: Dictionary, params: Dictionary) -> String:
	if not SupportScript.is_live_side(unit, "player") or context == null or not context.has_method(&"heal_unit"):
		return ""
	var healed := int(context.call(&"heal_unit", unit, int(params.get("amount", 5))))
	return "%s 触发%s：恢复%d生命。" % [
		SupportScript.unit_name(unit, "我方"),
		SupportScript.trace_name(trace),
		healed,
	]


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_trace(params, {
		"amount": "nonnegative_int",
	})
