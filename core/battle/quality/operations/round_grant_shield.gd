extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "round_grant_shield"


func round_start(_context: RefCounted, unit: Dictionary, params: Dictionary) -> Array:
	var before := int(unit.get("shield", 0))
	unit["shield"] = before + int(params.get("amount", 0))
	return ["%s 触发%s：护盾 %d→%d。" % [
		String(unit.get("name", "我方")),
		SupportScript.effect_name(unit),
		before,
		int(unit.get("shield", 0)),
	]]


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"amount": "int"})
