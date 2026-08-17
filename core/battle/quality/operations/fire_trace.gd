extends "res://core/battle/quality/quality_trace_operation_base.gd"

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const SupportScript := preload("res://core/battle/quality/quality_trace_operation_support.gd")


func plugin_id() -> String:
	return "fire_trace"


func trace_enter(context: RefCounted, unit: Dictionary, trace: Dictionary, params: Dictionary) -> String:
	if not SupportScript.is_live_side(unit, "enemy") or context == null or not context.has_method(&"deal_damage"):
		return ""
	var amount := int(params.get("amount", 3))
	context.call(
		&"deal_damage",
		{},
		unit,
		amount,
		String(params.get("element", "火")),
		true,
		{"sourceType": "quality_board_trace"},
		DamagePropsScript.non_move_unpowered()
	)
	return "%s 触发%s：受到%d点火伤害。" % [
		SupportScript.unit_name(unit, "敌人"),
		SupportScript.trace_name(trace),
		amount,
	]


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_trace(params, {
		"amount": "nonnegative_int",
		"element": "nonempty_string",
	})
