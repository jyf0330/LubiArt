extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "heal_core_ally"


func after_attack(context: RefCounted, attacker: Dictionary, option: Dictionary, _targets: Array, params: Dictionary) -> Array:
	var logs: Array = []
	var core_index := int(context.call(&"core_cell_index", option))
	for ally_value in Array(context.call(&"friendly_units_in_option", attacker, option)):
		var ally := Dictionary(ally_value)
		if int(context.call(&"option_cell_index", option, ally)) != core_index:
			continue
		var healed := int(context.call(&"heal_unit", ally, int(params.get("amount", 0))))
		logs.append("%s 覆盖 %s：恢复%d生命。" % [
			SupportScript.effect_name(attacker),
			String(ally.get("name", "我方")),
			healed,
		])
	return logs


func profile(params: Dictionary) -> Dictionary:
	return {"after_attack_rules": [SupportScript.lifecycle_rule(plugin_id(), params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"amount": "nonnegative_int"})
