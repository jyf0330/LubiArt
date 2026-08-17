extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "incoming_bonus_all_targets"


func after_attack(context: RefCounted, attacker: Dictionary, _option: Dictionary, targets: Array, params: Dictionary) -> Array:
	var amount := int(params.get("amount", 0))
	for target_value in targets:
		context.call(&"add_incoming_damage_bonus", Dictionary(target_value), amount)
	if targets.is_empty():
		return []
	return ["%s：命中目标下次受伤+%d。" % [SupportScript.effect_name(attacker), amount]]


func profile(params: Dictionary) -> Dictionary:
	return {"after_attack_rules": [SupportScript.lifecycle_rule(plugin_id(), params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"amount": "int"})
