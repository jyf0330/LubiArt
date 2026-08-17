extends RefCounted

const ParamSchemaScript := preload("res://core/battle/quality/quality_operation_param_schema.gd")
const SupportScript := preload("res://core/battle/quality/quality_operation_support.gd")


func plugin_id() -> String:
	return "permanent_attack_per_kills"


func after_attack(_context: RefCounted, attacker: Dictionary, _option: Dictionary, targets: Array, params: Dictionary) -> Array:
	var logs: Array = []
	var runtime := Dictionary(attacker.get("quality_runtime", {}))
	var kill_count: int = max(0, int(runtime.get("killCount", runtime.get("kill_count", 0))))
	var permanent_atk: int = max(0, int(runtime.get("permanentAtk", runtime.get("permanent_atk", 0))))
	var threshold: int = max(1, int(params.get("threshold", 5)))
	var amount := int(params.get("amount", 1))
	for target_value in targets:
		if int(Dictionary(target_value).get("hp", 0)) > 0:
			continue
		kill_count += 1
		if kill_count < threshold:
			continue
		kill_count -= threshold
		attacker["atk"] = int(attacker.get("atk", 0)) + amount
		permanent_atk += amount
		logs.append("%s：永久攻击+%d，当前攻击%d。" % [
			SupportScript.effect_name(attacker),
			amount,
			int(attacker.get("atk", 0)),
		])
	runtime["killCount"] = kill_count
	runtime["permanentAtk"] = permanent_atk
	attacker["quality_runtime"] = runtime
	return logs


func profile(params: Dictionary) -> Dictionary:
	return {"after_attack_rules": [SupportScript.lifecycle_rule(plugin_id(), params)]}


func _validate_params(params: Dictionary) -> Array[String]:
	return ParamSchemaScript.validate(params, {
		"threshold": "positive_int",
		"amount": "int",
	})
