extends "res://core/battle/quality/quality_trace_operation_base.gd"

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_trace_operation_support.gd")


func plugin_id() -> String:
	return "wind_trace"


func trace_enter(_context: RefCounted, unit: Dictionary, trace: Dictionary, params: Dictionary) -> String:
	if not SupportScript.is_live_side(unit, "player"):
		return ""
	var amount := int(params.get("amount", 2))
	unit["quality_next_damage_bonus"] = max(
		int(unit.get("quality_next_damage_bonus", 0)),
		amount
	)
	return "%s 触发%s：下次伤害+%d。" % [
		SupportScript.unit_name(unit, "我方"),
		SupportScript.trace_name(trace),
		amount,
	]


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_trace(params, {
		"amount": "int",
	})
