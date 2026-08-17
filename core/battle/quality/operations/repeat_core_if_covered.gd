extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "repeat_core_if_covered"


func after_attack(context: RefCounted, attacker: Dictionary, option: Dictionary, targets: Array, params: Dictionary) -> Array:
	if Array(context.call(&"units_in_option", option)).size() < int(params.get("minimum_units", 3)):
		return []
	var core_index := int(context.call(&"core_cell_index", option))
	for target_value in targets:
		var target := Dictionary(target_value)
		if int(context.call(&"option_cell_index", option, target)) != core_index or int(target.get("hp", 0)) <= 0:
			continue
		var damage: int = max(1, int(context.call(
			&"resolved_stat",
			attacker,
			"atk",
			{"hook": EffectHookIdsScript.QUALITY_REPEAT, "target": target}
		)))
		context.call(
			&"deal_damage",
			attacker,
			target,
			damage,
			String(attacker.get("element", "")),
			true,
			{"sourceType": "quality_repeat"},
			DamagePropsScript.move_damage()
		)
		return ["%s 核心再击 %s：追加%d伤害。" % [
			SupportScript.effect_name(attacker),
			String(target.get("name", "敌人")),
			damage,
		]]
	return []


func profile(params: Dictionary) -> Dictionary:
	return {"after_attack_rules": [SupportScript.lifecycle_rule(plugin_id(), params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"minimum_units": "nonnegative_int"})
