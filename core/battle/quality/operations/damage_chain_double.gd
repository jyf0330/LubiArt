extends RefCounted

const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")
const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")


func plugin_id() -> String:
	return "damage_chain_double"


func modify_hit_damage(hit_context: Dictionary, current: int, _params: Dictionary) -> int:
	var attacker := Dictionary(hit_context.get("attacker", {}))
	var runtime := Dictionary(attacker.get("quality_runtime", {}))
	var damage := current
	if bool(hit_context.get("first_hit", false)):
		damage = max(1, int(floor(float(damage) / 2.0)))
	else:
		damage = max(damage, max(1, int(runtime.get("lastChainDamage", 1))) * 2)
	runtime["lastChainDamage"] = damage
	attacker["quality_runtime"] = runtime
	return damage


func profile(params: Dictionary) -> Dictionary:
	return {"damage_rules": [SupportScript.damage_rule("chain_double", params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {}, {"when": "condition_map"})
