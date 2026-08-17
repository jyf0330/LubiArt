extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "kill_chase"


func after_hit(context: RefCounted, attacker: Dictionary, target: Dictionary, params: Dictionary) -> Array:
	if int(target.get("hp", 0)) > 0:
		return []
	var nearest := Dictionary(context.call(&"nearest_enemy", attacker, [target]))
	if nearest.is_empty():
		return []
	var amount := int(params.get("amount", 0))
	context.call(
		&"deal_damage",
		attacker,
		nearest,
		amount,
		String(attacker.get("element", "")),
		true,
		{"sourceType": "quality_chase"},
		DamagePropsScript.move_damage()
	)
	return ["%s %s %s：追加%d伤害。" % [
		SupportScript.effect_name(attacker),
		String(params.get("verb", "追击")),
		String(nearest.get("name", "敌人")),
		amount,
	]]


func profile(params: Dictionary) -> Dictionary:
	return {"after_hit_rules": [SupportScript.lifecycle_rule(plugin_id(), params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {
		"amount": "nonnegative_int",
		"verb": "nonempty_string",
	})
