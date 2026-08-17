extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "formation_shield"


func before_attack(context: RefCounted, attacker: Dictionary, option: Dictionary, params: Dictionary) -> Array:
	var logs: Array = []
	var runtime := Dictionary(attacker.get("quality_runtime", {}))
	var covered_units := Array(context.call(&"units_in_option", option))
	runtime["g28Active"] = covered_units.size() >= Array(option.get("cells", [])).size()
	if bool(runtime.get("g28Active", false)):
		for unit_value in covered_units:
			var unit := Dictionary(unit_value)
			if String(unit.get("side", "")) != "player":
				continue
			var before := int(unit.get("shield", 0))
			unit["shield"] = before + int(params.get("amount", 0))
			logs.append("%s 成阵覆盖 %s：护盾 %d→%d。" % [
				SupportScript.effect_name(attacker),
				String(unit.get("name", "我方")),
				before,
				int(unit.get("shield", 0)),
			])
	attacker["quality_runtime"] = runtime
	return logs


func profile(params: Dictionary) -> Dictionary:
	return {"before_attack_rules": [SupportScript.lifecycle_rule(plugin_id(), params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {"amount": "int"})
