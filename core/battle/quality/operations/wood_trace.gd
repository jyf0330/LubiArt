extends "res://core/battle/quality/quality_trace_operation_base.gd"

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_trace_operation_support.gd")


func plugin_id() -> String:
	return "wood_trace"


func trace_round_start(
	context: RefCounted,
	unit: Dictionary,
	traces: Array,
	params: Dictionary
) -> Array:
	var logs: Array = []
	if not SupportScript.is_live_side(unit, "player") or context == null or not context.has_method(&"heal_unit"):
		return logs
	for trace_value in traces:
		if typeof(trace_value) != TYPE_DICTIONARY:
			continue
		var trace := Dictionary(trace_value)
		var healed := int(context.call(&"heal_unit", unit, int(params.get("amount", 4))))
		if healed <= 0:
			continue
		logs.append("%s 触发%s：恢复%d生命。" % [
			SupportScript.unit_name(unit, "我方"),
			SupportScript.trace_name(trace),
			healed,
		])
	return logs


func _default_duration() -> int:
	return 2


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_trace(params, {
		"amount": "nonnegative_int",
	})
