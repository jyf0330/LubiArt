extends "res://core/battle/quality/quality_trace_operation_base.gd"

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_trace_operation_support.gd")


func plugin_id() -> String:
	return "earth_trace"


func trace_enter(_context: RefCounted, unit: Dictionary, trace: Dictionary, params: Dictionary) -> String:
	if not SupportScript.is_live_side(unit, "player"):
		return ""
	var amount := int(params.get("amount", 8))
	var shield_before := int(unit.get("shield", 0))
	unit["shield"] = shield_before + amount
	return "%s 触发%s：护盾 %d→%d。" % [
		SupportScript.unit_name(unit, "我方"),
		SupportScript.trace_name(trace),
		shield_before,
		int(unit.get("shield", 0)),
	]


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_trace(params, {
		"amount": "int",
	})
