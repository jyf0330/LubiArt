extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "chase_low_hp"


func after_attack(context: RefCounted, attacker: Dictionary, _option: Dictionary, _targets: Array, params: Dictionary) -> Array:
	var target := Dictionary(context.call(&"lowest_low_hp_enemy"))
	if target.is_empty():
		return []
	var amount := int(params.get("amount", 0))
	context.call(
		&"deal_damage",
		attacker,
		target,
		amount,
		String(attacker.get("element", "")),
		true,
		{"sourceType": "quality_chase"},
		DamagePropsScript.move_damage()
	)
	return ["%s 追击 %s：追加%d伤害。" % [
		SupportScript.effect_name(attacker),
		String(target.get("name", "敌人")),
		amount,
	]]


func profile(params: Dictionary) -> Dictionary:
	return {"after_attack_rules": [SupportScript.lifecycle_rule(plugin_id(), params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"amount": "nonnegative_int"})
