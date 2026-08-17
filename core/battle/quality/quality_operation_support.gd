extends RefCounted


static func effect_name(unit: Dictionary, fallback: String = "") -> String:
	var upgrade := Dictionary(unit.get("quality_upgrade", {}))
	return String(upgrade.get("name", upgrade.get("id", fallback)))


static func matches(conditions: Dictionary, context: Dictionary) -> bool:
	for key_value in conditions.keys():
		var key := String(key_value)
		var expected: Variant = conditions[key_value]
		if key.ends_with("_min"):
			var base_key := key.trim_suffix("_min")
			if int(context.get(base_key, 0)) < int(expected):
				return false
		elif key.ends_with("_max"):
			var base_key := key.trim_suffix("_max")
			if int(context.get(base_key, 0)) > int(expected):
				return false
		elif context.get(key, null) != expected:
			return false
	return true


static func damage_rule(operation: String, params: Dictionary) -> Dictionary:
	return {
		"when": Dictionary(params.get("when", {})).duplicate(true),
		"operation": operation,
		"value": int(params.get("value", 0)),
		"numerator": int(params.get("numerator", 1)),
		"denominator": int(params.get("denominator", 1)),
	}


static func lifecycle_rule(operation: String, params: Dictionary) -> Dictionary:
	var result := params.duplicate(true)
	result["operation"] = operation
	return result
