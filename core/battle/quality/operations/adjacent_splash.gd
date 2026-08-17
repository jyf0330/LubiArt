extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "adjacent_splash"


func after_hit(context: RefCounted, attacker: Dictionary, target: Dictionary, params: Dictionary) -> Array:
	if target.is_empty():
		return []
	var logs: Array = []
	var pending_deaths: Array = []
	var amount := int(params.get("amount", 0))
	for adjacent_value in Array(context.call(&"adjacent_enemies", target)):
		var adjacent := Dictionary(adjacent_value)
		var result := Dictionary(context.call(
			&"deal_damage",
			attacker,
			adjacent,
			amount,
			String(attacker.get("element", "")),
			true,
			{"sourceType": "quality_splash", "deferDeathResolution": true},
			DamagePropsScript.non_move_unpowered()
		))
		if bool(result.get("pending_death", false)):
			pending_deaths.append({"source": attacker, "target": adjacent, "result": result})
		logs.append("%s 扩散 %s：溅射%d伤害。" % [
			SupportScript.effect_name(attacker),
			String(adjacent.get("name", "敌人")),
			amount,
		])
	for death_line in Array(context.call(&"resolve_damage_deaths", pending_deaths)):
		logs.append(String(death_line))
	return logs


func profile(params: Dictionary) -> Dictionary:
	return {"after_hit_rules": [SupportScript.lifecycle_rule(plugin_id(), params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"amount": "nonnegative_int"})
