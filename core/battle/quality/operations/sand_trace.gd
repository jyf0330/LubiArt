extends "res://core/battle/quality/quality_trace_operation_base.gd"

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const SupportScript := preload("res://core/battle/quality/quality_trace_operation_support.gd")


func plugin_id() -> String:
	return "sand_trace"


func trace_enter(context: RefCounted, unit: Dictionary, trace: Dictionary, params: Dictionary) -> String:
	if (
		not SupportScript.is_live_side(unit, "enemy")
		or context == null
		or not context.has_method(&"deal_damage")
		or not context.has_method(&"add_incoming_damage_bonus")
	):
		return ""
	var damage := int(params.get("damage", 2))
	var incoming := int(params.get("incoming", 2))
	context.call(
		&"deal_damage",
		{},
		unit,
		damage,
		String(params.get("element", "地")),
		false,
		{"sourceType": "quality_board_trace"},
		DamagePropsScript.non_move_unpowered()
	)
	context.call(&"add_incoming_damage_bonus", unit, incoming)
	return "%s 触发%s：受到%d点伤害，下次受伤+%d。" % [
		SupportScript.unit_name(unit, "敌人"),
		SupportScript.trace_name(trace),
		damage,
		incoming,
	]


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate_trace(params, {
		"damage": "nonnegative_int",
		"incoming": "int",
		"element": "nonempty_string",
	})
