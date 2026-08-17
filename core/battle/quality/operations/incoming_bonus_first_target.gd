extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "incoming_bonus_first_target"


func after_attack(context: RefCounted, attacker: Dictionary, _option: Dictionary, targets: Array, params: Dictionary) -> Array:
	if targets.is_empty():
		return []
	var target := Dictionary(targets[0])
	var amount := int(params.get("amount", 0))
	context.call(&"add_incoming_damage_bonus", target, amount)
	return ["%s：%s 下次受伤+%d。" % [
		SupportScript.effect_name(attacker),
		String(target.get("name", "敌人")),
		amount,
	]]


func profile(params: Dictionary) -> Dictionary:
	return {"after_attack_rules": [SupportScript.lifecycle_rule(plugin_id(), params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"amount": "int"})
