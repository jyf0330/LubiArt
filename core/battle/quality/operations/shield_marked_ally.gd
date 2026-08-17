extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "shield_marked_ally"


func after_attack(context: RefCounted, attacker: Dictionary, option: Dictionary, _targets: Array, params: Dictionary) -> Array:
	var logs: Array = []
	var core_index := int(context.call(&"core_cell_index", option))
	var marked_cell := Dictionary(Dictionary(attacker.get("quality_runtime", {})).get("marked_cell", {}))
	for ally_value in Array(context.call(&"friendly_units_in_option", attacker, option)):
		var ally := Dictionary(ally_value)
		var ally_index := int(context.call(&"option_cell_index", option, ally))
		var matches := (
			not marked_cell.is_empty() and bool(context.call(&"mark_matches_unit", marked_cell, ally))
		) or (
			marked_cell.is_empty() and (ally_index == core_index or ally_index == 0)
		)
		if not matches:
			continue
		var before := int(ally.get("shield", 0))
		ally["shield"] = before + int(params.get("amount", 0))
		logs.append("%s 覆盖 %s：护盾 %d→%d。" % [
			SupportScript.effect_name(attacker),
			String(ally.get("name", "我方")),
			before,
			int(ally.get("shield", 0)),
		])
	return logs


func profile(params: Dictionary) -> Dictionary:
	return {"after_attack_rules": [SupportScript.lifecycle_rule(plugin_id(), params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"amount": "int"})
